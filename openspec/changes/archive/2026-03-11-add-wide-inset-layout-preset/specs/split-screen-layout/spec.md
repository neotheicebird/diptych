## MODIFIED Requirements
### Requirement: Viewer Control Overlay
Each active camera panel SHALL expose a top-right camera cycle control and a temporary camera label feedback surface.

#### Scenario: Camera cycle button styling and placement
- **GIVEN** any active camera panel
- **WHEN** overlays are rendered
- **THEN** a circular refresh-icon button appears in the panel's top-right corner.
- **AND** the button background uses the same gray tone as the shutter control.
- **AND** the button applies a small extra top inset margin from the panel edge in all orientations.

#### Scenario: Panel-local camera cycling
- **GIVEN** a panel camera cycle button is tapped
- **WHEN** the panel has another available camera device
- **THEN** only that panel switches to the next available camera device.

#### Scenario: Temporary camera label feedback
- **GIVEN** a panel camera switch completes
- **WHEN** feedback is displayed
- **THEN** a camera label (for example `front`, `main`, `tele`, `ultra`, `1x`, or `0.5x`) appears for a short duration.
- **AND** the label auto-hides without additional user input.

### Requirement: Layout Presets
The application SHALL provide exactly three selectable layout presets in v1: `include_photographer`, `zoomies`, and `wide inset`, while keeping those IDs internal to implementation.

#### Scenario: Portrait-authored canonical layout data
- **GIVEN** any layout preset is selected
- **WHEN** live feed and capture snapshots are generated
- **THEN** panel geometry is derived from portrait-authored canonical layout definitions.
- **AND** picker preview orientation metadata does not alter live-feed panel geometry.

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

#### Scenario: Wide inset preset
- **GIVEN** the user selects `wide inset`
- **WHEN** the layout is rendered
- **THEN** a full-screen base panel fills the camera viewing area with the rear `main` camera by default.
- **AND** an inset panel appears in the top-left corner with a 6:18 width-to-height aspect ratio (long side vertical).
- **AND** the inset panel defaults to `ultra`.

#### Scenario: Visual-only preset cards
- **GIVEN** layout cards are shown to users
- **WHEN** the picker renders
- **THEN** layout options are shown as visual-only cards without layout text labels.
- **AND** internal IDs (`include_photographer`, `zoomies`, `wide inset`) are not exposed in UI text.
