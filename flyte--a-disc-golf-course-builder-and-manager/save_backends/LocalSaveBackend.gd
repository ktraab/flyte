## Saves to user://save_data.json with a rolling backup.
class_name LocalSaveBackend
extends SaveBackend

const SAVE_PATH   := "user://save_data.json"
const BACKUP_PATH := "user://save_data_backup.json"

func save(data: Dictionary) -> void:
	# Rotate backup before overwrite
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("LocalSaveBackend: cannot open %s for writing" % SAVE_PATH)
		save_completed.emit(false)
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	save_completed.emit(true)

func load_data() -> void:
	var path := SAVE_PATH if FileAccess.file_exists(SAVE_PATH) else BACKUP_PATH
	if not FileAccess.file_exists(path):
		load_completed.emit(false, {})
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_completed.emit(false, {})
		return

	var raw := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(raw) != OK:
		push_error("LocalSaveBackend: JSON parse failed — save may be corrupt")
		load_completed.emit(false, {})
		return

	load_completed.emit(true, json.get_data())

func is_available() -> bool:
	return true
