# Change: Add WYSIWYG Layout-Driven Image Capture System

## Why
To implement authentic WYSIWYG photo capture where saved output matches the live composition exactly, while remaining robust to future layout changes (stacked, grid, or overlay) without rewriting capture logic per layout.

## What Changes
- **Layout Source of Truth**:
  - Introduce `LayoutManager` as the canonical owner of feed arrangement.
  - Define a shared `LayoutSnapshot` contract (normalized geometry, z-order, stream bindings, separators, overlays, and fallback policy).
- **Capture Logic (Native/C++)**:
  - Implement frame capture from active `AVCaptureSession`(s) keyed by stream ID.
  - Build an immutable `CapturePlan` from `LayoutSnapshot` at shutter time.
  - Implement a generic compositing engine that applies the plan to high-resolution frames and renders one final image.
- **UI (Godot)**:
  - Keep shutter, flash, thumbnail, and save-state feedback behavior.
  - Drive preview layout and capture layout from the same `LayoutSnapshot`.
- **Integration**:
  - Save the final composited image to iOS Camera Roll.
  - Open Camera Roll when thumbnail is tapped.

## Impact
- **Specs**:
  - `image-capture` (New): Defines layout-driven WYSIWYG composition and saving requirements.
- **Architecture**:
  - Decouples feed capture from layout composition via shared contracts.
  - Requires efficient image processing (CoreGraphics or Accelerate on iOS side) to avoid UI stalls.
- **Documentation**:
  - Update project documentation to describe the `LayoutManager`-centric flow and shared preview/capture contracts.
