# Change: Add Three-Layer Camera/HUD/FX Control Surface

## Why
The project is moving to a layered UI model where controls and effects are composited over fullscreen dual camera feeds. We need a first validated slice that establishes the layer stack and interaction behavior before wiring real capture/storage workflows.

## What Changes
- Introduce a three-layer composition model for the split-screen camera scene:
- Base camera feed layer (camera textures only)
- HUD overlay layer (shutter + thumbnail controls)
- FX overlay layer (flash animation)
- Add a HUD shutter control at bottom-center with defined physical sizing, ring/gap styling, and press animation.
- Add a bottom-left thumbnail control using `res://assets/icons/square.svg` with processing-state swap to `res://assets/icons/square_processing.svg` when shutter is pressed.
- Add a white flash FX on shutter press from the top-most FX layer.
- Keep this change scoped to UI behavior only (no image capture or photo-library navigation).
- Add optional haptic trigger on shutter press when available through existing platform bridge APIs; do not introduce heavy new native plumbing in this change.

## Impact
- Affected specs:
- `split-screen-layout` (layering guarantees for camera feed base)
- `hud-fx-controls` (new capability for HUD and FX interactions)
- Affected code (planned):
- `Main.tscn`
- `Main.gd`
- (Optional, only if lightweight existing API is available) `NativeBridge.gd` call-sites for haptic trigger
