# Tasks: Native Camera Feed Integration

- [x] Update project documentation (@openspec/project.md, @openspec/v1_phases.md, @openspec/v1_spec.md) to reflect C++ GDExtension stack.
- [x] Create feature specification (`openspec/specs/native-camera-feed/spec.md`).
- [x] Update `extension/SConstruct` to support Objective-C++ (`.mm`) and platform-specific source sets.
- [x] Implement `CameraManager` interface (`extension/src/camera_manager.h`).
- [x] Implement iOS Native `CameraManager` (`extension/src/platform/ios/camera_manager.mm`) using AVFoundation.
- [x] Implement Dummy `CameraManager` (`extension/src/platform/dummy/camera_manager.cpp`) for editor/macOS testing.
- [x] Update `NativeBridge` C++ class to manage `CameraManager` lifecycle and texture updates.
- [x] Add `TextureRect` to `Main.tscn` for camera feed display.
- [x] Update `Main.gd` to initialize camera and assign texture.
- [x] Verify on-device (iPhone 12) and fix any orientation or pixel format issues (e.g., BGRA vs RGBA).
    - *Note: iOS build system patched to correctly merge godot-cpp static library. Verified on-device.*
- [x] Implement camera permission signals (callback from iOS to Godot).
