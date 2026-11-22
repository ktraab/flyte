## Shared unlock-condition checks for World Circuit locations.
## Used by WorldMap (cards) and StoryManager (Chapter 4 trigger) so both agree.
extends RefCounted

static func is_met(key: String) -> bool:
	match key:
		"":                  return true
		"three_star":        return GoalsSystem.is_goal_complete("three_star")
		"five_star":         return GoalsSystem.is_goal_complete("five_star")
		"first_tourney":     return GoalsSystem.is_goal_complete("first_tourney")
		"vip_visit":         return GoalsSystem.is_goal_complete("vip_visit")
		"fifty_players":     return GoalsSystem.is_goal_complete("fifty_players")
		"ten_players":       return GoalsSystem.is_goal_complete("ten_players")
		"first_staff":       return GoalsSystem.is_goal_complete("first_staff")
		"balance_50k":       return GameManager.get_empire_balance() >= 50000.0
		"prestige_regional": return EconomyManager.get_prestige() >= 25.0
	push_warning("CourseUnlocks: unknown unlock key '%s'" % key)
	return false
