# Change: Implement Split-Screen Layout

## Why
To establish the fundamental visual structure of the application ("The Canvas"), enabling the intentional dual-perspective experience. This layout serves as the container for all future camera feeds and controls.

## What Changes
- Implement the "Split Canvas" layout with two equal vertical panes (Zone B & Zone C).
- Add placeholders for the Top Status Band (Zone A) and Bottom Control Band (Zone D).
- Render the visual divider between the two panes.
- Ensure the layout adapts to the target device screen (iPhone Portrait).

## Impact
- **New Capability**: `split-screen-layout`
- **Affected Code**: `Main.tscn`, `Main.gd` (or new UI scene files).
