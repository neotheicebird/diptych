extends Control

# EDUCATIONAL:
# Godot uses a Node-based scene tree. We can reference nodes using the '$' shorthand
# or the get_node() function. Using unique names or clear paths is best practice.
@onready var top_preview = $MainLayout/PanesContainer/ZoneB/TopPreview
@onready var bottom_preview = $MainLayout/PanesContainer/ZoneC/BottomPreview
# EDUCATIONAL:
# Capture UI elements are grouped here so the script can coordinate
# shutter actions, flash feedback, and thumbnail updates.
@onready var shutter_button = $MainLayout/ZoneD/ShutterButton
@onready var thumbnail_button = $MainLayout/ZoneD/ThumbnailButton
@onready var thumbnail_image = $MainLayout/ZoneD/ThumbnailButton/ThumbnailMask/ThumbnailImage
@onready var thumbnail_border = $MainLayout/ZoneD/ThumbnailButton/ThumbnailBorder
@onready var thumbnail_spinner = $MainLayout/ZoneD/ThumbnailButton/ThumbnailSpinner
@onready var flash_overlay = $FlashOverlay

# EDUCATIONAL:
# Layout references let us sync the compositor with the exact on-screen proportions.
@onready var zone_b = $MainLayout/PanesContainer/ZoneB
@onready var divider = $MainLayout/PanesContainer/Divider

var flash_tween: Tween

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
	# Hook up capture UI callbacks so input and feedback stay responsive.
	if shutter_button:
		shutter_button.pressed.connect(_on_shutter_pressed)
	if thumbnail_button:
		thumbnail_button.pressed.connect(_on_thumbnail_pressed)
	
	if Native:
		if Native.has_signal("image_save_started"):
			Native.image_save_started.connect(_on_image_save_started)
		if Native.has_signal("image_save_finished"):
			Native.image_save_finished.connect(_on_image_save_finished)
	
	# EDUCATIONAL:
	# Layout metrics are only valid after the first frame; defer and listen for resizes.
	call_deferred("_sync_composite_layout")
	get_viewport().size_changed.connect(_on_viewport_size_changed)

# EDUCATIONAL:
# _process(delta) runs every frame. We can use it for UI updates that depend on 
# real-time data from the native layer.
func _process(_delta):
	# If NativeBridge requires manual polling for updates (though our C++ code 
	# currently updates the texture internally), we could do it here.
	pass

# EDUCATIONAL:
# Shutter interaction triggers both the visual flash and the native still capture.
func _on_shutter_pressed():
	_trigger_flash()
	if Native:
		Native.capture_split_image()

func _on_thumbnail_pressed():
	# EDUCATIONAL:
	# Tapping the thumbnail opens the system Photos app.
	if Native:
		Native.open_photo_library()

func _on_image_save_started():
	# EDUCATIONAL:
	# Swap the static border for the animated spinner while saving.
	if thumbnail_border:
		thumbnail_border.visible = false
	if thumbnail_spinner:
		thumbnail_spinner.visible = true

func _on_image_save_finished(thumbnail_data: PackedByteArray):
	# EDUCATIONAL:
	# Decode the thumbnail bytes and update the UI with the latest capture.
	if thumbnail_spinner:
		thumbnail_spinner.visible = false
	if thumbnail_border:
		thumbnail_border.visible = true
	
	if thumbnail_image and thumbnail_data.size() > 0:
		var image := Image.new()
		var err = image.load_png_from_buffer(thumbnail_data)
		if err == OK:
			var texture := ImageTexture.create_from_image(image)
			thumbnail_image.texture = texture
		else:
			push_error("ERROR: Failed to decode thumbnail data")

func _trigger_flash():
	# EDUCATIONAL:
	# A quick white flash reinforces the shutter action without blocking capture.
	if not flash_overlay:
		return
	
	if flash_tween:
		flash_tween.kill()
	
	flash_overlay.visible = true
	flash_overlay.modulate.a = 0.0
	flash_tween = create_tween()
	flash_tween.tween_property(flash_overlay, "modulate:a", 1.0, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(flash_overlay, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flash_tween.tween_callback(func(): flash_overlay.visible = false)

func _on_viewport_size_changed():
	_sync_composite_layout()

func _sync_composite_layout():
	# EDUCATIONAL:
	# Provide the native compositor with exact viewer dimensions and divider styling.
	if not Native or not zone_b or not divider:
		return
	
	if zone_b.size.x <= 0 or zone_b.size.y <= 0:
		call_deferred("_sync_composite_layout")
		return
	
	var viewer_width = zone_b.size.x
	var viewer_height = zone_b.size.y
	var separator_thickness = divider.size.y
	var separator_color = divider.color
	
	Native.set_composite_layout(viewer_width, viewer_height, separator_thickness, separator_color)
