extends RefCounted
class_name LayoutManager

const PRESET_STACKED := "stacked_dual"
const PRESET_OVERLAY := "overlay_pip"
const LAYOUT_VERSION := 1
const DEFAULT_SEPARATOR_COLOR := Color(1.0, 1.0, 1.0, 0.22)

var _preset := PRESET_STACKED

func set_preset(preset: String) -> void:
	if preset == PRESET_STACKED or preset == PRESET_OVERLAY:
		_preset = preset

func get_preset() -> String:
	return _preset

func build_snapshot(viewport_size: Vector2, has_secondary_stream: bool) -> Dictionary:
	var output_size := Vector2i(max(1, int(viewport_size.x)), max(1, int(viewport_size.y)))
	var slots: Array = []
	var separators: Array = []

	if _preset == PRESET_OVERLAY:
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
	else:
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
