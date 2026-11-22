## Screen stack manager. Handles push/pop transitions and responsive layout.
## All screens live under a CanvasLayer so they render above the game world.
extends Node

var _canvas: CanvasLayer
var _stack: Array[Control] = []
var _cache: Dictionary = {}       # screen_name → Control instance
var _active_toasts: Array = []    # currently visible toast controls

const SCREENS := {
	"MainMenu":        "res://scenes/ui/screens/MainMenu.tscn",
	"WorldMap":        "res://scenes/ui/screens/WorldMap.tscn",
	"CourseBuilder":   "res://scenes/ui/screens/CourseBuilder.tscn",
	"Gameplay":        "res://scenes/ui/screens/Gameplay.tscn",
	"PauseMenu":       "res://scenes/ui/screens/PauseMenu.tscn",
	"Settings":        "res://scenes/ui/screens/Settings.tscn",
	"DialogueOverlay": "res://scenes/ui/screens/DialogueOverlay.tscn",
}

func _ready() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	# UI keeps working while the tree is paused (pause menu, story dialogue).
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)

	EventBus.screen_show_requested.connect(show_screen)
	EventBus.screen_push_requested.connect(push_screen)
	EventBus.screen_pop_requested.connect(pop_screen)
	EventBus.notification_requested.connect(_show_notification)
	EventBus.game_state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.WORLD_MAP:
		_clear_stack()  # hide all UI screens while hub world is active

# ── Screen stack ─────────────────────────────────────────────────────────────

## Replace entire stack with a single screen (navigation root change).
func show_screen(screen_name: String, params: Dictionary = {}) -> void:
	_clear_stack()
	push_screen(screen_name, params)

## Push a screen on top; previous screen is hidden but preserved.
func push_screen(screen_name: String, params: Dictionary = {}) -> void:
	if not SCREENS.has(screen_name):
		push_error("UIManager: unknown screen '%s'" % screen_name)
		return

	var screen := _get_or_load(screen_name)
	if screen in _stack:
		push_warning("UIManager: '%s' already on the stack — ignoring duplicate push" % screen_name)
		return

	# params.overlay = true keeps the screen below visible (e.g. story dialogue
	# over the HUD); the overlay is responsible for blocking input to it.
	if not _stack.is_empty() and not params.get("overlay", false):
		_stack.back().hide()

	_stack.append(screen)
	# Newest screen last among siblings → drawn on top and first to get input
	# (cached screens keep their old child index otherwise).
	_canvas.move_child(screen, -1)
	screen.show()

	if screen.has_method("on_screen_entered"):
		screen.on_screen_entered(params)

## Pop top screen; reveal the one beneath.
func pop_screen() -> void:
	if _stack.size() <= 1:
		return

	var top: Control = _stack.pop_back()
	if top.has_method("on_screen_exited"):
		top.on_screen_exited()
	top.hide()

	if not _stack.is_empty():
		_stack.back().show()

func current_screen_name() -> String:
	if _stack.is_empty():
		return ""
	for name in SCREENS:
		if _cache.get(name) == _stack.back():
			return name
	return ""

# ── Helpers ──────────────────────────────────────────────────────────────────

func _get_or_load(screen_name: String) -> Control:
	if _cache.has(screen_name):
		return _cache[screen_name]
	var packed: PackedScene = load(SCREENS[screen_name])
	var screen: Control = packed.instantiate()
	_canvas.add_child(screen)
	_cache[screen_name] = screen
	screen.hide()
	return screen

func _clear_stack() -> void:
	for screen in _stack:
		if screen.has_method("on_screen_exited"):
			screen.on_screen_exited()
		screen.hide()
	_stack.clear()

func _show_notification(message: String, notification_type: String) -> void:
	# Remove expired toasts from tracking list
	_active_toasts = _active_toasts.filter(func(t) -> bool: return is_instance_valid(t))

	var toast := PanelContainer.new()
	var lbl   := Label.new()
	lbl.text = message
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(lbl)
	toast.add_child(margin)

	var sb := StyleBoxFlat.new()
	match notification_type:
		"warning": sb.bg_color = Color(0.55, 0.22, 0.05, 0.95)
		"error":   sb.bg_color = Color(0.55, 0.08, 0.08, 0.95)
		_:         sb.bg_color = Color(0.09, 0.36, 0.12, 0.95)
	sb.set_corner_radius_all(7)
	toast.add_theme_stylebox_override("panel", sb)

	# Stack toasts vertically — each new one appears below existing ones
	var stack_offset: float = 80.0 + _active_toasts.size() * 52.0
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.offset_top = stack_offset
	toast.z_index    = 200
	toast.modulate   = Color(1.0, 1.0, 1.0, 0.0)

	_canvas.add_child(toast)
	_active_toasts.append(toast)

	var tw := toast.create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.18)
	tw.tween_interval(2.5)
	tw.tween_property(toast, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		_active_toasts.erase(toast)
		toast.queue_free()
		# Shift remaining toasts up
		_active_toasts = _active_toasts.filter(func(t) -> bool: return is_instance_valid(t))
		for i in _active_toasts.size():
			(_active_toasts[i] as Control).offset_top = 80.0 + i * 52.0
	)
