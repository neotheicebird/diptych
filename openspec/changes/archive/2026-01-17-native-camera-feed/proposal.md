# Change: Native Camera Feed Integration

## Why
To enable core functionality of the Diptych app, we need to stream live video from the iOS camera into the Godot engine with minimal latency and high performance.

## What Changes
- Created `CameraManager` (Obj-C++) to interface with AVFoundation.
- Implemented BGRA to RGBA conversion pipeline.
- Updated `NativeBridge` (C++) to manage camera lifecycle and texture updates.
- Integrated camera feed into Godot UI via `ImageTexture` and `TextureRect`.

## Impact
- **Capabilities**: Adds `native-camera-feed` capability.
- **Files**: `extension/src/platform/ios/camera_manager.mm`, `extension/src/camera_manager.h`, `NativeBridge.gd`, `Main.tscn`.
