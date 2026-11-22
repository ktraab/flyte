Review GDScript files against this project's architecture rules from CLAUDE.md.

Files to review: $ARGUMENTS
If blank, run: git diff --name-only HEAD~1 HEAD | grep "\.gd$" and review those.

Read each file. Check every violation of these rules — report file:line — RULE — problem — fix:

**Architecture rules (must follow)**
1. NO direct node references between systems — all cross-system comms via EventBus signals
2. NEVER call Input.* directly — use InputHandler autoload
3. ALL balance changes via EconomyManager.earn() or spend() — no direct balance mutation
4. OB and ROCK are overlay layers — never check TileType for OB/Rock; use world.is_ob_at() and world.is_rock_at()
5. Autoload order violated — lower autoload must not reference higher (order: EventBus → PlatformDetector → GameManager → InputHandler → SaveSystem → UIManager → EconomyManager → GoalsSystem → UIAudio)

**Godot 4 correctness**
6. @onready missing — node path in get_node() inside _ready() or _process() instead of @onready var
7. call_deferred pattern missing — PackedScene child lookup in _ready() must use call_deferred("_setup") + find_child(name, true, false)
8. Area3D input_event used without physics_object_picking — needs get_viewport().physics_object_picking = true

**GDScript conventions**
9. Naming — non-snake_case vars/functions, non-PascalCase class names
10. Signal over method call — direct method call between scenes that should be a signal
11. Dead code — unused variables, unreachable branches, signals never connected

**Game-specific**
12. NPC/Staff lifecycle — freed nodes accessed without is_instance_valid() guard
13. Shader parameter set every frame without dirty check
14. EventBus signal emitted in _process() every frame (should be event-driven)

Severity: BLOCKER (crashes/wrong behavior) | ARCH (breaks design) | STYLE (convention).
Sort by severity. Count totals at end.
