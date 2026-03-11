# Change: Add wide inset layout preset

## Why
The v1 layout picker currently supports two presets, but release needs a third preset with a stronger wide-inset identity. We also need a single layout source of truth so live feed and capture remain portrait-authored while picker cards can optionally present orientation-enhanced previews. A small top-margin adjustment for per-panel camera cycle controls is also required.

## What Changes
- Add a third layout preset with internal ID `wide inset`.
- Define all preset geometry, including `wide inset`, as portrait-authored canonical layout snapshots for live feed and capture.
- Set `wide inset` default camera mapping to `main` (background) + `ultra` (inset), with a top-left inset whose long side runs vertically.
- Add preview-orientation metadata for layout cards so picker rendering can present `wide inset` in landscape without changing live-feed geometry.
- Add a small extra top margin for per-panel camera cycle controls across orientations.

## Impact
- Affected specs:
  - `split-screen-layout`
  - `hud-fx-controls`
- Affected code:
  - `LayoutManager.gd`
  - `Main.gd`
