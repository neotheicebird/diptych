## 1. Scene Layering
- [x] 1.1 Add three ordered canvas layers in the scene: base camera feeds, HUD, then FX.
- [x] 1.2 Ensure top and bottom camera feeds render exclusively in the base layer.
- [x] 1.3 Preserve existing dual/fallback camera feed behavior while moving controls into HUD/FX layers.

## 2. HUD Controls
- [x] 2.1 Add bottom-center shutter control in HUD with target physical sizing (~1 cm diameter / ~181 px reference), plus 1 mm gap and 0.1 mm ring styling.
- [x] 2.2 Add shutter press animation that scales button to 90% briefly and returns to rest.
- [x] 2.3 Trigger lightweight haptic feedback on shutter press only if an existing bridge/API call is already available.
- [x] 2.4 Add bottom-left thumbnail control using `res://assets/icons/square.svg` at ~1 cm size.
- [x] 2.5 Align shutter and thumbnail controls so their center points are vertically aligned.

## 3. FX Layer Behavior
- [x] 3.1 Add top-layer white flash overlay node.
- [x] 3.2 Trigger short flash animation on shutter press.
- [x] 3.3 Switch thumbnail icon to `res://assets/icons/square_processing.svg` during processing animation state after shutter press.

## 4. Validation
- [ ] 4.1 Verify camera feeds remain fully visible in base layer and not occluded by opaque HUD background.
- [ ] 4.2 Verify shutter press animation, thumbnail state swap, and flash FX all trigger from one shutter tap.
- [ ] 4.3 Verify zoom/focus interactions still work on camera panes after layering changes.
- [ ] 4.4 Verify no photo capture or photo-app navigation is triggered by shutter/thumbnail in this change.
