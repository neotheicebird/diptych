# Split Dual Camera — OpenSpec

## Version
v1.1

## Platform
iOS (iPhone only)

## UI Engine
Godot (GDScript + C++ GDExtension)

## Overview

Split Dual Camera is a minimalist, split-screen camera application designed around **intentional dual-perspective capture**. The split view is the default and primary canvas, not a mode.

The app prioritizes:
- Clarity over automation
- Hardware honesty over illusion
- Calm, instrument-like interaction over feature density

---

## Core Principles

1. **Split canvas first**
   - The app always opens in split view.
   - The split is a compositional format, not a toggle.

2. **Hardware honesty**
   - Dual cameras are used when available.
   - Single-camera devices use a linked fallback without simulating extra hardware.

3. **Consistent UI**
   - Same layout across devices.
   - Capability differences do not change structure.

4. **Playable interaction**
   - Controls behave like a game HUD: analog, responsive, thumb-friendly.
   - The camera is “played”, not configured.

---

## Device Capability Model

### Primary Target Devices
- iPhones with dual rear cameras

### Fallback Devices
- iPhones with a single rear camera (not target audience)

Fallback behavior exists for consistency and stability, not feature parity.

---

## Camera Behavior

### Dual-Camera Devices
- Two rear cameras active simultaneously
- One camera per pane
- Independent:
  - Zoom
  - Focus
  - Exposure

### Single-Camera Devices (Fallback)
- One rear camera active
- Same live feed shown in both panes
- Interactions are linked:
  - Zoom affects both panes
  - Focus affects both panes

No attempt is made to imply multiple perspectives.

---

## Preview Layout

### Default Layout
- Portrait orientation
- Horizontal split:
  - Top viewer
  - Bottom viewer
- Equal size
- Thin, subtle divider

### Fallback Indicators
- Divider visually suggests linkage (e.g. subtle dotted line or link cue)
- No modal warnings or tooltips

---

## Control Philosophy

Controls are overlaid like a game HUD:
- Always visible
- Low visual weight
- Spatially consistent
- Optimized for one-handed use

No control requires navigating away from the preview.

---

## Control Zones (Textual Layout)

### Zone B — Top Camera Viewer
- Full interactive preview
- Tap:
  - Focus + exposure
- Pinch:
  - Zoom interaction
- Control Area (Bottom 5–10% of viewer):
  - Camera Label: Display selected camera (e.g., Wide, Ultra, Tele) in gray/white text.
  - Position: Right-aligned within the area.
  - Interaction: Tappable to change camera selection for this viewer.

---

### Zone C — Bottom Camera Viewer
- Mirrors Zone B exactly (including independent Control Area)
- Symmetry is required for muscle memory

---

### Zone D — Primary Control Band (Bottom)
- Height: ~18–22% of screen

#### Shutter Control
- Large white circular button
- Centered horizontally
- Positioned ~1 inch above Apple Camera default
- Tap only
- Dominant visual anchor

#### Secondary Controls
- Reserved space left/right of shutter
- Empty in v1
- Exists to balance layout and allow future expansion

---

## Zoom Behavior

- Analog (continuous)
- Pinch-to-zoom gesture on each viewer
- Light haptic feedback at major zoom milestones

### Zoom Linking
- Dual-cam devices: independent per viewer
- Single-cam devices: linked across viewers

---

## Focus Behavior

- Tap anywhere in a pane:
  - White square focus indicator
  - Fades smoothly
- Single-cam fallback:
  - Indicator mirrored in both panes

---

## Camera Selection

- Small, unobtrusive label in each viewer's control area
- Allows selecting which physical camera maps to that viewer
- Interaction:
  - Tap label to cycle through available cameras
- No automatic camera switching

Unavailable cameras are ignored gracefully.

---

## Capture Behavior

- Single shutter triggers capture
- Dual-cam devices:
  - Two images captured simultaneously
- Single-cam devices:
  - One image captured

### Output (v1)
- Images saved separately
- Same timestamp
- No compositing or stitching

---

## Rendering & Architecture

- Godot (GDScript) handles:
  - Rendering
  - Split composition
  - HUD
  - Input semantics
- C++ GDExtension (Native Bridge) handles:
  - Camera access (AVFoundation bridge)
  - Permissions
  - Capture execution
  - High-performance data marshalling

The two layers communicate via a strict message boundary (Function calls & Signals).

---

## Performance Goals

- Stable real-time preview
- Minimal latency between input and camera response
- No perceptible UI lag
- GPU used for composition and overlays

---

## Visual Design Constraints

- Color palette:
  - White
  - Light gray
  - Subtle alpha
- No gradients
- No skeuomorphism
- No decorative animation

Controls should feel **instrumental**, not playful.

---

## App Store Considerations

- Clearly state dual-camera requirements
- Explicitly mention single-camera fallback behavior
- No misleading lens or perspective claims
- No private APIs

---

## Non-Goals (v1)

- Three-camera capture
- Video recording
- Filters or effects
- Computational lens fusion
- Auto lens switching
- User-customizable layouts

---

## Success Criteria

- App always opens in split view
- Dual-cam capture feels stable and intentional
- UI feels calm, predictable, and confident
- Fallback behavior does not feel broken or deceptive
- The app feels like a tool with a point of view

---

## End of Spec
