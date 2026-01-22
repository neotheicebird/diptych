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
    
    // Top Stream (Back Camera / Wide) -> Zone B
    AVCaptureDeviceInput *topInput;
    AVCaptureVideoDataOutput *topOutput;
    
    // Bottom Stream (Front Camera / Ultra Wide) -> Zone C
    AVCaptureDeviceInput *bottomInput;
    AVCaptureVideoDataOutput *bottomOutput;
    
    CameraDelegate *delegate;
    
    // A dedicated serial dispatch queue for processing camera frames.
    dispatch_queue_t cameraQueue;
    
    // Stream Data Container
    struct StreamData {
        Ref<ImageTexture> texture;
        PackedByteArray current_buffer;
        bool has_new_frame = false;
        int buffer_width = 0;
        int buffer_height = 0;
    };
    
    StreamData top_stream;
    StreamData bottom_stream;
    
    // Thread safety is critical because frames arrive on a background queue
    std::mutex buffer_mutex;
    
    bool is_multicam = false;

    /**
     * process_sample_buffer
     * 
     * Converts CMSampleBuffer to Godot buffer for a specific stream.
     * stream_id: 0 = Top, 1 = Bottom
     */
    void process_sample_buffer(CMSampleBufferRef sampleBuffer, int stream_id) {
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
            
            StreamData* target = (stream_id == 0) ? &top_stream : &bottom_stream;
            
            // Lazy-initialize/resize our Godot byte array
            if (target->current_buffer.size() != dataSize) {
                target->current_buffer.resize((int64_t)dataSize);
            }
            
            uint8_t *dest = target->current_buffer.ptrw();
            
            /**
             * Color Space Conversion: BGRA to RGBA
             */
            for (int y = 0; y < height; y++) {
                uint8_t *src_row = baseAddress + (y * bytesPerRow);
                uint8_t *dst_row = dest + (y * width * 4);
                for (int x = 0; x < width; x++) {
                    uint8_t *src_pixel = src_row + (x * 4);
                    uint8_t *dst_pixel = dst_row + (x * 4);
                    
                    dst_pixel[0] = src_pixel[2]; // B -> R
                    dst_pixel[1] = src_pixel[1]; // G -> G
                    dst_pixel[2] = src_pixel[0]; // R -> B
                    dst_pixel[3] = src_pixel[3]; // A
                }
            }
            
            target->buffer_width = width;
            target->buffer_height = height;
            target->has_new_frame = true;
            
            // Fallback Mode: If single cam (not multicam) and stream_id is 0,
            // verify if we should copy to bottom_stream as well?
            // Actually, in fallback mode, we might just want to use the same texture for both?
            // Or easier: manually copy to the other stream data so we have two independent textures
            // even if the source is the same. This simplifies the Godot side.
            if (!is_multicam && stream_id == 0) {
                 StreamData* mirror = &bottom_stream;
                 if (mirror->current_buffer.size() != dataSize) {
                    mirror->current_buffer.resize((int64_t)dataSize);
                 }
                 memcpy(mirror->current_buffer.ptrw(), dest, dataSize);
                 mirror->buffer_width = width;
                 mirror->buffer_height = height;
                 mirror->has_new_frame = true;
            }
        }
        
        // Unlock the buffer so the OS can reuse the memory for the next frame
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    }
};

@implementation CameraDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (self.cppImpl) {
        int stream_id = 0; // Default to Top/Primary
        if (self.cppImpl->is_multicam) {
            if (output == self.cppImpl->bottomOutput) {
                stream_id = 1;
            }
        }
        self.cppImpl->process_sample_buffer(sampleBuffer, stream_id);
    }
}
@end

CameraManager::CameraManager() {
    impl = new Impl();
    
    // Create the serial queue for camera processing
    impl->cameraQueue = dispatch_queue_create("com.diptych.cameraQueue", DISPATCH_QUEUE_SERIAL);
    
    // Initialize the Godot textures
    // Top Stream
    impl->top_stream.texture.instantiate();
    Ref<Image> imgTop = Image::create(1, 1, false, Image::FORMAT_RGBA8);
    impl->top_stream.texture->set_image(imgTop);
    
    // Bottom Stream
    impl->bottom_stream.texture.instantiate();
    Ref<Image> imgBot = Image::create(1, 1, false, Image::FORMAT_RGBA8);
    impl->bottom_stream.texture->set_image(imgBot);
    
    impl->delegate = [[CameraDelegate alloc] init];
    impl->delegate.cppImpl = impl;
}

CameraManager::~CameraManager() {
    stop();
    impl->delegate = nil;
    impl->session = nil;
    delete impl;
}

void CameraManager::start() {
    UtilityFunctions::print("CameraManager: Requesting access...");
    
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        if (granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UtilityFunctions::print("CameraManager: Access granted.");
                
                // Determine Session Type
                if (@available(iOS 13.0, *)) {
                    if ([AVCaptureMultiCamSession isMultiCamSupported]) {
                        impl->is_multicam = true;
                        impl->session = [[AVCaptureMultiCamSession alloc] init];
                        UtilityFunctions::print("CameraManager: MultiCam supported. Using AVCaptureMultiCamSession.");
                    } else {
                        impl->is_multicam = false;
                        impl->session = [[AVCaptureSession alloc] init];
                         UtilityFunctions::print("CameraManager: MultiCam NOT supported. Using AVCaptureSession.");
                    }
                } else {
                     impl->is_multicam = false;
                     impl->session = [[AVCaptureSession alloc] init];
                }
                
                if (!impl->is_multicam) {
                    impl->session.sessionPreset = AVCaptureSessionPreset1920x1080;
                }

                [impl->session beginConfiguration];
                
                // --- Setup Top Camera (Back) ---
                AVCaptureDevice *backDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
                NSError *error = nil;
                AVCaptureDeviceInput *backInput = [AVCaptureDeviceInput deviceInputWithDevice:backDevice error:&error];
                
                if (backDevice && !error && [impl->session canAddInput:backInput]) {
                    [impl->session addInput:backInput];
                    impl->topInput = backInput;
                    
                    AVCaptureVideoDataOutput *backOutput = [[AVCaptureVideoDataOutput alloc] init];
                    backOutput.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
                    [backOutput setSampleBufferDelegate:impl->delegate queue:impl->cameraQueue];
                    
                    if ([impl->session canAddOutput:backOutput]) {
                        [impl->session addOutput:backOutput];
                        impl->topOutput = backOutput;
                        
                        AVCaptureConnection *conn = [backOutput connectionWithMediaType:AVMediaTypeVideo];
                        if (conn.isVideoOrientationSupported) {
                            conn.videoOrientation = AVCaptureVideoOrientationPortrait;
                        }
                    }
                } else {
                    UtilityFunctions::print("CameraManager: Failed to configure Back Camera.");
                }

                // --- Setup Bottom Camera (Front) for MultiCam ---
                if (impl->is_multicam) {
                    AVCaptureDevice *frontDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
                    NSError *frontError = nil;
                    AVCaptureDeviceInput *frontInput = [AVCaptureDeviceInput deviceInputWithDevice:frontDevice error:&frontError];
                    
                    if (frontDevice && !frontError && [impl->session canAddInput:frontInput]) {
                        [impl->session addInput:frontInput]; // MultiCam allows multiple inputs
                        impl->bottomInput = frontInput;
                        
                        AVCaptureVideoDataOutput *frontOutput = [[AVCaptureVideoDataOutput alloc] init];
                        frontOutput.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
                        [frontOutput setSampleBufferDelegate:impl->delegate queue:impl->cameraQueue];
                        
                        if ([impl->session canAddOutput:frontOutput]) {
                            [impl->session addOutput:frontOutput];
                            impl->bottomOutput = frontOutput;
                            
                             AVCaptureConnection *conn = [frontOutput connectionWithMediaType:AVMediaTypeVideo];
                            if (conn.isVideoOrientationSupported) {
                                conn.videoOrientation = AVCaptureVideoOrientationPortrait;
                            }
                            // Mirror front camera usually
                            if (conn.isVideoMirroringSupported) {
                                conn.videoMirrored = YES;
                            }
                        }
                    } else {
                        UtilityFunctions::print("CameraManager: Failed to configure Front Camera for MultiCam.");
                    }
                }

                [impl->session commitConfiguration];
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

void CameraManager::update() {
    std::lock_guard<std::mutex> lock(impl->buffer_mutex);
    
    // Update Top Stream
    if (impl->top_stream.has_new_frame) {
        Ref<Image> img = Image::create_from_data(impl->top_stream.buffer_width, impl->top_stream.buffer_height, false, Image::FORMAT_RGBA8, impl->top_stream.current_buffer);
        impl->top_stream.texture->set_image(img);
        impl->top_stream.has_new_frame = false;
    }
    
    // Update Bottom Stream
    if (impl->bottom_stream.has_new_frame) {
        Ref<Image> img = Image::create_from_data(impl->bottom_stream.buffer_width, impl->bottom_stream.buffer_height, false, Image::FORMAT_RGBA8, impl->bottom_stream.current_buffer);
        impl->bottom_stream.texture->set_image(img);
        impl->bottom_stream.has_new_frame = false;
    }
}

Ref<ImageTexture> CameraManager::get_texture_top() const {
    return impl->top_stream.texture;
}

Ref<ImageTexture> CameraManager::get_texture_bottom() const {
    return impl->bottom_stream.texture;
}

bool CameraManager::is_multicam_supported() const {
    return impl->is_multicam;
}

Dictionary CameraManager::get_available_devices() const {
    Dictionary devices;
    
    // Physical device types we are interested in
    NSArray<AVCaptureDeviceType> *types = @[
        AVCaptureDeviceTypeBuiltInWideAngleCamera,
        AVCaptureDeviceTypeBuiltInTelephotoCamera,
        AVCaptureDeviceTypeBuiltInUltraWideCamera
    ];
    
    AVCaptureDeviceDiscoverySession *discovery = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:types mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
    
    for (AVCaptureDevice *device in discovery.devices) {
        String id = String([device.uniqueID UTF8String]);
        String name = String([device.localizedName UTF8String]);
        devices[id] = name;
    }
    
    return devices;
}

void CameraManager::set_device(int view_index, String device_id) {
    NSString *uuid = [NSString stringWithUTF8String:device_id.utf8().get_data()];
    
    dispatch_async(impl->cameraQueue, ^{
        [impl->session beginConfiguration];
        
        // 1. Identify Target Output and Current Input
        AVCaptureVideoDataOutput *targetOutput = (view_index == 0) ? impl->topOutput : impl->bottomOutput;
        AVCaptureDeviceInput *currentInput = (view_index == 0) ? impl->topInput : impl->bottomInput;
        
        // In fallback mode, we only manipulate the primary input/output logic
        if (!impl->is_multicam) {
            // view_index 0 and 1 both rely on topInput/topOutput effectively for the source
            // But wait, in start(), topOutput is linked to topInput.
            // set_device should change the input that feeds the views.
            targetOutput = impl->topOutput;
            currentInput = impl->topInput;
        }

        // 2. Check if requested device is already the current input for this view
        if (currentInput && [currentInput.device.uniqueID isEqualToString:uuid]) {
            [impl->session commitConfiguration];
            return; 
        }

        // 3. Find or Create New Input
        AVCaptureDevice *newDevice = [AVCaptureDevice deviceWithUniqueID:uuid];
        if (!newDevice) {
             UtilityFunctions::print("CameraManager: Device not found ", device_id);
             [impl->session commitConfiguration];
             return;
        }

        AVCaptureDeviceInput *newInput = nil;
        // Check if this device is already being used by the session
        for (AVCaptureDeviceInput *input in impl->session.inputs) {
            if ([input.device.uniqueID isEqualToString:uuid]) {
                newInput = input;
                break;
            }
        }
        
        if (!newInput) {
            NSError *error = nil;
            newInput = [AVCaptureDeviceInput deviceInputWithDevice:newDevice error:&error];
            if (error || !newInput) {
                UtilityFunctions::print("CameraManager: Could not create input for device.");
                [impl->session commitConfiguration];
                return;
            }
        }

        // 4. Swap Inputs
        // Check if old input is in use by the OTHER view (only relevant in MultiCam)
        bool oldInputInUseByOther = false;
        if (impl->is_multicam) {
            AVCaptureDeviceInput *otherInput = (view_index == 0) ? impl->bottomInput : impl->topInput;
            if (otherInput == currentInput) {
                oldInputInUseByOther = true;
            }
        }
        
        if (currentInput && !oldInputInUseByOther) {
             [impl->session removeInput:currentInput];
        }
        
        if (![impl->session.inputs containsObject:newInput]) {
            if ([impl->session canAddInput:newInput]) {
                [impl->session addInput:newInput];
            } else {
                 UtilityFunctions::print("CameraManager: Cannot add new input.");
                 // Try to restore old input?
                 if (currentInput && !oldInputInUseByOther && [impl->session canAddInput:currentInput]) {
                     [impl->session addInput:currentInput];
                 }
                 [impl->session commitConfiguration];
                 return;
            }
        }
        
        // Update Pointers
        if (view_index == 0) impl->topInput = newInput;
        else if (impl->is_multicam) impl->bottomInput = newInput;
        else impl->topInput = newInput;
        
        // 5. Manage Connections
        // In MultiCam, we need to ensure the new input is connected to the target output.
        if (impl->is_multicam) {
            // Remove existing connection for this output if strictly needed?
            // Or just add new connection.
            AVCaptureConnection *existingConn = [targetOutput connectionWithMediaType:AVMediaTypeVideo];
            if (existingConn) {
                [impl->session removeConnection:existingConn];
            }
            
            AVCaptureConnection *newConn = [[AVCaptureConnection alloc] initWithInputPorts:newInput.ports output:targetOutput];
            if ([impl->session canAddConnection:newConn]) {
                [impl->session addConnection:newConn];
            } else {
                UtilityFunctions::print("CameraManager: Failed to add connection for new input.");
            }
        }
        
        // 6. Orientation & Mirroring
        AVCaptureConnection *conn = [targetOutput connectionWithMediaType:AVMediaTypeVideo];
        if (conn) {
            if (conn.isVideoOrientationSupported) {
                conn.videoOrientation = AVCaptureVideoOrientationPortrait;
            }
            if (conn.isVideoMirroringSupported) {
                 conn.videoMirrored = (newDevice.position == AVCaptureDevicePositionFront);
            }
        }
        
        [impl->session commitConfiguration];
    });
}


