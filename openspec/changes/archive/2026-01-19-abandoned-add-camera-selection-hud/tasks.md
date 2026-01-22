## 1. Native Bridge & Data Structures
- [x] 1.1 Update `CameraManager` interface (C++) to include `get_available_cameras()` and `set_camera(view_id, camera_id)`.
- [x] 1.2 Update `NativeBridge` (C++) to bind these new methods to Godot.
- [x] 1.3 Implement dummy/mock data in `platform/dummy/camera_manager.cpp` for testing in editor.

## 2. iOS Native Implementation
- [x] 2.1 Implement `get_available_cameras` in `platform/ios/camera_manager.mm` to query AVFoundation for available back/front cameras.
- [x] 2.2 Implement `set_camera` in `platform/ios/camera_manager.mm` to reconfigure `AVCaptureSession` inputs dynamically.

## 3. UI Implementation (Godot)
- [x] 3.1 Refactor `ZoneA` in `Main.tscn` to include `LeftSelector` and `RightSelector` buttons.
- [x] 3.2 Update `Main.gd` to fetch available cameras on startup.
- [x] 3.3 Implement signal handlers to cycle cameras when selectors are tapped.
- [x] 3.4 Implement UI update logic to reflect current selection (e.g., "TOP: 1x", "BOT: 0.5x").
