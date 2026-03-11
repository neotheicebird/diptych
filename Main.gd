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
const WORKBENCH_OPEN_DURATION := 0.32
const WORKBENCH_CLOSE_DURATION := 0.24
const LAYOUT_BACKDROP_CLOSE_GUARD_MS := 320
const LAYOUT_POINTER_DEBOUNCE_MS := 220
const PRESET_PREVIEW_PORTRAIT_SIZE := Vector2i(180, 320)
const PRESET_PREVIEW_LANDSCAPE_SIZE := Vector2i(320, 180)
const PRESET_PREVIEW_CANONICAL_SIZE := PRESET_PREVIEW_PORTRAIT_SIZE
const PRESET_CARD_HEIGHT := 356.0
const PRESET_PREVIEW_PORTRAIT_FRAME_SIZE := Vector2(204.0, 332.0)
const PRESET_PREVIEW_LANDSCAPE_FRAME_SIZE := Vector2(332.0, 204.0)
const WORKBENCH_CARD_OVERSCAN := 20.0
const WORKBENCH_INNER_MARGIN := 16.0
const WORKBENCH_CARD_GAP := 12.0
const WORKBENCH_BASE_HEIGHT_RATIO := 0.75
const WORKBENCH_WIDTH_RATIO := 0.80
const PANEL_BORDER_DEFAULT_COLOR := Color(0.917647, 0.929412, 0.941176, 0.62)
const PANEL_SWITCH_ICON_SIZE_RATIO := 0.375
const PANEL_SWITCH_LEGACY_ICON_SIZE_RATIO := 0.75
const PANEL_SWITCH_HIT_TARGET_MIN := 44.0
const PANEL_SWITCH_BASE_SIDE_MARGIN := 10.0
const PANEL_SWITCH_TOP_MARGIN := 20.0
const PANEL_SWITCH_EXTRA_TOP_MARGIN := 8.0
const PANEL_SWITCH_LABEL_TIMEOUT := 2.0
const PANEL_SWITCH_ICON_TINT := Color(0.745098, 0.768627, 0.796078, 0.95)
const PANEL_SWITCH_LABEL_BG := Color(0.05098, 0.066667, 0.086275, 0.58)
const PANEL_SWITCH_LABEL_WIDTH := 240.0
const PANEL_SWITCH_LABEL_HEIGHT := 96.0
const PANEL_SWITCH_LABEL_FONT_SIZE := 48
const CHANGE_CAM_ICON := preload("res://assets/icons/change_cam.svg")

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

const PANEL_CORNER_SHADER_CODE := """
shader_type canvas_item;

uniform float corner_radius_px = 0.0;
uniform vec2 panel_size_px = vec2(1.0, 1.0);

float rounded_rect_sdf(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + vec2(radius);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	if (corner_radius_px <= 0.5) {
		COLOR = tex_color;
	} else {
		vec2 panel_size = max(panel_size_px, vec2(1.0, 1.0));
		vec2 p = UV * panel_size - (panel_size * 0.5);
		vec2 half_size = (panel_size * 0.5) - vec2(0.5);
		float radius = min(corner_radius_px, min(half_size.x, half_size.y) - 1.0);
		float edge_distance = rounded_rect_sdf(p, half_size, radius);
		if (edge_distance > 1.0) {
			discard;
		}
		float alpha_mask = 1.0 - smoothstep(0.0, 1.0, edge_distance);
		tex_color.a *= alpha_mask;
		COLOR = tex_color;
	}
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
var panel_mask_nodes: Dictionary = {}
var panel_border_nodes: Dictionary = {}
var panel_switch_buttons: Dictionary = {}
var panel_switch_icons: Dictionary = {}
var panel_switch_label_panels: Dictionary = {}
var panel_switch_text_labels: Dictionary = {}
var panel_label_tweens: Dictionary = {}
var panel_device_catalog: Array = []
var panel_current_device_ids := {0: "", 1: ""}
var panel_cycle_device_ids := {0: [], 1: []}
var panel_corner_shader: Shader
var save_feedback_sequence := 0
var save_feedback_started_msec := 0
var has_thumbnail_capture := false
var layout_workbench_open := false
var layout_workbench_opened_msec := 0
var layout_pointer_event_msec := 0

func _ready() -> void:
	print("Main: Ready")
	panel_corner_shader = Shader.new()
	panel_corner_shader.code = PANEL_CORNER_SHADER_CODE
	_setup_preview_stage()
	_setup_panel_overlays()
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

		_refresh_camera_device_catalog()
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

	if layout_workbench:
		var panel_width: float = minf(560.0, maxf(288.0, viewport_size.x * WORKBENCH_WIDTH_RATIO))
		var card_count := maxf(1.0, float(layout_manager.get_preset_options().size()))
		var card_stack_height := (PRESET_CARD_HEIGHT * card_count) + ((card_count - 1.0) * WORKBENCH_CARD_GAP) + (WORKBENCH_INNER_MARGIN * 2.0) + WORKBENCH_CARD_OVERSCAN
		var panel_height: float = minf(viewport_size.y - (side_margin * 2.0), card_stack_height)
		var default_top := maxf(side_margin, viewport_size.y * 0.05)
		var baseline_height := minf(viewport_size.y - (side_margin * 2.0), viewport_size.y * WORKBENCH_BASE_HEIGHT_RATIO)
		var baseline_bottom := default_top + baseline_height
		var panel_x: float = (viewport_size.x - panel_width) * 0.5
		var panel_y: float = maxf(side_margin, baseline_bottom - panel_height)
		layout_workbench.position = Vector2(panel_x, panel_y)
		layout_workbench.size = Vector2(panel_width, panel_height)
		layout_workbench.pivot_offset = Vector2(panel_width, panel_height)

	_update_panel_switch_control_layout(0)
	_update_panel_switch_control_layout(1)

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

func _setup_panel_overlays() -> void:
	# EDUCATIONAL:
	# Every viewer gets its own border + camera switch affordance so camera routing
	# remains panel-local regardless of which layout preset is active.
	_setup_zone_overlay(primary_zone, top_preview, 0)
	_setup_zone_overlay(secondary_zone, bottom_preview, 1)

func _setup_zone_overlay(zone: Control, preview: TextureRect, view_index: int) -> void:
	var mask := Panel.new()
	mask.name = "PreviewMask"
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.add_theme_stylebox_override("panel", _make_style_box(Color(1.0, 1.0, 1.0, 1.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0))
	zone.add_child(mask)
	panel_mask_nodes[view_index] = mask

	preview.reparent(mask)
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview.offset_left = 0.0
	preview.offset_top = 0.0
	preview.offset_right = 0.0
	preview.offset_bottom = 0.0

	var border := Panel.new()
	border.name = "PanelBorder"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	zone.add_child(border)
	panel_border_nodes[view_index] = border

	var button := Button.new()
	button.name = "CameraSwitchButton"
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.text = ""
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.anchor_left = 1.0
	button.anchor_top = 0.0
	button.anchor_right = 1.0
	button.anchor_bottom = 0.0
	var initial_icon_size := maxf(PANEL_SWITCH_HIT_TARGET_MIN, layout_control.custom_minimum_size.x * PANEL_SWITCH_ICON_SIZE_RATIO)
	var side_margin := _compute_panel_switch_side_margin(layout_control.custom_minimum_size.x, initial_icon_size)
	var initial_top_margin := _panel_switch_top_margin()
	button.offset_left = -side_margin - initial_icon_size
	button.offset_top = initial_top_margin
	button.offset_right = -side_margin
	button.offset_bottom = initial_top_margin + initial_icon_size
	var transparent_button_style := _make_style_box(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	button.add_theme_stylebox_override("normal", transparent_button_style)
	button.add_theme_stylebox_override("hover", transparent_button_style)
	button.add_theme_stylebox_override("pressed", transparent_button_style)
	button.add_theme_stylebox_override("focus", transparent_button_style)
	button.pressed.connect(_on_panel_switch_pressed.bind(view_index))
	zone.add_child(button)
	panel_switch_buttons[view_index] = button

	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(icon_center)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = CHANGE_CAM_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.self_modulate = PANEL_SWITCH_ICON_TINT
	icon_center.add_child(icon)
	panel_switch_icons[view_index] = icon

	var label_panel := PanelContainer.new()
	label_panel.name = "CameraSwitchLabel"
	label_panel.visible = false
	label_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_panel.anchor_left = 0.5
	label_panel.anchor_top = 0.5
	label_panel.anchor_right = 0.5
	label_panel.anchor_bottom = 0.5
	label_panel.offset_left = -PANEL_SWITCH_LABEL_WIDTH * 0.5
	label_panel.offset_top = -PANEL_SWITCH_LABEL_HEIGHT * 0.5
	label_panel.offset_right = PANEL_SWITCH_LABEL_WIDTH * 0.5
	label_panel.offset_bottom = PANEL_SWITCH_LABEL_HEIGHT * 0.5
	label_panel.modulate.a = 0.0
	label_panel.add_theme_stylebox_override("panel", _make_style_box(PANEL_SWITCH_LABEL_BG, Color(0.0, 0.0, 0.0, 0.0), 0, 12))
	zone.add_child(label_panel)
	panel_switch_label_panels[view_index] = label_panel

	var label := Label.new()
	label.text = ""
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", PANEL_SWITCH_LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0.976471, 0.988235, 1.0, 0.98))
	label_panel.add_child(label)
	panel_switch_text_labels[view_index] = label

	var material := ShaderMaterial.new()
	material.shader = panel_corner_shader
	material.set_shader_parameter("corner_radius_px", 0.0)
	material.set_shader_parameter("panel_size_px", Vector2(1.0, 1.0))
	preview.material = material

	_update_panel_switch_control_layout(view_index)

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
		_make_style_box(Color(0.05098, 0.066667, 0.086275, 0.96), Color(0.568627, 0.678431, 0.780392, 0.42), 1, 30)
	)
	hud_root.add_child(layout_workbench)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(WORKBENCH_INNER_MARGIN))
	margin.add_theme_constant_override("margin_top", int(WORKBENCH_INNER_MARGIN))
	margin.add_theme_constant_override("margin_right", int(WORKBENCH_INNER_MARGIN))
	margin.add_theme_constant_override("margin_bottom", int(WORKBENCH_INNER_MARGIN))
	layout_workbench.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode = 0
	scroll.vertical_scroll_mode = 1
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	layout_cards_grid = GridContainer.new()
	layout_cards_grid.columns = 1
	layout_cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout_cards_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout_cards_grid.add_theme_constant_override("h_separation", int(WORKBENCH_CARD_GAP))
	layout_cards_grid.add_theme_constant_override("v_separation", int(WORKBENCH_CARD_GAP))
	scroll.add_child(layout_cards_grid)

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

	var button := Button.new()
	button.toggle_mode = true
	button.button_group = layout_button_group
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, PRESET_CARD_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = ""
	button.clip_contents = true
	button.add_theme_stylebox_override(
		"normal",
		_make_style_box(Color(0.101961, 0.141176, 0.184314, 0.96), Color(0.643137, 0.733333, 0.815686, 0.28), 1, 24)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_style_box(Color(0.145098, 0.196078, 0.247059, 0.98), Color(0.870588, 0.929412, 0.980392, 0.55), 1, 24)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_style_box(Color(0.090196, 0.239216, 0.356863, 1.0), Color(0.945098, 0.980392, 1.0, 0.95), 2, 24)
	)
	button.add_theme_stylebox_override(
		"focus",
		_make_style_box(Color(0.090196, 0.239216, 0.356863, 1.0), Color(0.945098, 0.980392, 1.0, 0.95), 2, 24)
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
	stack.add_theme_constant_override("separation", 10)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(stack)

	var preview_orientation := _preview_orientation_for_option(option)
	var preview_size := _preview_size_for_orientation(preview_orientation)
	var preview_frame_size := _preview_frame_size_for_orientation(preview_orientation)

	var preview_frame := PanelContainer.new()
	preview_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.clip_contents = true
	preview_frame.custom_minimum_size = preview_frame_size
	preview_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview_frame.add_theme_stylebox_override(
		"panel",
		_make_style_box(Color(0.078431, 0.109804, 0.141176, 1.0), Color(0.756863, 0.835294, 0.901961, 0.34), 1, 18)
	)
	stack.add_child(preview_frame)

	var preview_center := CenterContainer.new()
	preview_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_frame.add_child(preview_center)

	var preview := TextureRect.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview.custom_minimum_size = Vector2(preview_size.x, preview_size.y)
	preview.texture = _build_layout_preview_texture(preset_id, preview_size, preview_orientation)
	preview_center.add_child(preview)

	return button

func _build_layout_preview_texture(preset_id: String, preview_size: Vector2i, preview_orientation: String) -> Texture2D:
	var previous_preset := layout_manager.get_preset()
	layout_manager.set_preset(preset_id)
	# Picker orientation is a preview-card presentation hint only. Preview content
	# always comes from the portrait-authored canonical layout source.
	var snapshot_viewport_size := PRESET_PREVIEW_CANONICAL_SIZE
	var snapshot_size_float := Vector2(float(snapshot_viewport_size.x), float(snapshot_viewport_size.y))
	var snapshot := layout_manager.build_snapshot(snapshot_size_float, true)
	layout_manager.set_preset(previous_preset)

	var image := Image.create(snapshot_viewport_size.x, snapshot_viewport_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.054902, 0.07451, 0.094118, 1.0))
	_draw_slots_on_image(image, snapshot.get("slots", []), snapshot_viewport_size)
	_draw_separators_on_image(image, snapshot.get("separators", []), snapshot_viewport_size)
	if preview_orientation == "landscape":
		# Rotate preview content for landscape cards so the implied portrait mapping
		# matches the live-feed top-left inset expectation.
		image = _rotate_image_clockwise(image)
		image.flip_x()
		image.flip_y()

	return ImageTexture.create_from_image(image)

func _preview_orientation_for_option(option: Dictionary) -> String:
	var orientation := String(option.get("preview_orientation", "portrait"))
	if orientation == "landscape":
		return orientation
	return "portrait"

func _preview_size_for_orientation(preview_orientation: String) -> Vector2i:
	if preview_orientation == "landscape":
		return PRESET_PREVIEW_LANDSCAPE_SIZE
	return PRESET_PREVIEW_PORTRAIT_SIZE

func _preview_frame_size_for_orientation(preview_orientation: String) -> Vector2:
	if preview_orientation == "landscape":
		return PRESET_PREVIEW_LANDSCAPE_FRAME_SIZE
	return PRESET_PREVIEW_PORTRAIT_FRAME_SIZE

func _rotate_image_clockwise(source: Image) -> Image:
	var src_width := source.get_width()
	var src_height := source.get_height()
	var rotated := Image.create(src_height, src_width, false, source.get_format())
	for y in range(src_height):
		for x in range(src_width):
			rotated.set_pixel(src_height - 1 - y, x, source.get_pixel(x, y))
	return rotated

func _draw_slots_on_image(image: Image, slots: Array, canvas_size: Vector2i) -> void:
	for slot in slots:
		if not (slot is Dictionary):
			continue
		var slot_dict: Dictionary = slot
		var rect: Rect2 = slot_dict.get("rect", Rect2(0.0, 0.0, 1.0, 1.0))
		var stream_id := String(slot_dict.get("stream_id", "primary"))
		var fill_color := Color(0.94902, 0.333333, 0.243137, 1.0)
		if stream_id == "secondary":
			fill_color = Color(0.215686, 0.482353, 0.960784, 1.0)
		var pixel_rect := _normalized_to_pixel_rect(rect, canvas_size)
		image.fill_rect(pixel_rect, fill_color)
		_stroke_rect_on_image(image, pixel_rect, Color(0.945098, 0.980392, 1.0, 0.72), 2)

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

func _stroke_rect_on_image(image: Image, rect: Rect2i, color: Color, thickness: int) -> void:
	var stroke := maxi(1, thickness)
	image.fill_rect(Rect2i(rect.position.x, rect.position.y, rect.size.x, stroke), color)
	image.fill_rect(Rect2i(rect.position.x, rect.position.y + rect.size.y - stroke, rect.size.x, stroke), color)
	image.fill_rect(Rect2i(rect.position.x, rect.position.y, stroke, rect.size.y), color)
	image.fill_rect(Rect2i(rect.position.x + rect.size.x - stroke, rect.position.y, stroke, rect.size.y), color)

func _make_style_box(fill: Color, border: Color, border_width: int, corner_radius: int) -> StyleBoxFlat:
	return _make_style_box_sided(fill, border, border_width, border_width, border_width, border_width, corner_radius)

func _make_style_box_sided(
	fill: Color,
	border: Color,
	border_width_left: int,
	border_width_top: int,
	border_width_right: int,
	border_width_bottom: int,
	corner_radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = max(0, border_width_left)
	style.border_width_top = max(0, border_width_top)
	style.border_width_right = max(0, border_width_right)
	style.border_width_bottom = max(0, border_width_bottom)
	style.border_color = border
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	return style

func _resolve_slot_border_widths(slot: Dictionary, border_width_px: float) -> Dictionary:
	var width: int = maxi(0, int(round(border_width_px)))
	var left: int = width
	var top: int = width
	var right: int = width
	var bottom: int = width

	if bool(slot.get("omit_outer_border_edges", false)):
		var rect: Rect2 = slot.get("rect", Rect2(0.0, 0.0, 1.0, 1.0))
		var epsilon: float = 0.001
		if rect.position.x <= epsilon:
			left = 0
		if rect.position.y <= epsilon:
			top = 0
		if rect.position.x + rect.size.x >= 1.0 - epsilon:
			right = 0
		if rect.position.y + rect.size.y >= 1.0 - epsilon:
			bottom = 0

	return {
		"left": left,
		"top": top,
		"right": right,
		"bottom": bottom
	}

func _has_visible_slot_border(border_widths: Dictionary) -> bool:
	if int(border_widths.get("left", 0)) > 0:
		return true
	if int(border_widths.get("top", 0)) > 0:
		return true
	if int(border_widths.get("right", 0)) > 0:
		return true
	if int(border_widths.get("bottom", 0)) > 0:
		return true
	return false

func _sync_layout_snapshot() -> void:
	var snapshot := _build_layout_snapshot()
	_apply_preview_snapshot(snapshot)
	_publish_layout_snapshot(snapshot)
	_rebuild_panel_cycle_lists()
	_refresh_layout_card_selection()

func _apply_preview_snapshot(snapshot: Dictionary) -> void:
	var slots: Array = snapshot.get("slots", [])
	var primary_slot := _find_slot_for_stream(slots, "primary")
	var secondary_slot := _find_slot_for_stream(slots, "secondary")

	_apply_slot_to_zone(primary_zone, primary_slot)
	_apply_slot_to_zone(secondary_zone, secondary_slot)
	secondary_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_zone_visual_state(0, primary_slot)
	_apply_zone_visual_state(1, secondary_slot)

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

func _apply_zone_visual_state(view_index: int, slot: Dictionary) -> void:
	var zone: Control = primary_zone if view_index == 0 else secondary_zone
	var preview: TextureRect = top_preview if view_index == 0 else bottom_preview
	var mask: Panel = panel_mask_nodes.get(view_index)
	var border: Panel = panel_border_nodes.get(view_index)
	var button: Button = panel_switch_buttons.get(view_index)
	var label_panel: PanelContainer = panel_switch_label_panels.get(view_index)
	if not zone:
		return

	if slot.is_empty() or not zone.visible:
		if mask:
			mask.visible = false
		if border:
			border.visible = false
		if button:
			button.visible = false
		if label_panel:
			label_panel.visible = false
		return

	var corner_radius_px := float(slot.get("corner_radius_px", 0.0))
	var corner_radius := int(round(corner_radius_px))
	if preview and preview.material is ShaderMaterial:
		var panel_size_px := Vector2(maxf(1.0, zone.size.x), maxf(1.0, zone.size.y))
		(preview.material as ShaderMaterial).set_shader_parameter("corner_radius_px", corner_radius_px)
		(preview.material as ShaderMaterial).set_shader_parameter("panel_size_px", panel_size_px)

	if mask:
		mask.visible = true
		mask.add_theme_stylebox_override("panel", _make_style_box(Color(1.0, 1.0, 1.0, 1.0), Color(0.0, 0.0, 0.0, 0.0), 0, corner_radius))

	if border:
		var border_width_px := float(slot.get("border_width_px", 0.0))
		var border_color: Color = slot.get("border_color", PANEL_BORDER_DEFAULT_COLOR)
		var border_widths := _resolve_slot_border_widths(slot, border_width_px)
		if _has_visible_slot_border(border_widths):
			border.visible = true
			border.add_theme_stylebox_override(
				"panel",
				_make_style_box_sided(
					Color(0.0, 0.0, 0.0, 0.0),
					border_color,
					int(border_widths.get("left", 0)),
					int(border_widths.get("top", 0)),
					int(border_widths.get("right", 0)),
					int(border_widths.get("bottom", 0)),
					corner_radius
				)
			)
		else:
			border.visible = false

	if button:
		button.visible = true

func _compute_panel_switch_side_margin(base_size: float, switch_size: float) -> float:
	var effective_base_size := base_size
	if effective_base_size <= 0.0:
		effective_base_size = layout_control.custom_minimum_size.x
	var legacy_size := maxf(PANEL_SWITCH_HIT_TARGET_MIN, effective_base_size * PANEL_SWITCH_LEGACY_ICON_SIZE_RATIO)
	var legacy_center_offset := PANEL_SWITCH_BASE_SIDE_MARGIN + (legacy_size * 0.5)
	return maxf(0.0, legacy_center_offset - (switch_size * 0.5))

func _panel_switch_top_margin() -> float:
	return PANEL_SWITCH_TOP_MARGIN + PANEL_SWITCH_EXTRA_TOP_MARGIN

func _update_panel_switch_control_layout(view_index: int) -> void:
	var button: Button = panel_switch_buttons.get(view_index)
	if not button:
		return

	var base_size := layout_control.size.x
	if base_size <= 0.0:
		base_size = layout_control.custom_minimum_size.x
	var icon_size := maxf(PANEL_SWITCH_HIT_TARGET_MIN, base_size * PANEL_SWITCH_ICON_SIZE_RATIO)
	var switch_size := maxf(PANEL_SWITCH_HIT_TARGET_MIN, icon_size)
	var side_margin := _compute_panel_switch_side_margin(base_size, switch_size)
	var zone: Control = primary_zone if view_index == 0 else secondary_zone
	var target_center_y := layout_control.global_position.y + (layout_control.size.y * 0.5)
	var base_top_margin := _panel_switch_top_margin()
	var offset_top := base_top_margin
	if zone:
		var proposed_top := target_center_y - zone.global_position.y - (switch_size * 0.5)
		var max_top := maxf(base_top_margin, zone.size.y - switch_size - base_top_margin)
		offset_top = clampf(proposed_top, base_top_margin, max_top)

	button.offset_left = -side_margin - switch_size
	button.offset_top = offset_top
	button.offset_right = -side_margin
	button.offset_bottom = offset_top + switch_size

	var icon: TextureRect = panel_switch_icons.get(view_index)
	if icon:
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var label_panel: PanelContainer = panel_switch_label_panels.get(view_index)
	if label_panel:
		label_panel.offset_left = -PANEL_SWITCH_LABEL_WIDTH * 0.5
		label_panel.offset_top = -PANEL_SWITCH_LABEL_HEIGHT * 0.5
		label_panel.offset_right = PANEL_SWITCH_LABEL_WIDTH * 0.5
		label_panel.offset_bottom = PANEL_SWITCH_LABEL_HEIGHT * 0.5

func _refresh_layout_card_selection() -> void:
	var selected_id := layout_manager.get_preset()
	for preset_id in layout_card_buttons.keys():
		var card: Button = layout_card_buttons[preset_id]
		card.button_pressed = String(preset_id) == selected_id
		card.scale = Vector2.ONE

func _is_pointer_press_event(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	return false

func _can_consume_layout_pointer_event() -> bool:
	var now := Time.get_ticks_msec()
	if now - layout_pointer_event_msec < LAYOUT_POINTER_DEBOUNCE_MS:
		return false
	layout_pointer_event_msec = now
	return true

func _on_layout_gui_input(event: InputEvent) -> void:
	if not _is_pointer_press_event(event):
		return
	if not _can_consume_layout_pointer_event():
		return
	_toggle_layout_workbench()
	accept_event()

func _on_layout_backdrop_gui_input(event: InputEvent) -> void:
	if layout_workbench_open and Time.get_ticks_msec() - layout_workbench_opened_msec < LAYOUT_BACKDROP_CLOSE_GUARD_MS:
		return

	if not _is_pointer_press_event(event):
		return
	if not _can_consume_layout_pointer_event():
		return
	_close_layout_workbench()
	accept_event()

func _toggle_layout_workbench() -> void:
	if layout_workbench_open:
		_close_layout_workbench()
	else:
		_open_layout_workbench()

func _open_layout_workbench() -> void:
	layout_workbench_open = true
	layout_workbench_opened_msec = Time.get_ticks_msec()
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
	_apply_default_devices_for_active_layout()
	_sync_layout_snapshot()
	_play_layout_control_pulse()
	_close_layout_workbench()

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

func _on_panel_switch_pressed(view_index: int) -> void:
	_cycle_panel_camera(view_index)

func _refresh_camera_device_catalog() -> void:
	# EDUCATIONAL:
	# Native returns hardware-specific IDs and localized names. We normalize that
	# into stable "roles" (`main`, `tele`, `front`, ...) to keep UI defaults and
	# cycling behavior deterministic across devices.
	panel_device_catalog.clear()
	if not Native or not Native.has_method("get_available_devices"):
		return

	var devices: Dictionary = Native.get_available_devices()
	for raw_id in devices.keys():
		var device_id := String(raw_id)
		var device_name := String(devices[raw_id])
		panel_device_catalog.append({
			"id": device_id,
			"name": device_name,
			"role": _classify_device_role(device_id, device_name),
			"label": _device_feedback_label(device_id, device_name)
		})

	panel_device_catalog.sort_custom(Callable(self, "_sort_device_meta"))
	_apply_default_devices_for_active_layout()
	_rebuild_panel_cycle_lists()

func _classify_device_role(device_id: String, device_name: String) -> String:
	var fingerprint := (device_id + " " + device_name).to_lower()
	if "front" in fingerprint or "true depth" in fingerprint:
		return "front"
	if "tele" in fingerprint:
		return "tele"
	if "ultra" in fingerprint:
		return "ultra"
	if "wide" in fingerprint or "main" in fingerprint or "back" in fingerprint:
		return "main"
	return "other"

func _device_feedback_label(device_id: String, device_name: String) -> String:
	var role := _classify_device_role(device_id, device_name)
	match role:
		"front":
			return "front"
		"tele":
			return "tele"
		"ultra":
			return "ultra"
		"main":
			return "main"
		_:
			var words := device_name.strip_edges().split(" ", false)
			if words.is_empty():
				return "camera"
			return String(words[0]).to_lower()

func _role_sort_index(role: String) -> int:
	match role:
		"main":
			return 0
		"tele":
			return 1
		"ultra":
			return 2
		"front":
			return 3
		_:
			return 4

func _sort_device_meta(a: Dictionary, b: Dictionary) -> bool:
	var a_role := _role_sort_index(String(a.get("role", "other")))
	var b_role := _role_sort_index(String(b.get("role", "other")))
	if a_role == b_role:
		return String(a.get("name", "")).nocasecmp_to(String(b.get("name", ""))) < 0
	return a_role < b_role

func _priority_roles_for_view(view_index: int) -> PackedStringArray:
	var preset_id := layout_manager.get_preset()
	if preset_id == "include_photographer":
		if view_index == 1:
			return PackedStringArray(["front", "main", "tele", "ultra", "other"])
		return PackedStringArray(["main", "tele", "ultra", "front", "other"])
	if preset_id == "wide inset":
		if view_index == 1:
			return PackedStringArray(["ultra", "main", "tele", "front", "other"])
		return PackedStringArray(["main", "ultra", "tele", "front", "other"])
	if view_index == 1:
		return PackedStringArray(["tele", "main", "ultra", "front", "other"])
	return PackedStringArray(["main", "tele", "ultra", "front", "other"])

func _find_device_id_for_role(role: String, excluded_id: String = "") -> String:
	for device in panel_device_catalog:
		if not (device is Dictionary):
			continue
		var candidate: Dictionary = device
		if String(candidate.get("role", "")) != role:
			continue
		var candidate_id := String(candidate.get("id", ""))
		if candidate_id.is_empty():
			continue
		if not excluded_id.is_empty() and candidate_id == excluded_id:
			continue
		return candidate_id
	return ""

func _find_device_id_by_priority(priority: PackedStringArray, excluded_id: String = "") -> String:
	for role in priority:
		var match := _find_device_id_for_role(String(role), excluded_id)
		if not match.is_empty():
			return match
	return ""

func _is_multicam_active() -> bool:
	return Native and Native.has_method("is_multicam_supported") and Native.is_multicam_supported()

func _apply_default_devices_for_active_layout() -> void:
	# EDUCATIONAL:
	# Defaults are layout-driven so switching presets snaps to expected intent:
	# include_photographer => main + front, zoomies => main + tele,
	# wide inset => main + ultra.
	if panel_device_catalog.is_empty() or not Native or not Native.has_method("set_device"):
		return

	var primary_id := _find_device_id_by_priority(_priority_roles_for_view(0))
	if primary_id.is_empty():
		return

	if _is_multicam_active():
		var secondary_priority := _priority_roles_for_view(1)
		var secondary_id := _find_device_id_by_priority(secondary_priority, primary_id)
		if secondary_id.is_empty():
			secondary_id = _find_device_id_by_priority(secondary_priority)
		_set_panel_device(0, primary_id)
		if not secondary_id.is_empty():
			_set_panel_device(1, secondary_id)
	else:
		_set_panel_device(0, primary_id)
		panel_current_device_ids[1] = primary_id

func _rebuild_panel_cycle_lists() -> void:
	panel_cycle_device_ids[0] = _build_cycle_device_ids_for_view(0)
	panel_cycle_device_ids[1] = _build_cycle_device_ids_for_view(1)

func _build_cycle_device_ids_for_view(view_index: int) -> Array:
	var ordered_ids: Array = []
	var priority := _priority_roles_for_view(view_index)
	for role in priority:
		for device in panel_device_catalog:
			if not (device is Dictionary):
				continue
			var candidate: Dictionary = device
			if String(candidate.get("role", "")) != String(role):
				continue
			var candidate_id := String(candidate.get("id", ""))
			if candidate_id.is_empty() or ordered_ids.has(candidate_id):
				continue
			ordered_ids.append(candidate_id)
	return ordered_ids

func _set_panel_device(view_index: int, device_id: String) -> void:
	if device_id.is_empty() or not Native or not Native.has_method("set_device"):
		return
	if _is_multicam_active():
		Native.set_device(view_index, device_id)
		panel_current_device_ids[view_index] = device_id
	else:
		Native.set_device(0, device_id)
		panel_current_device_ids[0] = device_id
		panel_current_device_ids[1] = device_id

func _cycle_panel_camera(view_index: int) -> void:
	if panel_device_catalog.is_empty():
		_refresh_camera_device_catalog()
	if panel_device_catalog.is_empty():
		return

	var cycle_ids: Array = panel_cycle_device_ids.get(view_index, [])
	if cycle_ids.is_empty():
		cycle_ids = _build_cycle_device_ids_for_view(view_index)
	if cycle_ids.is_empty():
		return

	var current_id := String(panel_current_device_ids.get(view_index, ""))
	var next_index := 0
	var current_index := cycle_ids.find(current_id)
	if current_index >= 0:
		next_index = (current_index + 1) % cycle_ids.size()
	var next_id := String(cycle_ids[next_index])
	_set_panel_device(view_index, next_id)
	_show_panel_switch_label(view_index, _label_for_device_id(next_id))

func _label_for_device_id(device_id: String) -> String:
	for device in panel_device_catalog:
		if not (device is Dictionary):
			continue
		var candidate: Dictionary = device
		if String(candidate.get("id", "")) == device_id:
			return String(candidate.get("label", "camera"))
	return "camera"

func _show_panel_switch_label(view_index: int, label_text: String) -> void:
	var label_panel: PanelContainer = panel_switch_label_panels.get(view_index)
	var text_label: Label = panel_switch_text_labels.get(view_index)
	if not label_panel or not text_label:
		return

	if panel_label_tweens.has(view_index):
		var active_tween: Tween = panel_label_tweens[view_index]
		if active_tween:
			active_tween.kill()

	text_label.text = label_text
	label_panel.visible = true
	label_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(label_panel, "modulate:a", 1.0, 0.08)
	tween.tween_interval(PANEL_SWITCH_LABEL_TIMEOUT)
	tween.tween_property(label_panel, "modulate:a", 0.0, 0.16)
	tween.finished.connect(func():
		label_panel.visible = false
	)
	panel_label_tweens[view_index] = tween

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
	if Native.has_signal("permission_granted"):
		if not Native.permission_granted.is_connected(_on_native_permission_granted):
			Native.permission_granted.connect(_on_native_permission_granted)
	if Native.has_signal("image_save_started"):
		if not Native.image_save_started.is_connected(_on_native_image_save_started):
			Native.image_save_started.connect(_on_native_image_save_started)
	if Native.has_signal("image_save_finished"):
		if not Native.image_save_finished.is_connected(_on_native_image_save_finished):
			Native.image_save_finished.connect(_on_native_image_save_finished)

func _on_native_permission_granted() -> void:
	_refresh_camera_device_catalog()
	_sync_layout_snapshot()

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
	if Native and Native.has_method("open_latest_saved_photo"):
		Native.open_latest_saved_photo()
	elif Native and Native.has_method("open_photo_library"):
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
