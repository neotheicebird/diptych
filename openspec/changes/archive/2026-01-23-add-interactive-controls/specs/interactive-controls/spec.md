## ADDED Requirements

### Requirement: Zoom Control
The system SHALL allow the user to control the optical/digital zoom of the camera via a pinch gesture.

#### Scenario: Zoom In
- **GIVEN** a camera viewer is active
- **WHEN** the user performs a pinch-out gesture on the viewer
- **THEN** the camera zoom factor increases smoothly towards the maximum available range.

#### Scenario: Zoom Out
- **GIVEN** the camera is zoomed in
- **WHEN** the user performs a pinch-in gesture on the viewer
- **THEN** the camera zoom factor decreases smoothly towards 1.0x (or minimum available).

### Requirement: Focus and Exposure Control
The system SHALL allow the user to set the point of interest for focus and exposure via a tap gesture.

#### Scenario: Tap to Focus
- **WHEN** the user taps a specific point on the camera viewer
- **THEN** the camera system sets the focus and exposure point of interest to the corresponding sensor coordinates.
- **AND** a temporary visual indicator appears at the tapped location.

### Requirement: Haptic Feedback
The system SHALL provide haptic feedback during zoom interactions to indicate key milestones.

#### Scenario: Zoom Milestone
- **WHEN** the zoom factor crosses an integer value (e.g., 1.0x, 2.0x) during a gesture
- **THEN** a light impact haptic feedback is triggered.

### Requirement: Control Linking
The system SHALL route inputs to the appropriate physical camera based on the active device mode (Dual vs. Fallback).

#### Scenario: Dual Mode (Independent)
- **GIVEN** the device is in Dual Camera mode
- **WHEN** the user interacts (zoom or focus) with the Top Viewer
- **THEN** only the Top Camera is affected.

#### Scenario: Fallback Mode (Linked)
- **GIVEN** the device is in Single Camera (Fallback) mode
- **WHEN** the user interacts (zoom or focus) with ANY viewer
- **THEN** the single active physical camera is updated, affecting both views.
