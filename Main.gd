extends Control

# EDUCATIONAL:
# The scene is composed in three layers:
# 1) CameraFeedLayer for live camera textures.
# 2) HUDLayer for persistent controls.
# 3) FXLayer for transient visual feedback.
#
# Capture uses a separate LayoutManager snapshot so preview and saved output
# share one contract even when we add new layout presets later.
@onready var top_preview: TextureRect = $CameraFeedLayer/MainLayout/PanesContainer/ZoneB/TopPreview
@onready var bottom_preview: TextureRect = $CameraFeedLayer/MainLayout/PanesContainer/ZoneC/BottomPreview
@onready var thumbnail_control: TextureRect = $HUDLayer/HUDRoot/ThumbnailControl
@onready var layout_control: TextureRect = $HUDLayer/HUDRoot/LayoutControl
@onready var shutter_control: Control = $HUDLayer/HUDRoot/ShutterControl
@onready var shutter_button: Button = $HUDLayer/HUDRoot/ShutterControl/ShutterButton
@onready var flash_overlay: ColorRect = $FXLayer/FXRoot/FlashOverlay

const LayoutManagerScript := preload("res://LayoutManager.gd")
const HUD_ACCENT_COLOR := Color(0.968627, 0.980392, 0.988235, 1.0) # #f7fafc
const HUD_ROW_FROM_BOTTOM_RATIO := 0.10
const HUD_SIDE_MARGIN_RATIO := 0.05
const SHUTTER_PRESS_SCALE := 0.9
const SHUTTER_PRESS_IN_DURATION := 0.06
const SHUTTER_PRESS_OUT_DURATION := 0.09
const FLASH_IN_DURATION := 0.04
const FLASH_OUT_DURATION := 0.16
const THUMBNAIL_MIN_PROCESSING_DURATION := 0.56
const THUMBNAIL_PULSE_SCALE := 0.92
const THUMBNAIL_PULSE_HALF_DURATION := 0.18
const THUMBNAIL_PULSE_ALPHA := 0.6
const THUMBNAIL_CORNER_RADIUS_PX := 16.0
# EDUCATIONAL:
# We clip the thumbnail with a lightweight shader instead of nesting mask nodes.
# This keeps the HUD hierarchy simple and makes the rounded-corner treatment
# deterministic across all thumbnail textures.
const THUMBNAIL_SHADER_CODE := """
shader_type canvas_item;

uniform float corner_radius_px = 16.0;

float rounded_rect_sdf(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + vec2(radius);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 p = UV * tex_size - (tex_size * 0.5);
	vec2 half_size = (tex_size * 0.5) - vec2(0.5);
	float radius = min(corner_radius_px, min(half_size.x, half_size.y) - 1.0);
	float alpha_mask = 1.0 - smoothstep(0.0, 1.0, rounded_rect_sdf(p, half_size, radius));
	vec4 tex_color = texture(TEXTURE, UV);
	tex_color.a *= alpha_mask;
	COLOR = tex_color;
}
"""

var shutter_tween: Tween
var fx_tween: Tween
var thumbnail_tween: Tween

var layout_manager = LayoutManagerScript.new()
var save_feedback_sequence := 0
var save_feedback_started_msec := 0
var has_thumbnail_capture := false

func _ready() -> void:
	print("Main: Ready")

	shutter_button.pressed.connect(_on_shutter_pressed)
	thumbnail_control.gui_input.connect(_on_thumbnail_gui_input)
	resized.connect(_on_main_resized)
	_on_main_resized()

	_setup_thumbnail_style()
	_clear_thumbnail()
	thumbnail_control.modulate = HUD_ACCENT_COLOR
	thumbnail_control.mouse_filter = Control.MOUSE_FILTER_STOP
	layout_control.modulate = HUD_ACCENT_COLOR

	if Native:
		_connect_native_signals()
		Native.start_camera()

		var tex_top: Texture2D = Native.get_texture_top()
		var tex_bottom: Texture2D = Native.get_texture_bottom()
		if tex_top and tex_bottom:
			top_preview.texture = tex_top
			bottom_preview.texture = tex_bottom
		else:
			push_error("ERROR: Camera textures are null")

		_publish_layout_snapshot()
	else:
		push_error("ERROR: Native bridge not found")

func _on_main_resized() -> void:
	_layout_hud_controls()
	_publish_layout_snapshot()

func _layout_hud_controls() -> void:
	var viewport_size := size
	var shutter_size := shutter_control.custom_minimum_size
	# Keep thumbnail sized by the existing HUD layout baseline instead of a
	# thumbnail-specific hardcoded size.
	var thumb_size := layout_control.custom_minimum_size
	var layout_size := layout_control.custom_minimum_size
	var target_center_y := viewport_size.y * (1.0 - HUD_ROW_FROM_BOTTOM_RATIO)
	var side_margin := viewport_size.x * HUD_SIDE_MARGIN_RATIO

	shutter_control.position = Vector2((viewport_size.x - shutter_size.x) * 0.5, target_center_y - (shutter_size.y * 0.5))
	shutter_control.size = shutter_size

	thumbnail_control.position = Vector2(side_margin, target_center_y - (thumb_size.y * 0.5))
	thumbnail_control.size = thumb_size
	layout_control.position = Vector2(viewport_size.x - side_margin - layout_size.x, target_center_y - (layout_size.y * 0.5))
	layout_control.size = layout_size

	shutter_button.pivot_offset = shutter_button.size * 0.5
	thumbnail_control.pivot_offset = thumbnail_control.size * 0.5
	layout_control.pivot_offset = layout_control.size * 0.5

func _setup_thumbnail_style() -> void:
	var shader := Shader.new()
	shader.code = THUMBNAIL_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("corner_radius_px", THUMBNAIL_CORNER_RADIUS_PX)
	thumbnail_control.material = material

func _set_thumbnail_visibility(visible: bool) -> void:
	thumbnail_control.visible = visible

func _build_layout_snapshot() -> Dictionary:
	var has_secondary_stream := true
	if Native and Native.has_method("is_multicam_supported"):
		has_secondary_stream = Native.is_multicam_supported()
	return layout_manager.build_snapshot(size, has_secondary_stream)

func _publish_layout_snapshot() -> void:
	if Native and Native.has_method("set_layout_snapshot"):
		Native.set_layout_snapshot(_build_layout_snapshot())

func _connect_native_signals() -> void:
	if Native.has_signal("image_save_started"):
		if not Native.image_save_started.is_connected(_on_native_image_save_started):
			Native.image_save_started.connect(_on_native_image_save_started)
	if Native.has_signal("image_save_finished"):
		if not Native.image_save_finished.is_connected(_on_native_image_save_finished):
			Native.image_save_finished.connect(_on_native_image_save_finished)

func _on_shutter_pressed() -> void:
	_play_shutter_press_animation()
	_play_flash_fx()
	_try_trigger_shutter_haptic()

	if Native and Native.has_method("capture_layout_image"):
		Native.capture_layout_image(_build_layout_snapshot())
	else:
		_begin_thumbnail_processing_feedback()
		await get_tree().create_timer(THUMBNAIL_MIN_PROCESSING_DURATION).timeout
		_end_thumbnail_processing_feedback()

func _begin_thumbnail_processing_feedback() -> void:
	if not has_thumbnail_capture or not thumbnail_control.visible:
		return

	save_feedback_sequence += 1
	save_feedback_started_msec = Time.get_ticks_msec()

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

func _end_thumbnail_processing_feedback() -> void:
	if thumbnail_tween:
		thumbnail_tween.kill()
	thumbnail_control.scale = Vector2.ONE
	thumbnail_control.modulate = HUD_ACCENT_COLOR

func _on_native_image_save_started() -> void:
	_begin_thumbnail_processing_feedback()

func _on_native_image_save_finished(thumbnail_data: PackedByteArray) -> void:
	var sequence_at_finish := save_feedback_sequence

	var elapsed_seconds := 0.0
	if sequence_at_finish > 0:
		elapsed_seconds = float(Time.get_ticks_msec() - save_feedback_started_msec) / 1000.0
	var remaining_seconds: float = max(0.0, THUMBNAIL_MIN_PROCESSING_DURATION - elapsed_seconds)
	if remaining_seconds > 0.0:
		await get_tree().create_timer(remaining_seconds).timeout

	if sequence_at_finish > 0 and sequence_at_finish != save_feedback_sequence:
		return

	_end_thumbnail_processing_feedback()
	_apply_thumbnail_texture(thumbnail_data)

func _apply_thumbnail_texture(thumbnail_data: PackedByteArray) -> void:
	if thumbnail_data.is_empty():
		return

	var decoded_thumbnail := Image.new()
	var load_result := decoded_thumbnail.load_png_from_buffer(thumbnail_data)
	if load_result != OK:
		push_warning("Main: Failed to decode thumbnail PNG from native layer.")
		return

	thumbnail_control.texture = ImageTexture.create_from_image(decoded_thumbnail)
	has_thumbnail_capture = true
	_set_thumbnail_visibility(true)
	thumbnail_control.modulate = HUD_ACCENT_COLOR

func _clear_thumbnail() -> void:
	# EDUCATIONAL:
	# A "no capture yet" state is represented by a null texture + hidden control.
	# Keeping both conditions explicit avoids stale thumbnails after scene reloads.
	thumbnail_control.texture = null
	_set_thumbnail_visibility(false)

func _on_thumbnail_gui_input(event: InputEvent) -> void:
	if not has_thumbnail_capture or not thumbnail_control.visible:
		return

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open_photo_library()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_open_photo_library()

func _open_photo_library() -> void:
	if Native and Native.has_method("open_photo_library"):
		Native.open_photo_library()

func _play_shutter_press_animation() -> void:
	if shutter_tween:
		shutter_tween.kill()

	shutter_button.scale = Vector2.ONE
	shutter_tween = create_tween()
	shutter_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shutter_tween.tween_property(shutter_button, "scale", Vector2.ONE * SHUTTER_PRESS_SCALE, SHUTTER_PRESS_IN_DURATION)
	shutter_tween.set_ease(Tween.EASE_IN)
	shutter_tween.tween_property(shutter_button, "scale", Vector2.ONE, SHUTTER_PRESS_OUT_DURATION)

func _play_flash_fx() -> void:
	if fx_tween:
		fx_tween.kill()

	flash_overlay.modulate.a = 0.0
	fx_tween = create_tween()
	fx_tween.tween_property(flash_overlay, "modulate:a", 0.9, FLASH_IN_DURATION)
	fx_tween.tween_property(flash_overlay, "modulate:a", 0.0, FLASH_OUT_DURATION)

func _try_trigger_shutter_haptic() -> void:
	if Native and Native.has_method("trigger_haptic_impact"):
		Native.trigger_haptic_impact()

func _process(_delta: float) -> void:
	pass
