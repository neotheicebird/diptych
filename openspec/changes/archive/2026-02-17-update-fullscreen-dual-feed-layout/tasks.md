## 1. Split Layout Refactor
- [x] 1.1 Remove the bottom primary-controls area from the split-screen scene layout.
- [x] 1.2 Resize top and bottom camera panes so they consume the full screen height together.
- [x] 1.3 Preserve the visual divider behavior between panes.

## 2. Control Surface Adjustment
- [x] 2.1 Remove the shutter button from the split-screen scene.
- [x] 2.2 Keep camera feed switching UI available within the dual feed layout.
- [x] 2.3 Keep existing viewer interaction behaviors (pinch zoom, tap focus/exposure, linked control fallback) functional.

## 3. Validation
- [x] 3.1 Verify fullscreen dual feed rendering on target iPhone layout.
- [x] 3.2 Verify pinch-to-zoom still works in both dual and fallback modes.
- [x] 3.3 Verify no legacy bottom control strip remains visible.
