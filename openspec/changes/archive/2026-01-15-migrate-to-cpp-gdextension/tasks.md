## 1. Environment Setup
- [x] 1.1. Add `godot-cpp` (4.5 branch or compatible) as a git submodule in `extension/godot-cpp`.
- [x] 1.2. Create `SConstruct` file to configure the build for macOS (editor) and iOS (static library).
- [x] 1.3. Create the extension entry point (`register_types.cpp`, `register_types.h`).

## 2. Port NativeBridge
- [x] 2.1. Create `NativeBridge` C++ class inheriting from `Node`.
- [x] 2.2. Implement the placeholder methods (`request_camera_permission`, `initialize_camera`, `capture_photo`) in C++ binding them to the Godot API.
- [x] 2.3. Create the `diptych.gdextension` configuration file.

## 3. Integration
- [x] 3.1. Compile the extension for macOS (arm64) to ensure it loads in the Editor.
- [x] 3.2. Update `project.godot` to remove the `NativeBridge.gd` autoload and add the `Native` autoload pointing to the C++ wrapper (renamed to avoid collision).
- [x] 3.3. Verify `Main.gd` calls the C++ `NativeBridge` methods correctly.

## 4. iOS Build
- [x] 4.1. Compile the extension for iOS (arm64) as a static library (`.a`).
- [x] 4.2. Verify the library is included in the Godot iOS export (check `.gdextension` resource filters). (Verified: `libdiptych.ios.a` present in Xcode project).
- [x] 4.3. Export to Xcode and deploy to iPhone 12 to verify the app runs and prints logs from C++. (Verified by user: "Hello World" screen displayed on device).
