## 1. Native Compositing Engine (iOS/Obj-C++)
- [x] 1.1 Update `CameraManager` to handle `AVCapturePhotoOutput` for one or both active sessions.
- [x] 1.2 Implement `PhotoCompositor` class (or helper) to:
    - Receive `AVCapturePhoto` data.
    - Crop images to match the Viewer aspect ratio (Zone B / Zone C).
    - Draw images into a single context (Top/Bottom layout) with a separator line.
    - Render final `UIImage`.
- [x] 1.3 Handle "Fallback" mode: If only one stream, crop/duplicate appropriately to match the on-screen "linked" look (or just the single view if that's the design, but spec says WYSIWYG split). *Clarification: Fallback usually shows same feed in both. Compositor should burn this into the image.*
- [x] 1.4 Implement `saveToLibrary(image)` using `PHPhotoLibrary`.
- [x] 1.5 Update `NativeBridge` to expose `capture_split_image()` and signal `image_save_started`, `image_save_finished(thumbnail_data)`.

## 2. Godot UI & Feedback
- [x] 2.1 **Shutter Button**: Add to Zone D. Connect to `NativeBridge.capture_split_image()`.
- [x] 2.2 **Screen Flash**: Create a full-screen `ColorRect` (White) that fades in/out rapidly on capture trigger.
- [x] 2.3 **Thumbnail UI**:
    - Add `TextureRect` for thumbnail in Zone D (Bottom Left).
    - Apply rounded corner shader or mask.
    - Add a "Border" control (ReferenceRect or custom draw).
- [x] 2.4 **Rainbow Loader**:
    - Create a custom Shader for the "Thin Stylish Rainbow Spinner".
    - Apply this shader to the Thumbnail's border or a dedicated overlay `Control`.
    - Logic: Show rainbow shader on `image_save_started`, revert to Light Gray static border on `image_save_finished`.
- [x] 2.5 **Thumbnail Logic**:
    - Update texture with `image_save_finished` data.
    - Tap opens native gallery (`UIApplication.shared.openURL`).

## 3. Integration & Polish
- [x] 3.1 Verify aspect ratio of saved image matches screen layout exactly.
- [x] 3.2 Verify separator line width/color in saved image matches UI.
- [x] 3.3 Test Dual-Cam stitching performance (ensure no UI freeze).
- [x] 3.4 Test Fallback stitching.
