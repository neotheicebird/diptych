extends Control

# EDUCATIONAL:
# The scene is composed in three layers:
# 1) CameraFeedLayer for live camera textures.
# 2) HUDLayer for persistent controls.
# 3) FXLayer for transient visual feedback.
#
# Capture uses a separate LayoutManager snapshot so preview and saved output
# share one contract even when we add new layout presets later.
@onready var panes_container: Control = $CameraFeedLayer/MainLayout/PanesContainer
@onready var primary_zone: Control = $CameraFeedLayer/MainLayout/PanesContainer/ZoneB
@onready var secondary_zone: Control = $CameraFeedLayer/MainLayout/PanesContainer/ZoneC
@onready var top_preview: TextureRect = $CameraFeedLayer/MainLayout/PanesContainer/ZoneB/TopPreview
@onready var bottom_preview: TextureRect = $CameraFeedLayer/MainLayout/PanesContainer/ZoneC/BottomPreview
@onready var divider: ColorRect = $CameraFeedLayer/MainLayout/PanesContainer/Divider
@onready var thumbnail_control: TextureRect = $HUDLayer/HUDRoot/ThumbnailControl
@onready var layout_control: TextureRect = $HUDLayer/HUDRoot/LayoutControl
@onready var shutter_control: Control = $HUDLayer/HUDRoot/ShutterControl
@onready var shutter_button: Button = $HUDLayer/HUDRoot/ShutterControl/ShutterButton
@onready var hud_root: Control = $HUDLayer/HUDRoot
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
const WORKBENCH_BACKDROP_ALPHA := 0.42
const WORKBENCH_OPEN_DURATION := 0.24
const WORKBENCH_CLOSE_DURATION := 0.18
const PRESET_PREVIEW_SIZE := Vector2i(240, 140)

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
var layout_workbench_tween: Tween
var layout_icon_tween: Tween

var layout_manager = LayoutManagerScript.new()
var preview_stage: Control
var layout_backdrop: ColorRect
var layout_workbench: PanelContainer
var layout_cards_grid: GridContainer
var layout_button_group := ButtonGroup.new()
var layout_card_buttons: Dictionary = {}
var save_feedback_sequence := 0
var save_feedback_started_msec := 0
var has_thumbnail_capture := false
var layout_workbench_open := false

func _ready() -> void:
	print("Main: Ready")
	_setup_preview_stage()
	_setup_layout_workbench_ui()
	_rebuild_layout_cards()

	shutter_button.pressed.connect(_on_shutter_pressed)
	thumbnail_control.gui_input.connect(_on_thumbnail_gui_input)
	layout_control.gui_input.connect(_on_layout_gui_input)
	resized.connect(_on_main_resized)

	_setup_thumbnail_style()
	_clear_thumbnail()
	thumbnail_control.modulate = HUD_ACCENT_COLOR
	thumbnail_control.mouse_filter = Control.MOUSE_FILTER_STOP
	layout_control.modulate = HUD_ACCENT_COLOR
	layout_control.mouse_filter = Control.MOUSE_FILTER_STOP
	_on_main_resized()

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

		_sync_layout_snapshot()
	else:
		push_error("ERROR: Native bridge not found")

func _on_main_resized() -> void:
	_layout_hud_controls()
	_sync_layout_snapshot()

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

	if layout_cards_grid:
		layout_cards_grid.columns = 2
		if viewport_size.x < 920.0:
			layout_cards_grid.columns = 1

	if layout_workbench:
		var panel_width: float = minf(580.0, maxf(320.0, viewport_size.x - (side_margin * 2.0)))
		var panel_height: float = minf(430.0, maxf(260.0, viewport_size.y * 0.52))
		var panel_x: float = viewport_size.x - side_margin - panel_width
		var panel_y: float = target_center_y - (shutter_size.y * 0.5) - panel_height - 24.0
		panel_y = maxf(side_margin, panel_y)
		layout_workbench.position = Vector2(panel_x, panel_y)
		layout_workbench.size = Vector2(panel_width, panel_height)
		layout_workbench.pivot_offset = Vector2(panel_width, panel_height)

func _setup_preview_stage() -> void:
	preview_stage = Control.new()
	preview_stage.name = "PreviewStage"
	preview_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	$CameraFeedLayer/MainLayout.add_child(preview_stage)

	primary_zone.reparent(preview_stage)
	divider.reparent(preview_stage)
	secondary_zone.reparent(preview_stage)
	panes_container.visible = false

func _setup_layout_workbench_ui() -> void:
	layout_backdrop = ColorRect.new()
	layout_backdrop.name = "LayoutWorkbenchBackdrop"
	layout_backdrop.visible = false
	layout_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layout_backdrop.color = Color(0.019608, 0.031373, 0.043137, 0.0)
	layout_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout_backdrop.gui_input.connect(_on_layout_backdrop_gui_input)
	hud_root.add_child(layout_backdrop)

	layout_workbench = PanelContainer.new()
	layout_workbench.name = "LayoutWorkbench"
	layout_workbench.visible = false
	layout_workbench.mouse_filter = Control.MOUSE_FILTER_STOP
	layout_workbench.modulate.a = 0.0
	layout_workbench.scale = Vector2.ONE * 0.96
	layout_workbench.add_theme_stylebox_override(
		"panel",
		_make_style_box(Color(0.05098, 0.066667, 0.086275, 0.96), Color(0.568627, 0.678431, 0.780392, 0.52), 1, 28)
	)
	hud_root.add_child(layout_workbench)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	layout_workbench.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	body.add_child(header_row)

	var title_label := Label.new()
	title_label.text = "Layout Lab"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_color_override("font_color", Color(0.984314, 0.992157, 1.0, 1.0))
	title_label.add_theme_font_size_override("font_size", 30)
	header_row.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_stylebox_override(
		"normal",
		_make_style_box(Color(0.164706, 0.215686, 0.262745, 0.75), Color(0.803922, 0.866667, 0.921569, 0.28), 1, 18)
	)
	close_button.add_theme_stylebox_override(
		"hover",
		_make_style_box(Color(0.243137, 0.313725, 0.368627, 0.85), Color(0.92549, 0.960784, 0.988235, 0.48), 1, 18)
	)
	close_button.pressed.connect(_close_layout_workbench)
	header_row.add_child(close_button)

	var subtitle := Label.new()
	subtitle.text = "Tap a preset. Preview and capture stay perfectly in sync."
	subtitle.add_theme_color_override("font_color", Color(0.752941, 0.827451, 0.886275, 0.9))
	subtitle.add_theme_font_size_override("font_size", 18)
	body.add_child(subtitle)

	var categories := HBoxContainer.new()
	categories.add_theme_constant_override("separation", 8)
	body.add_child(categories)
	categories.add_child(_make_chip("Layouts", true))
	categories.add_child(_make_chip("Ratio Soon", false))
	categories.add_child(_make_chip("Filters Soon", false))
	categories.add_child(_make_chip("FX Soon", false))
	categories.add_child(_make_chip("Store Soon", false))

	layout_cards_grid = GridContainer.new()
	layout_cards_grid.columns = 2
	layout_cards_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout_cards_grid.add_theme_constant_override("h_separation", 10)
	layout_cards_grid.add_theme_constant_override("v_separation", 10)
	body.add_child(layout_cards_grid)

	var footer := Label.new()
	footer.text = "Layout Lab is built as a hub so new creative tools can join this surface later."
	footer.add_theme_color_override("font_color", Color(0.556863, 0.670588, 0.764706, 0.9))
	footer.add_theme_font_size_override("font_size", 15)
	body.add_child(footer)

func _rebuild_layout_cards() -> void:
	if not layout_cards_grid:
		return

	for child in layout_cards_grid.get_children():
		child.queue_free()
	layout_card_buttons.clear()

	for option in layout_manager.get_preset_options():
		var preset_id := String(option.get("id", ""))
		if preset_id.is_empty():
			continue
		var card := _create_layout_card(option)
		layout_cards_grid.add_child(card)
		layout_card_buttons[preset_id] = card

	_refresh_layout_card_selection()

func _create_layout_card(option: Dictionary) -> Button:
	var preset_id := String(option.get("id", ""))
	var title := String(option.get("title", preset_id))
	var description := String(option.get("description", ""))

	var button := Button.new()
	button.toggle_mode = true
	button.button_group = layout_button_group
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 170.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = ""
	button.clip_contents = true
	button.add_theme_stylebox_override(
		"normal",
		_make_style_box(Color(0.133333, 0.180392, 0.227451, 0.94), Color(0.643137, 0.733333, 0.815686, 0.24), 1, 22)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_style_box(Color(0.168627, 0.227451, 0.282353, 0.98), Color(0.870588, 0.929412, 0.980392, 0.55), 1, 22)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_style_box(Color(0.090196, 0.239216, 0.356863, 1.0), Color(0.945098, 0.980392, 1.0, 0.95), 2, 22)
	)
	button.add_theme_stylebox_override(
		"focus",
		_make_style_box(Color(0.090196, 0.239216, 0.356863, 1.0), Color(0.945098, 0.980392, 1.0, 0.95), 2, 22)
	)
	button.pressed.connect(_on_layout_card_pressed.bind(preset_id))
	button.mouse_entered.connect(_on_layout_card_mouse_entered.bind(button))
	button.mouse_exited.connect(_on_layout_card_mouse_exited.bind(button))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	button.add_child(margin)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var preview := TextureRect.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.expand_mode = 1
	preview.stretch_mode = 6
	preview.custom_minimum_size = Vector2(PRESET_PREVIEW_SIZE.x, PRESET_PREVIEW_SIZE.y)
	preview.texture = _build_layout_preview_texture(preset_id)
	stack.add_child(preview)

	var title_label := Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.992157, 0.996078, 1.0, 1.0))
	stack.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_label.text = description
	subtitle_label.add_theme_font_size_override("font_size", 15)
	subtitle_label.add_theme_color_override("font_color", Color(0.768627, 0.839216, 0.898039, 0.95))
	stack.add_child(subtitle_label)

	return button

func _build_layout_preview_texture(preset_id: String) -> Texture2D:
	var previous_preset := layout_manager.get_preset()
	layout_manager.set_preset(preset_id)
	var preview_size := Vector2(float(PRESET_PREVIEW_SIZE.x), float(PRESET_PREVIEW_SIZE.y))
	var snapshot := layout_manager.build_snapshot(preview_size, true)
	layout_manager.set_preset(previous_preset)

	var image := Image.create(PRESET_PREVIEW_SIZE.x, PRESET_PREVIEW_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.054902, 0.07451, 0.094118, 1.0))
	_draw_slots_on_image(image, snapshot.get("slots", []), PRESET_PREVIEW_SIZE)
	_draw_separators_on_image(image, snapshot.get("separators", []), PRESET_PREVIEW_SIZE)
	return ImageTexture.create_from_image(image)

func _draw_slots_on_image(image: Image, slots: Array, canvas_size: Vector2i) -> void:
	for slot in slots:
		if not (slot is Dictionary):
			continue
		var slot_dict: Dictionary = slot
		var rect: Rect2 = slot_dict.get("rect", Rect2(0.0, 0.0, 1.0, 1.0))
		var stream_id := String(slot_dict.get("stream_id", "primary"))
		var fill_color := Color(0.360784, 0.796078, 1.0, 1.0)
		if stream_id == "secondary":
			fill_color = Color(0.282353, 0.356863, 0.929412, 1.0)
		var pixel_rect := _normalized_to_pixel_rect(rect, canvas_size)
		image.fill_rect(pixel_rect, fill_color)

func _draw_separators_on_image(image: Image, separators: Array, canvas_size: Vector2i) -> void:
	for separator in separators:
		if not (separator is Dictionary):
			continue
		var separator_dict: Dictionary = separator
		var rect: Rect2 = separator_dict.get("rect", Rect2())
		var color: Color = separator_dict.get("color", Color(1.0, 1.0, 1.0, 0.5))
		var pixel_rect := _normalized_to_pixel_rect(rect, canvas_size)
		image.fill_rect(pixel_rect, color)

func _normalized_to_pixel_rect(normalized_rect: Rect2, canvas_size: Vector2i) -> Rect2i:
	var x := int(round(normalized_rect.position.x * float(canvas_size.x)))
	var y := int(round(normalized_rect.position.y * float(canvas_size.y)))
	var width: int = maxi(1, int(round(normalized_rect.size.x * float(canvas_size.x))))
	var height: int = maxi(1, int(round(normalized_rect.size.y * float(canvas_size.y))))
	return Rect2i(x, y, width, height)

func _make_chip(text_value: String, active: bool) -> PanelContainer:
	var chip := PanelContainer.new()
	var background := Color(0.105882, 0.14902, 0.192157, 0.85)
	var border := Color(0.6, 0.705882, 0.803922, 0.35)
	if active:
		background = Color(0.086275, 0.262745, 0.403922, 0.95)
		border = Color(0.945098, 0.980392, 1.0, 0.9)
	chip.add_theme_stylebox_override("panel", _make_style_box(background, border, 1, 14))

	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.968627, 0.992157, 1.0, 1.0))
	label.add_theme_constant_override("outline_size", 0)
	chip.add_child(label)

	return chip

func _make_style_box(fill: Color, border: Color, border_width: int, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	return style

func _sync_layout_snapshot() -> void:
	var snapshot := _build_layout_snapshot()
	_apply_preview_snapshot(snapshot)
	_publish_layout_snapshot(snapshot)
	_refresh_layout_card_selection()

func _apply_preview_snapshot(snapshot: Dictionary) -> void:
	var slots: Array = snapshot.get("slots", [])
	var primary_slot := _find_slot_for_stream(slots, "primary")
	var secondary_slot := _find_slot_for_stream(slots, "secondary")

	_apply_slot_to_zone(primary_zone, primary_slot)
	_apply_slot_to_zone(secondary_zone, secondary_slot)
	secondary_zone.mouse_filter = Control.MOUSE_FILTER_STOP

	var separators: Array = snapshot.get("separators", [])
	if separators.is_empty():
		divider.visible = false
	else:
		var separator: Dictionary = separators[0]
		var separator_rect: Rect2 = separator.get("rect", Rect2())
		divider.position = Vector2(separator_rect.position.x * size.x, separator_rect.position.y * size.y)
		divider.size = Vector2(separator_rect.size.x * size.x, separator_rect.size.y * size.y)
		divider.color = separator.get("color", Color(1.0, 1.0, 1.0, 0.22))
		divider.z_index = 100
		divider.visible = true

func _find_slot_for_stream(slots: Array, stream_id: String) -> Dictionary:
	for slot in slots:
		if not (slot is Dictionary):
			continue
		var slot_dict: Dictionary = slot
		if String(slot_dict.get("stream_id", "")) == stream_id:
			return slot_dict
	return {}

func _apply_slot_to_zone(zone: Control, slot: Dictionary) -> void:
	if slot.is_empty():
		zone.visible = false
		return
	var rect: Rect2 = slot.get("rect", Rect2(0.0, 0.0, 1.0, 1.0))
	zone.position = Vector2(rect.position.x * size.x, rect.position.y * size.y)
	zone.size = Vector2(rect.size.x * size.x, rect.size.y * size.y)
	zone.z_index = int(slot.get("z_index", 0))
	zone.visible = zone.size.x > 1.0 and zone.size.y > 1.0

func _refresh_layout_card_selection() -> void:
	var selected_id := layout_manager.get_preset()
	for preset_id in layout_card_buttons.keys():
		var card: Button = layout_card_buttons[preset_id]
		card.button_pressed = String(preset_id) == selected_id
		card.scale = Vector2.ONE

func _on_layout_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_toggle_layout_workbench()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_toggle_layout_workbench()

func _on_layout_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_close_layout_workbench()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_close_layout_workbench()

func _toggle_layout_workbench() -> void:
	if layout_workbench_open:
		_close_layout_workbench()
	else:
		_open_layout_workbench()

func _open_layout_workbench() -> void:
	layout_workbench_open = true
	_refresh_layout_card_selection()
	_play_layout_control_pulse()
	layout_control.modulate = Color(1.0, 1.0, 1.0, 1.0)
	layout_backdrop.visible = true
	layout_workbench.visible = true

	if layout_workbench_tween:
		layout_workbench_tween.kill()
	layout_backdrop.color.a = 0.0
	layout_workbench.modulate.a = 0.0
	layout_workbench.scale = Vector2.ONE * 0.96
	layout_workbench_tween = create_tween()
	layout_workbench_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	layout_workbench_tween.tween_property(layout_backdrop, "color:a", WORKBENCH_BACKDROP_ALPHA, WORKBENCH_OPEN_DURATION)
	layout_workbench_tween.parallel().tween_property(layout_workbench, "modulate:a", 1.0, WORKBENCH_OPEN_DURATION)
	layout_workbench_tween.parallel().tween_property(layout_workbench, "scale", Vector2.ONE, WORKBENCH_OPEN_DURATION)

func _close_layout_workbench() -> void:
	layout_workbench_open = false
	layout_control.modulate = HUD_ACCENT_COLOR
	_play_layout_control_pulse()

	if layout_workbench_tween:
		layout_workbench_tween.kill()
	layout_workbench_tween = create_tween()
	layout_workbench_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	layout_workbench_tween.tween_property(layout_backdrop, "color:a", 0.0, WORKBENCH_CLOSE_DURATION)
	layout_workbench_tween.parallel().tween_property(layout_workbench, "modulate:a", 0.0, WORKBENCH_CLOSE_DURATION)
	layout_workbench_tween.parallel().tween_property(layout_workbench, "scale", Vector2.ONE * 0.96, WORKBENCH_CLOSE_DURATION)
	layout_workbench_tween.finished.connect(_on_layout_workbench_hidden, CONNECT_ONE_SHOT)

func _on_layout_workbench_hidden() -> void:
	if not layout_workbench_open:
		layout_backdrop.visible = false
		layout_workbench.visible = false

func _play_layout_control_pulse() -> void:
	if layout_icon_tween:
		layout_icon_tween.kill()
	layout_control.scale = Vector2.ONE
	layout_icon_tween = create_tween()
	layout_icon_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	layout_icon_tween.tween_property(layout_control, "scale", Vector2.ONE * 0.92, 0.08)
	layout_icon_tween.tween_property(layout_control, "scale", Vector2.ONE, 0.12)

func _on_layout_card_pressed(preset_id: String) -> void:
	layout_manager.set_preset(preset_id)
	_sync_layout_snapshot()
	_play_layout_control_pulse()

func _on_layout_card_mouse_entered(card: Button) -> void:
	if card.button_pressed:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE * 1.015, 0.08)

func _on_layout_card_mouse_exited(card: Button) -> void:
	if card.button_pressed:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, 0.1)

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

func _publish_layout_snapshot(snapshot: Dictionary = {}) -> void:
	var snapshot_to_publish := snapshot
	if snapshot_to_publish.is_empty():
		snapshot_to_publish = _build_layout_snapshot()
	if Native and Native.has_method("set_layout_snapshot"):
		Native.set_layout_snapshot(snapshot_to_publish)

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
