# Change: Add Interactive Controls (Zoom & Focus)

## Why
To fulfill the "playable interaction" core principle, the camera interface must behave like a game HUD. Users expect analog, responsive control over the optical system (zoom and focus) without navigating menus. This change implements the logic to translate gestures into native camera commands.

## What Changes
- **New Capability**: `interactive-controls`
- **Zoom**: Pinch gestures map to native video zoom factor.
- **Focus**: Tap gestures map to point-of-interest focus and exposure.
- **Feedback**: Haptic feedback added for zoom milestones.
- **Logic**: Control linking implemented to handle single-camera fallback (one input drives both views) vs dual-camera independence (separate inputs).

## Impact
- **New Spec**: `specs/interactive-controls/spec.md`
- **Native Bridge**: New methods to set zoom factor and focus point per session/device.
- **Godot UI**: New gesture handling scripts on the Viewers.
