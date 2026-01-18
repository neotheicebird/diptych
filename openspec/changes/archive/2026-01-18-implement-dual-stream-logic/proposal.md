# Change: Implement Dual-Stream Logic

## Why
The core value proposition of the application is the "Diptych" format—capturing two perspectives simultaneously. To achieve this, we must enable simultaneous streaming from two physical cameras on supported devices (MultiCam) and gracefully handle single-camera devices.

## What Changes
- **Native Implementation**: 
    - Upgrade `CameraManager` to use `AVCaptureMultiCamSession` when available.
    - Implement a "Dual" mode that configures two distinct `AVCaptureDeviceInput`s (e.g., Wide + Ultra Wide or Back + Front) and two `AVCaptureVideoDataOutput`s.
    - Implement a "Fallback" mode for older devices that uses a standard `AVCaptureSession` but routes the single frame to both layout zones.
- **Data Model**: Update `NativeBridge` to expose *two* distinct textures (`texture_top` and `texture_bottom`).
- **Logic**: Add logic to detect MultiCam support (`AVCaptureMultiCamSession.isMultiCamSupported`) at startup.

## Impact
- **Specs**:
    - `native-camera-feed`: Add requirements for Multi-Cam session and Dual-Texture output.
    - `split-screen-layout`: Minor updates to clarify how textures are assigned to zones.
- **Code**:
    - `src/camera_manager.h/mm`: significant refactoring for session configuration.
    - `src/native_bridge.h/cpp`: Expose second texture.
    - `Main.gd`: Bind two textures instead of one.
