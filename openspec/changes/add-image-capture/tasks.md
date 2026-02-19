## 1. Layout Contract and Manager
- [x] 1.1 Define `LayoutSnapshot` schema with normalized geometry, z-order, stream bindings, overlays, separators, and per-slot fallback policy.
- [x] 1.2 Implement `LayoutManager` module to produce the active `LayoutSnapshot` for the selected layout preset.
- [x] 1.3 Expose a stable API so both preview rendering and capture pipeline consume the same snapshot data.
- [x] 1.4 Add schema versioning for `LayoutSnapshot` to support safe future evolution.

## 2. Native Capture and Compositor
- [ ] 2.1 Update `CameraManager` to capture photo frames by stream ID from active `AVCapturePhotoOutput` instances.
- [x] 2.2 Build immutable `CapturePlan` from the active `LayoutSnapshot` at shutter trigger time.
- [x] 2.3 Implement `PhotoCompositor` to compose frames using `CapturePlan` instead of layout-specific branches.
- [x] 2.4 Implement per-slot missing-stream fallback behavior from `CapturePlan`.
- [x] 2.5 Implement `saveToLibrary(image)` using `PHPhotoLibrary`.
- [x] 2.6 Update `NativeBridge` to expose `capture_layout_image()` and emit `image_save_started`, `image_save_finished(thumbnail_data)`.

## 3. UI and Feedback Integration
- [x] 3.1 Connect shutter action to `NativeBridge.capture_layout_image()`.
- [x] 3.2 Keep full-screen flash feedback on capture trigger.
- [x] 3.3 Keep thumbnail updates from `image_save_finished` and open native gallery on tap.
- [x] 3.4 Keep save-state border behavior (rainbow loader while saving, idle border when complete).

## 4. Validation and Documentation
- [ ] 4.1 Verify preview-to-save parity for multiple layout presets, including an overlay layout.
- [ ] 4.2 Verify compositing performance does not block UI.
- [x] 4.3 Update project documentation to reflect `LayoutManager` as the single source of truth for preview and capture composition.
