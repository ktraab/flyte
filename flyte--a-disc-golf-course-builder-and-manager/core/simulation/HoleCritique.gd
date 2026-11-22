## Hole Architect critique: the HoleScore breakdown as {score, grade, critiques}
## for the Course Builder (score = stars × 20, one line per part + tips), so
## the Architect and the star rating can never disagree. No UI here.
extends RefCounted

static func critique(hole_info: Dictionary) -> Dictionary:
	const HoleScore = preload("res://core/simulation/HoleScore.gd")
	var world := GameManager.world as GameWorld3D
	var s: Dictionary = HoleScore.score(hole_info, world)
	var parts: Dictionary = s["parts"]
	var names := {"length": "Length fits par", "fairway": "Fairway corridor",
		"challenge": "Challenge (hazards)", "framing": "Framing (trees + rough)", "shape": "Shape (dogleg / elevation)"}
	var crits: Array = []
	for k in ["length", "fairway", "challenge", "framing", "shape"]:
		var v: float = parts[k]
		var mark := "[color=green]✓[/color]" if v >= 0.8 else ("[color=yellow]△[/color]" if v >= 0.4 else "[color=red]✗[/color]")
		crits.append("%s %s — %.1f / 1.0" % [mark, names[k], v])
	if float(s["penalty"]) > 0.0:
		crits.append("[color=red]✗[/color] Fairness penalty −%.1f" % float(s["penalty"]))
	for tip in s["tips"]:
		crits.append("[color=yellow]↑[/color] " + str(tip))
	var score := roundi(float(s["stars"]) * 20.0)
	var grade := "F"
	if   score >= 90: grade = "A+"
	elif score >= 80: grade = "A"
	elif score >= 70: grade = "B"
	elif score >= 60: grade = "C"
	elif score >= 50: grade = "D"
	return { score = score, grade = grade, critiques = crits }
