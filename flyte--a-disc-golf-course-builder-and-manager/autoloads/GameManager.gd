## Central game coordinator. Owns state machine and holds the active simulation.
extends Node

const _MapleHillPreset          = preload("res://core/data/MapleHillPreset.gd")
const _AwayLayouts              = preload("res://core/data/AwayLayouts.gd")
const _WinthropGoldPreset       = preload("res://core/data/WinthropGoldPreset.gd")
const _IdlewildPreset           = preload("res://core/data/IdlewildPreset.gd")
const _DiscSideOfHeavenPreset   = preload("res://core/data/DiscSideOfHeavenPreset.gd")
const _KrokholPreset            = preload("res://core/data/KrokholPreset.gd")
const _AleWhitePreset           = preload("res://core/data/AleWhitePreset.gd")

enum GameState {
	LOADING,
	MAIN_MENU,
	WORLD_MAP,
	COURSE_BUILDER,
	GAMEPLAY,
	PAUSED,
}

var state: GameState = GameState.LOADING
var simulation: GameSimulation
var world: Node     # GameWorld3D — set by Main.gd after instantiation
var _previous_state: GameState = GameState.LOADING

# ── Multi-course ownership ────────────────────────────────────────────────────
var active_course_id: String       = "home"
var owned_courses: Array[String]   = ["home"]

# Per-course state (disk-persisted)
var _course_snapshots: Dictionary  = {}   # course_id → GameWorld3D state dict
var _course_economies: Dictionary  = {}   # course_id → EconomyManager.serialize() dict
var _course_bg_start: Dictionary   = {}   # course_id → {time, rate} for bg income
var away_course_id: String          = ""   # circuit course being visited for an away round ("" = none)
var _away_return_snapshot: Dictionary = {} # the real active course, restored after the round
var _away_best: Dictionary          = {}   # course_id → best score vs par (persisted)
var _course_stats: Dictionary      = {}   # course_id → {holes, rating, restrooms} (recorded on leave/save)
var _certified: Dictionary         = {}   # course_id → true once WDGA certified (never revoked)

# Empire pool — accumulates from bg income of all courses; used to buy new courses
var _empire_balance: float = 0.0

const COURSE_PRICES: Dictionary = {
	"maple_ridge":         25000.0,
	"winthrop_gold":       30000.0,
	"idlewild":            35000.0,
	"disc_side_of_heaven": 40000.0,
	"krokhol":             45000.0,
	"ale_white":           50000.0,
}

const _COURSES_DIR := "user://courses/"
const _EMPIRE_KEY  := "empire_balance"

# ── Affiliate / shop tiers ────────────────────────────────────────────────────
# Tier 0 = nothing purchased. Tiers 1-3 are cumulative upgrades.
var _shop_tiers: Dictionary = {"disc_depot": 0, "bag_shack": 0, "wdga_hq": 0, "bromez": 0}

const SHOP_TIER_DATA: Dictionary = {
	"disc_depot": [
		{"label": "Basic Stock",     "cost": 2000.0,  "desc": "Pro Shop & overall income +15%"},
		{"label": "Premium Catalog", "cost": 6000.0,  "desc": "Pro Shop & overall income +35%"},
		{"label": "Exclusive Runs",  "cost": 15000.0, "desc": "Pro Shop & overall income +60%"},
	],
	"bag_shack": [
		{"label": "Standard Kit",    "cost": 3000.0,  "desc": "Player happiness +10%"},
		{"label": "Pro Package",     "cost": 8000.0,  "desc": "Player happiness +25%"},
		{"label": "Elite Fit",       "cost": 18000.0, "desc": "Player happiness +45%"},
	],
	"wdga_hq": [
		{"label": "Affiliated",      "cost": 5000.0,  "desc": "Tournament prizes +50%"},
		{"label": "Sanctioned",      "cost": 12000.0, "desc": "Tournament prizes +100%"},
		{"label": "Elite Charter",   "cost": 25000.0, "desc": "Tournament prizes +150%"},
	],
	"bromez": [
		{"label": "Pilot Deal",      "cost": 8000.0,  "desc": "$50/day passive media income"},
		{"label": "Series Contract", "cost": 20000.0, "desc": "$120/day passive media income"},
		{"label": "Flagship",        "cost": 45000.0, "desc": "$200/day media income + prestige +15"},
	],
}

func get_shop_tier(loc_id: String) -> int:
	return _shop_tiers.get(loc_id, 0) as int

func buy_shop_tier(loc_id: String, tier: int) -> bool:
	var current: int = _shop_tiers.get(loc_id, 0) as int
	if tier != current + 1:
		return false
	var tiers: Array = SHOP_TIER_DATA.get(loc_id, []) as Array
	if tier < 1 or tier > tiers.size():
		return false
	var cost: float = (tiers[tier - 1] as Dictionary)["cost"] as float
	if _empire_balance < cost:
		EventBus.notification_requested.emit(
			"Need $%.0f empire funds — current: $%.0f" % [cost, _empire_balance], "warning")
		return false
	_empire_balance -= cost
	_shop_tiers[loc_id] = tier
	_save_course_meta()
	var label: String = (tiers[tier - 1] as Dictionary)["label"] as String
	EventBus.notification_requested.emit("Purchased: %s!" % label, "info")
	return true

func get_pro_shop_income_mult() -> float:
	match _shop_tiers.get("disc_depot", 0) as int:
		1: return 1.15
		2: return 1.35
		3: return 1.60
	return 1.0

func get_happiness_mult() -> float:
	match _shop_tiers.get("bag_shack", 0) as int:
		1: return 1.10
		2: return 1.25
		3: return 1.45
	return 1.0

func get_tournament_prize_mult() -> float:
	match _shop_tiers.get("wdga_hq", 0) as int:
		1: return 1.50
		2: return 2.00
		3: return 2.50
	return 1.0

func get_media_daily_income() -> float:
	match _shop_tiers.get("bromez", 0) as int:
		1: return 50.0
		2: return 120.0
		3: return 200.0
	return 0.0

func get_empire_balance() -> float:
	return _empire_balance

## Game seconds since launch (scaled by game speed, frozen while paused). Used
## for background income so 2× speed pays 2× (real seconds under-paid it).
var _game_clock: float = 0.0

## Credits a course for the time it ran in the background, split like an active
## course: EMPIRE_SHARE to the empire pool, the rest to its own balance. (It used
## to send 100% to the pool, so leaving home paid more than staying.)
func _accrue_background(course_id: String) -> float:
	if not _course_bg_start.has(course_id):
		return 0.0
	var bg := _course_bg_start[course_id] as Dictionary
	_course_bg_start.erase(course_id)
	var accrued := (bg["rate"] as float) * maxf(0.0, _game_clock - (bg["time"] as float))
	if accrued <= 0.1:
		return 0.0
	_empire_balance += accrued * EMPIRE_SHARE
	if _course_economies.has(course_id):
		var econ := _course_economies[course_id] as Dictionary
		econ["balance"] = float(econ.get("balance", 0.0)) + accrued * (1.0 - EMPIRE_SHARE)
	EventBus.notification_requested.emit(
		"While you were away: +$%.0f (%d%% to the empire pool)" % [accrued, roundi(EMPIRE_SHARE * 100.0)], "info")
	return accrued

## Moves spare money from the active course into the empire pool (1:1).
func invest_in_empire(amount: float) -> bool:
	if amount <= 0.0 or EconomyManager.balance < amount or is_away_round():
		return false
	EconomyManager.balance -= amount
	EventBus.balance_changed.emit(EconomyManager.balance)
	_empire_balance += amount
	_save_course_meta()
	EventBus.notification_requested.emit("Invested $%.0f in your empire." % amount, "info")
	return true

func is_course_owned(course_id: String) -> bool:
	return course_id in owned_courses

func get_course_price(course_id: String) -> float:
	return COURSE_PRICES.get(course_id, 0.0) as float

func buy_course(course_id: String) -> bool:
	if is_course_owned(course_id):
		return false
	var price := get_course_price(course_id)
	if _empire_balance < price:
		EventBus.notification_requested.emit(
			"Need $%.0f empire funds to purchase — current empire balance: $%.0f." % [price, _empire_balance],
			"warning")
		return false
	_empire_balance -= price
	owned_courses.append(course_id)
	_save_course_meta()
	EventBus.course_purchased.emit(course_id)
	EventBus.notification_requested.emit("Course purchased! Switching now.", "info")
	switch_to_course(course_id)
	return true

func switch_to_course(course_id: String) -> void:
	if is_away_round():
		end_away_round([], [])
	if not is_course_owned(course_id) and course_id != "home":
		push_error("switch_to_course: course '%s' not owned" % course_id)
		return
	if active_course_id == course_id:
		change_state(GameState.GAMEPLAY)
		return

	# Snapshot current course world + economy and start bg tracking.
	if world:
		_record_course_stats(active_course_id)
		_course_snapshots[active_course_id] = _tagged_snapshot(active_course_id)
		_course_economies[active_course_id] = EconomyManager.serialize()
		_course_bg_start[active_course_id] = {
			"time": _game_clock,
			"rate": EconomyManager.get_net_income_rate()
		}
		_save_course_to_disk(active_course_id)

	active_course_id = course_id

	# Income the destination course earned while you were away
	_accrue_background(course_id)

	# Restore world + economy: the player's own build if we have a snapshot
	# that provably belongs to this course, otherwise the course's terrain preset.
	if world:
		if _has_valid_snapshot(course_id):
			(world as GameWorld3D).import_full_state(_course_snapshots[course_id])
		else:
			(world as GameWorld3D).clear_all_tiles()
			_apply_course_preset(course_id)

		if course_id in _course_economies:
			EconomyManager.deserialize(_course_economies[course_id])
		else:
			EconomyManager.deserialize({"balance": 5000.0})

	_save_course_meta()
	EventBus.course_switched.emit(course_id)
	change_state(GameState.GAMEPLAY)

func _apply_course_preset(course_id: String) -> void:
	if world == null:
		return
	var tiles := _preset_tiles(course_id)
	if not tiles.is_empty():
		(world as GameWorld3D).load_terrain_preset(tiles)
		(world as GameWorld3D).ensure_entrance()

func _preset_tiles(course_id: String) -> Dictionary:
	match course_id:
		"maple_ridge":         return _MapleHillPreset.build()
		"winthrop_gold":       return _WinthropGoldPreset.build()
		"idlewild":            return _IdlewildPreset.build()
		"disc_side_of_heaven": return _DiscSideOfHeavenPreset.build()
		"krokhol":             return _KrokholPreset.build()
		"ale_white":           return _AleWhitePreset.build()
	return {}

# ── Away rounds (STORY.md Ch4) ────────────────────────────────────────────────
# Play a front nine at a World Circuit course with the Test Course controls.
# The real active course is snapshotted and restored afterwards; while away,
# the economy is frozen and saves use the snapshot, so the visited layout can
# never leak into a save or into goals/stats.

func is_away_round() -> bool:
	return away_course_id != ""

func can_play_away_round(course_id: String) -> bool:
	return world != null and not is_away_round() and course_id != "home" \
		and not _AwayLayouts.holes_for(course_id).is_empty()

func start_away_round(course_id: String) -> bool:
	if not can_play_away_round(course_id):
		return false
	_away_return_snapshot = _tagged_snapshot(active_course_id)
	away_course_id = course_id
	var tiles := _preset_tiles(course_id)
	(world as GameWorld3D).load_away_course(tiles, _AwayLayouts.resolve(course_id, tiles))
	EventBus.away_round_started.emit(course_id)
	change_state(GameState.GAMEPLAY)
	return true

## scores: throws per hole played; pars: par per hole on the layout.
## A round counts as completed only if every hole was played.
func end_away_round(scores: Array, pars: Array) -> void:
	if not is_away_round():
		return
	var cid := away_course_id
	away_course_id = ""
	(world as GameWorld3D).import_full_state(_away_return_snapshot)
	_away_return_snapshot = {}
	(world as GameWorld3D).set_gameplay_mode(state == GameState.GAMEPLAY)
	var completed := not pars.is_empty() and scores.size() == pars.size()
	if completed:
		var strokes := 0
		var par := 0
		for v in scores: strokes += int(v)
		for v in pars: par += int(v)
		var diff := strokes - par
		if not _away_best.has(cid) or diff < int(_away_best[cid]):
			_away_best[cid] = diff
		EventBus.away_round_completed.emit(cid, strokes, par)
		EventBus.notification_requested.emit("Away round done: %d strokes (%s). Welcome home." % [
			strokes, format_score(diff)], "info")
	_save_course_meta()

## Best away-round score vs par for a course, or null if never completed.
func get_away_best(course_id: String) -> Variant:
	return _away_best.get(course_id, null)

static func format_score(diff: int) -> String:
	if diff == 0:
		return "E"
	return "%+d" % diff

# ── Disk persistence (course snapshots + economies) ───────────────────────────

## World snapshot stamped with the course it belongs to. The stamp is what
## stops one course's tiles ever loading into another (the May 2026 bug that
## led to non-home builds being discarded entirely).
func _tagged_snapshot(course_id: String) -> Dictionary:
	# Mid away round the world holds the visited course — use the real one.
	if is_away_round() and course_id == active_course_id and not _away_return_snapshot.is_empty():
		return _away_return_snapshot.duplicate()
	var snap: Dictionary = (world as GameWorld3D).export_full_state()
	snap["course_id"] = course_id
	return snap

func _has_valid_snapshot(course_id: String) -> bool:
	if not _course_snapshots.has(course_id):
		return false
	var snap: Dictionary = _course_snapshots[course_id] as Dictionary
	# Home snapshots from before tagging are trusted (home always saved itself).
	var owner: String = snap.get("course_id", "home") as String
	return owner == course_id

func _record_course_stats(course_id: String) -> void:
	if not world or is_away_round():
		return
	_course_stats[course_id] = get_course_stats(course_id)
	if course_id != "home" and not _certified.has(course_id) and _meets_certification(course_id):
		_certified[course_id] = true
		EventBus.course_certified.emit(course_id)
		EventBus.notification_requested.emit("%s is now WDGA certified!" % course_id.replace("_", " ").capitalize(), "info")

# ── WDGA certification (circuit courses) ──────────────────────────────────────
# A circuit course counts as "beaten" for the story (Ch6) once the player has
# developed it to sanctioned standard.
const CERT_MIN_HOLES     := 9
const CERT_MIN_RATING    := 3.5
const CERT_MIN_RESTROOMS := 1

func _meets_certification(course_id: String) -> bool:
	var st := get_course_stats(course_id)
	return (int(st.get("holes", 0)) >= CERT_MIN_HOLES
		and float(st.get("rating", 0.0)) >= CERT_MIN_RATING
		and int(st.get("restrooms", 0)) >= CERT_MIN_RESTROOMS)

## Once earned, certification is remembered (a rescore or later edits can't revoke it).
func is_course_certified(course_id: String) -> bool:
	return _certified.has(course_id) or _meets_certification(course_id)

func get_certified_circuit_count() -> int:
	var n := 0
	for cid in owned_courses:
		if cid != "home" and is_course_certified(cid):
			n += 1
	return n

## Number of holes/rating recorded for a course (live for the active one).
func get_course_stats(course_id: String) -> Dictionary:
	if course_id == active_course_id and world and not is_away_round():
		var w := world as GameWorld3D
		return {"holes": w.get_holes_info().size(), "rating": w.get_course_rating(),
			"restrooms": int(w.get_facility_counts().get("restroom", 0))}
	return _course_stats.get(course_id, {"holes": 0, "rating": 0.0, "restrooms": 0}) as Dictionary

func _save_course_to_disk(course_id: String) -> void:
	if not DirAccess.dir_exists_absolute(_COURSES_DIR):
		DirAccess.make_dir_recursive_absolute(_COURSES_DIR)
	var path := _COURSES_DIR + course_id + ".json"
	var data := {
		"world":   _course_snapshots.get(course_id, {}) if _has_valid_snapshot(course_id) else {},
		"economy": _course_economies.get(course_id, {}),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _load_course_from_disk(course_id: String) -> void:
	var path := _COURSES_DIR + course_id + ".json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var d = json.get_data()
		if d is Dictionary:
			if d.has("world") and (d["world"] as Dictionary).size() > 0:
				_course_snapshots[course_id] = d["world"] as Dictionary
				if not _has_valid_snapshot(course_id):
					_course_snapshots.erase(course_id)  # untagged pre-2026-11 data: use preset
			if d.has("economy") and (d["economy"] as Dictionary).size() > 0:
				_course_economies[course_id] = d["economy"] as Dictionary
	file.close()

func _save_course_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("courses", "active",         active_course_id)
	cfg.set_value("courses", "owned",          owned_courses)
	cfg.set_value("courses", "stats",          _course_stats)
	cfg.set_value("courses", "certified",      _certified)
	cfg.set_value("courses", "away_best",      _away_best)
	cfg.set_value("courses", _EMPIRE_KEY,      _empire_balance)
	for loc_id in _shop_tiers:
		cfg.set_value("shops", loc_id as String, _shop_tiers[loc_id] as int)
	# Persist goal completion so unlock conditions survive restarts
	var gs: Dictionary = GoalsSystem.serialize()
	cfg.set_value("goals", "completed",    gs.get("completed",    {}))
	cfg.set_value("goals", "players",      gs.get("players",      0))
	cfg.set_value("goals", "vips",         gs.get("vips",         0))
	cfg.set_value("goals", "tournaments",  gs.get("tournaments",  0))
	cfg.set_value("goals", "staff",        gs.get("staff",        0))
	var ls: Dictionary = LevelSystem.serialize()
	cfg.set_value("level", "xp",    ls.get("xp",    0))
	cfg.set_value("level", "level", ls.get("level", 1))
	cfg.set_value("story", "data", StoryManager.serialize())
	cfg.save("user://settings.cfg")

func _load_course_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return
	active_course_id = cfg.get_value("courses", "active", "home") as String
	var saved: Array = cfg.get_value("courses", "owned", ["home"]) as Array
	owned_courses.clear()
	for id in saved:
		owned_courses.append(id as String)
	if not "home" in owned_courses:
		owned_courses.append("home")
	_empire_balance = cfg.get_value("courses", _EMPIRE_KEY, 0.0) as float
	_course_stats = (cfg.get_value("courses", "stats", {}) as Dictionary).duplicate(true)
	_certified = (cfg.get_value("courses", "certified", {}) as Dictionary).duplicate()
	_away_best = (cfg.get_value("courses", "away_best", {}) as Dictionary).duplicate(true)
	for loc_id in _shop_tiers:
		_shop_tiers[loc_id] = cfg.get_value("shops", loc_id as String, 0) as int
	# Restore goal completion so unlock conditions persist across restarts
	var gs_data: Dictionary = {
		"completed":   cfg.get_value("goals", "completed",   {}),
		"players":     cfg.get_value("goals", "players",     0),
		"vips":        cfg.get_value("goals", "vips",        0),
		"tournaments": cfg.get_value("goals", "tournaments",  0),
		"staff":       cfg.get_value("goals", "staff",       0),
	}
	GoalsSystem.deserialize(gs_data)
	LevelSystem.deserialize({
		"xp":    cfg.get_value("level", "xp",    0) as int,
		"level": cfg.get_value("level", "level",  1) as int,
	})
	if cfg.has_section_key("story", "data"):
		StoryManager.deserialize(cfg.get_value("story", "data", {}) as Dictionary)
	elif cfg.has_section_key("story", "chapter"):
		# Early dev format (chapter + beats only)
		StoryManager.deserialize({
			"chapter": cfg.get_value("story", "chapter", 0) as int,
			"beats":   cfg.get_value("story", "beats",   {}) as Dictionary,
		})
	else:
		# Save predates the story system — StoryManager works out the chapter.
		StoryManager.mark_legacy_save()
	# Load world + economy snapshots from disk for all owned courses.
	# Only home course loads world tiles — non-home courses use presets.
	for cid in owned_courses:
		_load_course_from_disk(cid as String)
	# Erase any stale world snapshots for non-home courses (migration safety)
	for cid in _course_snapshots.keys():
		if not _has_valid_snapshot(cid as String):
			_course_snapshots.erase(cid)

# ── Graphics settings ─────────────────────────────────────────────────────────
# preset: 0=Low  1=Medium  2=High  3=Custom
var graphics_preset: int = 1
var gfx_glow:    bool = false
var gfx_shadows: int  = 1   # 0=off  1=low(1 split 80m)  2=high(2 splits 180m)
var gfx_sky:     int  = 1   # 0=procedural  1=hdri
var gfx_fps_cap: int  = 60  # 30 / 60 / 0=unlimited
var gfx_flags:   bool = true
var gfx_render_scale: float = 1.0  # 3D resolution scale (UI stays sharp) — biggest GPU lever on phones / HiDPI
var gfx_clutter: bool = true       # decorative grass tufts
var gfx_trees: int = 1             # 1 = full-detail tree models, 0 = simplified (Low)

const _GFX_PRESETS := [
	{"glow": false, "shadows": 0, "sky": 0, "fps": 30,  "flags": false, "scale": 0.75, "clutter": false, "trees": 0},  # Low
	{"glow": false, "shadows": 1, "sky": 1, "fps": 60,  "flags": true,  "scale": 1.0,  "clutter": true,  "trees": 1},  # Medium
	{"glow": true,  "shadows": 2, "sky": 1, "fps": 60,  "flags": true,  "scale": 1.0,  "clutter": true,  "trees": 1},  # High
]
const RENDER_SCALES := [1.0, 0.85, 0.75, 0.6, 0.5]

## First-launch default: Low on phones/tablets, integrated non-Apple GPUs and
## software renderers; Medium everywhere else. Used until the player picks one.
static func recommended_graphics_preset() -> int:
	var ml := Engine.get_main_loop() as SceneTree
	var pd: Node = ml.root.get_node_or_null("PlatformDetector") if ml else null
	if pd and pd.get("is_mobile"):
		return 0
	match RenderingServer.get_video_adapter_type():
		RenderingDevice.DEVICE_TYPE_CPU:
			return 0
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
			return 1 if "apple" in RenderingServer.get_video_adapter_vendor().to_lower() else 0
	return 1

func _set_preset_values(preset: int) -> void:
	var p: Dictionary = _GFX_PRESETS[preset]
	gfx_glow    = p["glow"]
	gfx_shadows = p["shadows"]
	gfx_sky     = p["sky"]
	gfx_fps_cap = p["fps"]
	gfx_flags   = p["flags"]
	gfx_render_scale = p["scale"]
	gfx_clutter = p["clutter"]
	gfx_trees   = p["trees"]

func get_graphics_settings() -> Dictionary:
	return {"glow": gfx_glow, "shadows": gfx_shadows, "sky": gfx_sky, "fps": gfx_fps_cap, "flags": gfx_flags,
		"scale": gfx_render_scale, "clutter": gfx_clutter, "trees": gfx_trees}

func apply_graphics_preset(preset: int) -> void:
	graphics_preset = preset
	_set_preset_values(preset)
	_apply_engine_settings()
	EventBus.graphics_quality_changed.emit(get_graphics_settings())
	_save_graphics_config()

func apply_custom_graphics(settings: Dictionary) -> void:
	graphics_preset = 3
	if settings.has("glow"):    gfx_glow    = settings["glow"]
	if settings.has("shadows"): gfx_shadows = settings["shadows"]
	if settings.has("sky"):     gfx_sky     = settings["sky"]
	if settings.has("fps"):     gfx_fps_cap = settings["fps"]
	if settings.has("flags"):   gfx_flags   = settings["flags"]
	if settings.has("scale"):   gfx_render_scale = clampf(float(settings["scale"]), 0.5, 1.0)
	if settings.has("clutter"): gfx_clutter = settings["clutter"]
	if settings.has("trees"):   gfx_trees   = int(settings["trees"])
	_apply_engine_settings()
	EventBus.graphics_quality_changed.emit(get_graphics_settings())
	_save_graphics_config()

# ── Auto performance guard ───────────────────────────────────────────────────
# When on (default), if play/build runs well under its frame-rate target for
# several seconds, graphics drop one step (High→Medium→Low, then 30 FPS cap and
# render scale 75→60→50 %) and a toast says what changed. It never raises
# settings. Settings → Graphics can switch it off.
var gfx_auto: bool = true
const PERF_SAMPLE_WINDOW := 8     # one FPS sample per second; the median decides
const PERF_SLOW_FRACTION := 0.7   # slow = median below 70 % of the target FPS
const PERF_SETTLE_SAMPLES := 3    # samples ignored after any change / load
var _perf_samples: Array = []
var _perf_t := 0.0
var _perf_skip := PERF_SETTLE_SAMPLES

func _process(delta: float) -> void:
	_game_clock += delta   # game time: scaled by speed, stops while paused
	if not gfx_auto or DisplayServer.get_name() == "headless":
		return
	if state != GameState.GAMEPLAY and state != GameState.COURSE_BUILDER:
		return
	if not get_tree().root.has_focus():
		_perf_reset()  # background windows get throttled by the OS
		return
	_perf_t += delta
	if _perf_t >= 1.0:
		_perf_t = 0.0
		perf_guard_sample(Engine.get_frames_per_second())

func perf_target_fps() -> float:
	var target := float(gfx_fps_cap) if gfx_fps_cap > 0 else 60.0
	var hz := DisplayServer.screen_get_refresh_rate()
	if hz > 1.0:
		target = minf(target, hz)
	return target

## Feeds one FPS sample. Returns true when it lowered the settings.
func perf_guard_sample(fps: float) -> bool:
	if _perf_skip > 0:
		_perf_skip -= 1
		return false
	_perf_samples.append(fps)
	if _perf_samples.size() > PERF_SAMPLE_WINDOW:
		_perf_samples.pop_front()
	if _perf_samples.size() < PERF_SAMPLE_WINDOW:
		return false
	var sorted := _perf_samples.duplicate()
	sorted.sort()
	if float(sorted[PERF_SAMPLE_WINDOW / 2]) >= perf_target_fps() * PERF_SLOW_FRACTION:
		return false
	var what := lower_graphics_one_step()
	_perf_reset()
	if what == "":
		return false  # already at the floor
	EventBus.notification_requested.emit(
		"Running slow, so graphics were lowered (%s). Change it in Settings → Graphics." % what, "info")
	return true

func _perf_reset() -> void:
	_perf_samples.clear()
	_perf_t = 0.0
	_perf_skip = PERF_SETTLE_SAMPLES

## One step cheaper. Returns a short description of the change, "" at the floor.
func lower_graphics_one_step() -> String:
	if graphics_preset == 2 or graphics_preset == 1:
		apply_graphics_preset(graphics_preset - 1)
		return "Medium preset" if graphics_preset == 1 else "Low preset"
	if gfx_glow:
		apply_custom_graphics({"glow": false})
		return "glow off"
	if gfx_shadows > 0:
		apply_custom_graphics({"shadows": gfx_shadows - 1})
		return "shadows off" if gfx_shadows == 0 else "lower shadows"
	if gfx_clutter:
		apply_custom_graphics({"clutter": false})
		return "grass tufts off"
	if gfx_trees == 1:
		apply_custom_graphics({"trees": 0})
		return "simpler trees"
	if gfx_fps_cap != 30:
		apply_custom_graphics({"fps": 30})
		return "30 FPS cap"
	for sc in [0.75, 0.6, 0.5]:
		if gfx_render_scale > sc + 0.01:
			apply_custom_graphics({"scale": sc})
			return "render scale %d%%" % roundi(sc * 100.0)
	return ""

func set_gfx_auto(on: bool) -> void:
	gfx_auto = on
	_perf_reset()
	_save_graphics_config()

func _apply_engine_settings() -> void:
	_perf_reset()
	Engine.max_fps = gfx_fps_cap
	var root := get_tree().root if is_inside_tree() else null
	if root:
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		root.scaling_3d_scale = gfx_render_scale

func _load_graphics_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK or not cfg.has_section_key("graphics", "preset"):
		graphics_preset = recommended_graphics_preset()
		_set_preset_values(graphics_preset)
		_apply_engine_settings()
		if cfg.has_section("accessibility"):
			_load_accessibility_config(cfg)
		return
	graphics_preset = cfg.get_value("graphics", "preset",  1)
	gfx_glow    = cfg.get_value("graphics", "glow",    false)
	gfx_shadows = cfg.get_value("graphics", "shadows", 1)
	gfx_sky     = cfg.get_value("graphics", "sky",     1)
	gfx_fps_cap = cfg.get_value("graphics", "fps",     60)
	gfx_flags   = cfg.get_value("graphics", "flags",   true)
	gfx_render_scale = clampf(float(cfg.get_value("graphics", "scale", 1.0)), 0.5, 1.0)
	gfx_clutter = cfg.get_value("graphics", "clutter", true)
	gfx_auto    = cfg.get_value("graphics", "auto",    true)
	gfx_trees   = cfg.get_value("graphics", "trees",   0 if graphics_preset == 0 else 1)
	_apply_engine_settings()
	_load_accessibility_config(cfg)

func _save_graphics_config() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("graphics", "preset",  graphics_preset)
	cfg.set_value("graphics", "glow",    gfx_glow)
	cfg.set_value("graphics", "shadows", gfx_shadows)
	cfg.set_value("graphics", "sky",     gfx_sky)
	cfg.set_value("graphics", "fps",     gfx_fps_cap)
	cfg.set_value("graphics", "flags",   gfx_flags)
	cfg.set_value("graphics", "scale",   gfx_render_scale)
	cfg.set_value("graphics", "clutter", gfx_clutter)
	cfg.set_value("graphics", "auto",    gfx_auto)
	cfg.set_value("graphics", "trees",   gfx_trees)
	cfg.set_value("accessibility", "ui_scale",      ui_scale)
	cfg.set_value("accessibility", "colorblind",    colorblind_mode)
	cfg.save("user://settings.cfg")

# ── Accessibility settings ─────────────────────────────────────────────────────
# ui_scale: content scale factor — 1.0 = normal, 1.5 = large, 2.0 = huge
# colorblind_mode: 0=none  1=protanopia  2=deuteranopia  3=tritanopia
var ui_scale:        float = 1.0
var colorblind_mode: int   = 0

func apply_ui_scale(scale: float) -> void:
	ui_scale = clampf(scale, 0.75, 2.0)
	get_tree().root.content_scale_factor = ui_scale
	_save_graphics_config()

func apply_colorblind_mode(mode: int) -> void:
	colorblind_mode = clampi(mode, 0, 3)
	EventBus.colorblind_mode_changed.emit(colorblind_mode)
	_save_graphics_config()

func _load_accessibility_config(cfg: ConfigFile) -> void:
	ui_scale        = cfg.get_value("accessibility", "ui_scale",   1.0) as float
	colorblind_mode = cfg.get_value("accessibility", "colorblind", 0) as int
	get_tree().root.content_scale_factor = ui_scale

# ── Steam ─────────────────────────────────────────────────────────────────────
# Replace 0 with your Steamworks App ID before shipping.
# Also place a steam_appid.txt containing the App ID next to the executable.
const STEAM_APP_ID := 0

var _steam_initialized := false

func _init_steam() -> void:
	if not Engine.has_singleton("Steam"):
		return
	var steam = Engine.get_singleton("Steam")
	var result: Dictionary = steam.steamInitEx(true, STEAM_APP_ID) as Dictionary
	if result.get("status", -1) == 0:
		_steam_initialized = true
	else:
		push_warning("Steam init failed: %s" % result.get("verbal", "unknown"))

func is_steam_active() -> bool:
	return _steam_initialized

func _ready() -> void:
	_init_steam()
	_load_graphics_config()
	_load_course_meta()
	simulation = GameSimulation.new()
	add_child(simulation)

	EventBus.game_quit_requested.connect(_on_quit_requested)
	EventBus.game_paused.connect(_on_pause)
	EventBus.game_resumed.connect(_on_resume)
	EventBus.load_completed.connect(_on_load_completed)
	EventBus.save_requested.connect(_on_save_requested)
	EventBus.income_received.connect(_on_income_received)
	EventBus.rate_income_ticked.connect(func(amt: float) -> void: _empire_balance += amt * EMPIRE_SHARE)
	EventBus.day_changed.connect(func(_d: int, _s: String) -> void: _record_course_stats(active_course_id))

## Pause is reference-counted by reason ("menu", "dialogue", ...) so one system
## un-pausing can't cancel another's pause. UI (CanvasLayer under UIManager) keeps
## running while paused; the world, NPCs and EconomyManager freeze.
var _pause_reasons: Dictionary = {}

func set_pause_reason(reason: String, on: bool) -> void:
	if on:
		_pause_reasons[reason] = true
	else:
		_pause_reasons.erase(reason)
	get_tree().paused = not _pause_reasons.is_empty()

func is_paused_for(reason: String) -> bool:
	return _pause_reasons.has(reason)

func change_state(new_state: GameState) -> void:
	if state == new_state:
		return
	# Leaving play mid away round (menu, builder, map) abandons it and goes home.
	if is_away_round() and new_state != GameState.GAMEPLAY and new_state != GameState.PAUSED:
		end_away_round([], [])
	_previous_state = state
	state = new_state
	_perf_reset()  # loading / screen swaps spike frame times
	set_pause_reason("menu", state == GameState.PAUSED)
	EventBus.game_state_changed.emit(state)

	match state:
		GameState.MAIN_MENU:
			EventBus.screen_show_requested.emit("MainMenu", {})
		GameState.WORLD_MAP:
			EventBus.screen_show_requested.emit("WorldMap", {"from": _previous_state})
		GameState.COURSE_BUILDER:
			EventBus.screen_show_requested.emit("CourseBuilder", {})
		GameState.GAMEPLAY:
			EventBus.screen_show_requested.emit("Gameplay", {})
		GameState.PAUSED:
			EventBus.screen_push_requested.emit("PauseMenu", {})

func start_new_game() -> void:
	EventBus.load_requested.emit()

func _on_load_completed(success: bool) -> void:
	change_state(GameState.MAIN_MENU)

func _on_pause() -> void:
	change_state(GameState.PAUSED)

func _on_resume() -> void:
	if state != GameState.PAUSED:
		return
	set_pause_reason("menu", false)
	var resume_state := _previous_state if _previous_state != GameState.PAUSED else GameState.GAMEPLAY
	_previous_state = state
	state = resume_state
	EventBus.game_state_changed.emit(state)
	EventBus.screen_pop_requested.emit()

## 20% of all course income feeds the empire pool for buying new courses —
## one-off payments here, the steady per-second income via rate_income_ticked
## (it used to be left out, so the pool grew ~10x slower than the World Map says).
const EMPIRE_SHARE := 0.20

func _on_income_received(amount: float, _source: String) -> void:
	_empire_balance += amount * EMPIRE_SHARE

func restore_active_course() -> void:
	if not world:
		return
	# Preset-only courses have no playable holes — always resume at home.
	if active_course_id != "home":
		active_course_id = "home"
	if "home" in _course_snapshots:
		(world as GameWorld3D).import_full_state(_course_snapshots["home"])
	if "home" in _course_economies:
		EconomyManager.deserialize(_course_economies["home"])

func _save_active_course() -> void:
	if world and active_course_id != "":
		_record_course_stats(active_course_id)
		_course_snapshots[active_course_id] = _tagged_snapshot(active_course_id)
		_course_economies[active_course_id] = EconomyManager.serialize()
		_save_course_to_disk(active_course_id)
	_save_course_meta()

func _on_save_requested() -> void:
	_save_active_course()

func _on_quit_requested() -> void:
	_save_active_course()
	EventBus.save_requested.emit()
	await EventBus.save_completed
	get_tree().quit()
