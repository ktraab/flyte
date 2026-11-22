## Detects current platform once at startup.
## All other systems read from here rather than calling OS.get_name() themselves.
extends Node

enum Platform {
	DESKTOP_STEAM,
	DESKTOP_STANDALONE,
	MOBILE_IOS,
	MOBILE_ANDROID,
	WEB,
}

var current_platform: Platform
var is_mobile: bool = false
var is_steam: bool = false
var is_web: bool = false
var has_network: bool = true

func _ready() -> void:
	_detect()
	_start_network_polling()

func _detect() -> void:
	var os_name := OS.get_name()

	# GodotSteam registers a "Steam" singleton when active
	if Engine.has_singleton("Steam"):
		current_platform = Platform.DESKTOP_STEAM
		is_steam = true
	elif os_name == "iOS":
		current_platform = Platform.MOBILE_IOS
		is_mobile = true
	elif os_name == "Android":
		current_platform = Platform.MOBILE_ANDROID
		is_mobile = true
	elif os_name == "Web":
		current_platform = Platform.WEB
		is_web = true
	else:
		current_platform = Platform.DESKTOP_STANDALONE

func get_save_dir() -> String:
	# user:// resolves correctly on all platforms; keep it simple
	return "user://"

func get_platform_label() -> String:
	return Platform.keys()[current_platform]

# ── Network polling ──────────────────────────────────────────────────────────

func _start_network_polling() -> void:
	# Check every 10 s; fire EventBus signal on change
	var timer := Timer.new()
	timer.wait_time = 10.0
	timer.autostart = true
	timer.timeout.connect(_check_network)
	add_child(timer)
	_check_network()

func _check_network() -> void:
	# HTTPClient.STATUS_CANT_CONNECT is a decent offline proxy without a real ping
	var was_online := has_network
	# Godot 4 provides no built-in ping; use OS feature check as approximation
	has_network = OS.get_name() != "Unknown"
	# TODO: replace with real HTTP HEAD request to a lightweight health endpoint
	if was_online != has_network:
		EventBus.network_status_changed.emit(has_network)
		if has_network:
			EventBus.sync_requested.emit()
