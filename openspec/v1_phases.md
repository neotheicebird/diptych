Phase 1: Foundation & Core Pipeline

  1. Project Initialization & Architecture
   * Goal: Establish the Godot project and the C++ GDExtension structure.
   * Tasks:
       * Initialize Godot project.
       * Set up GDExtension with C++ (godot-cpp).
       * Configure iOS export settings and SCons build system.
       * Set up the message boundary/architecture for Godot <-> C++ <-> iOS Native communication.

  2. Native Camera Feed Integration
   * Goal: Get a live camera feed rendering inside Godot via GDExtension.
   * Tasks:
       * Implement iOS native code (Obj-C++) to initialize AVCaptureSession.
       * Expose camera texture data to Godot through GDExtension (Texture2D/Image).
       * Handle camera permission requests on app launch.

  3. Split-Screen Layout (The "Canvas")
   * Goal: Implement the visual structure of the app.
   * Tasks:
       * Create the UI layout in Godot with two equal vertical panes (Zone B & Zone C).
       * Implement Zone A (Top Status) and Zone D (Bottom Control) placeholders.
       * Draw the subtle divider between panes.

  Phase 2: Camera Logic & Interaction

  4. Dual-Stream Logic & Fallback
   * Goal: Handle device capabilities (Dual vs. Single).
   * Tasks:
       * Dual-Cam: Configure AVCaptureMultiCamSession (if available) to stream two distinct cameras.
       * Fallback: Detect single-cam devices and route the single feed to both Godot textures.
       * UI: Update the divider visual based on the mode (linked vs. independent).

  5. Camera Selection HUD (Zone A)
   * Goal: Allow users to assign cameras to panes.
   * Tasks:
       * Implement the UI control in Zone A.
       * Connect UI actions to the native layer to switch physical input devices for the specific pane.

  6. Interactive Controls (Zoom & Focus)
   * Goal: Implement the "Game HUD" interactions.
   * Tasks:
       * Zoom: Create vertical drag strips on the edges of Zone B & C. Map drag delta to native zoom factor.
       * Focus: Implement tap-to-focus (convert screen coordinates to camera sensor point of interest).
       * Linking: Ensure controls affect one or both cameras based on the active mode (Dual vs. Fallback).

  Phase 3: Capture & Output

  7. Image Capture System
   * Goal: Take photos and save them.
   * Tasks:
       * Implement the Shutter Button in Zone D (large white circle).
       * Trigger high-resolution capture from the active AVCaptureSession.
       * Handle simultaneous capture for dual streams.
       * Save resulting image(s) to the iOS Camera Roll.

  Phase 4: Polish

  8. Visual Polish & Performance
   * Goal: Meet the "Instrument-like" aesthetic.
   * Tasks:
       * Style all UI elements (White/Light Gray, no gradients).
       * Implement haptic feedback for zoom milestones.
       * Optimize rendering to ensure steady 60fps (or native refresh rate).
