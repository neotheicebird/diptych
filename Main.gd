extends Control

# EDUCATIONAL:
# The scene is composed in three layers:
# 1) CameraFeedLayer (base) for live camera textures
# 2) HUDLayer for controls
# 3) FXLayer for transient visual effects
#
# Keeping these concerns separate makes it easier to evolve each layer independently.
@onready var top_preview: TextureRect = $CameraFeedLayer/MainLayout/PanesContainer/ZoneB/TopPreview
@onready var bottom_preview: TextureRect = $CameraFeedLayer/MainLayout/PanesContainer/ZoneC/BottomPreview
@onready var thumbnail_control: TextureRect = $HUDLayer/HUDRoot/ThumbnailControl
@onready var shutter_control: Control = $HUDLayer/HUDRoot/ShutterControl
@onready var shutter_button: Button = $HUDLayer/HUDRoot/ShutterControl/ShutterButton
@onready var flash_overlay: ColorRect = $FXLayer/FXRoot/FlashOverlay

const THUMBNAIL_IDLE_TEXTURE := preload("res://assets/icons/square.svg")
const HUD_ACCENT_COLOR := Color(0.968627, 0.980392, 0.988235, 1.0) # #f7fafc
const HUD_BOTTOM_MARGIN_PX := 24.0
const HUD_SIDE_MARGIN_PX := 24.0
const SHUTTER_PRESS_SCALE := 0.9
const SHUTTER_PRESS_IN_DURATION := 0.06
const SHUTTER_PRESS_OUT_DURATION := 0.09
const FLASH_IN_DURATION := 0.04
const FLASH_OUT_DURATION := 0.16

var shutter_tween: Tween
var fx_tween: Tween

func _ready():
	print("Main: Ready")

	# EDUCATIONAL:
	# We explicitly bind HUD behavior in _ready so the scene stays declarative while
	# interaction logic remains centralized in this script.
	shutter_button.pressed.connect(_on_shutter_pressed)
	resized.connect(_layout_hud_controls)
	_layout_hud_controls()
	thumbnail_control.texture = THUMBNAIL_IDLE_TEXTURE
	thumbnail_control.modulate = HUD_ACCENT_COLOR
	
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

func _layout_hud_controls():
	# EDUCATIONAL:
	# We compute the controls from screen size so center alignment remains correct
	# across iPhone sizes and orientations.
	var shutter_size := shutter_control.custom_minimum_size
	var thumb_size := thumbnail_control.custom_minimum_size
	var target_center_y := size.y - HUD_BOTTOM_MARGIN_PX - (shutter_size.y * 0.5)

	shutter_control.position = Vector2((size.x - shutter_size.x) * 0.5, target_center_y - (shutter_size.y * 0.5))
	shutter_control.size = shutter_size

	thumbnail_control.position = Vector2(HUD_SIDE_MARGIN_PX, target_center_y - (thumb_size.y * 0.5))
	thumbnail_control.size = thumb_size

	# Pivot needs to be at visual center for clean scale animation.
	shutter_button.pivot_offset = shutter_button.size * 0.5
	thumbnail_control.pivot_offset = thumbnail_control.size * 0.5

func _on_shutter_pressed():
	_play_shutter_press_animation()
	_play_flash_fx()
	_try_trigger_shutter_haptic()

func _play_shutter_press_animation():
	if shutter_tween:
		shutter_tween.kill()

	shutter_button.scale = Vector2.ONE
	shutter_tween = create_tween()
	shutter_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shutter_tween.tween_property(shutter_button, "scale", Vector2.ONE * SHUTTER_PRESS_SCALE, SHUTTER_PRESS_IN_DURATION)
	shutter_tween.set_ease(Tween.EASE_IN)
	shutter_tween.tween_property(shutter_button, "scale", Vector2.ONE, SHUTTER_PRESS_OUT_DURATION)

func _play_flash_fx():
	if fx_tween:
		fx_tween.kill()

	flash_overlay.modulate.a = 0.0
	fx_tween = create_tween()
	fx_tween.tween_property(flash_overlay, "modulate:a", 0.9, FLASH_IN_DURATION)
	fx_tween.tween_property(flash_overlay, "modulate:a", 0.0, FLASH_OUT_DURATION)

func _try_trigger_shutter_haptic():
	# Use the native haptic bridge only if the method is already available.
	if Native and Native.has_method("trigger_haptic_impact"):
		Native.trigger_haptic_impact()

# EDUCATIONAL:
# _process(delta) runs every frame. We can use it for UI updates that depend on
# real-time data from the native layer.
func _process(_delta):
	# If NativeBridge requires manual polling for updates (though our C++ code
	# currently updates the texture internally), we could do it here.
	pass
