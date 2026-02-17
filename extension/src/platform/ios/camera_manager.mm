#include "../../camera_manager.h"

#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
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
 * PhotoCaptureDelegate (Objective-C)
 *
 * EDUCATIONAL:
 * AVCapturePhotoOutput delivers still-image results asynchronously.
 * We keep a tiny delegate object per stream so we can associate the result
 * with the correct top/bottom capture.
 */
@interface PhotoCaptureDelegate : NSObject <AVCapturePhotoCaptureDelegate>
@property (nonatomic, assign) CameraManager::Impl *cppImpl;
@property (nonatomic, assign) NSInteger streamId;
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
    AVCapturePhotoOutput *topPhotoOutput;
    
    // Bottom Stream (Front Camera / Ultra Wide) -> Zone C
    AVCaptureDeviceInput *bottomInput;
    AVCaptureVideoDataOutput *bottomOutput;
    AVCapturePhotoOutput *bottomPhotoOutput;
    
    CameraDelegate *delegate;
    PhotoCaptureDelegate *topPhotoDelegate;
    PhotoCaptureDelegate *bottomPhotoDelegate;
    
    // A dedicated serial dispatch queue for processing camera frames.
    dispatch_queue_t cameraQueue;
    
    // A dedicated serial dispatch queue for photo capture + compositing work.
    dispatch_queue_t photoQueue;
    
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
    
    // Thread safety for still capture state
    std::mutex capture_mutex;
    
    // Thread safety for layout inputs coming from Godot
    std::mutex layout_mutex;
    
    bool is_multicam = false;
    
    std::function<void()> permission_callback;
    
    // EDUCATIONAL:
    // Layout values are provided by Godot so the compositor can match the UI exactly.
    float viewer_width = 1.0f;
    float viewer_height = 1.0f;
    float separator_thickness = 1.0f;
    float separator_r = 1.0f;
    float separator_g = 1.0f;
    float separator_b = 1.0f;
    float separator_a = 0.2f;
    
    // EDUCATIONAL:
    // Capture lifecycle state for coordinating top/bottom still images.
    // We hold strong references so the images stay alive until compositing finishes.
    bool is_capturing = false;
    int pending_photo_count = 0;
    __strong UIImage *top_photo = nil;
    __strong UIImage *bottom_photo = nil;
    
    // Callbacks back into Godot (through NativeBridge).
    std::function<void()> image_save_started_callback;
    std::function<void(PackedByteArray)> image_save_finished_callback;

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
    
    /**
     * EDUCATIONAL:
     * Photo capture helpers for WYSIWYG split image compositing.
     */
    void capture_split_image();
    void handle_captured_photo(UIImage *image, int stream_id);
    UIImage *crop_to_aspect(UIImage *image, CGFloat target_aspect);
    UIImage *compose_split_image(UIImage *top_image, UIImage *bottom_image);
    PackedByteArray create_thumbnail_bytes(UIImage *image);
    void save_to_library(UIImage *image);
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

@implementation PhotoCaptureDelegate
- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    // EDUCATIONAL:
    // AVCapturePhoto delivers a high-quality still image.
    // We turn it into a UIImage so the compositor can crop and stitch.
    if (!self.cppImpl) {
        return;
    }
    
    if (error) {
        self.cppImpl->handle_captured_photo(nil, (int)self.streamId);
        return;
    }
    
    NSData *data = [photo fileDataRepresentation];
    if (!data) {
        self.cppImpl->handle_captured_photo(nil, (int)self.streamId);
        return;
    }
    
    UIImage *image = [UIImage imageWithData:data];
    if (!image) {
        self.cppImpl->handle_captured_photo(nil, (int)self.streamId);
        return;
    }
    
    self.cppImpl->handle_captured_photo(image, (int)self.streamId);
}
@end

CameraManager::CameraManager() {
    impl = new Impl();
    
    // Create the serial queue for camera processing
    impl->cameraQueue = dispatch_queue_create("com.diptych.cameraQueue", DISPATCH_QUEUE_SERIAL);
    // EDUCATIONAL:
    // Still capture and compositing can be heavier than live video.
    // We keep a separate queue so photo work never blocks video updates.
    impl->photoQueue = dispatch_queue_create("com.diptych.photoQueue", DISPATCH_QUEUE_SERIAL);
    
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

    // EDUCATIONAL:
    // We keep one photo delegate per stream so each still image is routed correctly.
    impl->topPhotoDelegate = [[PhotoCaptureDelegate alloc] init];
    impl->topPhotoDelegate.cppImpl = impl;
    impl->topPhotoDelegate.streamId = 0;
    
    impl->bottomPhotoDelegate = [[PhotoCaptureDelegate alloc] init];
    impl->bottomPhotoDelegate.cppImpl = impl;
    impl->bottomPhotoDelegate.streamId = 1;
}

CameraManager::~CameraManager() {
    stop();
    impl->delegate = nil;
    // EDUCATIONAL:
    // Releasing Objective-C delegates avoids dangling callbacks after shutdown.
    impl->topPhotoDelegate = nil;
    impl->bottomPhotoDelegate = nil;
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
                    
                    // EDUCATIONAL:
                    // A dedicated photo output lets us request high-resolution stills for compositing.
                    AVCapturePhotoOutput *backPhotoOutput = [[AVCapturePhotoOutput alloc] init];
                    if ([impl->session canAddOutput:backPhotoOutput]) {
                        [impl->session addOutput:backPhotoOutput];
                        impl->topPhotoOutput = backPhotoOutput;
                        // EDUCATIONAL:
                        // Request high-resolution capture when available; the system will clamp if unsupported.
                        backPhotoOutput.highResolutionCaptureEnabled = YES;
                        
                        AVCaptureConnection *photoConn = [backPhotoOutput connectionWithMediaType:AVMediaTypeVideo];
                        if (photoConn.isVideoOrientationSupported) {
                            photoConn.videoOrientation = AVCaptureVideoOrientationPortrait;
                        }
                        if (photoConn.isVideoMirroringSupported) {
                            photoConn.videoMirrored = NO;
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
                        
                        // EDUCATIONAL:
                        // The front stream needs its own photo output for WYSIWYG dual capture.
                        AVCapturePhotoOutput *frontPhotoOutput = [[AVCapturePhotoOutput alloc] init];
                        if ([impl->session canAddOutput:frontPhotoOutput]) {
                            [impl->session addOutput:frontPhotoOutput];
                            impl->bottomPhotoOutput = frontPhotoOutput;
                            // EDUCATIONAL:
                            // Request high-resolution capture when available; the system will clamp if unsupported.
                            frontPhotoOutput.highResolutionCaptureEnabled = YES;
                            
                            AVCaptureConnection *photoConn = [frontPhotoOutput connectionWithMediaType:AVMediaTypeVideo];
                            if (photoConn.isVideoOrientationSupported) {
                                photoConn.videoOrientation = AVCaptureVideoOrientationPortrait;
                            }
                            if (photoConn.isVideoMirroringSupported) {
                                photoConn.videoMirrored = YES;
                            }
                        }
                    } else {
                        UtilityFunctions::print("CameraManager: Failed to configure Front Camera for MultiCam.");
                    }
                }

                [impl->session commitConfiguration];
                [impl->session startRunning];
                UtilityFunctions::print("CameraManager: Session started.");
                
                if (impl->permission_callback) {
                    impl->permission_callback();
                }
            });
        } else {
             UtilityFunctions::print("CameraManager: Access denied.");
        }
    }];
}

void CameraManager::Impl::capture_split_image() {
    // EDUCATIONAL:
    // Still capture is asynchronous. We dispatch onto a dedicated queue and
    // guard with a mutex so only one capture pipeline runs at a time.
    dispatch_async(photoQueue, ^{
        bool capture_bottom = false;
        
        {
            std::lock_guard<std::mutex> lock(capture_mutex);
            if (!session || is_capturing || !topPhotoOutput) {
                return;
            }
            
            is_capturing = true;
            top_photo = nil;
            bottom_photo = nil;
            pending_photo_count = (is_multicam && bottomPhotoOutput) ? 2 : 1;
            capture_bottom = (pending_photo_count == 2);
        }
        
        if (image_save_started_callback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                image_save_started_callback();
            });
        }
        
        // EDUCATIONAL:
        // Photo settings request high quality stills; the system clamps to supported limits.
        AVCapturePhotoSettings *topSettings = [AVCapturePhotoSettings photoSettings];
        topSettings.flashMode = AVCaptureFlashModeOff;
        topSettings.highResolutionPhotoEnabled = YES;
        if (@available(iOS 13.0, *)) {
            topSettings.photoQualityPrioritization = AVCapturePhotoQualityPrioritizationQuality;
        }
        
        [topPhotoOutput capturePhotoWithSettings:topSettings delegate:topPhotoDelegate];
        
        if (capture_bottom) {
            AVCapturePhotoSettings *bottomSettings = [AVCapturePhotoSettings photoSettings];
            bottomSettings.flashMode = AVCaptureFlashModeOff;
            bottomSettings.highResolutionPhotoEnabled = YES;
            if (@available(iOS 13.0, *)) {
                bottomSettings.photoQualityPrioritization = AVCapturePhotoQualityPrioritizationQuality;
            }
            
            [bottomPhotoOutput capturePhotoWithSettings:bottomSettings delegate:bottomPhotoDelegate];
        }
    });
}

void CameraManager::Impl::handle_captured_photo(UIImage *image, int stream_id) {
    UIImage *top_image = nil;
    UIImage *bottom_image = nil;
    bool ready_to_compose = false;
    
    {
        std::lock_guard<std::mutex> lock(capture_mutex);
        if (!is_capturing) {
            return;
        }
        
        if (!image) {
            // EDUCATIONAL:
            // If capture fails, reset the state and notify the UI to stop the spinner.
            is_capturing = false;
            pending_photo_count = 0;
            
            if (image_save_finished_callback) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    image_save_finished_callback(PackedByteArray());
                });
            }
            return;
        }
        
        if (stream_id == 0) {
            top_photo = image;
        } else {
            bottom_photo = image;
        }
        
        pending_photo_count = MAX(pending_photo_count - 1, 0);
        if (pending_photo_count == 0) {
            top_image = top_photo;
            bottom_image = bottom_photo ? bottom_photo : top_photo;
            ready_to_compose = (top_image != nil);
        }
    }
    
    if (ready_to_compose) {
        dispatch_async(photoQueue, ^{
            UIImage *composed = compose_split_image(top_image, bottom_image);
            save_to_library(composed);
        });
    }
}

UIImage *CameraManager::Impl::crop_to_aspect(UIImage *image, CGFloat target_aspect) {
    if (!image || target_aspect <= 0.0f) {
        return image;
    }
    
    CGImageRef source = image.CGImage;
    if (!source) {
        return image;
    }
    
    size_t width = CGImageGetWidth(source);
    size_t height = CGImageGetHeight(source);
    if (width == 0 || height == 0) {
        return image;
    }
    
    CGFloat image_aspect = (CGFloat)width / (CGFloat)height;
    CGRect crop_rect = CGRectZero;
    
    if (image_aspect > target_aspect) {
        CGFloat new_width = height * target_aspect;
        CGFloat x = (width - new_width) * 0.5f;
        crop_rect = CGRectMake(x, 0.0f, new_width, height);
    } else {
        CGFloat new_height = width / target_aspect;
        CGFloat y = (height - new_height) * 0.5f;
        crop_rect = CGRectMake(0.0f, y, width, new_height);
    }
    
    CGImageRef cropped = CGImageCreateWithImageInRect(source, crop_rect);
    if (!cropped) {
        return image;
    }
    
    UIImage *result = [UIImage imageWithCGImage:cropped scale:1.0 orientation:image.imageOrientation];
    CGImageRelease(cropped);
    return result;
}

UIImage *CameraManager::Impl::compose_split_image(UIImage *top_image, UIImage *bottom_image) {
    if (!top_image) {
        return nil;
    }
    
    float view_width = 1.0f;
    float view_height = 1.0f;
    float separator_size = 1.0f;
    float sep_r = 1.0f;
    float sep_g = 1.0f;
    float sep_b = 1.0f;
    float sep_a = 0.2f;
    
    {
        std::lock_guard<std::mutex> lock(layout_mutex);
        view_width = viewer_width;
        view_height = viewer_height;
        separator_size = separator_thickness;
        sep_r = separator_r;
        sep_g = separator_g;
        sep_b = separator_b;
        sep_a = separator_a;
    }
    
    CGFloat target_aspect = (view_width > 0.0f && view_height > 0.0f) ? (view_width / view_height) : 0.0f;
    if (target_aspect <= 0.0f) {
        CGSize size = top_image.size;
        target_aspect = (size.height > 0.0f) ? (size.width / size.height) : 1.0f;
    }
    
    UIImage *top_crop = crop_to_aspect(top_image, target_aspect);
    UIImage *bottom_crop = crop_to_aspect(bottom_image ? bottom_image : top_image, target_aspect);
    
    size_t top_width = CGImageGetWidth(top_crop.CGImage);
    size_t bottom_width = CGImageGetWidth(bottom_crop.CGImage);
    size_t output_width = MIN(top_width, bottom_width);
    if (output_width == 0) {
        return nil;
    }
    
    size_t half_height = (size_t)round((double)output_width / (double)target_aspect);
    if (half_height == 0) {
        return nil;
    }
    
    float scale = (view_width > 0.0f) ? (output_width / view_width) : 1.0f;
    size_t separator_px = (size_t)MAX(1.0f, round(separator_size * scale));
    size_t output_height = (half_height * 2) + separator_px;
    
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1.0;
    format.opaque = YES;
    
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(output_width, output_height) format:format];
    UIColor *separator_color = [UIColor colorWithRed:sep_r green:sep_g blue:sep_b alpha:sep_a];
    
    UIImage *composed = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        // EDUCATIONAL:
        // Draw top, separator, and bottom in a single pass to avoid extra copies.
        CGRect top_rect = CGRectMake(0.0f, 0.0f, output_width, half_height);
        CGRect separator_rect = CGRectMake(0.0f, half_height, output_width, separator_px);
        CGRect bottom_rect = CGRectMake(0.0f, half_height + separator_px, output_width, half_height);
        
        [[UIColor blackColor] setFill];
        UIRectFill(CGRectMake(0.0f, 0.0f, output_width, output_height));
        
        [top_crop drawInRect:top_rect];
        [separator_color setFill];
        UIRectFill(separator_rect);
        [bottom_crop drawInRect:bottom_rect];
    }];
    
    return composed;
}

PackedByteArray CameraManager::Impl::create_thumbnail_bytes(UIImage *image) {
    PackedByteArray bytes;
    if (!image) {
        return bytes;
    }
    
    const CGFloat target_size = 256.0f;
    
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1.0;
    format.opaque = YES;
    
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(target_size, target_size) format:format];
    CGSize image_size = image.size;
    if (image_size.width <= 0.0f || image_size.height <= 0.0f) {
        return bytes;
    }
    
    CGFloat scale = MAX(target_size / image_size.width, target_size / image_size.height);
    CGSize draw_size = CGSizeMake(image_size.width * scale, image_size.height * scale);
    CGRect draw_rect = CGRectMake((target_size - draw_size.width) * 0.5f, (target_size - draw_size.height) * 0.5f, draw_size.width, draw_size.height);
    
    UIImage *thumb = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [image drawInRect:draw_rect];
    }];
    
    NSData *png_data = UIImagePNGRepresentation(thumb);
    if (!png_data) {
        return bytes;
    }
    
    bytes.resize((int64_t)png_data.length);
    memcpy(bytes.ptrw(), png_data.bytes, png_data.length);
    return bytes;
}

void CameraManager::Impl::save_to_library(UIImage *image) {
    // EDUCATIONAL:
    // Saving to Photos runs through PHPhotoLibrary and finishes asynchronously.
    if (!image) {
        if (image_save_finished_callback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                image_save_finished_callback(PackedByteArray());
            });
        }
        std::lock_guard<std::mutex> lock(capture_mutex);
        is_capturing = false;
        pending_photo_count = 0;
        return;
    }
    
    PHPhotoLibrary *library = [PHPhotoLibrary sharedPhotoLibrary];
    [library performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:image];
    } completionHandler:^(BOOL success, NSError *error) {
        PackedByteArray thumbnail_bytes = create_thumbnail_bytes(image);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (image_save_finished_callback) {
                image_save_finished_callback(thumbnail_bytes);
            }
        });
        
        std::lock_guard<std::mutex> lock(capture_mutex);
        is_capturing = false;
        pending_photo_count = 0;
        
        if (!success && error) {
            UtilityFunctions::print("CameraManager: Photo save failed.");
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

void CameraManager::set_zoom_factor(int view_index, float zoom_factor) {
    if (!impl->session) return;
    
    dispatch_async(impl->cameraQueue, ^{
        AVCaptureDeviceInput* input = (view_index == 0) ? impl->topInput : impl->bottomInput;
        if (!impl->is_multicam) input = impl->topInput;
        
        if (!input) return;
        AVCaptureDevice *device = input.device;
        
        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            CGFloat maxZoom = device.activeFormat.videoMaxZoomFactor;
            // Cap at reasonable 10x or device max, whichever is lower, to prevent extreme digital noise?
            // Spec doesn't strictly limit, but 10x is a safe practical limit for UI gestures.
            // Actually, let's respect device max but maybe the UI should clamp.
            // We'll just clamp to device limits here.
            CGFloat safeZoom = MIN(MAX(zoom_factor, 1.0), maxZoom);
            
            [device setVideoZoomFactor:safeZoom];
            [device unlockForConfiguration];
        }
    });
}

void CameraManager::set_focus_point(int view_index, float x, float y) {
    if (!impl->session) return;
    
    // Dispatch to camera queue to access device safely
    dispatch_async(impl->cameraQueue, ^{
        AVCaptureDeviceInput* input = (view_index == 0) ? impl->topInput : impl->bottomInput;
        if (!impl->is_multicam) input = impl->topInput;
        
        if (!input) return;
        AVCaptureDevice *device = input.device;
        
        // Coordinate Conversion for Portrait Orientation
        // setFocusPointOfInterest requires Sensor Coordinates (0..1, 0..1)
        // We assume the app is locked to Portrait.
        CGPoint point;
        if (device.position == AVCaptureDevicePositionFront) {
            // Front Camera (Portrait, Mirrored usually)
            // Screen X -> Sensor Y
            // Screen Y -> Sensor X
            // Mirrored X means 1-x? Or is it already handled?
            // Standard Front Portrait mapping:
            point = CGPointMake(y, x); 
        } else {
            // Back Camera (Portrait)
            // Screen (0,0) Top-Left -> Sensor (0.5, ?)
            // Standard Back Portrait mapping:
            point = CGPointMake(y, 1.0 - x);
        }

        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            // Focus
            if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
                [device setFocusPointOfInterest:point];
                [device setFocusMode:AVCaptureFocusModeAutoFocus];
            }
            
            // Exposure
            if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
                [device setExposurePointOfInterest:point];
                [device setExposureMode:AVCaptureExposureModeAutoExpose];
            }
            
            [device unlockForConfiguration];
        }
    });
}

void CameraManager::trigger_haptic_impact() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator prepare];
        [generator impactOccurred];
    });
}

void CameraManager::capture_split_image() {
    if (impl) {
        impl->capture_split_image();
    }
}

void CameraManager::set_composite_layout(float viewer_width, float viewer_height, float separator_thickness, Color separator_color) {
    if (!impl) {
        return;
    }
    
    // EDUCATIONAL:
    // We lock layout updates so the compositor can read consistent values.
    std::lock_guard<std::mutex> lock(impl->layout_mutex);
    impl->viewer_width = MAX(viewer_width, 1.0f);
    impl->viewer_height = MAX(viewer_height, 1.0f);
    impl->separator_thickness = MAX(separator_thickness, 1.0f);
    impl->separator_r = separator_color.r;
    impl->separator_g = separator_color.g;
    impl->separator_b = separator_color.b;
    impl->separator_a = separator_color.a;
}

void CameraManager::set_image_save_callbacks(std::function<void()> on_save_started, std::function<void(PackedByteArray)> on_save_finished) {
    if (!impl) {
        return;
    }
    
    // EDUCATIONAL:
    // We store these callbacks so the Objective-C layer can notify Godot on save state.
    impl->image_save_started_callback = on_save_started;
    impl->image_save_finished_callback = on_save_finished;
}

void CameraManager::open_photo_library() {
    // EDUCATIONAL:
    // Opening the Photos app must occur on the main thread.
    dispatch_async(dispatch_get_main_queue(), ^{
        NSURL *url = [NSURL URLWithString:@"photos-redirect://"];
        if (!url) {
            return;
        }
        
        UIApplication *app = [UIApplication sharedApplication];
        // EDUCATIONAL:
        // We call openURL directly to avoid requiring LSApplicationQueriesSchemes for canOpenURL.
        [app openURL:url options:@{} completionHandler:nil];
    });
}

void CameraManager::set_permission_callback(std::function<void()> callback) {
    impl->permission_callback = callback;
}
