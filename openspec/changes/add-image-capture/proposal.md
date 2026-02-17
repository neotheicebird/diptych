# Change: Add WYSIWYG Image Capture System

## Why
To implement the core photography capability of "Split Dual Camera" with a focus on "What You See Is What You Get" (WYSIWYG) authenticity. The output must honor the split-screen composition presented to the user, rather than saving raw, disconnected sensor data.

## What Changes
- **Capture Logic (Native/C++)**: 
  - Implement logic to capture from active `AVCaptureSession`(s).
  - **Compositing Engine**: New logic to crop and stitch high-resolution sensor images into a single image that matches the split-screen aspect ratio and layout (including the separator).
- **UI (Godot)**:
  - **Shutter Button**: Large white circle in Zone D.
  - **Visual Feedback**:
    - **Flash**: Full-screen white flash on shutter press.
    - **Thumbnail**: Rounded square in bottom-left showing the last capture.
    - **Rainbow Loader**: A stylish, thin rainbow spinner around the thumbnail while saving is in progress.
    - **Idle State**: Light gray border around thumbnail when idle.
- **Integration**:
  - Save the final composited image to iOS Camera Roll.
  - Open Camera Roll when thumbnail is tapped.

## Impact
- **Specs**:
  - `image-capture` (New): Defines stitching and saving requirements.
  - `split-screen-layout` (Modified): Updates Zone D definitions and feedback animations.
- **Architecture**:
  - Requires efficient image processing (likely CoreGraphics or Accelerate on iOS side) to stitch high-res images without stalling the UI.