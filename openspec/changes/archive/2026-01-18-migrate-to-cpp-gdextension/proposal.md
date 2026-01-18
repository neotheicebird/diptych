# Change: Migrate to C++ GDExtension

## Why
To establish a high-performance foundation for the application's core logic and facilitate robust integration with native platform features. Transitioning core systems to C++ ensures predictable performance and provides a strongly-typed, industry-standard environment for future complex image processing tasks.

## What Changes
- **Infrastructure**:
    - Add `godot-cpp` as a submodule.
    - Configure SCons build system for macOS (Editor) and iOS (Target) compilation.
- **Codebase**:
    - Port `NativeBridge` from GDScript to C++ as a GDExtension class.
    - Register the C++ `NativeBridge` class as the Autoload singleton in `project.godot`.
    - Keep `Main.gd` (UI logic) in GDScript, consuming the C++ `NativeBridge`.
- **Breaking**:
    - `NativeBridge.gd` will be removed.

## Impact
- **Specs**: Updates `architecture` to reflect C++ as the backend language.
- **Build**: Introduces a compilation step (SCons) before Godot export.
