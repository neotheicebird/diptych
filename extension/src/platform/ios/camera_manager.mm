#include "../../camera_manager.h"

#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <algorithm>
#include <cstring>
#include <mutex>
#include <vector>

using namespace godot;

namespace {

struct FrameSnapshot {
	PackedByteArray rgba;
	int width = 0;
	int height = 0;
	bool valid = false;
};

struct SlotSpec {
	String stream_id;
	Rect2 normalized_rect;
	int z_index = 0;
	String fallback_policy;
};

struct SeparatorSpec {
	Rect2 normalized_rect;
	Color color;
};

struct ParsedLayoutSnapshot {
	Vector2i output_size = Vector2i(1170, 2532);
	std::vector<SlotSpec> slots;
	std::vector<SeparatorSpec> separators;
};

static Vector2i extract_output_size(const Dictionary &layout_snapshot) {
	Vector2i output_size(1170, 2532);
	if (!layout_snapshot.has("output_size")) {
		return output_size;
	}

	Variant size_variant = layout_snapshot["output_size"];
	if (size_variant.get_type() == Variant::VECTOR2I) {
		output_size = size_variant;
	} else if (size_variant.get_type() == Variant::VECTOR2) {
		Vector2 size = size_variant;
		output_size = Vector2i((int)MAX(1.0f, size.x), (int)MAX(1.0f, size.y));
	}

	output_size.x = MAX(output_size.x, 1);
	output_size.y = MAX(output_size.y, 1);
	return output_size;
}

static ParsedLayoutSnapshot parse_layout_snapshot(const Dictionary &layout_snapshot) {
	ParsedLayoutSnapshot parsed;
	parsed.output_size = extract_output_size(layout_snapshot);

	if (layout_snapshot.has("slots")) {
		Array slots = layout_snapshot["slots"];
		for (int64_t i = 0; i < slots.size(); i++) {
			if (slots[i].get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary slot_dict = slots[i];
			if (!slot_dict.has("rect")) {
				continue;
			}

			SlotSpec slot;
			slot.stream_id = slot_dict.get("stream_id", String("primary"));
			slot.normalized_rect = slot_dict["rect"];
			slot.z_index = (int)slot_dict.get("z_index", 0);
			slot.fallback_policy = slot_dict.get("fallback_policy", String("duplicate_primary"));
			parsed.slots.push_back(slot);
		}
	}

	if (layout_snapshot.has("separators")) {
		Array separators = layout_snapshot["separators"];
		for (int64_t i = 0; i < separators.size(); i++) {
			if (separators[i].get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary separator_dict = separators[i];
			if (!separator_dict.has("rect")) {
				continue;
			}

			SeparatorSpec separator;
			separator.normalized_rect = separator_dict["rect"];
			separator.color = separator_dict.get("color", Color(1.0, 1.0, 1.0, 0.22));
			parsed.separators.push_back(separator);
		}
	}

	std::sort(parsed.slots.begin(), parsed.slots.end(), [](const SlotSpec &lhs, const SlotSpec &rhs) {
		return lhs.z_index < rhs.z_index;
	});

	return parsed;
}

static CGRect normalized_rect_to_pixels(const Rect2 &normalized_rect, const Vector2i &output_size) {
	CGFloat x = normalized_rect.position.x * output_size.x;
	CGFloat y = normalized_rect.position.y * output_size.y;
	CGFloat w = normalized_rect.size.x * output_size.x;
	CGFloat h = normalized_rect.size.y * output_size.y;
	return CGRectIntegral(CGRectMake(x, y, MAX(w, 1.0), MAX(h, 1.0)));
}

static CGImageRef create_cgimage_from_rgba_frame(const FrameSnapshot &frame) {
	if (!frame.valid || frame.width <= 0 || frame.height <= 0 || frame.rgba.size() <= 0) {
		return nullptr;
	}

	CFDataRef data_ref = CFDataCreate(kCFAllocatorDefault, frame.rgba.ptr(), frame.rgba.size());
	if (!data_ref) {
		return nullptr;
	}

	CGDataProviderRef provider = CGDataProviderCreateWithCFData(data_ref);
	CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
	CGImageRef image = CGImageCreate(
		frame.width,
		frame.height,
		8,
		32,
		frame.width * 4,
		color_space,
		kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault,
		provider,
		nullptr,
		false,
		kCGRenderingIntentDefault
	);

	CGColorSpaceRelease(color_space);
	CGDataProviderRelease(provider);
	CFRelease(data_ref);
	return image;
}

static void draw_aspect_fill_image(CGContextRef context, CGImageRef source_image, CGRect destination_rect) {
	if (!context || !source_image || CGRectIsEmpty(destination_rect)) {
		return;
	}

	size_t source_width = CGImageGetWidth(source_image);
	size_t source_height = CGImageGetHeight(source_image);
	if (source_width == 0 || source_height == 0) {
		return;
	}

	CGFloat scale = MAX(destination_rect.size.width / (CGFloat)source_width, destination_rect.size.height / (CGFloat)source_height);
	CGFloat crop_width = destination_rect.size.width / scale;
	CGFloat crop_height = destination_rect.size.height / scale;
	CGFloat crop_x = (((CGFloat)source_width) - crop_width) * 0.5;
	CGFloat crop_y = (((CGFloat)source_height - crop_height) * 0.5);
	CGRect crop_rect = CGRectIntegral(CGRectMake(crop_x, crop_y, crop_width, crop_height));

	CGImageRef cropped = CGImageCreateWithImageInRect(source_image, crop_rect);
	if (!cropped) {
		return;
	}
	CGContextDrawImage(context, destination_rect, cropped);
	CGImageRelease(cropped);
}

static UIImage *make_thumbnail_image(UIImage *input_image, int thumbnail_size) {
	if (!input_image || thumbnail_size <= 0) {
		return nil;
	}
	CGSize size = CGSizeMake(thumbnail_size, thumbnail_size);
	UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
	UIImage *thumbnail = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull renderer_context) {
		CGRect dest = CGRectMake(0, 0, size.width, size.height);
		CGContextRef context = renderer_context.CGContext;
		CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
		draw_aspect_fill_image(context, input_image.CGImage, dest);
	}];
	return thumbnail;
}

} // namespace

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
    
    std::function<void()> permission_callback;
    std::function<void()> image_save_started_callback;
    std::function<void(const PackedByteArray &)> image_save_finished_callback;
    Dictionary layout_snapshot;

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
                
                if (impl->permission_callback) {
                    impl->permission_callback();
                }
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

void CameraManager::set_permission_callback(std::function<void()> callback) {
    impl->permission_callback = callback;
}

void CameraManager::set_image_save_started_callback(std::function<void()> callback) {
    impl->image_save_started_callback = callback;
}

void CameraManager::set_image_save_finished_callback(std::function<void(const PackedByteArray &)> callback) {
    impl->image_save_finished_callback = callback;
}

void CameraManager::set_layout_snapshot(const Dictionary &layout_snapshot) {
    impl->layout_snapshot = layout_snapshot;
}

void CameraManager::capture_layout_image(const Dictionary &layout_snapshot) {
    Dictionary snapshot = layout_snapshot;
    if (snapshot.is_empty()) {
        snapshot = impl->layout_snapshot;
    }

    ParsedLayoutSnapshot parsed = parse_layout_snapshot(snapshot);
    if (parsed.slots.empty()) {
        SlotSpec primary;
        primary.stream_id = "primary";
        primary.normalized_rect = Rect2(0.0, 0.0, 1.0, 0.5);
        primary.z_index = 0;
        primary.fallback_policy = "duplicate_primary";

        SlotSpec secondary;
        secondary.stream_id = "secondary";
        secondary.normalized_rect = Rect2(0.0, 0.5, 1.0, 0.5);
        secondary.z_index = 1;
        secondary.fallback_policy = "duplicate_primary";

        parsed.slots.push_back(primary);
        parsed.slots.push_back(secondary);
    }

    if (impl->image_save_started_callback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (impl->image_save_started_callback) {
                impl->image_save_started_callback();
            }
        });
    }

    dispatch_async(impl->cameraQueue, ^{
        @autoreleasepool {
            auto copy_stream = [](const CameraManager::Impl::StreamData &stream) -> FrameSnapshot {
                FrameSnapshot snapshot;
                if (stream.current_buffer.size() <= 0 || stream.buffer_width <= 0 || stream.buffer_height <= 0) {
                    return snapshot;
                }
                snapshot.rgba = stream.current_buffer;
                snapshot.width = stream.buffer_width;
                snapshot.height = stream.buffer_height;
                snapshot.valid = true;
                return snapshot;
            };

            FrameSnapshot primary_frame;
            FrameSnapshot secondary_frame;
            {
                std::lock_guard<std::mutex> lock(impl->buffer_mutex);
                primary_frame = copy_stream(impl->top_stream);
                secondary_frame = copy_stream(impl->bottom_stream);
            }

            auto resolve_frame_for_slot = [&](const SlotSpec &slot) -> FrameSnapshot {
                FrameSnapshot selected;
                if (slot.stream_id == "primary") {
                    selected = primary_frame;
                } else if (slot.stream_id == "secondary") {
                    selected = secondary_frame;
                } else {
                    selected = primary_frame;
                }

                if (selected.valid) {
                    return selected;
                }

                if (slot.fallback_policy == "duplicate_primary") {
                    if (primary_frame.valid) {
                        return primary_frame;
                    }
                } else if (slot.fallback_policy == "fallback_to_secondary") {
                    if (secondary_frame.valid) {
                        return secondary_frame;
                    }
                } else if (slot.fallback_policy == "empty") {
                    return FrameSnapshot();
                }

                if (primary_frame.valid) {
                    return primary_frame;
                }
                return secondary_frame;
            };

            size_t output_width = (size_t)MAX(1, parsed.output_size.x);
            size_t output_height = (size_t)MAX(1, parsed.output_size.y);
            size_t bytes_per_row = output_width * 4;
            size_t canvas_byte_count = output_height * bytes_per_row;

            NSMutableData *canvas_data = [NSMutableData dataWithLength:canvas_byte_count];
            if (!canvas_data) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (impl->image_save_finished_callback) {
                        impl->image_save_finished_callback(PackedByteArray());
                    }
                });
                return;
            }

            CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
            CGContextRef context = CGBitmapContextCreate(
                canvas_data.mutableBytes,
                output_width,
                output_height,
                8,
                bytes_per_row,
                color_space,
                kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big
            );
            CGColorSpaceRelease(color_space);

            if (!context) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (impl->image_save_finished_callback) {
                        impl->image_save_finished_callback(PackedByteArray());
                    }
                });
                return;
            }

            // CoreGraphics uses a bottom-left origin by default; flip to top-left
            // so saved composition and thumbnail match on-screen orientation.
            CGContextTranslateCTM(context, 0.0, (CGFloat)output_height);
            CGContextScaleCTM(context, 1.0, -1.0);
            CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
            CGContextSetRGBFillColor(context, 0.0, 0.0, 0.0, 1.0);
            CGContextFillRect(context, CGRectMake(0, 0, output_width, output_height));

            for (const SlotSpec &slot : parsed.slots) {
                FrameSnapshot frame = resolve_frame_for_slot(slot);
                if (!frame.valid) {
                    continue;
                }

                CGRect destination_rect = normalized_rect_to_pixels(slot.normalized_rect, parsed.output_size);
                CGImageRef source_image = create_cgimage_from_rgba_frame(frame);
                if (!source_image) {
                    continue;
                }
                draw_aspect_fill_image(context, source_image, destination_rect);
                CGImageRelease(source_image);
            }

            for (const SeparatorSpec &separator : parsed.separators) {
                CGRect destination_rect = normalized_rect_to_pixels(separator.normalized_rect, parsed.output_size);
                CGContextSetRGBFillColor(
                    context,
                    separator.color.r,
                    separator.color.g,
                    separator.color.b,
                    separator.color.a
                );
                CGContextFillRect(context, destination_rect);
            }

            CGImageRef composed_cgimage = CGBitmapContextCreateImage(context);
            CGContextRelease(context);
            if (!composed_cgimage) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (impl->image_save_finished_callback) {
                        impl->image_save_finished_callback(PackedByteArray());
                    }
                });
                return;
            }

            UIImage *composed_image = [UIImage imageWithCGImage:composed_cgimage scale:1.0 orientation:UIImageOrientationUp];
            UIImage *thumbnail_image = make_thumbnail_image(composed_image, 256);
            NSData *thumbnail_data = thumbnail_image ? UIImagePNGRepresentation(thumbnail_image) : nil;
            PackedByteArray thumbnail_bytes;
            if (thumbnail_data && thumbnail_data.length > 0) {
                thumbnail_bytes.resize((int64_t)thumbnail_data.length);
                memcpy(thumbnail_bytes.ptrw(), thumbnail_data.bytes, thumbnail_data.length);
            }

            CGImageRelease(composed_cgimage);

            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromImage:composed_image];
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                if (!success && error) {
                    UtilityFunctions::print("CameraManager: Failed to save image to library.");
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (impl->image_save_finished_callback) {
                        impl->image_save_finished_callback(thumbnail_bytes);
                    }
                });
            }];
        }
    });
}

void CameraManager::open_photo_library() {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSURL *photos_url = [NSURL URLWithString:@"photos-redirect://"];
        UIApplication *application = [UIApplication sharedApplication];
        if ([application canOpenURL:photos_url]) {
            [application openURL:photos_url options:@{} completionHandler:nil];
        }
    });
}
