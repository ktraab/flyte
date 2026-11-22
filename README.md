# Flyte: A Disc Golf Course Builder and Manager

A free disc golf tycoon game. Inherit Uncle Ray's three scruffy holes, build them into a
championship course, run the business, then play rounds on six famous courses around the
world circuit.

- **Build** — paint fairways, rough, sand, water, trees, OB and hills; place tees, baskets and facilities
- **Manage** — green fees, staff, food stands, pro shop, tournaments, VIP touring pros
- **Story** — a seven-chapter campaign from backyard holes to world-class venue
- **Play** — throw your own rounds with realistic disc flight (turn, fade, wind, chain catches, tree kicks)
- **World Circuit** — buy and run more courses, or play away rounds on them

---

## Download and play

Grab the latest build from the [**Releases**](../../releases) page:

| System | File | How to start |
|---|---|---|
| **Windows** 10/11 (64-bit) | `Flyte-windows.zip` | Unzip, double-click `Flyte.exe` |
| **macOS** 11+ (Intel or Apple Silicon) | `Flyte-mac.zip` | Unzip, move the app to Applications, then see below |
| **Linux** (64-bit) | `Flyte-linux.zip` | Unzip, then `chmod +x Flyte.x86_64` and run it |

### "Unknown app" warnings (normal for free indie games)

Flyte isn't signed with a paid Apple or Microsoft certificate, so your computer will warn you the first time.

- **Windows:** "Windows protected your PC" → click **More info** → **Run anyway**.
- **macOS:** right-click (or Control-click) the app → **Open** → **Open**. If macOS says it "can't be opened",
  open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to Flyte.

You only need to do this once.

### Slow computer?

Open **Settings → Graphics** and choose **Low**. The game also lowers graphics automatically if it
notices it's running slow (you can switch that off with **Auto Adjust**). Low uses simpler trees,
no shadows and a lower 3D resolution, so it runs on most laptops.

---

## Controls

| | |
|---|---|
| Move camera | WASD / arrow keys |
| Rotate / tilt camera | Q / E · Page Up / Page Down |
| Zoom | Mouse wheel |
| Build | Pick a tile in the Course Builder and click / drag to paint |
| Undo (builder) | Ctrl+Z |
| Throwing | WASD / right-click to walk · mouse to aim, click to throw · 1–4 pick putter / mid-range / fairway / driver · F backhand ↔ forehand |
| Pause | Esc |

---

## Run from source

1. Install [Godot 4.6.2](https://godotengine.org/download)
2. Open Godot → **Import** → `flyte--a-disc-golf-course-builder-and-manager/project.godot`
3. Press **F5**

Tests: `flyte--a-disc-golf-course-builder-and-manager/tools/run_tests.sh` (runs headless with an isolated save folder).

To export your own builds: **Project → Export** — Windows, macOS and Linux presets are included (install Godot's export templates first).

Developer notes: [`CLAUDE.md`](CLAUDE.md) (architecture), [`DEVLOG.md`](DEVLOG.md) (history), [`STORY.md`](STORY.md) (campaign script), [`GOALS.md`](GOALS.md) (roadmap).

Optional extras (inactive unless configured): GodotSteam for Steam achievements/cloud saves (`addons/godotsteam/`), Supabase for mobile cloud saves (`save_backends/SupabaseBackend.gd`).

---

## License

Code and original game content: [MIT](LICENSE). Third-party art, sounds and fonts keep their own
(free) licenses — see [`CREDITS.md`](CREDITS.md).

Course names are inspired by real disc golf courses; Flyte is a free fan-made game and isn't
affiliated with or endorsed by them.
