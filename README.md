# Diptych - Dual-Stream Camera App

This project is a high-performance iOS application built with **Godot 4.5+** and **C++ GDExtension**. Its core feature is the ability to capture and display two simultaneous camera feeds (e.g., Front and Back) using iOS `AVCaptureMultiCamSession`.

## Project Overview
- **Engine:** Godot 4.5+
- **Languages:** 
  - **GDScript:** UI, Scene management, layout logic.
  - **C++ (GDExtension):** Core infrastructure, native Camera management (`AVFoundation`), image processing.
- **Target Platform:** iOS (iPhone 12 Baseline).
- **Key Feature:** Simultaneous Dual-Stream Video (MultiCam) with fallback for single-camera devices.

## Architecture

### The Hybrid Model
The app enforces a strict separation of concerns:
1.  **Godot Layer (GDScript):** Handles the "Split-Screen" UI, rendering two distinct texture rects for the camera feeds.
2.  **Core Layer (C++):** implemented via **GDExtension**. It manages the `AVCaptureMultiCamSession` and exposes two live texture targets (`Top` and `Bottom`) to Godot.

### Native Bridge
- **`NativeBridge` (C++):** A `Node`-derived class exposed to Godot.
    - `start_camera()`: Initializes the native session (MultiCam if supported).
    - `get_texture_top()` / `get_texture_bottom()`: Returns the `ImageTexture` resources for the two feeds.
    - `is_multicam_supported()`: Returns `true` if the device supports simultaneous capture.
- **`Native` (Autoload):** A global singleton in Godot that provides access to the `NativeBridge` instance anywhere in the app.

## Project Structure
- `project.godot`: Main engine configuration.
- `Main.tscn/gd`: The UI entry point. Manages the split-screen layout.
- `NativeBridge.gd`: A wrapper script extending the C++ class to enable Autoload registration.
- `extension/`: The C++ source code.
    - `src/`: Custom C++ classes (`NativeBridge`, `CameraManager`).
    - `src/platform/ios/`: Native iOS `AVFoundation` implementation.
    - `godot-cpp/`: The Godot C++ bindings submodule.
    - `SConstruct`: The build configuration file (SCons).
- `bin/`: Compiled GDExtension libraries (`.a`, `.framework`, `.gdextension`).
- `build/ios/`: The exported Xcode project.

## How to Build

### Prerequisites
1.  **Godot 4.5+** installed.
2.  **Python 3.x** and **SCons** (`pip install scons`).
3.  **Xcode** installed on macOS.

### 1. Compile C++ Extension
Before opening Godot or exporting, you must compile the C++ extension.

**For macOS (Editor):**
```bash
cd extension
scons platform=macos arch=arm64 target=editor
```

**For iOS (Device):**
```bash
cd extension
scons platform=ios arch=arm64 target=template_debug
```
*Note: This produces a static library (`libdiptych.ios.a`) in `bin/` which includes both the extension and the Godot C++ bindings.*

### 2. Export to Xcode
1.  Open `project.godot` in the Godot Editor.
2.  Go to **Project > Export**.
3.  Select **iOS**.
4.  Click **Export Project** (Export Path: `build/ios/Diptych.xcodeproj`).

*Alternatively, via CLI:*
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --export-debug "iOS" build/ios/Diptych.xcodeproj
```

### 3. Run on Device
1.  Open `build/ios/Diptych.xcodeproj` in Xcode.
2.  **Important:** Ensure `libdiptych.ios.a` is linked. (The export process usually handles this via the `.gdextension` file configuration).
3.  Select your Development Team in **Signing & Capabilities**.
4.  Connect your iPhone and press **Run**.

## Completed Tasks
- [x] Initial Godot Project Setup (Resolution: 1170x2532).
- [x] iOS Export Configuration (Privacy keys, Icons).
- [x] Migration to C++ GDExtension.
- [x] **Dual-Stream Logic:** Simultaneous capture from two cameras.
- [x] **Split-Screen Layout:** UI implementation for top/bottom feeds.
- [x] Validated On-Device Deployment.
