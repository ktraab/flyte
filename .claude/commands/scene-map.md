Map the scene hierarchy, signal connections, and EventBus usage in the Flyte project.

Scope: $ARGUMENTS — "ui" for UI screens only, "gameplay" for gameplay scenes, "world" for GameWorld3D, blank for full summary.

Steps:
1. List all .tscn files: find flyte--a-disc-golf-course-builder-and-manager/scenes -name "*.tscn"
2. For each scene, identify root node type and attached script (grep "script =" from .tscn)
3. For each attached .gd script, extract:
   - Signals declared (signal keyword)
   - EventBus signals it emits (EventBus.*.emit)
   - EventBus signals it connects to (EventBus.*.connect)
   - Other scenes/nodes it directly references (potential coupling)

Output format:
```
SceneName.tscn (RootType) → Script.gd
  EMITS:   signal_name, signal_name2
  LISTENS: EventBus.signal_name → handler_func
  WARNS:   [any direct cross-scene refs found]
```

Then show the UIManager screen stack (what screens exist, push vs show behavior).

Finally flag: any signals emitted but never connected anywhere (dead signals), any cross-scene direct node references that should use EventBus instead.
