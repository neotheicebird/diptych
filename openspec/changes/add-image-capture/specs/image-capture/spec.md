## ADDED Requirements
### Requirement: Layout-Driven WYSIWYG Capture
The system SHALL capture and save a single composited image that visually replicates the active on-screen layout.

#### Scenario: Snapshot-Based Composition
- **GIVEN** `LayoutManager` provides the active `LayoutSnapshot`
- **WHEN** capture is triggered
- **THEN** the system freezes that snapshot into a `CapturePlan` before compositing starts.
- **AND** the compositor uses the frozen plan for the full render operation.
- **AND** the saved image matches the layout represented by that snapshot.

### Requirement: Shared Layout Source of Truth
The system SHALL use the same layout contract for live preview rendering and saved-image compositing.

#### Scenario: Preset-Agnostic Rendering
- **GIVEN** a layout preset that defines multiple feed slots and optional overlays
- **WHEN** capture is triggered
- **THEN** preview and compositor consume identical slot geometry, bindings, and draw order from `LayoutSnapshot`.
- **AND** the compositor remains preset-agnostic and does not require hardcoded layout branches.

### Requirement: Stream Binding and Fallback Behavior
The system SHALL apply per-slot stream bindings and fallback policy from `LayoutSnapshot` during composition.

#### Scenario: Missing Stream in a Slot
- **GIVEN** a slot whose bound stream is unavailable at capture time
- **WHEN** the final image is composed
- **THEN** the compositor applies that slot's configured fallback policy.
- **AND** the final output remains valid and consistent with preview behavior.

### Requirement: Camera Roll Integration
The system SHALL save the final composited image to the iOS Camera Roll and provide feedback.

#### Scenario: Save with State
- **WHEN** compositing is complete
- **THEN** the image is saved to `PHPhotoLibrary`.
- **AND** the system emits distinct events for `image_save_started` and `image_save_finished(thumbnail_data)`.
