# Change: Add Camera Selection HUD

## Why
Users currently have no way to select which physical camera (Wide, Ultra Wide, Telephoto) is assigned to the top or bottom split-screen panes. The app defaults to a fixed configuration. To fulfill the "Instrument-like" design goal, users need direct, independent control over the lens selection for each pane.

## What Changes
- **New HUD UI**: Implement controls in "Zone A" (Top Status Bar) to cycle lenses for Top and Bottom panes.
- **Native Bridge API**: Expose available device cameras and methods to route them to specific split-screen views.
- **Fallback Logic**: Handle single-camera devices gracefully by locking or linking the selectors.

## Impact
- **Affected Specs**: `camera-selection-hud` (New Capability)
- **Affected Code**: 
    - `Main.tscn` / `Main.gd` (UI)
    - `extension/src/native_bridge.h/cpp` (Binding)
    - `extension/src/camera_manager.h` (Logic)
    - Platform implementations (iOS/Dummy)
