## Economy sanity: days advance, pause freezes the sim, prestige components work.
extends "res://tests/TestCase.gd"

func _econ() -> Node: return tree.root.get_node("EconomyManager")

func before_each() -> void:
	await goto_state(gm().GameState.GAMEPLAY)
	await quiet_story()

func test_day_advances() -> void:
	var day: int = _econ().current_day
	await advance_economy(61.0)
	check_eq(_econ().current_day, day + 1, "one in-game day per 60s")

func test_economy_frozen_while_paused() -> void:
	await press_key("ui_cancel")
	check(not _econ().can_process(), "EconomyManager stops processing while paused")
	check(ui().get("_canvas").can_process(), "UI keeps processing while paused")
	bus().game_resumed.emit()
	await frames(3)
	check(_econ().can_process(), "EconomyManager resumes")

func test_prestige_counts_completed_goals() -> void:
	var gs: Node = tree.root.get_node("GoalsSystem")
	gs.deserialize({"completed": {"first_hole": true, "six_holes": true, "ten_players": true}})
	var bd: Dictionary = _econ().get_prestige_breakdown()
	check_eq(bd.get("goals_done", 0), 3, "prestige sees completed goals")
	gs.deserialize({})

# ── Balance regressions (2026-11 balance pass) ────────────────────────────────

## Puts the economy in a known "typical mid-game" state: 10 amateurs, 3★, 50% happiness.
func _typical_state() -> Dictionary:
	var snap: Dictionary = _econ().serialize()
	var tiers := {}
	for i in 10:
		tiers["test_npc_%d" % i] = 1
	_econ().set("_npc_tiers", tiers)
	_econ().set("_course_rating", 3.0)
	_econ().set("current_happiness", 0.5)
	_econ().set("current_season", "Spring")
	_econ().balance = 100000.0
	_econ()._recalculate_rates()
	return snap

func _restore(snap: Dictionary) -> void:
	_econ().set("_npc_tiers", {})
	_econ().deserialize(snap)
	_econ()._recalculate_rates()

func _net() -> float:
	return _econ().income_rate - _econ().expense_rate

func test_disc_pro_and_concessions_pay_for_themselves() -> void:
	var snap := _typical_state()
	for t in [1, 2]:  # DISC_PRO, CONCESSIONS
		var before := _net()
		_econ().hire_staff(t)
		check(_net() > before, "staff type %d increases net income at tier 1 (%.2f → %.2f $/s)" % [t, before, _net()])
		_econ().fire_staff(t)
	_restore(snap)

func test_groundskeeper_is_nearly_free() -> void:
	var snap := _typical_state()
	var before := _net()
	_econ().hire_staff(0)
	check(before - _net() <= 0.25, "groundskeeper costs ≤ $15/day net before condition savings")
	_econ().fire_staff(0)
	_restore(snap)

func test_high_green_fee_reduces_arrivals() -> void:
	var snap := _typical_state()
	_econ().set_green_fee_mult(1.0)
	var base_spawn: float = _econ().get_spawn_rate_mult()
	_econ().set_green_fee_mult(3.0)
	check(_econ().get_spawn_rate_mult() < base_spawn / 4.0, "3× fee → under a quarter of the arrivals")
	_econ().set_green_fee_mult(1.0)
	_restore(snap)

func test_rating_raises_green_fees() -> void:
	var snap := _typical_state()
	_econ().set("_course_rating", 1.0)
	_econ()._recalculate_rates()
	var low: float = _econ().income_rate
	_econ().set("_course_rating", 5.0)
	_econ()._recalculate_rates()
	check(_econ().income_rate > low * 1.5, "5★ course earns >1.5× a 1★ course per player")
	_restore(snap)

func test_membership_not_counted_in_per_second_rate() -> void:
	var snap := _typical_state()
	var before: float = _econ().income_rate
	_econ().set("_membership_count", 20)
	_econ()._recalculate_rates()
	check_eq(_econ().income_rate, before, "membership dues only paid via the daily tick")
	_restore(snap)

func test_starting_balance_matches_rays_letter() -> void:
	check_eq(_econ().STARTING_BALANCE, 10000.0, "new games start with Ray's $10,000")
	var snap: Dictionary = _econ().serialize()
	_econ().deserialize({})
	check_eq(_econ().balance, 10000.0, "save without balance falls back to $10,000")
	_econ().deserialize(snap)

## Leaving the course view (builder, map) removes the players; the economy must
## stop charging green fees for them. It used to keep counting "ghost" players,
## so every builder trip permanently inflated income.
func test_builder_trip_does_not_leave_ghost_players() -> void:
	await quiet_story()
	var w: Node = gm().world
	var em: Node = tree.root.get_node("EconomyManager")
	for i in 3:
		w.call("_try_spawn_npc")
	await frames(2)
	var before: int = em.call("get_player_count")
	check(before > 0, "players arrived (%d)" % before)
	for trip in 3:
		await goto_state(gm().GameState.COURSE_BUILDER)
		check_eq(em.call("get_player_count"), 0, "builder trip %d: no players counted while the course is empty" % (trip + 1))
		await goto_state(gm().GameState.GAMEPLAY)
		await quiet_story()
	check(int(em.call("get_player_count")) <= 3 * 4, "count stays bounded after trips (%d)" % int(em.call("get_player_count")))
	em.call("_on_npc_left", "npc_never_existed")
	check(int(em.call("get_player_count")) >= 0, "unknown player leaving can't push the count negative")

## The World Map promises "20% of course income" to the empire pool. The steady
## per-second income used to be left out (only one-off payments counted).
func test_empire_pool_gets_share_of_per_second_income() -> void:
	var em: Node = tree.root.get_node("EconomyManager")
	var rate_before: float = em.get("income_rate")
	em.set("income_rate", 10.0)
	var e0: float = gm().call("get_empire_balance")
	for i in 5:
		em.call("_tick")
	var gained: float = float(gm().call("get_empire_balance")) - e0
	check(absf(gained - 10.0) < 0.01, "5 ticks at $10/s → $10 to the empire pool (got $%.2f)" % gained)
	em.set("income_rate", rate_before)

## Spare course money can be invested in the empire pool (1:1).
func test_invest_moves_course_money_to_empire() -> void:
	var em: Node = tree.root.get_node("EconomyManager")
	em.set("balance", 20000.0)
	var e0: float = gm().call("get_empire_balance")
	check(gm().call("invest_in_empire", 8000.0), "invest succeeds")
	check(is_equal_approx(float(em.get("balance")), 12000.0), "course balance −$8000")
	check(is_equal_approx(float(gm().call("get_empire_balance")) - e0, 8000.0), "empire +$8000")
	check(not gm().call("invest_in_empire", 50000.0), "can't invest more than you have")

## A course you're away from earns in game time and splits like an active one:
## 20% to the empire pool, 80% to its own balance (it used to send 100% to the pool).
func test_background_income_splits_and_uses_game_time() -> void:
	var econ: Dictionary = gm().get("_course_economies")
	var bg: Dictionary = gm().get("_course_bg_start")
	econ["bg_test"] = {"balance": 1000.0}
	bg["bg_test"] = {"time": float(gm().get("_game_clock")) - 100.0, "rate": 10.0}   # 100 game-seconds at $10/s
	var e0: float = gm().call("get_empire_balance")
	var got: float = gm().call("_accrue_background", "bg_test")
	check(absf(got - 1000.0) < 1.0, "100 game-seconds × $10/s = $1000 earned (got %.0f)" % got)
	check(absf(float(gm().call("get_empire_balance")) - e0 - 200.0) < 1.0, "20% to the empire pool")
	check(absf(float((econ["bg_test"] as Dictionary)["balance"]) - 1800.0) < 1.0, "80% to the course's own balance")
	check(not bg.has("bg_test"), "tracking cleared")
	econ.erase("bg_test")

func test_world_map_invest_button() -> void:
	var em: Node = tree.root.get_node("EconomyManager")
	em.set("balance", 10000.0)
	await goto_state(gm().GameState.WORLD_MAP)
	await drain_dialogue()
	var wm: Node = ui().get("_cache")["WorldMap"]
	var btn: Button = wm.find_child("InvestBtn", true, false)
	check(btn != null and not btn.disabled, "World Map shows an enabled Invest button")
	if btn:
		var e0: float = gm().call("get_empire_balance")
		var b0: float = em.get("balance")          # running costs tick while screens change
		btn.pressed.emit()
		var moved: float = float(gm().call("get_empire_balance")) - e0
		check(absf(moved - floorf(b0 * 0.5)) < 1.0, "invests half (%.0f of %.0f)" % [moved, b0])
		check(absf(float(em.get("balance")) - (b0 - moved)) < 1.0, "course keeps the other half")
	await goto_state(gm().GameState.GAMEPLAY)
	await quiet_story()

## The chosen game speed survives a trip to the builder (the builder itself
## runs at 1x); it used to reset to 1x every time.
func test_game_speed_restored_after_builder() -> void:
	var gp: Node = ui().get("_cache")["Gameplay"]
	gp.call("_set_time_speed", 2.0)
	await goto_state(gm().GameState.COURSE_BUILDER)
	check(is_equal_approx(Engine.time_scale, 1.0), "builder runs at 1x")
	await goto_state(gm().GameState.GAMEPLAY)
	await quiet_story()
	check(is_equal_approx(Engine.time_scale, 2.0), "back on the course: 2x again")
	gp.call("_set_time_speed", 1.0)
