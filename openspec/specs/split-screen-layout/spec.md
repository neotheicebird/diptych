# split-screen-layout Specification

## Purpose
TBD - created by archiving change implement-split-screen-layout. Update Purpose after archive.
## Requirements
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

### Requirement: Three-Layer Split-Screen Composition
The application SHALL compose the split-screen scene using three ordered layers: a base camera feed layer, a HUD overlay layer, and an FX overlay layer.

#### Scenario: Layer Order
- **GIVEN** the split-screen scene is active
- **WHEN** the UI is rendered
- **THEN** the top and bottom camera feeds are drawn in the base layer.
- **AND** HUD controls are drawn above the camera feeds.
- **AND** FX visuals are drawn above the HUD.

#### Scenario: Base Layer Camera Ownership
- **GIVEN** dual-stream or fallback mode is active
- **WHEN** camera textures update
- **THEN** the camera textures remain attached to base-layer viewer nodes.
- **AND** moving controls to HUD/FX does not change camera routing behavior.

