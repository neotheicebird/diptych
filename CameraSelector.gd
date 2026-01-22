extends MarginContainer

@export var view_index: int = 0

@onready var label = $CameraLabel

var devices = {} # ID: Name
var device_ids = []
var current_device_idx = 0

func _ready():
	# Wait a bit for native initialization
	await get_tree().create_timer(0.5).timeout
	refresh_devices()

func refresh_devices():
	if Native:
		devices = Native.get_available_devices()
		device_ids = devices.keys()
		
		# Set initial label based on current setup (or default)
		if device_ids.size() > 0:
			# For simplicity in v1, Top defaults to 0, Bottom defaults to 1 if available
			current_device_idx = view_index % device_ids.size()
			update_label()

func update_label():
	if device_ids.size() > 0:
		var id = device_ids[current_device_idx]
		var dev_name = devices[id]
		# Simplify name (e.g. "Back Wide Angle Camera" -> "WIDE")
		label.text = _format_device_name(dev_name)
	else:
		label.text = "NO CAMERA"

func _format_device_name(full_name: String) -> String:
	var n = full_name.to_upper()
	if "ULTRA WIDE" in n: return "ULTRA"
	if "WIDE" in n: return "WIDE"
	if "TELEPHOTO" in n: return "TELE"
	if "FRONT" in n: return "FRONT"
	return n.split(" ")[0]

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		cycle_camera()
	elif event is InputEventScreenTouch and event.pressed:
		cycle_camera()

func cycle_camera():
	if device_ids.size() <= 1:
		return
		
	current_device_idx = (current_device_idx + 1) % device_ids.size()
	var new_id = device_ids[current_device_idx]
	
	if Native:
		Native.set_device(view_index, new_id)
		update_label()
		print("CameraSelector [", view_index, "]: Switched to ", new_id)
