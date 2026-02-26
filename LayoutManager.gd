extends RefCounted
class_name LayoutManager

const PRESET_ZOOMIES := "zoomies"
const PRESET_INCLUDE_PHOTOGRAPHER := "include_photographer"
const LAYOUT_VERSION := 1
const DEFAULT_SEPARATOR_COLOR := Color(1.0, 1.0, 1.0, 0.22)
const DEFAULT_PANEL_BORDER_COLOR := Color(0.917647, 0.929412, 0.941176, 0.62)
const DEFAULT_PANEL_BORDER_WIDTH_PX := 2.0
const PRESET_OPTIONS := [
	{
		"id": PRESET_INCLUDE_PHOTOGRAPHER,
		"title": "Include Photographer"
	},
	{
		"id": PRESET_ZOOMIES,
		"title": "Zoomies"
	}
]

var _preset := PRESET_ZOOMIES

func set_preset(preset: String) -> void:
	if _is_valid_preset(preset):
		_preset = preset

func get_preset() -> String:
	return _preset

func get_preset_options() -> Array:
	return PRESET_OPTIONS.duplicate(true)

func build_snapshot(viewport_size: Vector2, has_secondary_stream: bool) -> Dictionary:
	var output_size := Vector2i(max(1, int(viewport_size.x)), max(1, int(viewport_size.y)))
	var slots: Array = []
	var separators: Array = []

	match _preset:
		PRESET_INCLUDE_PHOTOGRAPHER:
			# EDUCATIONAL:
			# Inset dimensions are authored in normalized space but adjusted by the
			# viewport aspect so the overlay remains visually square on screen.
			var inset_width_normalized := 0.48
			var inset_height_normalized := inset_width_normalized * (viewport_size.x / maxf(1.0, viewport_size.y))
			inset_height_normalized = clampf(inset_height_normalized, 0.24, 0.48)
			var inset_margin_x := 0.045
			var inset_margin_y := 0.055
			var inset_y := inset_margin_y
			var inset_corner_radius_px := clampf(viewport_size.x * 0.045, 14.0, 30.0)
			slots.append({
				"id": "slot_primary_background",
				"stream_id": "primary",
				"rect": Rect2(0.0, 0.0, 1.0, 1.0),
				"z_index": 0,
				"fallback_policy": "duplicate_primary",
				"default_camera_role": "main",
				"corner_radius_px": 0.0,
				"border_width_px": DEFAULT_PANEL_BORDER_WIDTH_PX,
				"border_color": DEFAULT_PANEL_BORDER_COLOR,
				"omit_outer_border_edges": true
			})
			slots.append({
				"id": "slot_secondary_inset",
				"stream_id": "secondary",
				"rect": Rect2(inset_margin_x, inset_y, inset_width_normalized, inset_height_normalized),
				"z_index": 10,
				"fallback_policy": "duplicate_primary",
				"default_camera_role": "front",
				"corner_radius_px": inset_corner_radius_px,
				"border_width_px": DEFAULT_PANEL_BORDER_WIDTH_PX,
				"border_color": DEFAULT_PANEL_BORDER_COLOR,
				"omit_outer_border_edges": true
			})
		_:
			slots.append({
				"id": "slot_primary_top",
				"stream_id": "primary",
				"rect": Rect2(0.0, 0.0, 1.0, 0.5),
				"z_index": 0,
				"fallback_policy": "duplicate_primary",
				"default_camera_role": "main",
				"corner_radius_px": 0.0,
				"border_width_px": DEFAULT_PANEL_BORDER_WIDTH_PX,
				"border_color": DEFAULT_PANEL_BORDER_COLOR,
				"omit_outer_border_edges": true
			})
			slots.append({
				"id": "slot_secondary_bottom",
				"stream_id": "secondary",
				"rect": Rect2(0.0, 0.5, 1.0, 0.5),
				"z_index": 1,
				"fallback_policy": "duplicate_primary",
				"default_camera_role": "tele",
				"corner_radius_px": 0.0,
				"border_width_px": DEFAULT_PANEL_BORDER_WIDTH_PX,
				"border_color": DEFAULT_PANEL_BORDER_COLOR,
				"omit_outer_border_edges": true
			})
			var separator_height_normalized := 1.0 / float(max(output_size.y, 1))
			separators.append({
				"id": "main_separator",
				"rect": Rect2(0.0, 0.5 - (separator_height_normalized * 0.5), 1.0, separator_height_normalized),
				"color": DEFAULT_SEPARATOR_COLOR
			})

	if not has_secondary_stream:
		for slot in slots:
			if slot.get("stream_id", "primary") == "secondary":
				slot["fallback_policy"] = "duplicate_primary"

	return {
		"layout_version": LAYOUT_VERSION,
		"preset_id": _preset,
		"output_size": output_size,
		"slots": slots,
		"separators": separators
	}

func _is_valid_preset(preset: String) -> bool:
	for option in PRESET_OPTIONS:
		if option.get("id", "") == preset:
			return true
	return false
