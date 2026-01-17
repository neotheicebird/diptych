# Project Context

## Purpose

This project is an iOS camera application built around a **split-screen capture format**.  
The goal is to create a calm, intentional, instrument-like camera experience that allows users to capture dual perspectives simultaneously, without computational tricks or feature overload.

The app prioritizes:
- Compositional clarity over automation
- Hardware honesty over illusion
- Real-time performance and responsiveness
- A consistent visual and interaction model across supported devices

The split view is the primary canvas, not a mode.

---

## Tech Stack

- Godot Engine (UI, rendering, interaction)
- C++ GDExtension (Native Bridge & Performance Critical Logic)
- Native iOS layer (Objective-C++/Swift mixed via GDExtension)
- AVFoundation (camera hardware control)
- iOS Photos framework (saving captured images)

Godot is used for UI, rendering, and high-level input handling.
All camera access, heavy lifting, and platform-specific capture logic lives in the C++ GDExtension and native iOS layer.

---

## Project Conventions

### Code Style

- Prefer clarity over cleverness
- Explicit naming over abbreviations
- Avoid over-abstracting early
- Keep Godot-side code declarative and state-driven
- Keep native-side code imperative and hardware-focused

Naming should reflect **intent**, not implementation detail.

---

### Architecture Patterns

- **Strict separation of concerns**
  - Native iOS layer (C++/Obj-C):
    - Camera access
    - Permissions
    - Capture execution
  - Godot layer (GDScript):
    - Rendering
    - HUD and overlays
    - Input semantics and control zones

- **Message-based boundary**
  - Communication between Godot and native uses explicit commands and signals via GDExtension
  - No shared mutable state across layers
  - `NativeBridge` singleton acts as the interface

- **Split canvas as a constant**
  - UI layout does not branch by device capability
  - Only camera capability changes behavior, not structure

---

### Testing Strategy

- Manual testing is prioritized in v1
- Focus on:
  - Input responsiveness
  - Frame stability
  - Correct camera selection and fallback behavior
- Test across:
  - Dual-camera devices (primary target)
  - Single-camera devices (fallback only)

Automated tests (e.g., GDExtension unit tests) are optional but encouraged for core logic.

---

### Git Workflow

- Trunk-based development preferred
- Small, focused commits
- Commit messages describe **intent**, not just files changed
- Avoid long-lived feature branches

The project favors momentum and iteration over heavy process.

---

## Domain Context

- The app is **not** a general-purpose camera replacement
- It is a **format-driven camera tool**
- Users are expected to:
  - Understand basic photography concepts
  - Appreciate compositional control
  - Value consistency and restraint

Apple’s default Camera app uses private APIs and computational fusion; this app intentionally does not attempt to replicate that behavior.

---

## Important Constraints

- iOS only (iPhone)
- Photo capture only (no video in v1)
- Dual-camera devices are the primary target
- Single-camera devices are supported as a fallback, not a focus
- No private APIs
- No deceptive UI or hardware claims
- Performance and responsiveness are more important than feature breadth

The app must always feel honest and intentional.

---

## External Dependencies

- iOS camera hardware via AVFoundation
- Godot engine runtime
- iOS system frameworks for permissions and photo storage

No external services, cloud APIs, or third-party SDKs are required in v1.
