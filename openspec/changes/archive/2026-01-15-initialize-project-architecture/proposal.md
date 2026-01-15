# Change: Initialize Project Architecture

## Why
To establish the foundational structure for the Diptych application. This initial setup is the prerequisite for all subsequent development, enabling a "walking skeleton" that can be deployed to an iPhone for early validation of the build and export pipeline.

## What Changes
- A new Godot project will be created with C# support.
- iOS export presets will be configured, including placeholder permissions for camera and photo library access.
- A new `architecture` spec will be created to formalize the separation of concerns between the Godot (UI) and native iOS (Camera) layers.
- A new `ios-integration` spec will be created to define iOS-specific project requirements.

## Impact
- **New Specs:**
  - `architecture`
  - `ios-integration`
- **Affected Code:**
  - This is a foundational change; it creates the project structure itself. No existing code is affected.
