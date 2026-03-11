## 1. Layout preset and defaults
- [x] 1.1 Add the new `wide inset` preset to `LayoutManager` options.
- [x] 1.2 Implement `wide inset` snapshot geometry: full-screen base panel + inset panel.
- [x] 1.3 Ensure `wide inset` uses default cameras `main` (base) and `ultra` (inset).
- [x] 1.4 Update the `wide inset` geometry ratio to 18:6 by magnitude (implemented as 6:18 width:height in portrait).
- [x] 1.5 Ensure preset geometry remains portrait-authored canonical data used by live feed and capture.
- [x] 1.6 Move `wide inset` to the top-left corner and orient it vertically (6:18 width:height).

## 2. Layout picker presentation
- [x] 2.1 Include `wide inset` as a third selectable visual-only layout card.
- [x] 2.2 Add a preview orientation property to layout options and use it only in layout-card rendering.
- [x] 2.3 Render the `wide inset` picker preview in landscape based on preview orientation metadata, without mutating live layout snapshots.
- [x] 2.4 Verify live feed geometry for `wide inset` still follows the portrait-authored snapshot.

## 3. Panel switch control spacing
- [x] 3.1 Add a small extra top margin for panel camera cycle controls across orientations.

## 4. Validation
- [x] 4.1 Validate `openspec validate add-wide-inset-layout-preset --strict`.
- [x] 4.2 Verify all three presets render correctly and publish valid layout snapshots.
