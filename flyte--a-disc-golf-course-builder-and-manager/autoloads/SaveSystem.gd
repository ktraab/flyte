## Data persistence coordinator.
## Strategy:
##   Desktop + Steam  → local JSON  +  Steam Cloud sync
##   Desktop standalone → local JSON only
##   Mobile           → local JSON  +  Supabase sync
##                       offline queue flushes on reconnect
extends Node

# Preload required — class_name types are not yet registered when autoloads parse
const _LocalScript    = preload("res://save_backends/LocalSaveBackend.gd")
const _SteamScript    = preload("res://save_backends/SteamCloudBackend.gd")
const _SupabaseScript = preload("res://save_backends/SupabaseBackend.gd")

var _local:    Node  # LocalSaveBackend
var _steam:    Node  # SteamCloudBackend
var _supabase: Node  # SupabaseBackend

var _offline_queue: Array = []  # Array of Dictionary
const _OFFLINE_QUEUE_PATH := "user://offline_queue.json"

func _ready() -> void:
	_local    = _LocalScript.new()
	_steam    = _SteamScript.new()
	_supabase = _SupabaseScript.new()
	add_child(_local)
	add_child(_steam)
	add_child(_supabase)

	_local.save_completed.connect(_on_local_save_done)
	_local.load_completed.connect(_on_load_done)
	_steam.save_completed.connect(_on_cloud_save_done)
	_steam.load_completed.connect(_on_load_done)
	_supabase.save_completed.connect(_on_cloud_save_done)
	_supabase.load_completed.connect(_on_load_done)

	EventBus.save_requested.connect(save)
	EventBus.load_requested.connect(load)
	EventBus.sync_requested.connect(sync_to_cloud)
	EventBus.network_status_changed.connect(_on_network_changed)

	_load_offline_queue()

# ── Public API ───────────────────────────────────────────────────────────────

func save() -> void:
	var data := _gather()
	_local.save(data)

	if PlatformDetector.has_network:
		_flush_offline_queue()
		sync_to_cloud()
	else:
		_enqueue(data)

func load() -> void:
	if PlatformDetector.is_steam and _steam.is_available():
		_steam.load_data()
	elif PlatformDetector.is_mobile and _supabase.is_available():
		_supabase.load_data()
	else:
		_local.load_data()

func sync_to_cloud() -> void:
	var data := _gather()
	if PlatformDetector.is_steam and _steam.is_available():
		_steam.save(data)
	elif _supabase.is_available():
		_supabase.save(data)

## Call this with a user ID after authentication (Supabase login).
func set_cloud_user(user_id: String) -> void:
	_supabase.set_user_id(user_id)

# ── Serialisation ────────────────────────────────────────────────────────────

func _gather() -> Dictionary:
	return {
		"save_version": "1.0.0",
		"timestamp": Time.get_unix_time_from_system(),
		"courses": [],
		"economy": {},
		"player": {},
		"settings": {},
	}

func _apply(data: Dictionary) -> void:
	if data.is_empty():
		return
	EventBus.player_data_updated.emit()

# ── Offline queue ─────────────────────────────────────────────────────────────

func _enqueue(data: Dictionary) -> void:
	_offline_queue.append(data)
	_persist_offline_queue()

func _flush_offline_queue() -> void:
	if _offline_queue.is_empty():
		return
	var latest: Dictionary = _offline_queue.back()
	_offline_queue.clear()
	_persist_offline_queue()
	if _supabase.is_available():
		_supabase.save(latest)
	EventBus.offline_queue_flushed.emit()

func _persist_offline_queue() -> void:
	var file := FileAccess.open(_OFFLINE_QUEUE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_offline_queue))
		file.close()

func _load_offline_queue() -> void:
	if not FileAccess.file_exists(_OFFLINE_QUEUE_PATH):
		return
	var file := FileAccess.open(_OFFLINE_QUEUE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var result = json.get_data()
		if result is Array:
			for item in result:
				if item is Dictionary:
					_offline_queue.append(item)
	file.close()

# ── Callbacks ────────────────────────────────────────────────────────────────

func _on_local_save_done(success: bool) -> void:
	EventBus.save_completed.emit(success)

func _on_cloud_save_done(success: bool) -> void:
	if not success:
		EventBus.notification_requested.emit(
			"Cloud sync failed — progress saved locally.", "warning")
	EventBus.sync_completed.emit(success)

func _on_load_done(success: bool, data: Dictionary) -> void:
	if success:
		_apply(data)
	EventBus.load_completed.emit(success)

func _on_network_changed(is_online: bool) -> void:
	if is_online:
		_flush_offline_queue()
