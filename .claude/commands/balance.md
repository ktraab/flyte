Audit game economy balance for Flyte: A Disc Golf Course Builder and Manager.

Read these files fully:
- flyte--a-disc-golf-course-builder-and-manager/core/economy/EconomyManager.gd
- flyte--a-disc-golf-course-builder-and-manager/autoloads/GoalsSystem.gd
- flyte--a-disc-golf-course-builder-and-manager/scenes/game_world/GameWorld3D.gd (TILE_COSTS, FACILITY_COSTS constants)

Focus: $ARGUMENTS (blank = full audit)

Analyze and report:

**Facility ROI** — For each facility (Parking $1500, Restroom $3000, Food Stand $2500, Pro Shop $8000): at typical NPC flow (10 NPCs/day avg), how many in-game days to break even? Flag if < 2 days (trivial) or > 20 days (too punishing for early game).

**Green Fee Curve** — How does fee scale with course rating? Does higher rating meaningfully reward the player with proportionally more income?

**Tile Cost Proportionality** — Do expensive tiles (TEE $250, BASKET $450, ENTRANCE $500) provide enough rating/revenue benefit to justify cost?

**Goal Rewards** — Are goal reward amounts (GoalsSystem) meaningful relative to what they unlock? First 3 goals critical — too small = feels bad.

**Staff ROI** — Does each staff type (Groundskeeper, Disc Pro, Concessions) pay off within 5–10 in-game days at tier 1?

**Upgrade Tiers** — Are tier 2/3 upgrade costs proportional to the benefit multiplier?

**NPC Spawn Rate vs Income** — At max 10 NPCs with current spawn interval, is income/day enough to progress meaningfully?

For each issue found: current value → suggested value → reasoning. Keep suggestions grounded in tycoon game design principles (early game fast, mid game steady, late game aspirational).
