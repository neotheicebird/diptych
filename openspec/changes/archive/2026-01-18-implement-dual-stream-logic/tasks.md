## 1. Native MultiCam Support
- [x] 1.1 Update `CameraManager` to check `AVCaptureMultiCamSession.isMultiCamSupported`.
- [x] 1.2 Implement `configureMultiCamSession` to set up two inputs (e.g., built-in wide and ultra-wide) and two outputs.
- [x] 1.3 Implement `configureSingleCamSession` as a fallback or for unsupported devices.
- [x] 1.4 Update the sample buffer delegate to identify which video connection/output the frame came from.

## 2. GDExtension Updates
- [x] 2.1 Update `NativeBridge` to hold two `Ref<ImageTexture>` objects: `texture_top` and `texture_bottom`.
- [x] 2.2 Update `CameraManager` callback to accept an ID (0 or 1) indicating the target texture.
- [x] 2.3 Expose `get_texture_top()` and `get_texture_bottom()` methods to Godot.
- [x] 2.4 Expose a boolean `is_multicam_supported()` to Godot.

## 3. Godot Integration
- [x] 3.1 Update `Main.gd` to retrieve both textures.
- [x] 3.2 Assign `texture_top` to the Top Pane (Zone B) and `texture_bottom` to the Bottom Pane (Zone C).
- [x] 3.3 Verify dual streaming on the target device (iPhone 12).