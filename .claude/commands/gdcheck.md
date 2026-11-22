Run GDScript validation on the Godot project using the headless engine.

Execute and capture output:
```
/Applications/Godot.app/Contents/MacOS/Godot --path flyte--a-disc-golf-course-builder-and-manager --headless --quit 2>&1
```

Wait for it to finish (up to 15 seconds). Filter the output for lines containing: ERROR, SCRIPT ERROR, Parse Error, syntax error, undefined, invalid.

If $ARGUMENTS is a file path (e.g. "scenes/game_world/GameWorld3D.gd"), highlight errors from that file first.

Report:
- Total error count
- Each error: file:line — error message — likely cause
- "CLEAN — no GDScript errors found" if none

Fix any errors found before reporting done.
