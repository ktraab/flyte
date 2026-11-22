## Top-level save data container. Serialised/deserialised by SaveSystem.
class_name SaveData
extends Resource

@export var save_version: String = "1.0.0"
@export var timestamp: int = 0
@export var courses: Array[CourseData] = []
@export var player: PlayerData = null
@export var economy_data: Dictionary = {}
@export var settings: Dictionary = {}

func serialize() -> Dictionary:
	var course_array := []
	for c in courses:
		course_array.append(c.serialize())
	return {
		"save_version": save_version,
		"timestamp":    timestamp,
		"courses":      course_array,
		"player":       player.serialize() if player else {},
		"economy_data": economy_data,
		"settings":     settings,
	}

static func deserialize(d: Dictionary) -> SaveData:
	var s := SaveData.new()
	s.save_version  = d.get("save_version", "1.0.0")
	s.timestamp     = d.get("timestamp", 0)
	s.economy_data  = d.get("economy_data", {})
	s.settings      = d.get("settings", {})
	for cd in d.get("courses", []):
		s.courses.append(CourseData.deserialize(cd))
	var pd = d.get("player", {})
	if not pd.is_empty():
		s.player = PlayerData.deserialize(pd)
	return s
