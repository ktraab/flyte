## Tracks course-building objectives. Autoload singleton.
extends Node

signal goal_completed(goal_id: String, text: String, reward: float)
signal goals_updated()

const GOALS: Array = [
	{"id": "first_hole",    "text": "Build your first complete hole",       "reward": 1000.0,  "type": "holes",      "target": 1},
	{"id": "six_holes",     "text": "Build 6 complete holes",               "reward": 3000.0,  "type": "holes",      "target": 6},
	{"id": "nine_holes",    "text": "Build a full 9-hole course",           "reward": 5000.0,  "type": "holes",      "target": 9},
	{"id": "full_course",   "text": "Build an 18-hole championship course", "reward": 15000.0, "type": "holes",      "target": 18},
	{"id": "ten_players",   "text": "Welcome 10 disc golfers",              "reward": 1500.0,  "type": "players",    "target": 10},
	{"id": "fifty_players", "text": "Welcome 50 disc golfers",              "reward": 5000.0,  "type": "players",    "target": 50},
	{"id": "first_staff",   "text": "Hire your first staff member",         "reward": 500.0,   "type": "staff",      "target": 1},
	{"id": "three_star",    "text": "Achieve a 3-star course rating",       "reward": 3000.0,  "type": "rating",     "target": 3.0},
	{"id": "five_star",     "text": "Achieve a 5-star course rating",       "reward": 12000.0, "type": "rating",     "target": 4.8},
	{"id": "vip_visit",     "text": "Host a VIP touring pro",               "reward": 2000.0,  "type": "vip",        "target": 1},
	{"id": "first_tourney", "text": "Run your first tournament",            "reward": 5000.0,  "type": "tournament", "target": 1},
	{"id": "balance_100k",  "text": "Accumulate $100,000 balance",          "reward": 5000.0,  "type": "balance",    "target": 100000.0},
]

var _completed: Dictionary = {}      # goal_id → true
var _player_total: int     = 0
var _vip_total:    int     = 0
var _tournament_total: int = 0
var _staff_total:  int     = 0
var _current_rating: float = 0.0

func _ready() -> void:
	EventBus.npc_arrived.connect(_on_npc_arrived)
	EventBus.vip_arrived.connect(_on_vip_arrived)
	EventBus.tournament_completed.connect(_on_tournament_completed)
	EventBus.staff_hired.connect(_on_staff_hired)

func _on_npc_arrived(_id: String) -> void:
	_player_total += 1
	_check_all()

func _on_vip_arrived(_id: String) -> void:
	_vip_total += 1
	_check_all()

func _on_tournament_completed(_prize: float) -> void:
	_tournament_total += 1
	_check_all()

func _on_staff_hired(_type: int) -> void:
	_staff_total += 1
	_check_all()

func notify_rating(rating: float) -> void:
	_current_rating = rating
	_check_all()

func notify_hole_count(count: int) -> void:
	_check_goals_of_type("holes", float(count))

func notify_balance(bal: float) -> void:
	_check_goals_of_type("balance", bal)

func get_current_value(type: String) -> float:
	match type:
		"players":    return float(_player_total)
		"vip":        return float(_vip_total)
		"tournament": return float(_tournament_total)
		"staff":      return float(_staff_total)
		"rating":     return _current_rating
		"balance":    return EconomyManager.balance
		"holes":
			if GameManager.world:
				return float((GameManager.world as GameWorld3D).get_holes_info().size())
	return 0.0

func is_goal_complete(goal_id: String) -> bool:
	return _completed.get(goal_id, false)

func get_active_goal() -> Dictionary:
	for g in GOALS:
		var gd: Dictionary = g as Dictionary
		if not _completed.get(gd["id"], false):
			return gd
	return {}

func get_all_goals() -> Array:
	var out: Array = []
	for g in GOALS:
		var gd: Dictionary = g as Dictionary
		var entry: Dictionary = gd.duplicate()
		entry["done"] = _completed.get(gd["id"], false)
		out.append(entry)
	return out

func serialize() -> Dictionary:
	return {"completed": _completed.duplicate(), "players": _player_total,
			"vips": _vip_total, "tournaments": _tournament_total, "staff": _staff_total}

func deserialize(data: Dictionary) -> void:
	_completed        = data.get("completed", {})
	_player_total     = data.get("players", 0)
	_vip_total        = data.get("vips", 0)
	_tournament_total = data.get("tournaments", 0)
	_staff_total      = data.get("staff", 0)

func _check_all() -> void:
	_check_goals_of_type("players",    float(_player_total))
	_check_goals_of_type("vip",        float(_vip_total))
	_check_goals_of_type("tournament", float(_tournament_total))
	_check_goals_of_type("staff",      float(_staff_total))
	_check_goals_of_type("rating",     _current_rating)
	if GameManager.world:
		var bal := EconomyManager.balance
		_check_goals_of_type("balance", bal)

func _check_goals_of_type(type: String, value: float) -> void:
	for g in GOALS:
		var gid: String = g["id"] as String
		if _completed.get(gid, false):
			continue
		if (g["type"] as String) != type:
			continue
		if value >= (g["target"] as float):
			_completed[gid] = true
			var reward: float = g["reward"] as float
			EconomyManager.earn(reward, "goal_reward")
			EventBus.goal_completed.emit(gid, g["text"] as String, reward)
			EventBus.notification_requested.emit("Goal complete: %s (+$%s)" % [g["text"], _fmt(reward)], "info")
			goals_updated.emit()
			_unlock_steam_achievement(gid)

## Unlock a Steam achievement by goal ID.
## Achievement API names in Steamworks dashboard must match these goal IDs:
##   first_hole, six_holes, nine_holes, full_course,
##   ten_players, fifty_players, first_staff,
##   three_star, five_star, vip_visit, first_tourney, balance_100k
func _unlock_steam_achievement(goal_id: String) -> void:
	if not GameManager.is_steam_active():
		return
	if not Engine.has_singleton("Steam"):
		return
	var steam = Engine.get_singleton("Steam")
	steam.setAchievement(goal_id)
	steam.storeStats()

func _fmt(v: float) -> String:
	if v >= 1000.0: return "%.0fK" % (v / 1000.0)
	return "%.0f" % v
