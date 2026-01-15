## Context
The project currently uses GDScript for all logic. We are migrating core infrastructure to C++ via GDExtension to prepare for performance-intensive tasks and cleaner native integration, while keeping UI logic in GDScript for iteration speed.

## Goals
- **Hybrid Architecture**: Use C++ for "Engine/System" logic and GDScript for "Game/UI" logic.
- **iOS Compatibility**: Ensure the GDExtension compiles statically for iOS and links correctly into the exported Xcode project.
- **Maintainability**: Use standard `godot-cpp` workflow.

## Decisions
- **Decision**: Use GDExtension (not C# or Modules).
    - **Rationale**: Best balance of performance and portability without recompiling the engine.
- **Decision**: `NativeBridge` as a C++ Class.
    - **Rationale**: It is the boundary to the OS.
- **Decision**: Keep `Main.tscn` logic in GDScript.
    - **Rationale**: UI layout and simple state management are faster to write in GDScript.

## Risks
- **Build Complexity**: Compiling for iOS requires correct SCons setup (arch `arm64`, platform `ios`).
- **Signing**: The static library must be signed/embedded correctly (handled by Xcode usually).
