## ADDED Requirements
### Requirement: Shutter Control
Zone D SHALL contain a primary shutter interaction element.

#### Scenario: Visual Style
- **WHEN** rendered
- **THEN** a large white circular button is displayed, centered horizontally in Zone D.

#### Scenario: Interaction
- **WHEN** the shutter button is tapped
- **THEN** a capture event is triggered.

### Requirement: Capture Feedback
The system SHALL provide distinct visual feedback for capture actions.

#### Scenario: Screen Flash
- **WHEN** the shutter is tapped
- **THEN** the entire screen flashes white briefly (fade in/out).

#### Scenario: Thumbnail - Idle
- **GIVEN** no save is in progress
- **WHEN** rendered
- **THEN** the thumbnail in the bottom-left of Zone D appears as a rounded square with a static Light Gray border.

#### Scenario: Thumbnail - Saving (Rainbow Loader)
- **GIVEN** a capture is in progress (saving to library)
- **WHEN** rendered
- **THEN** the thumbnail border animates with a "thin stylish rainbow spinner" effect.

#### Scenario: Thumbnail - Update
- **WHEN** saving completes
- **THEN** the thumbnail image updates to the newly captured photo.
- **AND** the rainbow animation stops (reverts to Light Gray).