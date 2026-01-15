## ADDED Requirements
### Requirement: Separation of Concerns
The system architecture SHALL enforce a strict separation between the UI/rendering layer and the native services layer.

- The Godot (C#) layer is exclusively responsible for UI, rendering, input handling, and application state.
- The native iOS layer is exclusively responsible for hardware access, including camera control, permissions, and image capture.

#### Scenario: Godot Layer Responsibility
- **GIVEN** the application is running
- **WHEN** a user taps a UI button
- **THEN** the input event is processed entirely within the Godot layer.

#### Scenario: Native Layer Responsibility
- **GIVEN** the application needs to access the camera
- **WHEN** the Godot layer requests camera initialization
- **THEN** all `AVFoundation` interactions are handled exclusively by the native iOS layer.

### Requirement: Message-Based Boundary
Communication between the Godot layer and the native iOS layer MUST be conducted via an explicit, message-based boundary.

- No shared mutable state shall exist between the two layers.
- Godot SHALL invoke native functionality by sending commands or requests.
- The native layer SHALL communicate back to Godot using signals or events.

#### Scenario: Godot to Native Communication
- **GIVEN** the Godot `NativeBridge` singleton exists
- **WHEN** a C# function like `RequestCameraPermission()` is called
- **THEN** it is marshalled as a message to the corresponding native iOS implementation.

#### Scenario: Native to Godot Communication
- **GIVEN** a native process (e.g., permission granted) completes
- **WHEN** the native layer needs to notify Godot
- **THEN** it emits a named signal or event (e.g., `permission_granted`) that the Godot layer can listen for.
