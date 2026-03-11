# Change: Update v1 Layout Picker and Panel Camera Controls

## Why
The current layout and camera switching surface is broader than the v1 release target. We need a tighter, more familiar interaction model that keeps the app's dual-perspective identity while reducing decision friction.

## What Changes
- Reduce selectable layouts to exactly two presets:
- `include_photographer`: fullscreen rear `main` panel with a rounded-square front-camera inset in the lower-left corner.
- `zoomies`: stacked dual split with top `main` and bottom `tele` by default.
- Keep preset IDs internal; user-facing layout cards are visual-only (no layout text labels).
- Enlarge the layout picker presentation to a large-card popup proportion (Instagram-like long-press preview feel), and keep only this large state in v1.
- Recreate the picker as a clean visual chooser: remove "future" tabs/options and non-essential helper copy.
- Replace per-panel bottom camera label tap target with a top-right circular refresh control per panel for camera cycling.
- Show a temporary camera label (for example `front`, `main`, `tele`, `ultra` or zoom-style equivalents) for a short duration after each panel camera switch.
- Add a thin, dull-white border around every active panel.

## Impact
- Affected specs:
- `split-screen-layout`
- `hud-fx-controls`
- Affected code:
- `LayoutManager.gd`
- `Main.gd`
- `Main.tscn`
- `CameraControlManager.gd`
