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

### Requirement: HUD Side Controls Row
The system SHALL show side controls on the HUD row: a bottom-left thumbnail control using `res://assets/icons/square.svg` and a bottom-right layout control using `res://assets/icons/layout.svg`, both with approximately 1 cm side length and vertically center-aligned with the shutter control.

#### Scenario: Side Control Placement
- **GIVEN** HUD controls are rendered
- **WHEN** the layout is computed
- **THEN** the thumbnail appears near the bottom-left edge and the layout icon appears near the bottom-right edge.
- **AND** both side controls have center Y coordinates matching the shutter button center Y coordinate.
- **AND** the side controls use approximately 5% horizontal screen margins.
- **AND** the control row baseline is approximately 10% from the bottom edge.

### Requirement: Thumbnail Processing Feedback
The system SHALL provide thumbnail processing feedback after shutter tap via a short pulse animation with at least 560 ms visible duration, without invoking capture or photo-library actions.

#### Scenario: Processing Feedback Pulse
- **GIVEN** the idle thumbnail icon is visible
- **WHEN** shutter is tapped
- **THEN** the thumbnail enters a processing visual pulse state for at least 560 ms.
- **AND** image capture and photo-library navigation are not invoked by this behavior.
