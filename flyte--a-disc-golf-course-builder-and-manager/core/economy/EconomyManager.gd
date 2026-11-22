## Tracks balance, income from NPCs, maintenance expenses, day cycle, and facility bonuses.
## Autoload — access anywhere as EconomyManager.
extends Node

const DAY_REAL_SECONDS := 60.0
const BASE_EXPENSE     := 5.0
const PER_HOLE_EXPENSE := 0.8

# beginner=0, amateur=1, pro=2
const NPC_TIER_WEIGHTS := [0.50, 0.35, 0.15]
const NPC_TIER_INCOME  := [1.5,  2.5,  5.0]
const NPC_TIER_NAMES   := ["Beginner", "Amateur", "Pro"]

const SEASONAL_INCOME_MULT := {"Spring": 1.00, "Summer": 1.15, "Fall": 0.90, "Winter": 0.70}

## Ray's letter: "I left $10,000 in the account." (Was $25k, which let a new
## player buy 6 holes + every facility in minute one; Ray's 3 holes already
## earn ~$300–600/day idle, so $10k is tight but can't soft-lock.)
const STARTING_BALANCE := 10000.0
var balance: float = STARTING_BALANCE
var income_rate: float = 0.0
var expense_rate: float = BASE_EXPENSE
var current_day: int = 1
var current_season: String = "Spring"
var current_happiness: float = 0.0

var _npc_tiers: Dictionary = {}
var _npc_count: int = 0
var _hole_count: int = 0
var _day_timer: float = 0.0

var _parking_count:    int = 0
var _restroom_count:   int = 0
var _food_stand_count: int = 0
var _pro_shop_count:   int = 0

# Staff
enum StaffType { GROUNDSKEEPER = 0, DISC_PRO = 1, CONCESSIONS = 2 }
const STAFF_MAX:    int   = 5
const STAFF_NAMES:  Array = ["Groundskeeper", "Disc Pro", "Concessions Worker"]
const STAFF_COST:   Array = [500.0, 1200.0, 800.0]
# Balance pass 2026-11: every staff type now pays for itself at tier 1 (was net-negative for Disc Pro + Concessions)
const STAFF_SALARY: Array = [1.0,   2.0,    2.0]
const STAFF_HIRE_LIMIT: Array = [3, 3, 4]
# Tier upgrade costs: [cost_to_tier2, cost_to_tier3] per staff type
const STAFF_UPGRADE_COST: Array = [
    [1500.0, 3500.0],
    [3000.0, 7000.0],
    [2000.0, 5000.0],
]
const STAFF_TIER_NAMES: Array = ["Basic", "Trained", "Expert"]

var _staff_counts: Array = [0, 0, 0]
var _staff_tiers:  Array = [1, 1, 1]   # 1=Basic 2=Trained 3=Expert

# Facility upgrade tiers (1=Basic 2=Upgraded 3=Premium per facility type)
const FACILITY_NAMES: Dictionary = {
    "restroom": "Restroom", "food_stand": "Food Stand",
    "parking": "Parking Lot", "pro_shop": "Pro Shop",
}
const FACILITY_TIER_NAMES: Array = ["Basic", "Upgraded", "Premium"]
const FACILITY_UPGRADE_COST: Dictionary = {
    "restroom":   [3000.0,  8000.0],
    "food_stand": [2500.0,  6000.0],
    "parking":    [2500.0,  6000.0],
    "pro_shop":   [5000.0, 12000.0],
}
var _facility_tiers: Dictionary = {"restroom": 1, "food_stand": 1, "parking": 1, "pro_shop": 1}

# Loan/financing
const LOAN_OPTIONS: Array = [
    {"amount": 5000.0,  "total": 5750.0,  "daily": 25.0,  "label": "Small  — $5,000"},
    {"amount": 15000.0, "total": 17500.0, "daily": 60.0,  "label": "Medium — $15,000"},
    {"amount": 30000.0, "total": 35000.0, "daily": 100.0, "label": "Large  — $30,000"},
]
var _loan_balance: float = 0.0
var _loan_daily_payment: float = 0.0

# Marketing
const MARKETING_BUDGET_MAX := 500.0
var _marketing_budget: float = 0.0   # weekly spend budget

# Events
const EVENTS: Dictionary = {
    "Discount Day": {
        "desc": "50% green fees all day. +50% player attraction.",
        "duration": 1, "cooldown": 7, "cost": 0.0,
        "req_pro_shop": 0, "req_restroom": 0, "req_food_stand": 0, "req_holes": 0,
    },
    "Pro Invitational": {
        "desc": "Elite pros visit. Big prestige boost. Requires Pro Shop.",
        "duration": 1, "cooldown": 14, "cost": 500.0,
        "req_pro_shop": 1, "req_restroom": 0, "req_food_stand": 0, "req_holes": 0,
    },
    "Night Golf": {
        "desc": "+30% income all sources. Requires Restroom + Food Stand.",
        "duration": 1, "cooldown": 7, "cost": 200.0,
        "req_pro_shop": 0, "req_restroom": 1, "req_food_stand": 1, "req_holes": 0,
    },
    "Charity Round": {
        "desc": "Massive prestige boost. Requires 9+ holes. 2-day event.",
        "duration": 2, "cooldown": 30, "cost": 300.0,
        "req_pro_shop": 0, "req_restroom": 0, "req_food_stand": 0, "req_holes": 9,
    },
}
var _active_event: String = ""
var _event_timer: float = 0.0          # real seconds remaining
var _event_cooldowns: Dictionary = {}  # event_name -> real seconds cooldown

# Course condition (0–100%)
const CONDITION_DECAY_PER_DAY := 1.0
const REPAIR_BASE_COST  := 500.0
const REPAIR_PER_HOLE   := 100.0
var _course_condition: float = 100.0
var _last_condition_warn: int = -1   # day number of last condition warning (avoids daily spam)

# Financial history — last 14 days of net balance change
var _daily_net_history: Array = []
var _day_start_balance: float = 10000.0

# Tournament
const TOURNAMENT_BURST := 8
const TOURNAMENT_COOLDOWN_SEC := 480.0

var _tournament_cooldown: float = 0.0
var _tournament_active:   bool  = false
var _tournaments_run:     int   = 0

# Membership
const MEMBERSHIP_FEE_DEFAULT := 25.0
const MEMBERSHIP_FEE_MIN := 10.0
const MEMBERSHIP_FEE_MAX := 100.0
const MEMBERSHIP_JOIN_HAPPINESS := 0.65
const MEMBERSHIP_LEAVE_HAPPINESS := 0.38

var _membership_count: int = 0
var _membership_fee: float = MEMBERSHIP_FEE_DEFAULT

# Green fee multiplier (player-adjustable)
const GREEN_FEE_MULT_MIN := 0.5
const GREEN_FEE_MULT_MAX := 3.0
var _green_fee_mult: float = 1.0

# Prestige (0-100)
var _prestige: float = 0.0

# ── Balance knobs (2026-11 balance pass — see DEVLOG) ─────────────────────────
const RATING_FEE_BASE         := 0.70   # green fee multiplier at 0★
const RATING_FEE_PER_STAR     := 0.15   # +15% per star
const DISC_PRO_BONUS_PER_TIER := 0.08   # +8% / 16% / 24% green-fee income per Disc Pro
const CONCESSIONS_PER_STAFF: Array = [3.5, 5.0, 7.0]   # $/s per concessions worker by tier
const FOOD_STAND_INCOME       := 3.0    # $/s per food stand (was 2.0)
const FOOD_STAND_TIER_MULT: Array = [1.0, 1.6, 2.2]
var _course_rating: float = 0.0          # cached from GameWorld3D on facility/hole updates

# Revenue totals by source (for analytics)
var _revenue_total: Dictionary = {
	"green_fee": 0.0, "food": 0.0, "tournament": 0.0, "membership": 0.0
}
var _total_rounds_completed: int = 0

func _ready() -> void:
	var tick_timer := Timer.new()
	tick_timer.wait_time = 1.0
	tick_timer.autostart = true
	tick_timer.timeout.connect(_tick)
	add_child(tick_timer)

	EventBus.npc_arrived.connect(_on_npc_arrived)
	EventBus.npc_left.connect(_on_npc_left)
	# Upkeep/income use the active course's holes and facilities — refresh them
	# on a switch (state stays GAMEPLAY, so the state-change refresh never ran
	# and a new course kept paying the old course's per-hole upkeep).
	EventBus.course_switched.connect(func(_id: String) -> void:
		_update_hole_count()
		_update_facility_counts())
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.round_completed.connect(func(_id: String, _v: bool, _e: float, _h: int): _total_rounds_completed += 1)

# ── Public API ────────────────────────────────────────────────────────────────

func get_npc_capacity_bonus() -> int:
	var rest_tier := _facility_tiers.get("restroom", 1) as int
	var park_tier := _facility_tiers.get("parking", 1) as int
	return _parking_count * park_tier * 2 + _restroom_count * rest_tier + _pro_shop_count * 3

func spend(amount: float, category: String = "general") -> bool:
	if balance < amount:
		EventBus.notification_requested.emit("Not enough funds!", "warning")
		return false
	balance -= amount
	EventBus.expense_incurred.emit(amount, category)
	EventBus.balance_changed.emit(balance)
	return true

func earn(amount: float, source: String = "green_fee") -> void:
	balance += amount
	if _revenue_total.has(source):
		_revenue_total[source] += amount
	EventBus.income_received.emit(amount, source)
	EventBus.balance_changed.emit(balance)
	GoalsSystem.notify_balance(balance)

func hire_staff(type: int) -> bool:
	if _staff_counts[type] >= (STAFF_HIRE_LIMIT[type] as int):
		EventBus.notification_requested.emit("No more %s slots!" % STAFF_NAMES[type], "warning")
		return false
	if not spend(STAFF_COST[type] as float, "staff"):
		return false
	_staff_counts[type] += 1
	_recalculate_rates()
	EventBus.staff_hired.emit(type)
	EventBus.notification_requested.emit("%s hired!" % STAFF_NAMES[type], "info")
	return true

func fire_staff(type: int) -> bool:
	if _staff_counts[type] <= 0:
		return false
	_staff_counts[type] -= 1
	_recalculate_rates()
	EventBus.staff_fired.emit(type)
	return true

func get_staff_count(type: int) -> int:
	return _staff_counts[type] as int

func get_staff_tier(type: int) -> int:
	return _staff_tiers[type] as int

func get_upgrade_cost(type: int) -> float:
	var tier: int = _staff_tiers[type] as int
	if tier >= 3:
		return -1.0
	return STAFF_UPGRADE_COST[type][tier - 1] as float

func upgrade_staff(type: int) -> bool:
	var tier: int = _staff_tiers[type] as int
	if tier >= 3:
		EventBus.notification_requested.emit("Already at Expert tier!", "warning")
		return false
	if _staff_counts[type] <= 0:
		EventBus.notification_requested.emit("Hire staff first!", "warning")
		return false
	var cost: float = STAFF_UPGRADE_COST[type][tier - 1] as float
	if not spend(cost, "staff"):
		return false
	_staff_tiers[type] = tier + 1
	_recalculate_rates()
	EventBus.staff_upgraded.emit(type, _staff_tiers[type])
	EventBus.notification_requested.emit(
		"%s upgraded to %s!" % [STAFF_NAMES[type] as String, STAFF_TIER_NAMES[_staff_tiers[type] - 1] as String],
		"info")
	return true

# ── Facility upgrade tiers ────────────────────────────────────────────────────

func get_facility_tier(key: String) -> int:
	return _facility_tiers.get(key, 1) as int

func get_facility_upgrade_cost(key: String) -> float:
	var tier := get_facility_tier(key)
	if tier >= 3:
		return -1.0
	var costs: Array = FACILITY_UPGRADE_COST.get(key, []) as Array
	if costs.is_empty():
		return -1.0
	return costs[tier - 1] as float

func upgrade_facility(key: String) -> bool:
	var tier := get_facility_tier(key)
	if tier >= 3:
		EventBus.notification_requested.emit("Already at Premium tier!", "warning")
		return false
	var count_map := {"restroom": _restroom_count, "food_stand": _food_stand_count,
	                  "parking": _parking_count, "pro_shop": _pro_shop_count}
	if count_map.get(key, 0) as int <= 0:
		EventBus.notification_requested.emit("Build a %s first!" % FACILITY_NAMES.get(key, key), "warning")
		return false
	var cost := get_facility_upgrade_cost(key)
	if not spend(cost, "facility"):
		return false
	_facility_tiers[key] = tier + 1
	_recalculate_rates()
	EventBus.facility_upgraded.emit(key, tier + 1)
	var tier_name: String = FACILITY_TIER_NAMES[_facility_tiers[key] - 1] as String
	EventBus.notification_requested.emit(
		"%s upgraded to %s!" % [FACILITY_NAMES.get(key, key) as String, tier_name], "info")
	return true

# ── Loan / financing ──────────────────────────────────────────────────────────

func get_loan_balance() -> float:
	return _loan_balance

func get_loan_payment_rate() -> float:
	return _loan_daily_payment

func take_loan(option_idx: int) -> bool:
	if _loan_balance > 0.0:
		EventBus.notification_requested.emit("Repay existing loan first!", "warning")
		return false
	if option_idx < 0 or option_idx >= LOAN_OPTIONS.size():
		return false
	var opt: Dictionary = LOAN_OPTIONS[option_idx] as Dictionary
	_loan_balance = opt["total"] as float
	_loan_daily_payment = opt["daily"] as float
	balance += opt["amount"] as float
	EventBus.balance_changed.emit(balance)
	_recalculate_rates()
	EventBus.notification_requested.emit(
		"Loan: +$%.0f received. Repay $%.0f at $%.0f/day." % [
			opt["amount"] as float, opt["total"] as float, opt["daily"] as float], "info")
	return true


# ── Marketing API ──────────────────────────────────────────────────────────────

func get_marketing_budget() -> float:
	return _marketing_budget

func set_marketing_budget(budget: float) -> void:
	_marketing_budget = clampf(budget, 0.0, MARKETING_BUDGET_MAX)
	EventBus.marketing_changed.emit(_marketing_budget)

## Green-fee price elasticity: above-standard fees slow arrivals (fee^1.5),
## discounts speed them up. Makes the fee slider a real trade-off — the revenue
## sweet spot is roughly 1.2–1.5× instead of "always max it".
const FEE_ELASTICITY := 1.5

func get_spawn_rate_mult() -> float:
	var base := 1.0 + (_marketing_budget / MARKETING_BUDGET_MAX) * 0.75
	base /= pow(_green_fee_mult, FEE_ELASTICITY)
	if _active_event == "Discount Day":
		base *= 1.5
	elif _active_event == "Pro Invitational":
		base *= 1.2
	return base

# ── Events API ────────────────────────────────────────────────────────────────

func get_event_names() -> Array:
	return EVENTS.keys()

func get_event_info(event_name: String) -> Dictionary:
	return EVENTS.get(event_name, {})

func can_start_event(event_name: String) -> Dictionary:
	if _active_event != "":
		return {"can": false, "reason": "Event already running: %s" % _active_event}
	var cd: float = _event_cooldowns.get(event_name, 0.0) as float
	if cd > 0.0:
		return {"can": false, "reason": "Cooldown: %.0fs" % cd}
	var ev: Dictionary = EVENTS.get(event_name, {})
	if ev.is_empty():
		return {"can": false, "reason": "Unknown event"}
	if ev.get("req_pro_shop", 0) as int > 0 and _pro_shop_count <= 0:
		return {"can": false, "reason": "Requires Pro Shop"}
	if ev.get("req_restroom", 0) as int > 0 and _restroom_count <= 0:
		return {"can": false, "reason": "Requires Restroom"}
	if ev.get("req_food_stand", 0) as int > 0 and _food_stand_count <= 0:
		return {"can": false, "reason": "Requires Food Stand"}
	var req_holes: int = ev.get("req_holes", 0) as int
	if req_holes > 0 and _hole_count < req_holes:
		return {"can": false, "reason": "Requires %d holes (have %d)" % [req_holes, _hole_count]}
	var cost: float = ev.get("cost", 0.0) as float
	if cost > balance:
		return {"can": false, "reason": "Not enough funds ($%.0f)" % cost}
	return {"can": true, "reason": ""}

func start_event(event_name: String) -> void:
	var check: Dictionary = can_start_event(event_name)
	if not check.get("can", false) as bool:
		EventBus.notification_requested.emit(check.get("reason", "Cannot start event") as String, "warning")
		return
	var ev: Dictionary = EVENTS.get(event_name, {})
	var cost: float = ev.get("cost", 0.0) as float
	if cost > 0.0:
		spend(cost, "events")
	_active_event = event_name
	var duration_days: int = ev.get("duration", 1) as int
	_event_timer = float(duration_days) * DAY_REAL_SECONDS
	_recalculate_rates()
	EventBus.event_started.emit(event_name)
	EventBus.notification_requested.emit("Event started: %s!" % event_name, "info")

func get_active_event() -> String:
	return _active_event

func get_event_timer() -> float:
	return _event_timer

func get_event_cooldown(event_name: String) -> float:
	return _event_cooldowns.get(event_name, 0.0) as float

# ── Course Condition API ───────────────────────────────────────────────────────

func get_course_condition() -> float:
	return _course_condition

func get_repair_cost() -> float:
	return REPAIR_BASE_COST + float(_hole_count) * REPAIR_PER_HOLE

func repair_course() -> void:
	var cost := get_repair_cost()
	if not spend(cost, "maintenance"):
		return
	_course_condition = 100.0
	_last_condition_warn = -1
	EventBus.course_condition_changed.emit(_course_condition)
	EventBus.notification_requested.emit("Course restored to 100% condition!", "info")

# ── Financial History API ──────────────────────────────────────────────────────

func get_daily_net_history() -> Array:
	return _daily_net_history.duplicate()

func can_start_tournament() -> bool:
	if not GameManager.world:
		return false
	var world := GameManager.world as GameWorld3D
	return (world.get_holes_info().size() >= 6
			and world.get_course_rating() >= 2.0
			and _tournament_cooldown <= 0.0
			and not _tournament_active)

func start_tournament() -> void:
	if not can_start_tournament():
		EventBus.notification_requested.emit("Tournament requirements not met!", "warning")
		return
	_tournament_active = true
	_tournaments_run  += 1
	_tournament_cooldown = TOURNAMENT_COOLDOWN_SEC
	EventBus.tournament_started.emit()
	EventBus.notification_requested.emit("Tournament started! Extra players incoming!", "info")
	if GameManager.world:
		for i in TOURNAMENT_BURST:
			(GameManager.world as GameWorld3D).call_deferred("_try_spawn_npc")
	var prize := _calc_tournament_prize()
	var t := get_tree().create_timer(90.0)
	t.timeout.connect(func() -> void:
		_tournament_active = false
		earn(prize, "tournament")
		EventBus.tournament_completed.emit(prize)
		EventBus.notification_requested.emit("Tournament complete! Prize: $%s" % _fmt_prize(prize), "info")
		_recalculate_prestige()
	)

func get_tournament_cooldown() -> float:
	return _tournament_cooldown

func is_tournament_active() -> bool:
	return _tournament_active

# ── Membership API ─────────────────────────────────────────────────────────────

func get_membership_count() -> int:
	return _membership_count

func get_membership_fee() -> float:
	return _membership_fee

func get_membership_monthly_income() -> float:
	return float(_membership_count) * _membership_fee

func set_membership_fee(fee: float) -> void:
	_membership_fee = clampf(fee, MEMBERSHIP_FEE_MIN, MEMBERSHIP_FEE_MAX)
	_recalculate_rates()
	EventBus.membership_changed.emit(_membership_count, _membership_fee)

# ── Prestige API ───────────────────────────────────────────────────────────────

func get_prestige() -> float:
	return _prestige

func get_prestige_tier() -> String:
	if   _prestige >= 75.0: return "World Class"
	elif _prestige >= 50.0: return "National"
	elif _prestige >= 25.0: return "Regional"
	else:                   return "Local"

# ── Green Fee API ──────────────────────────────────────────────────────────────

func get_green_fee_mult() -> float:
	return _green_fee_mult

func set_green_fee_mult(mult: float) -> void:
	_green_fee_mult = clampf(mult, GREEN_FEE_MULT_MIN, GREEN_FEE_MULT_MAX)
	_recalculate_rates()

# ── Analytics API ──────────────────────────────────────────────────────────────

func get_revenue_total() -> Dictionary:
	return _revenue_total.duplicate()

func get_npc_tier_counts() -> Array:
	var counts := [0, 0, 0]
	for npc_id in _npc_tiers:
		var tier: int = _npc_tiers[npc_id] as int
		counts[tier] += 1
	return counts

func get_total_rounds() -> int:
	return _total_rounds_completed

func get_tournaments_run() -> int:
	return _tournaments_run

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	return {
		"balance":        balance,
		"current_day":    current_day,
		"staff":          _staff_counts.duplicate(),
		"staff_tiers":    _staff_tiers.duplicate(),
		"tourney_cd":     _tournament_cooldown,
		"tourney_run":    _tournaments_run,
		"membership_count": _membership_count,
		"membership_fee":   _membership_fee,
		"green_fee_mult":   _green_fee_mult,
		"revenue_total":    _revenue_total.duplicate(),
		"total_rounds":     _total_rounds_completed,
		"marketing_budget": _marketing_budget,
		"course_condition": _course_condition,
		"event_cooldowns":  _event_cooldowns.duplicate(),
		"facility_tiers":   _facility_tiers.duplicate(),
		"loan_balance":     _loan_balance,
		"loan_payment":     _loan_daily_payment,
	}

func deserialize(data: Dictionary) -> void:
	balance           = data.get("balance", STARTING_BALANCE)
	current_day       = data.get("current_day", 1)
	current_season    = _season_for_day(current_day)
	var s: Array      = data.get("staff", [0, 0, 0])
	for i in mini(s.size(), 3):
		_staff_counts[i] = s[i] as int
	var st: Array = data.get("staff_tiers", [1, 1, 1])
	for i in mini(st.size(), 3):
		_staff_tiers[i] = clampi(st[i] as int, 1, 3)
	_tournament_cooldown = data.get("tourney_cd", 0.0)
	_tournaments_run     = data.get("tourney_run", 0)
	_membership_count    = data.get("membership_count", 0)
	_membership_fee      = data.get("membership_fee", MEMBERSHIP_FEE_DEFAULT)
	_green_fee_mult      = data.get("green_fee_mult", 1.0)
	_total_rounds_completed = data.get("total_rounds", 0)
	var rt: Dictionary = data.get("revenue_total", {})
	for k in rt:
		if _revenue_total.has(k):
			_revenue_total[k] = rt[k] as float
	_marketing_budget  = data.get("marketing_budget", 0.0)
	_course_condition  = data.get("course_condition", 100.0)
	_event_cooldowns   = data.get("event_cooldowns", {}).duplicate()
	var ft: Dictionary = data.get("facility_tiers", {}) as Dictionary
	for k in _facility_tiers:
		if ft.has(k):
			_facility_tiers[k] = clampi(ft[k] as int, 1, 3)
	_loan_balance      = data.get("loan_balance", 0.0) as float
	_loan_daily_payment = data.get("loan_payment", 0.0) as float
	_day_start_balance = balance
	_recalculate_rates()
	EventBus.balance_changed.emit(balance)

func get_net_income_rate() -> float:
	return income_rate - expense_rate

# ── Internals ─────────────────────────────────────────────────────────────────

func _tick() -> void:
	if GameManager.is_away_round():
		return  # course clock stops while you're away on the circuit
	var net := income_rate - expense_rate
	if net != 0.0:
		balance += net
		EventBus.balance_changed.emit(balance)
	if income_rate > 0.0:
		EventBus.rate_income_ticked.emit(income_rate)
	# Track food income portion for analytics (matches _recalculate_rates formula)
	var concess_tier: int = _staff_tiers[StaffType.CONCESSIONS] as int
	var food_concess_mult := 1.0 + float(concess_tier - 1) * 0.40
	var food_concess_pp: float = CONCESSIONS_PER_STAFF[concess_tier - 1]
	var food_fs_mult: float = FOOD_STAND_TIER_MULT[(_facility_tiers.get("food_stand", 1) as int) - 1]
	var food_income: float = (float(_food_stand_count) * FOOD_STAND_INCOME * food_concess_mult * food_fs_mult
		+ float(_staff_counts[StaffType.CONCESSIONS]) * food_concess_pp) \
		* (0.60 + current_happiness * 0.80) \
		* (SEASONAL_INCOME_MULT.get(current_season, 1.0) as float)
	_revenue_total["food"] = _revenue_total.get("food", 0.0) + maxf(food_income, 0.0)

	# Loan payoff tracking — expense_rate already deducts the payment each tick
	if _loan_balance > 0.0:
		_loan_balance -= _loan_daily_payment / 60.0
		if _loan_balance <= 0.0:
			_loan_balance = 0.0
			_loan_daily_payment = 0.0
			_recalculate_rates()
			EventBus.notification_requested.emit("Loan fully repaid!", "info")

func _on_npc_arrived(npc_id: String) -> void:
	var rng := randf()
	var cumulative := 0.0
	var tier := 0
	var prestige_shift := _prestige / 100.0 * 0.20
	var weights := [
		maxf(0.05, NPC_TIER_WEIGHTS[0] - prestige_shift),
		NPC_TIER_WEIGHTS[1],
		minf(0.50, NPC_TIER_WEIGHTS[2] + prestige_shift),
	]
	for i in weights.size():
		cumulative += weights[i]
		if rng < cumulative:
			tier = i
			break
	_npc_tiers[npc_id] = tier
	_npc_count = _npc_tiers.size()
	_recalculate_rates()

## Players currently on the course (HUD reads this — single source of truth).
func get_player_count() -> int:
	return _npc_tiers.size()

## Count is derived from the id set, so a duplicate or unknown "left" can't
## drift it (it used to leak upward: see GameWorld3D.set_gameplay_mode).
func _on_npc_left(npc_id: String) -> void:
	if not _npc_tiers.has(npc_id):
		return
	_npc_tiers.erase(npc_id)
	_npc_count = _npc_tiers.size()
	_recalculate_rates()

func _on_game_state_changed(new_state: int) -> void:
	if GameManager.is_away_round():
		return  # the world holds the visited course — don't count its holes/rating
	if new_state == GameManager.GameState.GAMEPLAY:
		_update_hole_count()
		_update_facility_counts()
		GoalsSystem.notify_hole_count(_hole_count)
		GoalsSystem.notify_balance(balance)
		if GameManager.world:
			GoalsSystem.notify_rating((GameManager.world as GameWorld3D).get_course_rating())
		_recalculate_prestige()

func _update_hole_count() -> void:
	if GameManager.world:
		_hole_count = (GameManager.world as GameWorld3D).get_holes_info().size()
		_course_rating = (GameManager.world as GameWorld3D).get_course_rating()
		_recalculate_rates()

func _update_facility_counts() -> void:
	if not GameManager.world:
		return
	var world := GameManager.world as GameWorld3D
	var counts := world.get_facility_counts()
	_course_rating    = world.get_course_rating()
	_parking_count    = counts.get("parking", 0)
	_restroom_count   = counts.get("restroom", 0)
	_food_stand_count = counts.get("food_stand", 0)
	_pro_shop_count   = counts.get("pro_shop", 0)
	var new_happiness := world.get_course_happiness()
	if absf(new_happiness - current_happiness) > 0.005:
		current_happiness = new_happiness
		EventBus.happiness_changed.emit(current_happiness)
	_recalculate_rates()
	_recalculate_prestige()

func _recalculate_rates() -> void:
	# Staff tier multipliers
	var disc_pro_tier: int  = _staff_tiers[StaffType.DISC_PRO] as int
	var concess_tier: int   = _staff_tiers[StaffType.CONCESSIONS] as int
	var concess_income_mult := 1.0 + float(concess_tier - 1) * 0.40

	# Better courses command higher green fees: 1★ 0.85×, 3★ 1.15×, 5★ 1.45×
	var rating_mult := RATING_FEE_BASE + _course_rating * RATING_FEE_PER_STAR
	var base_income := 0.0
	for npc_id in _npc_tiers:
		var tier: int = _npc_tiers[npc_id]
		base_income += NPC_TIER_INCOME[tier] * _green_fee_mult * rating_mult
	var ps_tier := _facility_tiers.get("pro_shop", 1) as int
	var ps_bonus := ([0.0, 0.20, 0.40, 0.65] as Array)[ps_tier] as float if _pro_shop_count > 0 else 0.0
	var pro_mult   := (1.0 + ps_bonus
		+ float(_staff_counts[StaffType.DISC_PRO]) * DISC_PRO_BONUS_PER_TIER * float(disc_pro_tier))
	# Overpricing sours the mood a little (on top of fewer arrivals).
	var fee_mood   := 1.0 - 0.12 * maxf(_green_fee_mult - 1.0, 0.0)
	var happy_mult := (0.60 + current_happiness * 0.80) * GameManager.get_happiness_mult() * fee_mood
	var season_mult: float = SEASONAL_INCOME_MULT.get(current_season, 1.0) as float
	var concess_per_staff: float = CONCESSIONS_PER_STAFF[concess_tier - 1]
	var concess_bonus := float(_staff_counts[StaffType.CONCESSIONS]) * concess_per_staff
	var fs_tier_mult := FOOD_STAND_TIER_MULT[(_facility_tiers.get("food_stand", 1) as int) - 1] as float
	var flat_income   := float(_food_stand_count) * FOOD_STAND_INCOME * concess_income_mult * fs_tier_mult + concess_bonus
	# Membership dues are paid once per day in _tick_membership() — not here too
	# (they used to be counted in both places).
	var media_per_sec := GameManager.get_media_daily_income() / 60.0
	income_rate = (((base_income * pro_mult + flat_income) * happy_mult) * season_mult
		+ media_per_sec) * GameManager.get_pro_shop_income_mult()

	# Course condition income multiplier
	var cond_mult := 1.0
	if _course_condition < 75.0:
		cond_mult = 0.95 - (75.0 - _course_condition) / 100.0 * 0.40
		cond_mult = clampf(cond_mult, 0.60, 0.95)
	income_rate *= cond_mult

	# Active event modifiers
	if _active_event == "Discount Day":
		income_rate *= 0.5     # half green fees, but more players via spawn mult
	elif _active_event == "Night Golf":
		income_rate *= 1.30
	elif _active_event == "Pro Invitational":
		income_rate *= 1.15

	var staff_salary := 0.0
	for t in 3:
		staff_salary += float(_staff_counts[t]) * float(STAFF_SALARY[t])
	var gk_tier: int = _staff_tiers[StaffType.GROUNDSKEEPER] as int
	var gk_discount_per_staff: float = [0.80, 1.40, 2.20][gk_tier - 1]
	var groundskeeper_discount := minf(float(_staff_counts[StaffType.GROUNDSKEEPER]) * gk_discount_per_staff, 4.0)
	var restroom_reduction := float(_restroom_count) * 0.8
	expense_rate = maxf(0.0, BASE_EXPENSE + float(_hole_count) * PER_HOLE_EXPENSE
		- restroom_reduction - groundskeeper_discount + staff_salary
		+ _loan_daily_payment / 60.0)

func get_prestige_breakdown() -> Dictionary:
	if not GameManager.world:
		return {}
	var world := GameManager.world as GameWorld3D
	var rating    := world.get_course_rating()
	var happiness := current_happiness
	var counts    := world.get_facility_counts()
	var fac_score := minf(
		float(counts.get("restroom",   0)) * 0.25 +
		float(counts.get("food_stand", 0)) * 0.25 +
		(1.0 if counts.get("pro_shop", 0) > 0 else 0.0) +
		float(counts.get("parking",    0)) * 0.10,
		1.0
	)
	var tourney_score := minf(float(_tournaments_run) / 5.0, 1.0)
	var goals_done := 0
	for g in GoalsSystem.get_all_goals():
		if g.get("done", false):
			goals_done += 1
	var goal_score := minf(float(goals_done) / 12.0, 1.0)
	return {
		"rating_pts":    (rating / 5.0) * 35.0,
		"rating_max":    35.0,
		"rating_raw":    rating,
		"happiness_pts": happiness * 30.0,
		"happiness_max": 30.0,
		"happiness_raw": happiness,
		"facility_pts":  fac_score * 20.0,
		"facility_max":  20.0,
		"facility_score":fac_score,
		"facility_counts": counts,
		"tourney_pts":   tourney_score * 10.0,
		"tourney_max":   10.0,
		"tourneys_run":  _tournaments_run,
		"tourneys_needed": 5,
		"goal_pts":      goal_score * 5.0,
		"goal_max":      5.0,
		"goals_done":    goals_done,
		"goals_total":   12,
		"total":         _prestige,
	}

func _recalculate_prestige() -> void:
	if not GameManager.world:
		return
	var world := GameManager.world as GameWorld3D
	var rating    := world.get_course_rating()
	var happiness := current_happiness
	var counts    := world.get_facility_counts()
	var fac_score := minf(
		float(counts.get("restroom",   0)) * 0.25 +
		float(counts.get("food_stand", 0)) * 0.25 +
		(1.0 if counts.get("pro_shop", 0) > 0 else 0.0) +
		float(counts.get("parking",    0)) * 0.10,
		1.0
	)
	var tourney_score := minf(float(_tournaments_run) / 5.0, 1.0)
	var goals_done := 0
	for g in GoalsSystem.get_all_goals():
		if g.get("done", false):
			goals_done += 1
	var goal_score := minf(float(goals_done) / 12.0, 1.0)
	var new_prestige := clampf(
		(rating / 5.0) * 35.0 +
		happiness       * 30.0 +
		fac_score       * 20.0 +
		tourney_score   * 10.0 +
		goal_score       * 5.0,
		0.0, 100.0
	)
	if absf(new_prestige - _prestige) >= 0.5:
		_prestige = new_prestige
		EventBus.prestige_changed.emit(_prestige)

func _process(delta: float) -> void:
	if GameManager.is_away_round():
		return
	_day_timer += delta
	if _day_timer >= DAY_REAL_SECONDS:
		_day_timer -= DAY_REAL_SECONDS
		_day_start_balance = balance
		current_day += 1
		current_season = _season_for_day(current_day)
		EventBus.day_changed.emit(current_day, current_season)
		_tick_membership()
		_tick_condition()
		_recalculate_rates()
		_recalculate_prestige()
		_daily_net_history.push_back(balance - _day_start_balance)
		if _daily_net_history.size() > 14:
			_daily_net_history.pop_front()
	if _tournament_cooldown > 0.0:
		_tournament_cooldown -= delta
	# Event timer
	if _event_timer > 0.0:
		_event_timer -= delta
		if _event_timer <= 0.0:
			_event_timer = 0.0
			var finished := _active_event
			var ev_info: Dictionary = EVENTS.get(finished, {})
			var cooldown_days: int = ev_info.get("cooldown", 7) as int
			_event_cooldowns[finished] = float(cooldown_days) * DAY_REAL_SECONDS
			_active_event = ""
			_recalculate_rates()
			EventBus.event_completed.emit(finished)
			EventBus.notification_requested.emit("Event ended: %s" % finished, "info")
			# Charity Round prestige bonus
			if finished == "Charity Round":
				_prestige = minf(_prestige + 10.0, 100.0)
				EventBus.prestige_changed.emit(_prestige)
	# Event cooldowns
	for ev_name in _event_cooldowns.keys():
		var cd: float = _event_cooldowns[ev_name] as float
		if cd > 0.0:
			_event_cooldowns[ev_name] = maxf(0.0, cd - delta)

func _tick_membership() -> void:
	# Marketing daily spend
	if _marketing_budget > 0.0:
		var daily_ad_cost := _marketing_budget / 7.0
		if balance >= daily_ad_cost:
			balance -= daily_ad_cost
			EventBus.expense_incurred.emit(daily_ad_cost, "marketing")
			EventBus.balance_changed.emit(balance)

	if _pro_shop_count <= 0:
		# memberships require a Pro Shop
		if _membership_count > 0:
			_membership_count = 0
			EventBus.membership_changed.emit(_membership_count, _membership_fee)
		return
	# Collect membership income
	if _membership_count > 0:
		var day_income := float(_membership_count) * _membership_fee / 7.0  # weekly dues
		earn(day_income, "membership")
	# Members join/leave based on happiness
	var max_members := _pro_shop_count * 20 + _parking_count * 5
	if current_happiness >= MEMBERSHIP_JOIN_HAPPINESS and _membership_count < max_members:
		var joins := randi_range(0, 2)
		_membership_count = mini(_membership_count + joins, max_members)
		if joins > 0:
			EventBus.membership_changed.emit(_membership_count, _membership_fee)
	elif current_happiness < MEMBERSHIP_LEAVE_HAPPINESS and _membership_count > 0:
		var leaves := randi_range(1, maxi(1, _membership_count / 5))
		_membership_count = maxi(0, _membership_count - leaves)
		EventBus.membership_changed.emit(_membership_count, _membership_fee)
		if _membership_count == 0:
			EventBus.notification_requested.emit("All members left! Improve happiness.", "warning")

func _tick_condition() -> void:
	var gk_count: float = float(_staff_counts[StaffType.GROUNDSKEEPER])
	var gk_tier: int    = _staff_tiers[StaffType.GROUNDSKEEPER] as int
	var slow_per_gk: float = [0.9, 1.5, 2.4][gk_tier - 1]
	var decay := maxf(0.0, CONDITION_DECAY_PER_DAY - gk_count * slow_per_gk)
	_course_condition = maxf(0.0, _course_condition - decay)
	EventBus.course_condition_changed.emit(_course_condition)
	if _last_condition_warn != current_day:
		if _course_condition < 25.0:
			EventBus.notification_requested.emit("Course condition critical! Repair soon!", "error")
			_last_condition_warn = current_day
		elif _course_condition < 50.0:
			EventBus.notification_requested.emit("Course condition poor. Income and happiness affected.", "warning")
			_last_condition_warn = current_day

func _calc_tournament_prize() -> float:
	if not GameManager.world:
		return 500.0
	var world := GameManager.world as GameWorld3D
	var holes := world.get_holes_info().size()
	var rating := world.get_course_rating()
	var base := 500.0 + float(holes) * 80.0 + rating * 200.0 + _prestige * 5.0
	return base * GameManager.get_tournament_prize_mult()

func _fmt_prize(v: float) -> String:
	if v >= 1000.0: return "%.1fK" % (v / 1000.0)
	return "%.0f" % v

func _season_for_day(day: int) -> String:
	var d := (day - 1) % 120
	if   d < 30: return "Spring"
	elif d < 60: return "Summer"
	elif d < 90: return "Fall"
	else:        return "Winter"
