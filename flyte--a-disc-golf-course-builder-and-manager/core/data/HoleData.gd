## One disc golf hole. Attach to a CourseData resource.
class_name HoleData
extends Resource

@export var hole_number: int = 1
@export var par: int = 3
@export var distance_meters: float = 100.0
@export_range(0.0, 1.0) var difficulty: float = 0.5

## Designer-rated goals shown in the Hole Design Guide panel (0–5 stars each).
@export var design_goals := {
	"strategic_placement": 0,
	"aesthetic_cohesion":  0,
	"maintenance_cost":    0,
	"fun_factor":          0,
	"replay_value":        0,
}

@export_multiline var description: String = ""

func serialize() -> Dictionary:
	return {
		"hole_number":    hole_number,
		"par":            par,
		"distance_meters": distance_meters,
		"difficulty":     difficulty,
		"design_goals":   design_goals,
		"description":    description,
	}

static func deserialize(d: Dictionary) -> HoleData:
	var h := HoleData.new()
	h.hole_number      = d.get("hole_number", 1)
	h.par              = d.get("par", 3)
	h.distance_meters  = d.get("distance_meters", 100.0)
	h.difficulty       = d.get("difficulty", 0.5)
	h.design_goals     = d.get("design_goals", h.design_goals)
	h.description      = d.get("description", "")
	return h
