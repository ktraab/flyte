## Global UI audio. Auto-connects click/switch sounds to every Button in the scene.
## No per-scene setup needed — just add to autoloads.
extends Node

const _CLICK_PATH  := "res://assets/audio/ui/kenney_ui-audio/Audio/click1.ogg"
const _SWITCH_PATH := "res://assets/audio/ui/kenney_ui-audio/Audio/switch1.ogg"

var _click_stream:  AudioStream
var _switch_stream: AudioStream

var _click_player:  AudioStreamPlayer
var _switch_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep sounds/music alive while paused
	_click_stream  = load(_CLICK_PATH)  as AudioStream
	_switch_stream = load(_SWITCH_PATH) as AudioStream

	_click_player  = _make_player(_click_stream,  -4.0)
	_switch_player = _make_player(_switch_stream, -6.0)

	get_tree().node_added.connect(_on_node_added)
	_scan_existing(get_tree().root)

func _make_player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream    = stream
	p.volume_db = volume_db
	p.bus       = "Master"
	add_child(p)
	return p

func _scan_existing(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_scan_existing(child)

func _on_node_added(node: Node) -> void:
	if node is Button:
		var btn := node as Button
		if not btn.pressed.is_connected(_on_btn_pressed.bind(btn)):
			btn.pressed.connect(_on_btn_pressed.bind(btn))

func _on_btn_pressed(btn: Button) -> void:
	if btn.toggle_mode:
		_switch_player.play()
	else:
		_click_player.play()
