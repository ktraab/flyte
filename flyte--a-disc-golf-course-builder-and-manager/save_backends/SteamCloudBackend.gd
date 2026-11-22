## Wraps GodotSteam remote storage API.
## Requires the GodotSteam addon and a valid Steam App ID.
## https://godotsteam.com/
class_name SteamCloudBackend
extends SaveBackend

const CLOUD_FILENAME := "flyte_save.json"

func save(data: Dictionary) -> void:
	if not is_available():
		save_completed.emit(false)
		return

	var steam = Engine.get_singleton("Steam")
	var bytes: PackedByteArray = JSON.stringify(data).to_utf8_buffer()
	var ok: bool = steam.fileWrite(CLOUD_FILENAME, bytes)
	save_completed.emit(ok)

func load_data() -> void:
	if not is_available():
		load_completed.emit(false, {})
		return

	var steam = Engine.get_singleton("Steam")
	if not steam.fileExists(CLOUD_FILENAME):
		load_completed.emit(false, {})
		return

	var size: int = steam.getFileSize(CLOUD_FILENAME)
	var buffer: PackedByteArray = steam.fileRead(CLOUD_FILENAME, size)
	var raw := buffer.get_string_from_utf8()

	var json := JSON.new()
	if json.parse(raw) != OK:
		push_error("SteamCloudBackend: JSON parse failed")
		load_completed.emit(false, {})
		return

	load_completed.emit(true, json.get_data())

func is_available() -> bool:
	if not Engine.has_singleton("Steam"):
		return false
	var steam = Engine.get_singleton("Steam")
	# isCloudEnabledForApp() returns false when the user has disabled Steam Cloud
	return steam.isCloudEnabledForApp() and steam.isCloudEnabledForAccount()
