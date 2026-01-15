# Diptych - Hybrid C++/GDScript Architecture

This project is a "walking skeleton" demonstrating a **Hybrid Architecture** for high-performance iOS applications using Godot 4.5+. It combines the ease of GDScript for UI with the raw power of C++ GDExtension for core systems and native integration.

## Project Overview
- **Engine:** Godot 4.5+
- **Languages:** 
  - **GDScript:** UI, Scene management, high-level game logic.
  - **C++ (GDExtension):** Core infrastructure, image processing, native iOS bridging.
- **Target Platform:** iOS (iPhone 12 Baseline).

## Architecture

### The Hybrid Model
The app enforces a strict separation of concerns:
1.  **Godot Layer (GDScript):** Handles all visual elements, user input, and screen navigation. It treats the core systems as a "black box" API.
2.  **Core Layer (C++):** implemented via **GDExtension**. It provides a high-performance backend for heavy lifting (future image processing) and acts as the bridge to native iOS frameworks (`AVFoundation`, etc.).

### Native Bridge
- **`NativeBridge` (C++):** A `Node`-derived class exposed to Godot. It defines the contract for hardware access (Camera, Permissions).
- **`Native` (Autoload):** A global singleton in Godot that provides access to the `NativeBridge` instance anywhere in the app.

## Project Structure
- `project.godot`: Main engine configuration.
- `Main.tscn/gd`: The UI entry point (GDScript).
- `NativeBridge.gd`: A wrapper script extending the C++ class to enable Autoload registration.
- `extension/`: The C++ source code.
    - `src/`: Custom C++ classes (`NativeBridge`, `register_types`).
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

## completed Tasks
- [x] Initial Godot Project Setup (Resolution: 1170x2532).
- [x] iOS Export Configuration (Privacy keys, Icons).
- [x] Migration to C++ GDExtension (Removed C#).
- [x] Validated On-Device Deployment.
