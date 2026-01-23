# Change: Add Camera Selection Overlay

## Why
To allow users to select which physical camera (Wide, Ultra, Tele) is displayed in each viewer, adhering to the "Instrument-like" design philosophy where controls are overlaid on the preview rather than in a separate status bar.

## What Changes
- **UI Layout**: Removes the dedicated top "Zone A" status bar.
- **Control Overlay**: Adds a persistent text-based control overlay to the bottom of each viewer (Top and Bottom).
- **Interaction**: Users tap the text label to cycle through available cameras for that specific viewer.
- **Native Logic**: Exposes camera switching functionality to the GDExtension layer.

## Impact
- **Specs**:
    - `split-screen-layout`: Updates layout definitions to remove Zone A and add overlay zones.
    - `native-camera-feed`: Adds requirements for selecting specific physical devices per stream.
- **Code**:
    - Godot: Update `Main.tscn` to remove TopBar and add Labels to Viewers.
    - GDExtension (`NativeBridge`): Add methods to `select_camera(view_id, device_id)`.
