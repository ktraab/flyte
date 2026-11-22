## Story dialogue overlay. Pushed by StoryManager via UIManager — one beat at a time.
## Reads beat data from StoryManager.BEATS. Supports four looks:
##   dialogue  — portrait + name + text (default)
##   letter    — parchment panel, italic body, title as salutation/letterhead
##   newspaper — newsprint panel, bold headline
##   card      — full-screen black memorial card, centered text
## Optional "choices" appear after the last page; the chosen reply is shown before closing.
extends Control

const PORTRAIT_SIZE := 112.0   # portraits are 256px SVGs (tools/gen_portraits.py)

const _STYLES: Dictionary = {
	"dialogue":  {"bg": Color(0.07, 0.10, 0.07, 0.96), "border": Color(0.25, 0.55, 0.30), "text": Color(0.92, 0.95, 0.90), "name": Color(0.72, 1.0, 0.76)},
	"letter":    {"bg": Color(0.93, 0.89, 0.78, 0.98), "border": Color(0.55, 0.42, 0.25), "text": Color(0.20, 0.15, 0.10), "name": Color(0.38, 0.26, 0.12)},
	"newspaper": {"bg": Color(0.95, 0.95, 0.92, 0.98), "border": Color(0.15, 0.15, 0.15), "text": Color(0.10, 0.10, 0.10), "name": Color(0.10, 0.10, 0.10)},
	"card":      {"bg": Color(0.0, 0.0, 0.0, 1.0),     "border": Color(0.0, 0.0, 0.0),    "text": Color(0.85, 0.85, 0.82), "name": Color(0.85, 0.85, 0.82)},
}

var _beat_id: String = ""
var _lines: Array = []
var _choices: Array = []
var _line_idx: int = 0
var _style: String = "dialogue"
var _finished: bool = false
var _in_reply: bool = false

var _dimmer: ColorRect = null
var _panel: PanelContainer = null
var _panel_sb: StyleBoxFlat = null
var _char_row: HBoxContainer = null
var _portrait_placeholder: ColorRect = null
var _portrait_tex: TextureRect = null
var _char_name: Label = null
var _title: Label = null
var _dialogue_text: RichTextLabel = null
var _page_lbl: Label = null
var _btn_row: HBoxContainer = null
var _choice_row: HBoxContainer = null
var _next_btn: Button = null
var _name_row: HBoxContainer = null
var _name_edit: LineEdit = null
var _look_row: HBoxContainer = null
var _look_btns: Dictionary = {}   # look id → Button
var _input_kind: String = ""
var _skip_btn: Button = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_dimmer = ColorRect.new()
	_dimmer.color = Color(0.0, 0.0, 0.0, 0.4)
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dimmer)

	_panel = PanelContainer.new()
	_panel_sb = StyleBoxFlat.new()
	_panel_sb.set_corner_radius_all(10)
	_panel_sb.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", _panel_sb)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   20)
	margin.add_theme_constant_override("margin_right",  20)
	margin.add_theme_constant_override("margin_top",    14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# ── Character row ──────────────────────────────────────────────────────
	_char_row = HBoxContainer.new()
	_char_row.add_theme_constant_override("separation", 14)
	vbox.add_child(_char_row)

	_portrait_placeholder = ColorRect.new()
	_portrait_placeholder.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_char_row.add_child(_portrait_placeholder)

	_portrait_tex = TextureRect.new()
	_portrait_tex.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_tex.visible = false
	_char_row.add_child(_portrait_tex)

	var name_col := VBoxContainer.new()
	name_col.alignment = BoxContainer.ALIGNMENT_CENTER
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # lets long headlines wrap at panel width
	_char_row.add_child(name_col)

	_char_name = Label.new()
	_char_name.add_theme_font_size_override("font_size", 18)
	name_col.add_child(_char_name)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 13)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_col.add_child(_title)

	# ── Body ───────────────────────────────────────────────────────────────
	_dialogue_text = RichTextLabel.new()
	_dialogue_text.bbcode_enabled = true
	_dialogue_text.fit_content = true
	_dialogue_text.scroll_active = false
	_dialogue_text.custom_minimum_size = Vector2(0, 56)
	_dialogue_text.add_theme_font_size_override("normal_font_size", 17)
	_dialogue_text.add_theme_font_size_override("italics_font_size", 17)
	_dialogue_text.add_theme_font_size_override("bold_font_size", 17)
	vbox.add_child(_dialogue_text)

	# ── Choices (hidden unless the beat has them) ──────────────────────────
	_choice_row = HBoxContainer.new()
	_choice_row.add_theme_constant_override("separation", 10)
	_choice_row.alignment = BoxContainer.ALIGNMENT_END
	_choice_row.visible = false
	vbox.add_child(_choice_row)

	# ── Look picker + name entry (beats with input: "name") ────────────────
	_look_row = HBoxContainer.new()
	_look_row.add_theme_constant_override("separation", 10)
	_look_row.visible = false
	vbox.add_child(_look_row)
	var look_lbl := Label.new()
	look_lbl.text = "That's you:"
	_look_row.add_child(look_lbl)
	var look_group := ButtonGroup.new()
	for look in StoryManager.PLAYER_LOOKS:
		var b := Button.new()
		b.name = "Look_" + look
		b.toggle_mode = true
		b.button_group = look_group
		b.icon = load(StoryManager.PLAYER_LOOKS[look]) as Texture2D
		b.expand_icon = true
		b.custom_minimum_size = Vector2(76, 76)
		b.tooltip_text = "Pick this look"
		b.pressed.connect(_on_look_picked.bind(look))
		_look_row.add_child(b)
		_look_btns[look] = b

	_name_row = HBoxContainer.new()
	_name_row.add_theme_constant_override("separation", 10)
	_name_row.visible = false
	vbox.add_child(_name_row)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = StoryManager.DEFAULT_PLAYER_NAME
	_name_edit.max_length = StoryManager.MAX_NAME_LENGTH
	_name_edit.custom_minimum_size = Vector2(0, 44)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(func(_t: String) -> void: _confirm_name())
	_name_row.add_child(_name_edit)
	var ok_btn := Button.new()
	ok_btn.text = "That's me"
	ok_btn.custom_minimum_size = Vector2(110, 44)
	ok_btn.pressed.connect(_confirm_name)
	_name_row.add_child(ok_btn)

	# ── Button row ─────────────────────────────────────────────────────────
	_btn_row = HBoxContainer.new()
	_btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(_btn_row)

	_page_lbl = Label.new()
	_page_lbl.add_theme_font_size_override("font_size", 12)
	_page_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_btn_row.add_child(_page_lbl)

	_skip_btn = Button.new()
	_skip_btn.text = "Skip"
	_skip_btn.custom_minimum_size = Vector2(80, 44)
	_skip_btn.pressed.connect(_skip)
	_btn_row.add_child(_skip_btn)

	_next_btn = Button.new()
	_next_btn.text = "Next  >"
	_next_btn.custom_minimum_size = Vector2(104, 44)
	_next_btn.pressed.connect(_on_next)
	_btn_row.add_child(_next_btn)

# ── Screen lifecycle ──────────────────────────────────────────────────────────

func on_screen_entered(params: Dictionary = {}) -> void:
	_beat_id = params.get("beat_id", "") as String
	_finished = false
	_in_reply = false
	if _beat_id.is_empty() or not StoryManager.BEATS.has(_beat_id):
		_finish()
		return

	var beat: Dictionary = StoryManager.BEATS[_beat_id] as Dictionary
	_lines = beat.get("lines", []) as Array
	_choices = beat.get("choices", []) as Array
	_input_kind = beat.get("input", "") as String
	_name_row.visible = false
	_look_row.visible = false
	_line_idx = 0
	_style = beat.get("style", "dialogue") as String
	if not _STYLES.has(_style):
		_style = "dialogue"

	var char_id: String = beat.get("character", "narrator") as String
	var char_data: Dictionary = StoryManager.CHARACTERS.get(char_id, {}) as Dictionary
	_char_name.text = char_data.get("name", "") as String
	_title.text = StoryManager.format_text(beat.get("title", "") as String)
	_apply_style(char_id, StoryManager.get_portrait(char_id))
	if _style == "card":
		GameAudio.set_ambient_only(true)  # STORY.md: final card — ambient wind/nature only, no music
	_show_line()
	_next_btn.grab_focus.call_deferred()

## Called by UIManager on pop, or when a state change clears the stack mid-beat.
func on_screen_exited() -> void:
	if _style == "card":
		GameAudio.set_ambient_only(false)
	var id := _beat_id
	_beat_id = ""
	if id != "":
		StoryManager.on_dialogue_closed(id, _finished)

# ── Layout / style ────────────────────────────────────────────────────────────

func _apply_style(char_id: String, portrait_path: String) -> void:
	var st: Dictionary = _STYLES[_style] as Dictionary
	_panel_sb.bg_color = st["bg"] as Color
	_panel_sb.border_color = st["border"] as Color
	_dialogue_text.add_theme_color_override("default_color", st["text"] as Color)
	_char_name.add_theme_color_override("font_color", st["name"] as Color)
	_title.add_theme_color_override("font_color", (st["text"] as Color).darkened(0.1) if _style != "dialogue" else Color(0.62, 0.78, 0.62))
	_page_lbl.add_theme_color_override("font_color", (st["text"] as Color) * Color(1, 1, 1, 0.55))

	var is_card := _style == "card"
	_dimmer.color = Color(0, 0, 0, 1.0) if is_card else Color(0, 0, 0, 0.4)
	_skip_btn.visible = not is_card

	# Portrait only for spoken dialogue; documents show letterhead instead.
	var show_portrait := _style == "dialogue" and char_id != "narrator"
	_portrait_placeholder.visible = false
	_portrait_tex.visible = false
	if show_portrait:
		var tex: Texture2D = null
		if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
			tex = load(portrait_path) as Texture2D
		if tex:
			_portrait_tex.texture = tex
			_portrait_tex.visible = true
		else:
			_portrait_placeholder.visible = true
			_portrait_placeholder.color = _char_color(char_id)
	_char_row.visible = not is_card

	if _style == "newspaper":
		_char_name.add_theme_font_size_override("font_size", 13)
		_title.add_theme_font_size_override("font_size", 22)
	else:
		_char_name.add_theme_font_size_override("font_size", 18)
		_title.add_theme_font_size_override("font_size", 13)

	# Panel placement: bottom bar for dialogue, centered sheet for documents.
	# Height always fits the content (panel grows from a zero-height anchor).
	if _style == "dialogue":
		_set_panel_rect(1.0, 400.0, -20.0)
	elif is_card:
		_set_panel_rect(0.5, 320.0, 0.0)
	else:
		_set_panel_rect(0.5, 330.0, 0.0)

func _set_panel_rect(anchor_y: float, half_width: float, y_offset: float) -> void:
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = anchor_y
	_panel.anchor_bottom = anchor_y
	# Keep a 16px gutter on narrow (phone) screens.
	var half_w: float = minf(half_width, get_viewport_rect().size.x * 0.5 - 16.0)
	_panel.offset_left = -half_w
	_panel.offset_right = half_w
	_panel.offset_top = y_offset
	_panel.offset_bottom = y_offset
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# Bottom-anchored bar grows upward; centered sheets grow both ways.
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN if anchor_y >= 1.0 else Control.GROW_DIRECTION_BOTH
	# Width is fixed via min size so wrapped text can't collapse it; height
	# comes from content (offsets give zero height → min size takes over).
	_panel.custom_minimum_size = Vector2(half_w * 2.0, 0.0)

# ── Navigation ────────────────────────────────────────────────────────────────

func _show_line() -> void:
	if _line_idx >= _lines.size():
		_complete()
		return
	var text: String = StoryManager.format_text(_lines[_line_idx] as String)
	if _style == "card":
		text = "[center]%s[/center]" % text
	_dialogue_text.text = text
	var last := _line_idx >= _lines.size() - 1
	_page_lbl.text = "%d / %d" % [_line_idx + 1, _lines.size()] if _lines.size() > 1 else ""
	if last and _input_kind == "name":
		_choice_row.visible = false
		_name_row.visible = true
		_look_row.visible = true
		(_look_btns.get(StoryManager.player_look, _look_btns.values()[0]) as Button).button_pressed = true
		_next_btn.visible = false
		_skip_btn.visible = false
		_name_edit.text = ""
		_name_edit.grab_focus.call_deferred()
	elif last and not _choices.is_empty():
		_show_choices()
	else:
		_choice_row.visible = false
		_next_btn.visible = true
		_next_btn.text = ("Close" if _style == "card" else "Finish") if last else "Next  >"

func _show_choices() -> void:
	for c in _choice_row.get_children():
		c.queue_free()
	for choice in _choices:
		var cd: Dictionary = choice as Dictionary
		var b := Button.new()
		b.text = cd.get("label", "...") as String
		b.custom_minimum_size = Vector2(120, 44)
		b.pressed.connect(_on_choice.bind(cd))
		_choice_row.add_child(b)
	_choice_row.visible = true
	_next_btn.visible = false
	_skip_btn.visible = false

func _on_choice(choice: Dictionary) -> void:
	StoryManager.record_choice(_beat_id, choice.get("label", "") as String)
	_choice_row.visible = false
	_in_reply = true
	_char_name.text = "You"
	_dialogue_text.text = "[i]%s[/i]" % (choice.get("reply", "") as String)
	_page_lbl.text = ""
	_next_btn.text = "Finish"
	_next_btn.visible = true
	_next_btn.grab_focus.call_deferred()

func _on_look_picked(look: String) -> void:
	StoryManager.set_player_look(look)
	_portrait_tex.texture = load(StoryManager.get_portrait("player")) as Texture2D
	_name_edit.grab_focus.call_deferred()

func _confirm_name() -> void:
	StoryManager.set_player_name(_name_edit.text)
	_name_row.visible = false
	_look_row.visible = false
	_complete()

func _on_next() -> void:
	if _in_reply:
		_complete()
		return
	_line_idx += 1
	_show_line()

func _skip() -> void:
	# Skipping a choice beat still records a default so the story state is complete.
	if not _choices.is_empty() and StoryManager.get_choice(_beat_id) == "":
		StoryManager.record_choice(_beat_id, (_choices[0] as Dictionary).get("label", "") as String)
	_complete()

func _complete() -> void:
	_finished = true
	_finish()

func _finish() -> void:
	EventBus.screen_pop_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	# Hidden overlays stay in the tree (UIManager caches screens) — only react while shown.
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _name_row.visible:
			_confirm_name()  # ESC on the name prompt keeps the default name
		elif _style != "card":
			_skip()
	elif event.is_action_pressed("ui_accept") and _next_btn.visible and not _next_btn.has_focus():
		get_viewport().set_input_as_handled()
		_on_next()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _char_color(char_id: String) -> Color:
	match char_id:
		"uncle_ray":     return Color(0.16, 0.28, 0.20)
		"diana_cross":   return Color(0.28, 0.10, 0.12)
		"marcus_bell":   return Color(0.10, 0.16, 0.32)
		"jess_nakamura": return Color(0.28, 0.22, 0.08)
		"dani_walsh":    return Color(0.22, 0.10, 0.28)
		"player":        return Color(0.20, 0.30, 0.24)
		_:               return Color(0.14, 0.16, 0.14)
