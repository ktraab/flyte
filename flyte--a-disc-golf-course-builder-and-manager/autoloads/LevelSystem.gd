## Player leveling and XP progression system.
## XP sources: tile placement, NPC rounds played, course purchases, goals completed.
## Level-up fires EventBus.player_level_up and shows a toast notification.
extends Node

# ── Level thresholds (cumulative XP required to reach this level) ─────────────
const LEVEL_THRESHOLDS: Array = [
	0,     # L1
	100,   # L2
	300,   # L3
	700,   # L4
	1400,  # L5
	2500,  # L6
	4000,  # L7
	6000,  # L8
	8500,  # L9
	11500, # L10 (max)
]

const LEVEL_TITLES: Array = [
	"Rookie",
	"Disc Golfer",
	"Course Designer",
	"Park Manager",
	"Tournament Host",
	"Regional Operator",
	"World Circuit Scout",
	"Master Builder",
	"Legend",
	"Hall of Fame",
]

# ── XP values ─────────────────────────────────────────────────────────────────
const XP_TILE_PLACED      := 1     # per new tile placed in builder
const XP_ROUND_PER_HOLE   := 8     # per hole played by an NPC
const XP_VIP_BONUS        := 15    # bonus when VIP completes a round
const XP_COURSE_PURCHASE  := 150   # buying a new course on world map
const XP_GOAL_COMPLETE    := 75    # completing a goal

# ── State ──────────────────────────────────────────────────────────────────────
var _xp:    int = 0
var _level: int = 1

# ── Public API ─────────────────────────────────────────────────────────────────

func get_xp() -> int:
	return _xp

func get_level() -> int:
	return _level

func get_xp_for_next_level() -> int:
	if _level >= LEVEL_THRESHOLDS.size():
		return 0
	return (LEVEL_THRESHOLDS[_level] as int) - _xp

func get_level_title() -> String:
	return LEVEL_TITLES[clampi(_level - 1, 0, LEVEL_TITLES.size() - 1)] as String

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	_xp += amount
	_check_level_up()

func serialize() -> Dictionary:
	return { "xp": _xp, "level": _level }

func deserialize(data: Dictionary) -> void:
	_xp    = data.get("xp", 0) as int
	_level = data.get("level", 1) as int

# ── Internal ───────────────────────────────────────────────────────────────────

func _ready() -> void:
	EventBus.tile_placed.connect(_on_tile_placed)
	EventBus.round_completed.connect(_on_round_completed)
	EventBus.course_purchased.connect(_on_course_purchased)
	EventBus.goal_completed.connect(_on_goal_completed)

func _check_level_up() -> void:
	var max_level := LEVEL_THRESHOLDS.size()
	while _level < max_level:
		var threshold: int = LEVEL_THRESHOLDS[_level] as int
		if _xp >= threshold:
			_level += 1
			var title := get_level_title()
			EventBus.player_level_up.emit(_level, title)
			EventBus.notification_requested.emit(
				"Level Up! You are now Level %d — %s" % [_level, title], "info")
		else:
			break

func _on_tile_placed(_tile_type: int) -> void:
	add_xp(XP_TILE_PLACED)

func _on_round_completed(_npc_id: String, is_vip: bool, _earn: float, holes_played: int) -> void:
	var xp := holes_played * XP_ROUND_PER_HOLE
	if is_vip:
		xp += XP_VIP_BONUS
	add_xp(xp)

func _on_course_purchased(_course_id: String) -> void:
	add_xp(XP_COURSE_PURCHASE)

func _on_goal_completed(_goal_id: String, _text: String, _reward: float) -> void:
	add_xp(XP_GOAL_COMPLETE)
