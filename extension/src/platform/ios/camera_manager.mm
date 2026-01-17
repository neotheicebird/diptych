#include "../../camera_manager.h"

#import <AVFoundation/AVFoundation.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/image.hpp>
#include <mutex>

using namespace godot;

/**
 * CameraDelegate (Objective-C)
 * 
 * In iOS development, delegates are a core pattern for handling asynchronous events.
 * Here, we implement AVCaptureVideoDataOutputSampleBufferDelegate to receive
 * individual video frames (sample buffers) as they are captured by the hardware.
 */
@interface CameraDelegate : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, assign) CameraManager::Impl *cppImpl;
@end

/**
 * CameraManager::Impl
 * 
 * We use the PIMPL (Pointer to IMPLementation) idiom to hide Objective-C types
 * from the C++ header file. This keeps the Godot-facing API clean C++.
 */
struct CameraManager::Impl {
    // AVFoundation components for managing the camera lifecycle
    AVCaptureSession *session;
    AVCaptureDeviceInput *deviceInput;
    AVCaptureVideoDataOutput *videoOutput;
    CameraDelegate *delegate;
    
    // A dedicated serial dispatch queue for processing camera frames.
    // This ensures we don't block the main UI/Godot thread during pixel manipulation.
    dispatch_queue_t cameraQueue;
    
    // Godot resources that hold the camera feed data
    Ref<ImageTexture> texture;
    PackedByteArray current_buffer;
    
    // Thread safety is critical because frames arrive on a background queue
    // while Godot reads them on the main thread during 'update()'.
    std::mutex buffer_mutex;
    bool has_new_frame = false;
    int buffer_width = 0;
    int buffer_height = 0;

    /**
     * process_sample_buffer
     * 
     * This is the heart of the native-to-Godot bridge. It converts the iOS-specific
     * CMSampleBuffer into a format Godot understands.
     */
    void process_sample_buffer(CMSampleBufferRef sampleBuffer) {
        // Retrieve the image buffer (pixel data) from the sample buffer
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if (!imageBuffer) return;

        // Lock the buffer to ensure memory safety while we read from it
        CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

        int width = (int)CVPixelBufferGetWidth(imageBuffer);
        int height = (int)CVPixelBufferGetHeight(imageBuffer);
        uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        
        // RGBA8 format uses 4 bytes per pixel (Red, Green, Blue, Alpha)
        long dataSize = width * height * 4;

        {
            // Lock the mutex to protect current_buffer and metadata during the copy
            std::lock_guard<std::mutex> lock(buffer_mutex);
            
            // Lazy-initialize/resize our Godot byte array
            if (current_buffer.size() != dataSize) {
                current_buffer.resize((int64_t)dataSize);
            }
            
            uint8_t *dest = current_buffer.ptrw();
            
            /**
             * Color Space Conversion: BGRA to RGBA
             * 
             * iOS cameras typically output BGRA (Blue-Green-Red-Alpha).
             * Godot's FORMAT_RGBA8 expects RGBA. We perform the swap here.
             * Optimization Note: We could use vImage (Accelerate framework) for
             * high-performance SIMD-accelerated swizzling if needed.
             */
            for (int y = 0; y < height; y++) {
                uint8_t *src_row = baseAddress + (y * bytesPerRow);
                uint8_t *dst_row = dest + (y * width * 4);
                for (int x = 0; x < width; x++) {
                    uint8_t *src_pixel = src_row + (x * 4);
                    uint8_t *dst_pixel = dst_row + (x * 4);
                    
                    dst_pixel[0] = src_pixel[2]; // Source Blue -> Destination Red
                    dst_pixel[1] = src_pixel[1]; // Source Green -> Destination Green
                    dst_pixel[2] = src_pixel[0]; // Source Red -> Destination Blue
                    dst_pixel[3] = src_pixel[3]; // Alpha remains same
                }
            }
            
            buffer_width = width;
            buffer_height = height;
            has_new_frame = true;
        }
        
        // Unlock the buffer so the OS can reuse the memory for the next frame
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    }
};

@implementation CameraDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (self.cppImpl) {
        self.cppImpl->process_sample_buffer(sampleBuffer);
    }
}
@end

CameraManager::CameraManager() {
    impl = new Impl();
    
    // Initialize the AVCaptureSession - the central hub for iOS camera management
    impl->session = [[AVCaptureSession alloc] init];
    // 1080p provides a good balance between resolution and processing overhead
    impl->session.sessionPreset = AVCaptureSessionPreset1920x1080;
    
    // Connect our delegate to the session's data output
    impl->delegate = [[CameraDelegate alloc] init];
    impl->delegate.cppImpl = impl;
    
    // Create the serial queue for camera processing
    impl->cameraQueue = dispatch_queue_create("com.diptych.cameraQueue", DISPATCH_QUEUE_SERIAL);
    
    // Initialize the Godot texture that GDScript will eventually display
    impl->texture.instantiate();
    // Start with a 1x1 placeholder to avoid null references in shaders
    Ref<Image> img = Image::create(1, 1, false, Image::FORMAT_RGBA8);
    impl->texture->set_image(img);
}

CameraManager::~CameraManager() {
    stop();
    impl->delegate = nil;
    impl->session = nil;
    delete impl;
}

void CameraManager::start() {
    UtilityFunctions::print("CameraManager: Requesting access...");
    
    /**
     * Privacy and Permissions
     * 
     * iOS requires explicit user permission to access the camera.
     * The completion handler runs asynchronously once the user decides.
     */
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        if (granted) {
            // Permissions are granted, now we configure the session on the main queue
            dispatch_async(dispatch_get_main_queue(), ^{
                UtilityFunctions::print("CameraManager: Access granted.");
                
                // Select the default back-facing wide-angle camera
                AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
                
                NSError *error = nil;
                AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
                
                if (error) {
                    UtilityFunctions::print("CameraManager: Error creating input: ", error.localizedDescription.UTF8String);
                    return;
                }
                
                // Group configuration changes to minimize performance impact
                [impl->session beginConfiguration];
                
                // Attach the hardware input to the session
                if ([impl->session canAddInput:input]) {
                    [impl->session addInput:input];
                    impl->deviceInput = input;
                }
                
                // Configure the data output for raw pixel access
                AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
                // Request BGRA format explicitly
                output.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
                [output setSampleBufferDelegate:impl->delegate queue:impl->cameraQueue];
                
                if ([impl->session canAddOutput:output]) {
                    [impl->session addOutput:output];
                    impl->videoOutput = output;
                    
                    // Handle device orientation. Most mobile apps are locked to Portrait.
                    AVCaptureConnection *conn = [output connectionWithMediaType:AVMediaTypeVideo];
                    if (conn.isVideoOrientationSupported) {
                        conn.videoOrientation = AVCaptureVideoOrientationPortrait;
                    }
                }
                
                [impl->session commitConfiguration];
                // Start the capture flow
                [impl->session startRunning];
                UtilityFunctions::print("CameraManager: Session started.");
            });
        } else {
             UtilityFunctions::print("CameraManager: Access denied.");
        }
    }];
}

void CameraManager::stop() {
    if (impl->session && impl->session.isRunning) {
        [impl->session stopRunning];
    }
}

/**
 * update()
 * 
 * This is called from Godot's _process() via the NativeBridge.
 * It checks if a new frame has been processed by the background queue and,
 * if so, uploads it to the GPU by updating the ImageTexture.
 */
void CameraManager::update() {
    // Thread-safe check for new frame data
    std::lock_guard<std::mutex> lock(impl->buffer_mutex);
    if (impl->has_new_frame) {
        // Create a Godot Image wrapper around our raw pixel buffer
        // FORMAT_RGBA8 matches our manual conversion in process_sample_buffer
        Ref<Image> img = Image::create_from_data(impl->buffer_width, impl->buffer_height, false, Image::FORMAT_RGBA8, impl->current_buffer);
        
        // Update the texture. This triggers an internal GPU upload.
        impl->texture->set_image(img);
        
        impl->has_new_frame = false;
    }
}

Ref<ImageTexture> CameraManager::get_texture() const {
    return impl->texture;
}


