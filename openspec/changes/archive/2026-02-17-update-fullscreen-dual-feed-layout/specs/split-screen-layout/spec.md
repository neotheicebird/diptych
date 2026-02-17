## MODIFIED Requirements
### Requirement: Horizontal Split Canvas
The application interface SHALL be divided horizontally into two equal-sized panes (Top and Bottom) that together occupy the full available screen height for camera viewing.

#### Scenario: Fullscreen Split Occupancy
- **GIVEN** the split-screen camera UI is rendered
- **WHEN** the layout is constructed
- **THEN** the Top and Bottom panes fill the full vertical space allocated to the dual feed canvas.
- **AND** no dedicated bottom control strip reserves vertical space outside the two panes.

#### Scenario: Independent Feeds
- **GIVEN** the application is in Dual-Stream mode
- **WHEN** the layout renders
- **THEN** the Top Pane displays the `texture_top` feed and the Bottom Pane displays the `texture_bottom` feed.

### Requirement: Layout Zones
The application SHALL organize the split-screen surface into two viewer zones (Top Viewer and Bottom Viewer) plus in-view overlays, without a separate primary-controls bottom zone.

#### Scenario: Zone Allocation
- **GIVEN** the screen height is H
- **WHEN** the layout is constructed
- **THEN** the dual feed surface consumes the full camera viewing area.
- **AND** each viewer occupies approximately half of that viewing area.

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
