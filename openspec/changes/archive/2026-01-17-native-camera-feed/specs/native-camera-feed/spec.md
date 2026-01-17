## ADDED Requirements

### Requirement: iOS Camera Access
The system SHALL request and handle iOS camera permissions to access the hardware sensor.

#### Scenario: Permission Granted
- **WHEN** the user allows camera access in the iOS system dialog
- **THEN** the `CameraManager` initializes the `AVCaptureSession` and starts the feed.

#### Scenario: Permission Denied
- **WHEN** the user denies camera access
- **THEN** the system logs an "Access denied" message and does not start the feed.

### Requirement: Real-time Texture Updates
The system SHALL capture video frames and update a Godot `ImageTexture` in real-time.

#### Scenario: Frame Update
- **WHEN** a new `CMSampleBuffer` is received from the iOS camera
- **THEN** it is converted from BGRA to RGBA and uploaded to the Godot `ImageTexture` on the main thread.

### Requirement: Efficient Data Pipeline
The system SHALL use a background serial queue for pixel processing to avoid blocking the main thread.

#### Scenario: Background Processing
- **WHEN** multiple frames arrive in rapid succession
- **THEN** they are processed on `com.diptych.cameraQueue` while the Godot main thread remains responsive.
