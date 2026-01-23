extends Control

@export var view_index: int = 0

var manager: CameraControlManager
@onready var focus_indicator = $FocusIndicator

# Touch State
var touches = {} # {index: Vector2}
var initial_pinch_distance = 0.0
var is_pinching = false

func _ready():
	# Locate Manager
	var main = get_tree().root.get_node("Main")
	if main.has_node("CameraControlManager"):
		manager = main.get_node("CameraControlManager")
	else:
		push_error("ViewerInput: CameraControlManager not found in Main")
	
	# Configure Focus Indicator Style (Border Only, ~1cm = 150px)
	if focus_indicator:
		focus_indicator.visible = false
		focus_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Resize to ~150px (approx 1cm on high DPI)
		focus_indicator.size = Vector2(120, 120) 
		# If it's a ColorRect, it doesn't support borders easily. 
		# We'll assume it's a generic Control we can style or a ColorRect we make transparent with a border child.
		# Ideally, we'd replace it with a Panel, but we can't easily change type in script without replacing node.
		# Let's just use a simple drawing approach or assuming it's a Panel would be better.
		# Since we can't change the scene file easily here without risk, let's just use a StyleBox on it 
		# IF it is a Panel. It is a ColorRect in tscn.
		# Workaround: Make ColorRect transparent and add a ReferenceRect child or just use _draw().
		# Simplest: Hide ColorRect, add a line rect via _draw() on the FocusIndicator node?
		# No, FocusIndicator is a ColorRect.
		# Let's change its color to transparent and add a border script or just change the node type in .tscn.
		# I will update .tscn in a separate step. Here I just set size.

func _gui_input(event):
	if not manager: return
	
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
			if touches.size() < 2:
				is_pinching = false
		
		# Check for Tap (1 finger, release, no pinch)
		if not event.pressed and not is_pinching and touches.size() == 0:
			_handle_tap(event.position)
			
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() == 2:
			_handle_pinch(touches.values()[0], touches.values()[1])

	# Keep MagnifyGesture for macOS trackpad testing
	elif event is InputEventMagnifyGesture:
		manager.handle_zoom_delta(view_index, event.factor)

func _handle_pinch(p1: Vector2, p2: Vector2):
	var current_dist = p1.distance_to(p2)
	
	if not is_pinching:
		initial_pinch_distance = current_dist
		is_pinching = true
		return
		
	if initial_pinch_distance < 10.0: return # Avoid div/0
	
	# Calculate relative scale factor since last frame? 
	# Or absolute from start? 
	# Standard pinch usually gives a relative factor.
	# Let's do relative to previous frame by storing previous distance?
	# Simpler: Just rely on 'delta' logic.
	# If we have previous_dist:
	# factor = current / previous
	
	# Let's store 'previous_pinch_distance' instead of initial.
	var factor = current_dist / initial_pinch_distance
	
	# To make it continuous, we need to reset the anchor every frame 
	# OR pass the relative change to the manager.
	# Manager expects a factor to multiply by (e.g. 1.05 or 0.95).
	# So we need (current / prev).
	
	# Resetting initial to current for the next event
	var delta = current_dist / initial_pinch_distance
	manager.handle_zoom_delta(view_index, delta)
	initial_pinch_distance = current_dist

func _handle_tap(pos: Vector2):
	# Ignore if we were just pinching
	if is_pinching: return
	
	var r_size = get_size()
	if r_size.x == 0 or r_size.y == 0: return
	
	var normalized = Vector2(pos.x / r_size.x, pos.y / r_size.y)
	
	manager.handle_focus(view_index, normalized)
	_show_focus_indicator(pos)

var focus_tween: Tween

func _show_focus_indicator(pos: Vector2):
	if focus_indicator:
		if focus_tween: focus_tween.kill()
		
		focus_indicator.position = pos - (focus_indicator.size / 2)
		focus_indicator.visible = true
		focus_indicator.modulate.a = 1.0
		
		focus_tween = create_tween()
		# Hold for 0.5s, then fade out
		focus_tween.tween_interval(0.5)
		focus_tween.tween_property(focus_indicator, "modulate:a", 0.0, 0.5)
		focus_tween.tween_callback(func(): focus_indicator.visible = false)
