# architecture Specification

## Purpose
TBD - created by archiving change initialize-project-architecture. Update Purpose after archive.
## Requirements
### Requirement: Separation of Concerns
The system architecture SHALL enforce a strict separation between the UI/rendering layer and the native services layer.

- The Godot (GDScript) layer is exclusively responsible for UI, rendering, input handling, and application state.
- The Core (C++) layer is responsible for bridging to native services and performance-critical logic.
- The native iOS layer is exclusively responsible for hardware access, including camera control, permissions, and image capture.

#### Scenario: Godot Layer Responsibility
- **GIVEN** the application is running
- **WHEN** a user taps a UI button
- **THEN** the input event is processed entirely within the Godot (GDScript) layer.

#### Scenario: Core Layer Responsibility
- **GIVEN** the application needs to access the camera
- **WHEN** the Godot layer requests camera initialization
- **THEN** the request is routed through the C++ NativeBridge.

#### Scenario: Native Layer Responsibility
- **GIVEN** the C++ layer requests camera access
- **WHEN** the initialization is triggered
- **THEN** all `AVFoundation` interactions are handled exclusively by the native iOS layer.

### Requirement: Message-Based Boundary
Communication between the Godot layer and the native iOS layer MUST be conducted via an explicit, message-based boundary.

- No shared mutable state shall exist between the two layers.
- Godot SHALL invoke native functionality by sending commands or requests.
- The native layer SHALL communicate back to Godot using signals or events.

#### Scenario: Godot to Native Communication
- **GIVEN** the Godot `NativeBridge` singleton exists (implemented in C++)
- **WHEN** a GDScript function calls `NativeBridge.request_camera_permission()`
- **THEN** it executes the compiled C++ logic which marshals the request to the OS.

#### Scenario: Native to Godot Communication
- **GIVEN** a native process (e.g., permission granted) completes
- **WHEN** the native layer needs to notify Godot
- **THEN** it emits a named signal or event (e.g., `permission_granted`) that the Godot layer can listen for.

