Systematically find the root cause of a bug in the Flyte disc golf game.

Bug description: $ARGUMENTS

Investigation steps:
1. Reproduce path — trace the exact sequence of events that triggers the bug (user action → EventBus signals → system responses)
2. Identify suspects — which systems are involved? (GameWorld3D, NPCPlayer, EconomyManager, GoalsSystem, UIManager?)
3. Read the relevant code fully — don't skim
4. Check these common failure modes first:
   - Freed node accessed without is_instance_valid() → null reference crash
   - Signal connected multiple times → doubled effects
   - @onready node not found → null at runtime
   - State machine in wrong state → event ignored silently
   - OB/Rock checked as tile type instead of using is_ob_at() / is_rock_at()
   - EconomyManager not called for balance change → goals/signals not triggered
   - PackedScene child looked up in _ready() before deferred → null
5. If Godot headless can reproduce: run /gdcheck first
6. Propose the fix with exact file:line changes
7. Explain why this fix is correct and won't break related systems

Report: root cause (1 sentence) → fix location → code change needed → regression risk.
