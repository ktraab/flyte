## Global signal bus — all cross-system communication flows through here.
## No direct node references needed between systems.
extends Node

# ── Game State ──────────────────────────────────────────────────────────────
signal game_state_changed(new_state: int)
signal game_paused()
signal game_resumed()
signal game_quit_requested()

# ── Course ───────────────────────────────────────────────────────────────────
signal course_loaded(course_data: Resource)
signal course_unloaded()
signal hole_completed(hole_index: int, player_id: String, score: int)
signal course_saved(course_id: String)

# ── Economy ──────────────────────────────────────────────────────────────────
signal balance_changed(new_balance: float)
signal income_received(amount: float, source: String)
## Per-second course income (EconomyManager._tick). Separate from income_received
## so the cash sound etc. only react to one-off payments.
signal rate_income_ticked(amount: float)
signal expense_incurred(amount: float, category: String)
signal upgrade_purchased(upgrade_id: String)
signal day_changed(day: int, season: String)

# ── NPC / Players ────────────────────────────────────────────────────────────
signal npc_arrived(npc_id: String)
signal npc_left(npc_id: String)
signal npc_score_recorded(hole_index: int, score: int)
signal player_data_updated()
signal disc_launched()
signal disc_landed(penalty: int)
signal disc_impact(kind: String, pos: Vector3)   # "chains" | "rim" | "tree" | "rock" | "splash"
signal hole_scored(hole_idx: int, throws: int, par: int, diff: int)

# ── Weather ───────────────────────────────────────────────────────────────────
signal wind_changed(direction: float, speed: float)

# ── Happiness / Ratings ───────────────────────────────────────────────────────
signal happiness_changed(value: float)
signal prestige_changed(value: float)
signal membership_changed(count: int, fee: float)
signal tournament_started()
signal tournament_completed(prize: float)
signal goal_completed(goal_id: String, text: String, reward: float)
signal vip_arrived(npc_id: String)
signal vip_left(npc_id: String, satisfied: bool)
signal staff_hired(staff_type: int)
signal staff_fired(staff_type: int)
signal staff_upgraded(staff_type: int, tier: int)
signal player_needs_failed(npc_id: String)
signal course_condition_changed(pct: float)
signal event_started(event_name: String)
signal event_completed(event_name: String)
signal marketing_changed(weekly_budget: float)
signal npc_inspect_requested(info: Dictionary)
signal round_completed(npc_id: String, is_vip: bool, earn: float, holes_played: int)
signal tee_painted(cell: Vector2i, hole_num: int)
signal tile_placed(tile_type: int)         # emitted by GameWorld3D when a new tile type is painted
signal player_level_up(new_level: int, title: String)  # emitted by LevelSystem

# ── Graphics ─────────────────────────────────────────────────────────────────
signal graphics_quality_changed(settings: Dictionary)
signal colorblind_mode_changed(mode: int)

# ── UI ───────────────────────────────────────────────────────────────────────
signal screen_show_requested(screen_name: String, params: Dictionary)  # replaces full stack
signal screen_push_requested(screen_name: String, params: Dictionary)  # overlay (pause only)
signal screen_pop_requested()
signal notification_requested(message: String, notification_type: String)
signal tooltip_requested(text: String, position: Vector2)

# ── Story ────────────────────────────────────────────────────────────────────
signal story_chapter_started(chapter: int)
signal story_beat_fired(beat_id: String)

# ── Multi-course ──────────────────────────────────────────────────────────────
signal course_switched(course_id: String)
signal course_purchased(course_id: String)
signal course_certified(course_id: String)   # circuit course reached WDGA standard
signal away_round_started(course_id: String)
signal away_round_completed(course_id: String, strokes: int, par: int)
signal facility_upgraded(key: String, tier: int)

# ── Persistence ──────────────────────────────────────────────────────────────
signal save_requested()
signal save_completed(success: bool)
signal load_requested()
signal load_completed(success: bool)
signal sync_requested()
signal sync_completed(success: bool)
signal offline_queue_flushed()
signal network_status_changed(is_online: bool)
