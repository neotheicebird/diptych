## ADDED Requirements
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

## MODIFIED Requirements
### Requirement: Real-time Texture Updates
The system SHALL capture video frames and update two distinct Godot `ImageTexture` resources in real-time.

#### Scenario: Frame Update
- **WHEN** a new `CMSampleBuffer` is received from a specific video output (Top or Bottom)
- **THEN** it is converted and uploaded to the corresponding Godot `ImageTexture` (Top or Bottom) on the main thread.
