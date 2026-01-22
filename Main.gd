extends Control

# EDUCATIONAL:
# Godot uses a Node-based scene tree. We can reference nodes using the '$' shorthand
# or the get_node() function. Using unique names or clear paths is best practice.
@onready var top_preview = $MainLayout/PanesContainer/ZoneB/TopPreview
@onready var bottom_preview = $MainLayout/PanesContainer/ZoneC/BottomPreview

func _ready():
	print("Main: Ready")
	
	# EDUCATIONAL:
	# Hybrid Architecture Communication:
	# Here, GDScript (UI) calls into GDExtension (C++) via the 'Native' singleton.
	# This singleton is registered in C++ and made available to Godot as an Autoload.
	if Native:
		Native.start_camera()
		
		# EDUCATIONAL:
		# GDExtension can return Godot-native types like Ref<Texture2D>.
		# This allows for seamless high-performance data sharing between C++ and UI.
		var tex_top = Native.get_texture_top()
		var tex_bottom = Native.get_texture_bottom()
		
		if tex_top and tex_bottom:
			top_preview.texture = tex_top
			bottom_preview.texture = tex_bottom
		else:
			push_error("ERROR: CAMERA TEXTURE NULL")
	else:
		push_error("ERROR: NATIVE BRIDGE NOT FOUND")

# EDUCATIONAL:
# _process(delta) runs every frame. We can use it for UI updates that depend on 
# real-time data from the native layer.
func _process(_delta):
	# If NativeBridge requires manual polling for updates (though our C++ code 
	# currently updates the texture internally), we could do it here.
	pass
