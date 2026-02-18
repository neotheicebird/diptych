## ADDED Requirements
### Requirement: HUD Shutter Control
The system SHALL provide a bottom-center shutter control in the HUD overlay as a mid-gray circular button with approximately 1 cm diameter (~181 px reference), surrounded by a 1 mm transparent gap and a 0.1 mm outer ring.

#### Scenario: Shutter Visual Layout
- **GIVEN** the camera screen is visible
- **WHEN** HUD controls are rendered
- **THEN** the shutter appears centered horizontally near the bottom edge.
- **AND** the shutter button visual includes the configured gap and ring treatment.

#### Scenario: Shutter Press Animation
- **GIVEN** the user taps the shutter control
- **WHEN** the press begins
- **THEN** the shutter button scales down to 90% briefly.
- **AND** it returns to its original scale automatically.

#### Scenario: Optional Haptic Trigger
- **GIVEN** a lightweight existing platform haptic API is available
- **WHEN** the shutter is tapped
- **THEN** a light haptic pulse is triggered.
- **AND** if no lightweight API is available, the UI behavior still completes without haptics.

### Requirement: FX Flash Overlay
The system SHALL provide a short white screen-flash effect from the FX overlay layer when shutter is tapped.

#### Scenario: Flash On Shutter
- **GIVEN** the FX overlay exists above HUD
- **WHEN** the user taps shutter
- **THEN** the FX layer displays a brief white flash animation.
- **AND** the flash does not permanently obscure HUD or camera feeds.

### Requirement: Thumbnail HUD Control and Processing State
The system SHALL show a bottom-left thumbnail control in HUD using `res://assets/icons/square.svg` with approximately 1 cm side length, vertically aligned by center with the shutter control, and temporarily switch to `res://assets/icons/square_processing.svg` after shutter tap.

#### Scenario: Thumbnail Placement
- **GIVEN** HUD controls are rendered
- **WHEN** the layout is computed
- **THEN** the thumbnail appears near the bottom-left edge.
- **AND** its center Y coordinate matches the shutter button center Y coordinate.

#### Scenario: Processing Icon Swap
- **GIVEN** the idle thumbnail icon is visible
- **WHEN** shutter is tapped
- **THEN** the thumbnail icon switches to `res://assets/icons/square_processing.svg` for a short processing-state animation window.
- **AND** image capture and photo-library navigation are not invoked by this behavior.
