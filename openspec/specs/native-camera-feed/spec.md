# Native Camera Feed Integration Spec

## Purpose
Establish a high-performance pipeline to stream live video frames from the iOS camera (AVFoundation) into a Godot `Texture2D` for rendering.
## Requirements
### Requirement: iOS Camera Access
The system SHALL request and handle iOS camera permissions to access the hardware sensor.

#### Scenario: Permission Granted
- **WHEN** the user allows camera access in the iOS system dialog
- **THEN** the `CameraManager` initializes the `AVCaptureSession` and starts the feed.

#### Scenario: Permission Denied
- **WHEN** the user denies camera access
- **THEN** the system logs an "Access denied" message and does not start the feed.

### Requirement: Real-time Texture Updates
The system SHALL capture video frames and update two distinct Godot `ImageTexture` resources in real-time.

#### Scenario: Frame Update
- **WHEN** a new `CMSampleBuffer` is received from a specific video output (Top or Bottom)
- **THEN** it is converted and uploaded to the corresponding Godot `ImageTexture` (Top or Bottom) on the main thread.

### Requirement: Efficient Data Pipeline
The system SHALL use a background serial queue for pixel processing to avoid blocking the main thread.

#### Scenario: Background Processing
- **WHEN** multiple frames arrive in rapid succession
- **THEN** they are processed on `com.diptych.cameraQueue` while the Godot main thread remains responsive.

### Requirement: Dual-Stream Support
The system SHALL support simultaneous capture from two physical camera devices if the hardware allows (MultiCam).

#### Scenario: MultiCam Available
- **GIVEN** the device supports `AVCaptureMultiCamSession` (e.g., iPhone XS or newer)
- **WHEN** the session is initialized
- **THEN** two distinct camera feeds (e.g., Wide and Ultra Wide) are started simultaneously.

#### Scenario: MultiCam Fallback
- **GIVEN** the device does not support MultiCam
- **WHEN** the session is initialized
- **THEN** a standard single-camera session is started, and its feed is duplicated or routed to both logical outputs.

## Architecture

### Data Flow
1.  **Hardware**: iOS Camera Sensor.
2.  **AVFoundation**: `AVCaptureSession` captures frames as `CMSampleBuffer` (YUV or BGRA).
3.  **Native Bridge (Obj-C++)**: 
    - `CameraManager` receives `CMSampleBuffer`.
    - Converts/Copies buffer to a raw byte array (or directly to a Godot `Image`).
    - Signals `NativeBridge` that a new frame is available.
4.  **GDExtension (C++)**: 
    - `NativeBridge` holds a reference to the Godot `ImageTexture` or `ExternalTexture`.
    - Updates the texture data on the Godot main thread (or via thread-safe visual server commands).
5.  **Godot (GDScript)**:
    - `NativeBridge` singleton emits a signal (optional) or simply updates a texture resource bound to a `TextureRect`.

### Components

#### 1. `CameraManager` (Objective-C++)
A purely internal class (hidden from Godot) that manages the iOS `AVCaptureSession`.
- **Responsibilities**:
  - Request Camera Permissions.
  - Setup `AVCaptureSession`, `AVCaptureDeviceInput`, `AVCaptureVideoDataOutput`.
  - Implement `AVCaptureVideoDataOutputSampleBufferDelegate`.
  - Handle orientation and device selection (Front/Back/Dual).

#### 2. `NativeBridge` (C++ GDExtension)
The public face to Godot.
- **Methods**:
  - `start_camera()`: Triggers `CameraManager` startup.
  - `stop_camera()`: Stops the session.
  - `get_camera_texture()`: Returns the `ImageTexture` that will be updated.
- **Signals**:
  - `permission_granted()`
  - `permission_denied()`
