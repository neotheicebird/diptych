extends RefCounted
class_name LayoutManager

const PRESET_STACKED := "stacked_dual"
const PRESET_OVERLAY := "overlay_pip"
const PRESET_VERTICAL := "side_by_side"
const PRESET_FOCUS_STRIP := "focus_strip"
const LAYOUT_VERSION := 1
const DEFAULT_SEPARATOR_COLOR := Color(1.0, 1.0, 1.0, 0.22)
const PRESET_OPTIONS := [
	{
		"id": PRESET_STACKED,
		"title": "Stacked",
		"description": "Balanced top and bottom composition."
	},
	{
		"id": PRESET_OVERLAY,
		"title": "Overlay",
		"description": "Picture-in-picture framing."
	},
	{
		"id": PRESET_VERTICAL,
		"title": "Side by Side",
		"description": "Parallel vertical split."
	},
	{
		"id": PRESET_FOCUS_STRIP,
		"title": "Focus Strip",
		"description": "Hero primary with cinematic strip."
	}
]

var _preset := PRESET_STACKED

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
		PRESET_OVERLAY:
			slots.append({
				"id": "slot_primary_full",
				"stream_id": "primary",
				"rect": Rect2(0.0, 0.0, 1.0, 1.0),
				"z_index": 0,
				"fallback_policy": "duplicate_primary"
			})
			slots.append({
				"id": "slot_secondary_overlay",
				"stream_id": "secondary",
				"rect": Rect2(0.62, 0.62, 0.34, 0.34),
				"z_index": 10,
				"fallback_policy": "duplicate_primary"
			})
		PRESET_VERTICAL:
			slots.append({
				"id": "slot_primary_left",
				"stream_id": "primary",
				"rect": Rect2(0.0, 0.0, 0.5, 1.0),
				"z_index": 0,
				"fallback_policy": "duplicate_primary"
			})
			slots.append({
				"id": "slot_secondary_right",
				"stream_id": "secondary",
				"rect": Rect2(0.5, 0.0, 0.5, 1.0),
				"z_index": 1,
				"fallback_policy": "duplicate_primary"
			})
			var separator_width_normalized := 1.0 / float(max(output_size.x, 1))
			separators.append({
				"id": "main_separator",
				"rect": Rect2(0.5 - (separator_width_normalized * 0.5), 0.0, separator_width_normalized, 1.0),
				"color": DEFAULT_SEPARATOR_COLOR
			})
		PRESET_FOCUS_STRIP:
			slots.append({
				"id": "slot_primary_hero",
				"stream_id": "primary",
				"rect": Rect2(0.0, 0.0, 1.0, 0.74),
				"z_index": 0,
				"fallback_policy": "duplicate_primary"
			})
			slots.append({
				"id": "slot_secondary_strip",
				"stream_id": "secondary",
				"rect": Rect2(0.0, 0.74, 1.0, 0.26),
				"z_index": 1,
				"fallback_policy": "duplicate_primary"
			})
			var strip_separator_height := 1.0 / float(max(output_size.y, 1))
			separators.append({
				"id": "main_separator",
				"rect": Rect2(0.0, 0.74 - (strip_separator_height * 0.5), 1.0, strip_separator_height),
				"color": DEFAULT_SEPARATOR_COLOR
			})
		_:
			slots.append({
				"id": "slot_primary_top",
				"stream_id": "primary",
				"rect": Rect2(0.0, 0.0, 1.0, 0.5),
				"z_index": 0,
				"fallback_policy": "duplicate_primary"
			})
			slots.append({
				"id": "slot_secondary_bottom",
				"stream_id": "secondary",
				"rect": Rect2(0.0, 0.5, 1.0, 0.5),
				"z_index": 1,
				"fallback_policy": "duplicate_primary"
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
