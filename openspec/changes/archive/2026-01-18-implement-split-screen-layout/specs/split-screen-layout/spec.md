## ADDED Requirements

### Requirement: Horizontal Split Canvas
The application interface SHALL be divided horizontally into two equal-sized panes (Top and Bottom) for camera previews, sandwiched between top and bottom control bands.

#### Scenario: Default Orientation
- **GIVEN** the application is launched on an iPhone
- **WHEN** the main screen loads
- **THEN** it displays a horizontal split layout in portrait orientation (Top Pane above Bottom Pane).

#### Scenario: Pane Symmetry
- **GIVEN** the split view is active
- **WHEN** the layout is rendered
- **THEN** the Top Pane (Zone B) and Bottom Pane (Zone C) occupy equal height.

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
