## RENAMED Requirements
- FROM: `### Requirement: Horizontal Split Canvas`
- TO: `### Requirement: Layout Presets`
- FROM: `### Requirement: Visual Divider`
- TO: `### Requirement: Panel Borders`

## MODIFIED Requirements
### Requirement: Layout Presets
The application SHALL provide exactly two selectable layout presets in v1: `include_photographer` and `zoomies`, while keeping those IDs internal to implementation.

#### Scenario: Zoomies preset
- **GIVEN** the user selects `zoomies`
- **WHEN** the layout is rendered
- **THEN** the camera canvas is split into two equal-height stacked panels that fill the full available camera viewing area.
- **AND** the top panel defaults to the rear `main` camera.
- **AND** the bottom panel defaults to `tele` when available, otherwise the next available rear camera.

#### Scenario: Include Photographer preset
- **GIVEN** the user selects `include_photographer`
- **WHEN** the layout is rendered
- **THEN** a near-fullscreen base panel fills the camera viewing area with the rear `main` camera by default.
- **AND** a rounded-square inset panel appears in the lower-left corner at approximately half of the screen width.
- **AND** the inset panel defaults to the front camera.

#### Scenario: Visual-only preset cards
- **GIVEN** layout cards are shown to users
- **WHEN** the picker renders
- **THEN** layout options are shown as visual-only cards without layout text labels.
- **AND** internal IDs (`include_photographer`, `zoomies`) are not exposed in UI text.

### Requirement: Layout Zones
The application SHALL organize the split-screen surface as active camera panels plus in-view overlays, without reserving a dedicated bottom control strip outside the camera canvas.

#### Scenario: Zoomies zone allocation
- **GIVEN** `zoomies` is active
- **WHEN** the layout is constructed
- **THEN** the two stacked camera panels consume the full camera viewing area.

#### Scenario: Include Photographer zone allocation
- **GIVEN** `include_photographer` is active
- **WHEN** the layout is constructed
- **THEN** the base panel consumes the full camera viewing area.
- **AND** the inset remains overlaid within the base panel bounds.

### Requirement: Panel Borders
Each active camera panel SHALL render a thin, dull-white border around its perimeter.

#### Scenario: Border visibility in zoomies
- **GIVEN** `zoomies` is active
- **WHEN** the panels are rendered
- **THEN** both stacked panels show a visible thin dull-white border.

#### Scenario: Border visibility in include photographer
- **GIVEN** `include_photographer` is active
- **WHEN** the base and inset panels are rendered
- **THEN** both panels show a visible thin dull-white border.
- **AND** the inset border follows the inset's rounded corners.

### Requirement: Viewer Control Overlay
Each active camera panel SHALL expose a top-right camera cycle control and a temporary camera label feedback surface.

#### Scenario: Camera cycle button styling and placement
- **GIVEN** any active camera panel
- **WHEN** overlays are rendered
- **THEN** a circular refresh-icon button appears in the panel's top-right corner.
- **AND** the button background uses the same gray tone as the shutter control.

#### Scenario: Panel-local camera cycling
- **GIVEN** a panel camera cycle button is tapped
- **WHEN** the panel has another available camera device
- **THEN** only that panel switches to the next available camera device.

#### Scenario: Temporary camera label feedback
- **GIVEN** a panel camera switch completes
- **WHEN** feedback is displayed
- **THEN** a camera label (for example `front`, `main`, `tele`, `ultra`, `1x`, or `0.5x`) appears for a short duration.
- **AND** the label auto-hides without additional user input.
