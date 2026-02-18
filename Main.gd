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
@onready var layout_control: TextureRect = $HUDLayer/HUDRoot/LayoutControl
@onready var shutter_control: Control = $HUDLayer/HUDRoot/ShutterControl
@onready var shutter_button: Button = $HUDLayer/HUDRoot/ShutterControl/ShutterButton
@onready var flash_overlay: ColorRect = $FXLayer/FXRoot/FlashOverlay

const THUMBNAIL_IDLE_TEXTURE := preload("res://assets/icons/square.svg")
const HUD_ACCENT_COLOR := Color(0.968627, 0.980392, 0.988235, 1.0) # #f7fafc
const HUD_ROW_FROM_BOTTOM_RATIO := 0.10
const HUD_SIDE_MARGIN_RATIO := 0.05
const SHUTTER_PRESS_SCALE := 0.9
const SHUTTER_PRESS_IN_DURATION := 0.06
const SHUTTER_PRESS_OUT_DURATION := 0.09
const FLASH_IN_DURATION := 0.04
const FLASH_OUT_DURATION := 0.16
const THUMBNAIL_MIN_PROCESSING_DURATION := 0.56
const THUMBNAIL_MOCK_SAVE_DURATION := 0.72
const THUMBNAIL_PULSE_SCALE := 0.92
const THUMBNAIL_PULSE_HALF_DURATION := 0.18
const THUMBNAIL_PULSE_ALPHA := 0.6

var shutter_tween: Tween
var fx_tween: Tween
var thumbnail_tween: Tween
var thumbnail_processing_sequence := 0
var thumbnail_processing_started_msec := 0

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
	layout_control.modulate = HUD_ACCENT_COLOR
	
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
	var viewport_size := size
	var shutter_size := shutter_control.custom_minimum_size
	var thumb_size := thumbnail_control.custom_minimum_size
	var layout_size := layout_control.custom_minimum_size
	var target_center_y := viewport_size.y * (1.0 - HUD_ROW_FROM_BOTTOM_RATIO)
	var side_margin := viewport_size.x * HUD_SIDE_MARGIN_RATIO

	shutter_control.position = Vector2((viewport_size.x - shutter_size.x) * 0.5, target_center_y - (shutter_size.y * 0.5))
	shutter_control.size = shutter_size

	thumbnail_control.position = Vector2(side_margin, target_center_y - (thumb_size.y * 0.5))
	thumbnail_control.size = thumb_size
	layout_control.position = Vector2(viewport_size.x - side_margin - layout_size.x, target_center_y - (layout_size.y * 0.5))
	layout_control.size = layout_size

	# Pivot needs to be at visual center for clean scale animation.
	shutter_button.pivot_offset = shutter_button.size * 0.5
	thumbnail_control.pivot_offset = thumbnail_control.size * 0.5
	layout_control.pivot_offset = layout_control.size * 0.5

func _on_shutter_pressed():
	_play_shutter_press_animation()
	_play_flash_fx()
	_start_thumbnail_processing_feedback()
	_try_trigger_shutter_haptic()

func _start_thumbnail_processing_feedback():
	thumbnail_processing_sequence += 1
	var sequence_id := thumbnail_processing_sequence
	thumbnail_processing_started_msec = Time.get_ticks_msec()
	_begin_thumbnail_processing_tween()
	_finish_thumbnail_processing_feedback(sequence_id)

func _begin_thumbnail_processing_tween():
	if thumbnail_tween:
		thumbnail_tween.kill()

	thumbnail_control.scale = Vector2.ONE
	thumbnail_control.modulate = HUD_ACCENT_COLOR
	thumbnail_tween = create_tween()
	thumbnail_tween.set_loops()
	thumbnail_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	thumbnail_tween.tween_property(thumbnail_control, "scale", Vector2.ONE * THUMBNAIL_PULSE_SCALE, THUMBNAIL_PULSE_HALF_DURATION)
	thumbnail_tween.parallel().tween_property(thumbnail_control, "modulate:a", THUMBNAIL_PULSE_ALPHA, THUMBNAIL_PULSE_HALF_DURATION)
	thumbnail_tween.tween_property(thumbnail_control, "scale", Vector2.ONE, THUMBNAIL_PULSE_HALF_DURATION)
	thumbnail_tween.parallel().tween_property(thumbnail_control, "modulate:a", 1.0, THUMBNAIL_PULSE_HALF_DURATION)

func _finish_thumbnail_processing_feedback(sequence_id: int):
	# Placeholder until native capture/save callback is integrated.
	await get_tree().create_timer(THUMBNAIL_MOCK_SAVE_DURATION).timeout
	if sequence_id != thumbnail_processing_sequence:
		return

	var elapsed_seconds := float(Time.get_ticks_msec() - thumbnail_processing_started_msec) / 1000.0
	var remaining_seconds: float = max(0.0, THUMBNAIL_MIN_PROCESSING_DURATION - elapsed_seconds)
	if remaining_seconds > 0.0:
		await get_tree().create_timer(remaining_seconds).timeout

	if sequence_id != thumbnail_processing_sequence:
		return

	if thumbnail_tween:
		thumbnail_tween.kill()
	thumbnail_control.scale = Vector2.ONE
	thumbnail_control.modulate = HUD_ACCENT_COLOR

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
