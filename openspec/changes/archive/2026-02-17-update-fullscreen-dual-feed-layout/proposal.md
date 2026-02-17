# Change: Update Fullscreen Dual Feed Layout

## Why
The product is pivoting to a transparent HUD overlay model. The current bottom control region reserves screen space that should now be reclaimed for camera composition.

## What Changes
- Expand the dual camera feed layout to occupy the full screen height.
- Remove the dedicated bottom control area from the split-screen layout.
- Remove the shutter button from the current split-screen scene.
- Keep existing interaction behavior (for example pinch-to-zoom and other viewer gestures) functional in the fullscreen layout.
- Keep camera feed switching controls within the dual feed layout until HUD migration is implemented.

## Impact
- Affected specs: `split-screen-layout`
- Affected code: `Main.tscn`, `Main.gd`, and related viewer/control layout scripts
- Follow-up: HUD-specific controls and visual layers will be added in a subsequent change.
