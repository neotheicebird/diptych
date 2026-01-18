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
The application SHALL organize UI elements into four distinct spatial zones: Status (Top), Top Preview, Bottom Preview, and Controls (Bottom).

#### Scenario: Zone Allocation
- **GIVEN** the screen height is H
- **WHEN** the layout is constructed
- **THEN** Zone A (Status) takes ~10%, Zone D (Controls) takes ~20%, and the remaining space is split equally vertically between Zone B and C.

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

