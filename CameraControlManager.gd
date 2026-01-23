extends Node
class_name CameraControlManager

# State
var zoom_factors = [1.0, 1.0]
var min_zoom = 1.0
var max_zoom = 10.0 # Clamp to reasonable limit

# Haptics
# In Godot 4, Input.vibrate_handheld() is simple vibration.
# For specific iOS haptics (impact), we might need NativeBridge support later.
# For now, we can omit or just use basic feedback if available.
# But spec says "Trigger iOS Haptics (UIImpactFeedbackGenerator) on zoom integer milestones".
# We didn't add haptics to NativeBridge yet. 
# Task 3.3 says "Trigger iOS Haptics".
# I should probably add `trigger_haptic_impact()` to NativeBridge later. 
# For now, I'll put a TODO.

# Linking
var is_dual_mode = false

func _ready():
	if Native:
		is_dual_mode = Native.is_multicam_supported()
		if Native.has_signal("permission_granted"):
			Native.permission_granted.connect(_on_permission_granted)
	
	# Initial zoom
	zoom_factors[0] = 1.0
	zoom_factors[1] = 1.0

func _on_permission_granted():
	if Native:
		is_dual_mode = Native.is_multicam_supported()
		print("CameraControlManager: Permission granted. Dual Mode: ", is_dual_mode)

func handle_zoom_delta(view_index: int, zoom_delta: float):
	var current = zoom_factors[view_index]
	var new_zoom = current * zoom_delta
	set_zoom(view_index, new_zoom)

func set_zoom(view_index: int, value: float):
	var old_zoom = zoom_factors[view_index]
	var new_zoom = clamp(value, min_zoom, max_zoom)
	zoom_factors[view_index] = new_zoom
	
	# Haptic check (Integer crossing)
	if floor(old_zoom) != floor(new_zoom):
		_trigger_haptic()

	# Apply
	if Native:
		if is_dual_mode:
			Native.set_zoom_factor(view_index, new_zoom)
		else:
			# Fallback: Link controls. 
			# If we touch ZoneB (0), we affect the single camera.
			# If we touch ZoneC (1), we affect the single camera.
			# And we should update the OTHER zoom factor to match visual state if we want to keep them in sync?
			# In fallback, there is only one camera stream (mirrored).
			# So we should set both.
			zoom_factors[0] = new_zoom
			zoom_factors[1] = new_zoom
			Native.set_zoom_factor(0, new_zoom) # Primary
			Native.set_zoom_factor(1, new_zoom) # Secondary (if applicable logic)

func handle_focus(view_index: int, relative_point: Vector2):
	# relative_point is (0..1, 0..1) relative to the Viewer
	
	if Native:
		if is_dual_mode:
			Native.set_focus_point(view_index, relative_point.x, relative_point.y)
		else:
			# Fallback: Linked
			Native.set_focus_point(0, relative_point.x, relative_point.y)
			# Theoretically we should update visual indicator on both views
			# This manager deals with Logic. Visuals are on ViewerInput.

func _trigger_haptic():
	# iOS Haptic Impact
	if Native:
		Native.trigger_haptic_impact()
	else:
		print("Haptic Impact (Mock)")
