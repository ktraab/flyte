## Decoupled game logic layer. No UI references — emits signals only.
## Owned by GameManager as a child node.
class_name GameSimulation
extends Node

signal hole_completed(hole_index: int, player_id: String, score: int)
signal round_completed(player_id: String, total_score: int, vs_par: int)

var active_course: CourseData

func load_course(course: CourseData) -> void:
	active_course = course

func unload_course() -> void:
	active_course = null

# ── NPC simulation ────────────────────────────────────────────────────────────

## Simulate a full NPC round. skill = 0.0 (beginner) … 1.0 (pro).
func simulate_npc_round(npc_id: String, skill: float = 0.5) -> void:
	if not active_course:
		push_error("GameSimulation: no active course loaded")
		return

	var total := 0
	for i in active_course.holes.size():
		var hole: HoleData = active_course.holes[i]
		var score := _simulate_hole(hole, skill)
		total += score
		hole_completed.emit(i, npc_id, score)
		EventBus.npc_score_recorded.emit(i, score)

	var vs_par := total - active_course.par_total
	round_completed.emit(npc_id, total, vs_par)

func _simulate_hole(hole: HoleData, skill: float) -> int:
	# Higher skill → tighter distribution around par
	var spread := (1.0 - skill) * 3.0 * hole.difficulty
	var offset := int(round(randf_range(-spread, spread + 0.5)))
	return max(1, hole.par + offset)
