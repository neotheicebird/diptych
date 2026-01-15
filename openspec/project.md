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
- C# (Godot scripting)
- Native iOS layer (camera access and capture)
- AVFoundation (camera hardware control)
- iOS Photos framework (saving captured images)

Godot is used strictly for UI, rendering, and input handling.  
All camera access and capture logic lives in the native iOS layer.

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
  - Native iOS layer:
    - Camera access
    - Permissions
    - Capture execution
  - Godot layer:
    - Rendering
    - HUD and overlays
    - Input semantics and control zones

- **Message-based boundary**
  - Communication between Godot and native uses explicit commands and events
  - No shared mutable state across layers

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

Automated tests are optional but should not slow iteration.

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
