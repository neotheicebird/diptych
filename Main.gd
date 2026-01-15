extends Control

# EDUCATIONAL:
# _ready() is a built-in Godot lifecycle method. It runs once when the node 
# and its children have entered the scene tree and are ready.
func _ready():
	print("Hello World from GDScript")

	# EDUCATIONAL:
	# Here we demonstrate the Hybrid Architecture.
	# 'Native' is our Autoload singleton (implemented in C++, wrapped in GDScript).
	# We call a function defined in C++ (request_camera_permission) directly from GDScript.
	# This shows how the UI layer triggers high-performance native code.
	if Native:
		Native.request_camera_permission()

	# EDUCATIONAL:
	# $Path is a shorthand for get_node("Path") to access child nodes.
	var label = $Label
	if label:
		label.text = "Hello World (GDScript Verified)"