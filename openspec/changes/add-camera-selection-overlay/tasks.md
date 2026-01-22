## 1. Native Bridge Implementation
- [x] 1.1 Update `CameraManager` (Obj-C++) to support switching inputs for active sessions.
- [x] 1.2 Implement `get_available_devices()` in `NativeBridge` to return list of cameras (ID + Name).
- [x] 1.3 Implement `set_device(view_index, device_id)` in `NativeBridge`.
- [x] 1.4 Handle "Fallback" mode logic (single-cam devices) where selection might be linked or limited.

## 2. Godot UI Implementation
- [x] 2.1 Refactor `Main.tscn`: Remove `ZoneA` (Status Bar).
- [x] 2.2 Update `ZoneB` (Top) and `ZoneC` (Bottom) to include a `ControlOverlay` Container (bottom aligned).
- [x] 2.3 Add `CameraLabel` (Label node) to the overlay.
- [x] 2.4 Implement `CameraSelector.gd`:
    - Fetch available devices from `NativeBridge`.
    - Handle tap input (GuiInput signal).
    - Cycle through devices and call `NativeBridge.set_device()`.
    - Update label text.

## 3. Polish & Verification
- [x] 3.1 Style the labels (Font, Color, Shadow) per spec.
- [x] 3.2 Verify behavior on device (mock data if needed for simulator).
