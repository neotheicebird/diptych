## ADDED Requirements
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
