## Human player profile — persisted in save data.
class_name PlayerData
extends Resource

@export var player_id: String = ""
@export var display_name: String = "Player"
@export var total_rounds: int = 0
@export var career_earnings: float = 0.0
## course_id → all-time best score (int)
@export var best_scores: Dictionary = {}
@export var achievements: Array[String] = []
@export var settings: Dictionary = {}

func serialize() -> Dictionary:
	return {
		"player_id":       player_id,
		"display_name":    display_name,
		"total_rounds":    total_rounds,
		"career_earnings": career_earnings,
		"best_scores":     best_scores,
		"achievements":    achievements,
		"settings":        settings,
	}

static func deserialize(d: Dictionary) -> PlayerData:
	var p := PlayerData.new()
	p.player_id       = d.get("player_id", "")
	p.display_name    = d.get("display_name", "Player")
	p.total_rounds    = d.get("total_rounds", 0)
	p.career_earnings = d.get("career_earnings", 0.0)
	p.best_scores     = d.get("best_scores", {})
	p.achievements    = d.get("achievements", [])
	p.settings        = d.get("settings", {})
	return p
