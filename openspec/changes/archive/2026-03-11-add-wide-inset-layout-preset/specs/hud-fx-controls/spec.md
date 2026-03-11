## MODIFIED Requirements
### Requirement: HUD Side Controls Row
The system SHALL show side controls on the HUD row: a bottom-left thumbnail control using `res://assets/icons/square.svg` and a bottom-right layout control using `res://assets/icons/layout.svg`, both with approximately 1 cm side length and vertically center-aligned with the shutter control.

#### Scenario: Side Control Placement
- **GIVEN** HUD controls are rendered
- **WHEN** the layout is computed
- **THEN** the thumbnail appears near the bottom-left edge and the layout icon appears near the bottom-right edge.
- **AND** both side controls have center Y coordinates matching the shutter button center Y coordinate.
- **AND** the side controls use approximately 5% horizontal screen margins.
- **AND** the control row baseline is approximately 10% from the bottom edge.

#### Scenario: Enlarged Layout Picker Presentation
- **GIVEN** the layout control is visible
- **WHEN** the user opens the layout picker
- **THEN** a large rounded popup appears using card-like proportions that prioritize preview familiarity.
- **AND** the popup occupies a large presentation state in v1 (approximately 72-88% of screen height).
- **AND** three layout options are shown: `include_photographer`, `zoomies`, and `wide inset`.

#### Scenario: Low-noise layout chooser content
- **GIVEN** the layout picker is open
- **WHEN** the picker content is rendered
- **THEN** selection is driven by large visual cards with colored layout previews.
- **AND** "future" tabs/options and non-essential helper text are not shown.

#### Scenario: Landscape wide inset preview card
- **GIVEN** the layout picker is open
- **WHEN** the `wide inset` preset card is shown
- **THEN** its preview canvas is rendered in landscape orientation to reflect the preset composition.
- **AND** this card orientation behavior is preview-only and does not change live feed layout geometry.
