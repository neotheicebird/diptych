## 1. Layout Preset Reduction
- [x] 1.1 Restrict layout selection to `include_photographer` and `zoomies` only.
- [x] 1.2 Implement `include_photographer` geometry: fullscreen base panel plus rounded-square lower-left inset at approximately 50% of screen width.
- [x] 1.3 Ensure default camera mapping is `main` (base) + `front` (inset) for `include_photographer`.
- [x] 1.4 Ensure default camera mapping is top `main` + bottom `tele` for `zoomies`, with fallback to the next available rear camera when tele is unavailable.

## 2. Layout Picker Presentation
- [x] 2.1 Update layout picker popup to a larger rounded-card presentation sized to match the v1 large-state target proportions.
- [x] 2.2 Show only the two supported layout choices in the picker.
- [x] 2.3 Keep preset IDs internal; show layout options as visual-only cards (no layout text labels).
- [x] 2.4 Remove future tabs/options and non-essential text so the picker stays high-signal and low-noise.
- [x] 2.5 Keep the colored preview-card language as the primary selection cue.

## 3. Panel Camera Switching Controls
- [x] 3.1 Add a top-right circular refresh button on every active panel with gray background matching the shutter gray tone.
- [x] 3.2 Wire each button to cycle camera devices only for its owning panel.
- [x] 3.3 Show a temporary camera label after a panel switch and auto-hide it after a short timeout.

## 4. Panel Border Styling
- [x] 4.1 Add a thin, dull-white border around each active panel in both layouts.
- [x] 4.2 Ensure inset borders and rounded corners remain visually clean during live preview.

## 5. Validation
- [x] 5.1 Verify both layouts preserve independent per-panel pinch-to-zoom behavior.
- [x] 5.2 Verify panel camera switching updates only the targeted panel and displays the temporary label.
- [x] 5.3 Verify layout picker size and proportions match the intended large-card v1 presentation on supported iPhone sizes.
