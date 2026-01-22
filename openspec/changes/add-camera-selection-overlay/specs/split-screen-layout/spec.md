## MODIFIED Requirements
### Requirement: Layout Zones
The application SHALL organize UI elements into three distinct spatial zones: Top Viewer, Bottom Viewer, and Primary Controls (Bottom).

#### Scenario: Zone Allocation
- **GIVEN** the screen height is H
- **WHEN** the layout is constructed
- **THEN** Zone D (Primary Controls) takes ~18–22%, and the remaining space is split equally between the Top and Bottom Viewers.

## ADDED Requirements
### Requirement: Viewer Control Overlay
Each camera viewer SHALL contain a persistent control overlay area positioned at its bottom edge.

#### Scenario: Overlay Position
- **GIVEN** a camera viewer (Top or Bottom)
- **WHEN** rendered
- **THEN** a transparent control area occupies the bottom 5-10% of the viewer's frame.

#### Scenario: Camera Label
- **GIVEN** the control overlay
- **WHEN** active
- **THEN** it displays a text label (e.g., "Wide", "Tele") aligned to the right, indicating the current active camera for that viewer.

#### Scenario: Camera Selection Interaction
- **GIVEN** the Camera Label is visible
- **WHEN** the user taps the label
- **THEN** the viewer cycles to the next available camera device.
