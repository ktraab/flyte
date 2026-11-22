## Phase 3 narrative state machine.
##
## Chapters (0–6) advance strictly in order — each chapter's requirement is only
## checked once the previous chapter has started, so no beat is ever skipped.
## Beats are queued and presented one at a time through DialogueOverlay, only
## while the player is in a gameplay-context state (never over the main menu).
##
## Content lives in BEATS below (from STORY.md). Edit text freely — no code changes needed.
## Portraits: drop PNGs in res://assets/portraits/ and set CHARACTERS[*].portrait.
extends Node

# ── Characters ────────────────────────────────────────────────────────────────

const CHARACTERS: Dictionary = {
	"uncle_ray":     {"name": "Uncle Ray",         "portrait": "res://assets/portraits/uncle_ray.svg"},
	"diana_cross":   {"name": "Diana Cross",       "portrait": "res://assets/portraits/diana_cross.svg"},
	"marcus_bell":   {"name": "Marcus Bell",       "portrait": "res://assets/portraits/marcus_bell.svg"},
	"jess_nakamura": {"name": "Jess Nakamura",     "portrait": "res://assets/portraits/jess_nakamura.svg"},
	"dani_walsh":    {"name": "Lakewood Courier",  "portrait": "res://assets/portraits/dani_walsh.svg"},
	"player":        {"name": "You",               "portrait": "res://assets/portraits/player.svg"},
	"visitor":       {"name": "A Regular",         "portrait": "res://assets/portraits/visitor.svg"},
	"wdga":          {"name": "WDGA",              "portrait": ""},
	"narrator":      {"name": "",                  "portrait": ""},
}

# ── Beats ─────────────────────────────────────────────────────────────────────
# character: key into CHARACTERS
# style:     "dialogue" (default) | "letter" | "newspaper" | "card" | "toast"
#            | "pan" (camera tour of the player's holes — no UI; Esc/click skips)
# title:     header line (letters/newspapers show it as the headline)
# lines:     Array of pages; BBCode allowed ([i], [b])
# choices:   optional [{label, reply}] shown after the last page (cosmetic)
# input:     "name" → last page asks for the player's name + look (player_name, player_look)
# {name} in any title/line is replaced with the player's name
# toast:     for style "toast" — the notification text

const BEATS: Dictionary = {
	# ── Chapter 0 — Inheritance ──────────────────────────────────────────────
	"ch0_start": {
		"character": "uncle_ray",
		"style": "letter",
		"title": "To whoever opens this —",
		"lines": [
			"[i]I always figured you'd show up eventually. Not like this, I know. I'm sorry for that.[/i]",
			"[i]The land is paid off. Three holes are roughed in — nothing fancy, but they're playable. I left $10,000 in the account; it's not much but it's a start. The shed has everything I collected over the years.[/i]",
			"[i]I never finished it. Life kept getting in the way, then time ran out.[/i]",
			"[i]I'm not leaving it to you because you're good at business. I'm leaving it to you because you're the only one in this family who ever picked up a disc and smiled.[/i]",
			"[i]Don't sell it. Finish it.[/i]\n\n— Ray",
		],
	},
	"ch0_name": {
		"character": "player",
		"title": "Inheritance",
		"lines": [
			"The letter is addressed to 'whoever opens this.' That's you.\n\nWhat do the regulars call you?",
		],
		"input": "name",   # DialogueOverlay shows a name field instead of Next
	},
	"ch0_arrival": {
		"character": "player",
		"title": "Inheritance",
		"lines": [
			"This place looks worse than you remembered. But Ray's basket is still standing.",
			"Let's see what we're working with.",
		],
	},
	"ch0_pan": {
		"style": "pan",   # STORY.md: camera pans across the overgrown course
	},
	"ch0_first_visitor": {
		"style": "toast",
		"toast": "Someone found the place. Word travels fast — or they just saw the gate was open.",
	},
	"ch0_three_holes": {
		"character": "player",
		"title": "A Course Again",
		"lines": [
			"Ray's three holes, and now one of yours. It's not much, but it's a course.",
			"Keep going.",
		],
	},

	# ── Chapter 1 — First Steps ──────────────────────────────────────────────
	"ch1_start": {
		"character": "dani_walsh",
		"style": "newspaper",
		"title": "Hollis Course Reopens After Years of Neglect",
		"lines": [
			"A family member of the late Raymond Hollis has begun restoring the disc golf course at 44 Timber Creek Road. The six-hole layout is now open to the public.\n\n— Dani Walsh, Staff Reporter",
		],
	},
	"ch1_reflection": {
		"character": "player",
		"title": "First Steps",
		"lines": [
			"Six holes. Ray would've called it 'a solid start.' You'll take that.",
		],
	},
	"ch1_vip_visit": {
		"character": "jess_nakamura",
		"title": "A Pro Drops In",
		"lines": [
			"This isn't on the circuit yet, but it should be.",
			"Whoever designed these holes knows what they're doing. I'm putting it in my recommendations.",
		],
	},
	"ch1_jess_post": {
		"style": "toast",
		"toast": "Jess Nakamura posted about the course. 43 new follows before you closed up for the day!",
	},
	"ch1_close": {
		"character": "player",
		"title": "Word Is Out",
		"lines": [
			"Word is out. From here, it goes one of two ways — up, or forgotten.",
			"Ray didn't leave you this place to be forgotten.",
		],
	},

	# ── Chapter 2 — Word Gets Out ────────────────────────────────────────────
	"ch2_diana_toast": {
		"style": "toast",
		"toast": "You just realized the woman on the back nine this afternoon was Diana Cross.",
	},
	"ch2_start": {
		"character": "diana_cross",
		"style": "letter",
		"title": "CROSS PINES HOLDINGS",
		"lines": [
			"[i]Dear {name},[/i]\n\n[i]Congratulations on what you've built. Raymond would be proud.[/i]",
			"[i]I'll be direct: Cross Pines is expanding into disc golf, and your location is ideal for our plans. I'm prepared to offer $85,000 for the property and existing infrastructure — well above market.[/i]",
			"[i]No rush. But the offer doesn't stay open forever.[/i]\n\n— Diana Cross",
		],
		"choices": [
			{"label": "Decline", "reply": "Ray said don't sell it. That's good enough for you."},
			{"label": "Consider It", "reply": "...No. Not after everything. Not yet."},
		],
	},
	"ch2_close": {
		"character": "player",
		"title": "Word Gets Out",
		"lines": [
			"She'll be back. People like Diana always come back.",
			"The only answer she'll accept is a course she can't buy her way past.",
		],
	},

	# ── Chapter 3 — Going Pro ────────────────────────────────────────────────
	"ch3_tourney_day": {
		"style": "toast",
		"toast": "32 players signed up. Biggest day this course has ever seen.",
	},
	"ch3_tourney_busy": {
		"style": "toast",
		"toast": "Hole 6 is backing up — players taking pictures between shots.",
	},
	"ch3_tourney_done": {
		"style": "toast",
		"toast": "Tournament complete. Three players asked when the next one is.",
	},
	"ch3_start": {
		"character": "marcus_bell",
		"title": "Going Pro",
		"lines": [
			"Marcus Bell. WDGA Regional. Sorry — I've got about four clipboards going.",
			"I've been watching what you've built here. The Regional Circuit has an opening in the spring schedule. I think you're ready — if you want it.",
			"Sanctioned events mean scrutiny. But they also mean your course gets rated on the official ladder. Your call.",
		],
		"choices": [
			{"label": "Let's do it.", "reply": "Marcus grins and scribbles something on clipboard number three."},
		],
	},
	"ch3_newspaper": {
		"character": "dani_walsh",
		"style": "newspaper",
		"title": "Hollis Course Enters the Big Leagues",
		"lines": [
			"WDGA sanctioned tournament draws regional players to Timber Creek Road. Three of them asked when the next one is.\n\n— Dani Walsh, Staff Reporter",
			"[i]Ray's name is in a headline. That one's for him.[/i]",
		],
	},

	# ── Chapter 4 — Road Trip ────────────────────────────────────────────────
	"ch4_start": {
		"character": "jess_nakamura",
		"title": "The Invitation",
		"lines": [
			"Maple Hill is hosting an open challenge week. Low-key, no rankings, just disc golf. I told them about your course. They want you there.",
			"Pack light. These courses will make you rethink everything you built.",
			"[i]The Circuit button is now on your HUD.[/i]",
		],
	},
	"ch4_world_map": {
		"character": "player",
		"title": "The World Circuit",
		"lines": [
			"You've built something worth being proud of. Now go see what the rest of the world built.",
			"[i]Pick a course and choose Play an Away Round to walk its front nine. Your course waits for you.[/i]",
		],
	},
	"ch4_first_away": {
		"character": "player",
		"title": "Road Trip",
		"lines": [
			"Humbling. Inspiring. Both at the same time.",
			"You took notes the whole way around. Half of them were about your own course.",
			"Ray never left the county. But he built something that led you here. That counts for something.",
		],
	},

	# ── Chapter 5 — National Stage ───────────────────────────────────────────
	"ch5_start": {
		"character": "wdga",
		"style": "letter",
		"title": "WDGA National Circuit Committee",
		"lines": [
			"[i]The Committee is pleased to invite Hollis Course to apply as a host venue for the National Championship qualifying round.[/i]",
			"[i]Minimum requirements: 18 holes, course rating 4.0+, certified facilities.[/i]\n\n[i]Recommending official: Marcus Bell, Regional Director[/i]",
		],
	},
	"ch5_diana": {
		"character": "diana_cross",
		"title": "Rivals No More",
		"lines": [
			"I'm not here to make an offer. I just wanted to see it.",
			"You know what Ray told me when he was building this? He said, 'Diana, I don't need it to be famous. I need it to be finished.'",
			"Looks like you finished it.",
			"Good luck with the nationals.",
		],
	},
	"ch5_close": {
		"character": "player",
		"title": "National Stage",
		"lines": [
			"National-level players will walk Ray's holes. He never got to see it. You'll have to see it for him.",
		],
	},

	"ch5_sponsor": {
		"style": "toast",
		"toast": "A new sponsor matched today's purse: Cross Pines Holdings. No note. No explanation.",
	},

	# ── Chapter 6 — World Class ──────────────────────────────────────────────
	"ch5_bench": {
		"style": "toast",
		"toast": "You placed a bench where Diana sat. Felt like the right spot.",
	},
	"ch6_ranking": {
		"style": "toast",
		"toast": "Hollis Course has been added to the WDGA World Rankings.",
	},
	"ch6_start": {
		"character": "player",
		"title": "World Class",
		"lines": [
			"The disc bag is still on the fence. You never moved it.",
			"Ray's three holes are still here — buried inside the full 18 now, but they're here. You can walk them without a map.",
			"You used to wonder if he left you this because he trusted you, or because he had nobody else.",
			"You stopped wondering a long time ago.",
			"Finish it, he said.",
			"Done.",
		],
	},
	"ch6_card": {
		"character": "narrator",
		"style": "card",
		"title": "",
		"lines": [
			"In memory of Raymond Hollis.\n\nHe built three holes.\nThat was enough to start.",
		],
	},
	"ch6_dani": {   # epilogue — the next in-game day after the final card
		"character": "dani_walsh",
		"style": "newspaper",
		"title": "Hollis Course Joins the World Rankings",
		"lines": [
			"The WDGA World Rankings added a new name this week: Hollis Course, 44 Timber Creek Road. The first three holes on the card are still the ones Raymond Hollis built.\n\n— Dani Walsh, Staff Reporter",
			"[i]You pinned it up in the shed, next to Ray's old scorecards.[/i]",
		],
	},

	# ── Recurring side beats (any chapter) ───────────────────────────────────
	"side_disc_bag": {
		"character": "visitor",
		"title": "The Bag on the Fence",
		"lines": [
			"Hey — whose bag is that on the gate? Looks like it's been there a while.",
			"Discs are all sun-faded. Nobody's touched it in years, huh?",
		],
		"choices": [
			{"label": "It belongs there.", "reply": "They nod, like that's answer enough, and head for the first tee."},
		],
	},
	"side_shed": {
		"style": "toast",
		"toast": "You're converting Ray's storage, one upgrade at a time.",
	},
}

## Beats queued (in order) when each chapter starts.
const CHAPTER_BEATS: Dictionary = {
	0: ["ch0_start", "ch0_name", "ch0_pan", "ch0_arrival"],
	1: ["ch1_start", "ch1_reflection"],
	2: ["ch2_start", "ch2_close"],
	3: ["ch3_start", "ch3_newspaper"],
	4: ["ch4_start"],
	5: ["ch5_start", "ch5_diana", "ch5_close"],
	6: ["ch6_ranking", "ch6_start", "ch6_card"],
}

## Side beats that belong to a chapter (marked as seen when a legacy save is migrated past it).
const SIDE_BEATS: Dictionary = {
	0: ["ch0_first_visitor", "ch0_three_holes"],
	1: ["ch1_vip_visit", "ch1_jess_post", "ch1_close"],
	2: ["ch2_diana_toast"],
	3: ["ch3_tourney_day", "ch3_tourney_busy", "ch3_tourney_done"],
	4: ["ch4_world_map", "ch4_first_away"],
}

const MAX_CHAPTER: int = 6
const CIRCUIT_CHAPTER: int = 4

const PRESTIGE_REGIONAL: float    = 25.0
const PRESTIGE_NATIONAL: float    = 50.0
const PRESTIGE_WORLD_CLASS: float = 75.0
## "Beat 5 world circuit courses" — 5 owned circuit courses developed to WDGA
## certification (GameManager.is_course_certified: 9+ holes, 3.5★, a restroom).
const WORLD_CLASS_COURSES: int    = 5

const _WorldMapScript = preload("res://scenes/ui/screens/WorldMap.gd")
const _CourseUnlocks  = preload("res://core/data/CourseUnlocks.gd")

# ── State ─────────────────────────────────────────────────────────────────────

var _chapter: int = 0
var _fired_beats: Dictionary = {}    # beat_id → true (queued or shown; never re-queued)
var _choices: Dictionary = {}        # beat_id → chosen label
var _queue: Array[String] = []       # beats waiting to be shown (persisted)
var _days_in_chapter: int = 0        # in-game days since the current chapter started
var _showing: String = ""            # beat currently on screen ("" = none)
var _needs_migration: bool = false   # save predates the story system
var player_name: String = DEFAULT_PLAYER_NAME
var player_look: String = DEFAULT_PLAYER_LOOK   # which "You" portrait: "male" | "female"

const DEFAULT_PLAYER_NAME := "Coach"   # STORY.md default
const MAX_NAME_LENGTH := 20
const DEFAULT_PLAYER_LOOK := "male"
## Portrait per player look, picked on the name prompt (beat input "name").
const PLAYER_LOOKS: Dictionary = {
	"male":   "res://assets/portraits/player.svg",
	"female": "res://assets/portraits/player_female.svg",
}

func _ready() -> void:
	EventBus.goal_completed.connect(func(_id: String, _t: String, _r: float) -> void: _evaluate())
	EventBus.prestige_changed.connect(func(_v: float) -> void: _evaluate())
	EventBus.course_purchased.connect(_on_course_purchased)
	EventBus.course_certified.connect(func(_id: String) -> void: _evaluate())
	EventBus.day_changed.connect(_on_day_changed)
	EventBus.vip_left.connect(_on_vip_left)
	EventBus.npc_arrived.connect(_on_npc_arrived)
	EventBus.tournament_started.connect(_on_tournament_started)
	EventBus.tile_placed.connect(_on_tile_placed)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.tournament_completed.connect(_on_tournament_completed)
	EventBus.round_completed.connect(_on_round_completed)
	EventBus.facility_upgraded.connect(_on_facility_upgraded)
	EventBus.away_round_completed.connect(_on_away_round_completed)
	# Runs while paused so the camera-pan beat can be skipped with Esc/click.
	process_mode = Node.PROCESS_MODE_ALWAYS

# ── Public API ────────────────────────────────────────────────────────────────

func get_chapter() -> int:
	return _chapter

func is_beat_fired(beat_id: String) -> bool:
	return _fired_beats.get(beat_id, false)

func get_choice(beat_id: String) -> String:
	return _choices.get(beat_id, "") as String

## True once the World Circuit should be reachable from the HUD. Also true for
## anyone who already owns a second course, so nobody is locked away from them.
func is_circuit_unlocked() -> bool:
	return _chapter >= CIRCUIT_CHAPTER or GameManager.owned_courses.size() > 1

## Queue a beat. No-op if it was already queued/shown or doesn't exist.
func fire_beat(beat_id: String) -> void:
	if _fired_beats.get(beat_id, false) or not BEATS.has(beat_id):
		return
	_fired_beats[beat_id] = true
	_queue.append(beat_id)
	_pump.call_deferred()

## Called by DialogueOverlay when its beat closes.
## finished=false means it was torn down early (e.g. state change) — re-show later.
func on_dialogue_closed(beat_id: String, finished: bool) -> void:
	if beat_id != _showing:
		return
	_showing = ""
	GameManager.set_pause_reason("dialogue", false)
	if finished:
		EventBus.story_beat_fired.emit(beat_id)
	else:
		_queue.push_front(beat_id)
	_pump.call_deferred()

func record_choice(beat_id: String, label: String) -> void:
	_choices[beat_id] = label

func set_player_name(n: String) -> void:
	var clean := n.strip_edges().replace("[", "").replace("]", "").left(MAX_NAME_LENGTH)
	player_name = clean if clean != "" else DEFAULT_PLAYER_NAME

func set_player_look(look: String) -> void:
	player_look = look if PLAYER_LOOKS.has(look) else DEFAULT_PLAYER_LOOK

## Portrait path for a character ("" = none). The player's follows player_look.
func get_portrait(char_id: String) -> String:
	if char_id == "player":
		return PLAYER_LOOKS.get(player_look, PLAYER_LOOKS[DEFAULT_PLAYER_LOOK]) as String
	return (CHARACTERS.get(char_id, {}) as Dictionary).get("portrait", "") as String

## Beat text with placeholders filled in ({name}).
func format_text(text: String) -> String:
	return text.replace("{name}", player_name)

func serialize() -> Dictionary:
	var pending: Array = _queue.duplicate()
	if _showing != "":
		pending.push_front(_showing)
	return {
		"chapter": _chapter,
		"beats":   _fired_beats.duplicate(),
		"choices": _choices.duplicate(),
		"queue":   pending,
		"days":    _days_in_chapter,
		"name":    player_name,
		"look":    player_look,
	}

func deserialize(data: Dictionary) -> void:
	_end_showing()
	_chapter         = clampi(data.get("chapter", 0) as int, 0, MAX_CHAPTER)
	_fired_beats     = (data.get("beats", {}) as Dictionary).duplicate()
	_choices         = (data.get("choices", {}) as Dictionary).duplicate()
	_days_in_chapter = data.get("days", 0) as int
	player_name      = data.get("name", DEFAULT_PLAYER_NAME) as String
	set_player_look(data.get("look", DEFAULT_PLAYER_LOOK) as String)
	_queue.clear()
	for b in data.get("queue", []) as Array:
		_queue.append(b as String)
	_showing = ""
	_needs_migration = false
	_pump.call_deferred()  # resume any beats left pending at last save

## Called by GameManager when loading a save that has no story data yet.
## The chapter is worked out on the next evaluation, once prestige is known.
func mark_legacy_save() -> void:
	deserialize({})
	_needs_migration = true

## Reset everything (new game / tests).
func reset() -> void:
	deserialize({})

## Drop whatever beat is on screen without firing it. Loading story state while
## a beat was showing used to leave the "dialogue" pause on with nothing on
## screen (the overlay's close no longer matched _showing) — a frozen world.
func _end_showing() -> void:
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	_pan_tween = null
	if _showing == "":
		return
	_showing = ""
	GameManager.set_pause_reason("dialogue", false)
	if UIManager.current_screen_name() == "DialogueOverlay":
		EventBus.screen_pop_requested.emit()

# ── Chapter progression ───────────────────────────────────────────────────────

## Requirement for starting chapter `n`, checked only while the current chapter is n-1.
func _requirement_met(n: int, ignore_pacing: bool = false) -> bool:
	match n:
		1: return GoalsSystem.is_goal_complete("six_holes")
		2:
			# At least one in-game day after Ch1: building the six holes already
			# lifts prestige past Regional, so both chapters used to fire together.
			return EconomyManager.get_prestige() >= PRESTIGE_REGIONAL and (ignore_pacing or _days_in_chapter >= 1)
		3: return GoalsSystem.is_goal_complete("first_tourney")
		4:
			# Give chapter 3 at least one in-game day to breathe before the road trip.
			return _any_circuit_course_unlocked() and (ignore_pacing or _days_in_chapter >= 1)
		5: return EconomyManager.get_prestige() >= PRESTIGE_NATIONAL
		6:
			return (EconomyManager.get_prestige() >= PRESTIGE_WORLD_CLASS
				and GameManager.get_certified_circuit_count() >= WORLD_CLASS_COURSES)
	return false

func _evaluate() -> void:
	if not _in_play_state():
		return
	if _needs_migration:
		_migrate_legacy()
	while _chapter < MAX_CHAPTER and _requirement_met(_chapter + 1):
		_start_chapter(_chapter + 1)
	_check_side_beats()

func _start_chapter(n: int) -> void:
	_chapter = n
	_days_in_chapter = 0
	EventBus.story_chapter_started.emit(n)
	if n == 2 and GoalsSystem.is_goal_complete("vip_visit"):
		fire_beat("ch2_diana_toast")  # she played a round incognito before writing
	for b in CHAPTER_BEATS.get(n, []) as Array:
		fire_beat(b as String)

func _check_side_beats() -> void:
	# A new game starts with Ray's 3 holes — this fires when the player adds their own.
	if _chapter == 0 and GoalsSystem.get_current_value("holes") >= 4.0:
		fire_beat("ch0_three_holes")

## Legacy save: jump silently to the chapter the player has already earned,
## mark everything before it as seen, and show just the current chapter's opener.
func _migrate_legacy() -> void:
	_needs_migration = false
	var target := 0
	while target < MAX_CHAPTER and _requirement_met(target + 1, true):
		target += 1
	if target == 0:
		return  # genuinely new player — normal Ch0 flow
	_chapter = target
	_days_in_chapter = 0
	for c in range(0, target + 1):
		for b in CHAPTER_BEATS.get(c, []) as Array:
			_fired_beats[b as String] = true
		for b in SIDE_BEATS.get(c, []) as Array:
			_fired_beats[b as String] = true
	var opener: String = (CHAPTER_BEATS[target] as Array)[0] as String
	_fired_beats.erase(opener)
	fire_beat(opener)
	EventBus.story_chapter_started.emit(target)

func _any_circuit_course_unlocked() -> bool:
	for loc in _WorldMapScript.LOCATIONS:
		var l: Dictionary = loc as Dictionary
		if l["type"] == "course" and l["id"] != "home" and _CourseUnlocks.is_met(l.get("unlock_key", "") as String):
			return true
	return false


# ── Event hooks ───────────────────────────────────────────────────────────────

func _on_day_changed(_day: int, _season: String) -> void:
	_days_in_chapter += 1
	_evaluate()
	# Epilogue: Dani's world-rankings piece runs the day after the final card.
	if _chapter == MAX_CHAPTER and is_beat_fired("ch6_card"):
		fire_beat("ch6_dani")

func _on_course_purchased(_course_id: String) -> void:
	_evaluate()

## STORY.md Ch4 "After first away round".
func _on_away_round_completed(_course_id: String, _strokes: int, _par: int) -> void:
	if _chapter >= CIRCUIT_CHAPTER:
		fire_beat("ch4_first_away")

func _on_vip_left(_npc_id: String, satisfied: bool) -> void:
	if _chapter >= 1 and satisfied and not is_beat_fired("ch1_vip_visit"):
		fire_beat("ch1_vip_visit")
		fire_beat("ch1_jess_post")
		if _chapter == 1:
			fire_beat("ch1_close")

func _on_npc_arrived(_npc_id: String) -> void:
	if _chapter == 0:
		fire_beat("ch0_first_visitor")

const BENCH_TILE := 20            # GameWorld3D.TileType.BENCH
const BENCH_NEAR_HOLE1_CELLS := 8

## STORY.md: after Ch5, a bench near Hole 1 (where Diana sat) gets a quiet toast.
func _on_tile_placed(tile_type: int) -> void:
	if tile_type != BENCH_TILE or _chapter < 5 or is_beat_fired("ch5_bench") or GameManager.world == null:
		return
	var w := GameManager.world as GameWorld3D
	var holes := w.get_holes_info()
	if holes.is_empty():
		return
	var tee_pos: Vector3 = w.get_cell_world_pos((holes[0] as Dictionary)["tee_cell"] as Vector2i)
	var max_d: float = BENCH_NEAR_HOLE1_CELLS * GameWorld3D.CELL_SIZE
	for b in w.get_tiles_of_type(BENCH_TILE):   # world positions
		var p: Vector3 = b as Vector3
		if Vector2(p.x - tee_pos.x, p.z - tee_pos.z).length() <= max_d:
			fire_beat("ch5_bench")
			return

var _story_tourney: bool = false   # the first tournament is running (Ch3 toast series)

## Diana's quiet sponsorship after Ch5 matches the tournament purse, at least this much.
const SPONSOR_MIN := 10000.0
const ENTRANCE_TILE := 8   # GameWorld3D.TileType.ENTRANCE

func _on_tournament_started() -> void:
	if not is_beat_fired("ch3_tourney_day"):
		_story_tourney = true
	fire_beat("ch3_tourney_day")

func _on_tournament_completed(prize: float) -> void:
	if _story_tourney:
		_story_tourney = false
		fire_beat("ch3_tourney_done")
	# STORY.md Ch5: Diana "quietly sends one tournament sponsor your way, no explanation".
	if _chapter >= 5 and is_beat_fired("ch5_diana") and not is_beat_fired("ch5_sponsor"):
		var bonus := maxf(SPONSOR_MIN, prize)
		EconomyManager.earn(bonus, "sponsor")
		fire_beat("ch5_sponsor")
		EventBus.notification_requested.emit("Sponsorship: +$%s" % String.num_int64(int(bonus)), "info")

func _on_round_completed(_npc_id: String, is_vip: bool, _earn: float, _holes: int) -> void:
	if _story_tourney:
		fire_beat("ch3_tourney_busy")
	# Recurring element: a regular asks about Ray's bag on the gate.
	if not is_vip and _chapter >= 2 and not is_beat_fired("side_disc_bag") \
			and GameManager.active_course_id == "home" and not GameManager.is_away_round() \
			and GameManager.world and not (GameManager.world as GameWorld3D).get_tiles_of_type(ENTRANCE_TILE).is_empty():
		fire_beat("side_disc_bag")

## Recurring element: Ray's shed becomes the pro shop.
func _on_facility_upgraded(key: String, _tier: int) -> void:
	if key == "pro_shop" and GameManager.active_course_id == "home":
		fire_beat("side_shed")

func _on_game_state_changed(_state: int) -> void:
	if _in_play_state():
		_evaluate()  # runs legacy migration first if needed
		if _chapter == 0:
			for b in CHAPTER_BEATS[0] as Array:
				fire_beat(b as String)
		_pump.call_deferred()

# ── Presentation ──────────────────────────────────────────────────────────────

func _in_play_state() -> bool:
	var s: int = GameManager.state
	return (s == GameManager.GameState.GAMEPLAY
		or s == GameManager.GameState.COURSE_BUILDER
		or s == GameManager.GameState.WORLD_MAP)

## Show the next queued beat if nothing is on screen and the player is in-game.
func _pump() -> void:
	if _showing != "" or _queue.is_empty() or not _in_play_state():
		return
	var beat_id: String = _queue.pop_front()
	var beat: Dictionary = BEATS.get(beat_id, {}) as Dictionary
	if beat.get("style", "dialogue") == "toast":
		EventBus.notification_requested.emit(beat.get("toast", "") as String, "info")
		EventBus.story_beat_fired.emit(beat_id)
		_pump.call_deferred()
		return
	_showing = beat_id
	GameManager.set_pause_reason("dialogue", true)
	if beat.get("style", "") == "pan":
		_start_pan(beat_id)
		return
	EventBus.screen_push_requested.emit("DialogueOverlay", {"beat_id": beat_id, "overlay": true})

# ── Camera pan beat ───────────────────────────────────────────────────────────

const PAN_HOLES := 3   # Ray's three holes
var _pan_tween: Tween = null

func is_panning() -> bool:
	return _showing != "" and (BEATS.get(_showing, {}) as Dictionary).get("style", "") == "pan"

func _start_pan(beat_id: String) -> void:
	var cam: Node = GameManager.world.get_node_or_null("CourseCamera3D") if GameManager.world else null
	var pts := _pan_points()
	if cam == null or not cam.has_method("play_tour") or pts.is_empty():
		on_dialogue_closed.call_deferred(beat_id, true)
		return
	EventBus.notification_requested.emit("Esc to skip", "info")
	_pan_tween = cam.call("play_tour", pts) as Tween
	_pan_tween.finished.connect(finish_pan)

## Tee and baskets of the first holes, in playing order.
func _pan_points() -> Array:
	var w := GameManager.world as GameWorld3D
	if w == null:
		return []
	var holes := w.get_holes_info()
	var pts: Array = []
	for i in mini(PAN_HOLES, holes.size()):
		var h: Dictionary = holes[i] as Dictionary
		if i == 0:
			pts.append(w.get_cell_world_pos(h["tee_cell"] as Vector2i))
		pts.append(w.get_cell_world_pos(h["basket_cell"] as Vector2i))
	return pts

## Ends the pan beat (tween finished, or skipped).
func finish_pan() -> void:
	if not is_panning():
		return
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	_pan_tween = null
	var cam: Node = GameManager.world.get_node_or_null("CourseCamera3D") if GameManager.world else null
	if cam and cam.has_method("end_tour"):
		cam.call("end_tour")
	on_dialogue_closed(_showing, true)

func _unhandled_input(event: InputEvent) -> void:
	if not is_panning():
		return
	var mb := event as InputEventMouseButton
	if event.is_action_pressed("ui_cancel") or (mb and mb.pressed):
		get_viewport().set_input_as_handled()
		finish_pan()
