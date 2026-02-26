## Context
v1 is being narrowed to a focused feature slice while preserving the core dual-perspective identity. The current UI supports more layout options than needed and uses a smaller layout chooser. Camera switching is currently less discoverable than desired.

## Goals / Non-Goals
- Goals:
- Limit user-facing layout options to two strong defaults.
- Make layout choice visual-only (no layout text labels in picker cards).
- Increase layout picker familiarity with a large, card-like popup presentation.
- Improve panel-level camera switching discoverability with an explicit top-right control.
- Add clear panel boundaries that remain subtle in the live camera experience.
- Non-Goals:
- Implementing the future smaller picker state with menu emphasis.
- Adding new capture formats beyond the two v1 layouts.
- Changing pinch/zoom interaction fundamentals already implemented per panel.

## Decisions
- Decision: Use two preset IDs (`include_photographer`, `zoomies`) and remove other presets from the picker list.
  - Rationale: Reduces cognitive load and sharpens the v1 product surface.
- Decision: Keep preset IDs internal and present visual-only layout cards without text labels.
  - Rationale: Preserves implementation clarity while maximizing signal and minimizing UI noise.
- Decision: Use a large rounded-card layout picker overlay as the only v1 presentation state.
  - Rationale: Matches familiar interaction proportions and prioritizes preview clarity.
- Decision: Keep the picker visual-first by removing future tabs and non-essential copy.
  - Rationale: Produces a high-signal, low-noise selection surface.
- Decision: Move panel camera switching to top-right circular refresh controls.
  - Rationale: Improves discoverability and avoids accidental taps in lower overlay areas.
- Decision: Show temporary per-panel camera labels for short confirmation after switch.
  - Rationale: Preserves low visual noise while confirming state changes.

## Risks / Trade-offs
- Larger picker footprint may obscure more of the live preview while open.
  - Mitigation: Keep the interaction lightweight and dismiss quickly after selection.
- Tele default in `zoomies` may not exist on all devices.
  - Mitigation: Fall back deterministically to the next available rear camera.

## Migration Plan
1. Update layout catalog and geometry generation in `LayoutManager`.
2. Update HUD layout picker sizing and options in `Main` scene/script.
3. Replace per-panel switch affordances with top-right circular controls.
4. Add temporary label rendering tied to panel switch events.
5. Add panel border styling and validate both layouts on supported device classes.

## Open Questions
- None for this proposal; the v1 scope is intentionally narrowed and explicit.
