## A disc golf course: metadata + ordered list of holes.
class_name CourseData
extends Resource

@export var course_id: String = ""
@export var course_name: String = "New Course"
@export var location: String = ""
@export var holes: Array[HoleData] = []
@export var created_at: String = ""
@export var thumbnail_path: String = ""

## Computed; call recalculate_par() after editing holes.
var par_total: int = 0

func recalculate_par() -> int:
	par_total = 0
	for hole in holes:
		par_total += hole.par
	return par_total

func add_hole() -> HoleData:
	var h := HoleData.new()
	h.hole_number = holes.size() + 1
	holes.append(h)
	return h

func remove_hole(index: int) -> void:
	holes.remove_at(index)
	for i in holes.size():
		holes[i].hole_number = i + 1

func serialize() -> Dictionary:
	var hole_array := []
	for h in holes:
		hole_array.append(h.serialize())
	return {
		"course_id":      course_id,
		"course_name":    course_name,
		"location":       location,
		"par_total":      recalculate_par(),
		"created_at":     created_at,
		"thumbnail_path": thumbnail_path,
		"holes":          hole_array,
	}

static func deserialize(d: Dictionary) -> CourseData:
	var c := CourseData.new()
	c.course_id      = d.get("course_id", "")
	c.course_name    = d.get("course_name", "New Course")
	c.location       = d.get("location", "")
	c.par_total      = d.get("par_total", 0)
	c.created_at     = d.get("created_at", "")
	c.thumbnail_path = d.get("thumbnail_path", "")
	for hd in d.get("holes", []):
		c.holes.append(HoleData.deserialize(hd))
	return c
