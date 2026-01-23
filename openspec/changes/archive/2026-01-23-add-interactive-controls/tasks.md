## 1. Native Implementation (iOS)
- [x] 1.1 Expose `setZoomFactor(float scale, int cameraIndex)` in `CameraManager`.
- [x] 1.2 Expose `setFocusPoint(float x, float y, int cameraIndex)` in `CameraManager`.
- [x] 1.3 Implement smooth ramp-to-zoom logic in `CameraManager` (if not handled by AVFoundation effectively).
- [x] 1.4 Bridge these methods through `NativeBridge` (GDExtension).

## 2. Godot Input Handling
- [x] 2.1 Implement `PinchGesture` detection script on Viewer nodes.
- [x] 2.2 Implement `TapGesture` detection script on Viewer nodes.
- [x] 2.3 Create `CameraControlManager` (GDScript) to arbitrate inputs based on Link Mode.

## 3. Feedback & Polish
- [x] 3.1 Implement visual focus indicator (fading square) at tap location.
- [x] 3.2 Add UI feedback for current zoom level (optional, per design).
- [x] 3.3 Trigger iOS Haptics (UIImpactFeedbackGenerator) on zoom integer milestones (1x, 2x).

## 4. Linking Logic
- [x] 4.1 Implement "Dual Mode" logic: Input on Viewer A -> Camera A only.
- [x] 4.2 Implement "Fallback Mode" logic: Input on Viewer A -> Camera A (which is mirrored to Viewer B).