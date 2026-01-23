# split-screen-layout Specification

## Purpose
TBD - created by archiving change implement-split-screen-layout. Update Purpose after archive.
## Requirements
### Requirement: Horizontal Split Canvas
The application interface SHALL be divided horizontally into two equal-sized panes (Top and Bottom), each capable of rendering an independent camera feed.

#### Scenario: Independent Feeds
- **GIVEN** the application is in Dual-Stream mode
- **WHEN** the layout renders
- **THEN** the Top Pane displays the `texture_top` feed and the Bottom Pane displays the `texture_bottom` feed.

### Requirement: Layout Zones
The application SHALL organize UI elements into three distinct spatial zones: Top Viewer, Bottom Viewer, and Primary Controls (Bottom).

#### Scenario: Zone Allocation
- **GIVEN** the screen height is H
- **WHEN** the layout is constructed
- **THEN** Zone D (Primary Controls) takes ~18–22%, and the remaining space is split equally between the Top and Bottom Viewers.

### Requirement: Visual Divider
A subtle visual divider SHALL demarcate the horizontal boundary between the two camera panes.

#### Scenario: Divider Visibility
- **GIVEN** the two camera panes are adjacent vertically
- **WHEN** the UI is drawn
- **THEN** a thin horizontal line or separator is visible between them.

### Requirement: Minimalist Styling
The UI SHALL use a high-contrast, minimalist color palette (White/Light Gray) without gradients or decorative animations.

#### Scenario: Background Color
- **GIVEN** the application starts
- **WHEN** the UI backgrounds are rendered
- **THEN** they appear as solid flat colors (e.g., white or light gray).

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

