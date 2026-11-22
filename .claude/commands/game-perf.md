Audit Godot 4 game code for performance problems specific to this project.

Target files (or $ARGUMENTS if specified):
- flyte--a-disc-golf-course-builder-and-manager/scenes/game_world/GameWorld3D.gd (most critical — 150×150 grid, heavy _process)
- flyte--a-disc-golf-course-builder-and-manager/scenes/gameplay/NPCPlayer.gd
- flyte--a-disc-golf-course-builder-and-manager/scenes/gameplay/StaffMember.gd
- flyte--a-disc-golf-course-builder-and-manager/scenes/ui/screens/Gameplay.gd

Read each file fully. Flag these patterns with severity CRITICAL / HIGH / MEDIUM:

**CRITICAL**
- Object/Array/Dictionary allocation inside _process() or _physics_process() every frame
- get_node() / find_child() called inside _process() — must be @onready
- Shader or Material .new() inside loops or _process()
- Signals connected inside _process() (doubles up each frame)

**HIGH**
- String formatting (%, format(), str()) inside _process() with no dirty flag
- Large array iteration every frame with no early exit or dirty flag
- Missing is_instance_valid() guard before accessing potentially freed nodes
- Timer logic using _process() countdown instead of Timer node
- New Vector3/Color/Rect2 created in tight per-frame loops (cache as member vars)

**MEDIUM**
- _physics_process() used when _process() would suffice (no physics needed)
- MultiMesh not used where 10+ identical meshes are placed
- Repeated world.get_tiles_of_type() calls — result should be cached
- Minimap or UI rebuild not throttled with a dirty flag

Report: file:line — severity — problem — recommended fix. Then give an estimated GPU/CPU impact ranking (worst first).
