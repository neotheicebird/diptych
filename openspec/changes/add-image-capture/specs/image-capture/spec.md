## ADDED Requirements
### Requirement: WYSIWYG Split Capture
The system SHALL capture and save a single composited image that visually replicates the on-screen split layout.

#### Scenario: Dual Stream Stitching
- **GIVEN** two active camera feeds (Dual Mode)
- **WHEN** capture is triggered
- **THEN** the system captures a high-resolution frame from each camera.
- **AND** crops each frame to match the aspect ratio of its respective Viewer (Zone B/C).
- **AND** stitches them vertically with a visual separator line (matching the UI).
- **AND** saves the result as a single image file.

#### Scenario: Fallback Stream Stitching
- **GIVEN** a single active camera feed (Fallback Mode)
- **WHEN** capture is triggered
- **THEN** the system uses the single frame to generate the split composition (replicating how it appears on screen, e.g., duplicated or linked view).
- **AND** saves the result as a single image file.

### Requirement: Camera Roll Integration
The system SHALL save the final composited image to the iOS Camera Roll and provide feedback.

#### Scenario: Save with State
- **WHEN** compositing is complete
- **THEN** the image is saved to `PHPhotoLibrary`.
- **AND** the system emits distinct events for "Save Started" and "Save Finished".