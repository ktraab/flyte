# Flyte — Project Goals & Roadmap

Long-term vision and phased delivery plan. Near-term task backlog lives in `DEVLOG.md`. This file is the north star.

---

## Vision

**Flyte** starts as a single-course builder and manager. Once that core loop is polished, the game expands outward — a world map of disc golf destinations, real-world famous courses to visit and challenge, and an overarching storyline that ties it all together. The same desktop game (and save data) syncs to a mobile companion app, with eventual Steam release.

**The core builder is the foundation. Perfect it first. Everything else is built on top of it.**

---

## Phase 1 — Core Course ✅ COMPLETE

**Goal:** One course, fully featured, polished, fun to play and manage.

### Builder
- [x] 100×100 isometric tile grid, 15+ tile types
- [x] Elevation, trees, sand, rock, OB overlays
- [x] Hole Architect mode (routing tool, templates, grading/critique)
- [x] Undo stack
- [x] Save/load multiple course layouts (slot system)
- [x] Hole preview thumbnail in course builder

### Management
- [x] EconomyManager: income/expense, day/season cycle
- [x] Staff system with 3 types, 3 tiers, upgrade costs
- [x] Course condition decay + repair
- [x] Marketing/ad spend → spawn rate multiplier
- [x] Events calendar (4 event types)
- [x] 14-day financial history chart
- [x] Tournament system
- [x] Membership system
- [x] Prestige system
- [x] Facility upgrade tiers (e.g. Restroom → Deluxe Restroom)
- [x] Loan/financing system for expensive builds

### Gameplay / Play-Test Mode
- [x] Click-to-throw disc arc, 4 disc types
- [x] WASD player movement, camera occlusion
- [x] Per-hole scoring, scorecard
- [x] Full 18-hole round scorecard screen
- [x] Disc customization persistence (saved per session)

### Polish / Platform
- [x] Music tracks (season-aware routing; Morning_in_the_Fairway.mp3 active)
- [x] Settings: control remapping, graphics quality
- [x] Accessibility: UI scale slider, colorblind palette option
- [x] Mobile touch optimization pass (pan magnitude fixed, pinch-zoom, all touch targets ≥44px)
- [x] Steam achievements wired to GoalsSystem
- [x] GodotSteam addon installed and loading on macOS (release dylib used for debug runs — no debug build ships)

---

## Phase 2 — World Circuit & Real-World Courses

**Goal:** Player travels a disc golf world tour circuit, visiting and challenging iconic courses. The single-course builder becomes one node on a larger world.

### World Circuit Hub ✅ (implemented Phase 1 bridge)
- `GameState.WORLD_MAP` added; `WorldMap.gd` screen fully built
- Stylized tour circuit map: 3-column location grid + detail panel
- 11 locations across 4 types: courses, shops, organizations, media
- Accessible from MainMenu ("World Circuit" button) and Gameplay HUD ("Circuit" button)
- All locations except home course locked behind in-game unlock conditions

### Location Roster (as implemented in `WorldMap.gd` / `GameManager.COURSE_PRICES`)

| Location | Type | Unlock condition | Price (empire balance) |
|---|---|---|---|
| Your Course | home | Always | — |
| **Maple Hill** (`maple_ridge`) | course | 3★ home rating | $25,000 |
| **Winthrop Gold** | course | First tournament | $30,000 |
| **Idlewild** | course | First VIP visit | $35,000 |
| **Disc Side of Heaven** | course | 50 players welcomed | $40,000 |
| **Krokhol** | course | $50K empire balance | $45,000 |
| **Ale DGC — White** | course | 5★ home rating | $50,000 |
| **Disc Depot** | shop | 10 players welcomed | tiers 2k/6k/15k |
| **The Bag Shack** | shop | First staff hired | tiers |
| **WDGA HQ** | org | First tournament | tiers |
| **Bromez** | media | Regional prestige (25+) | tiers |

Unlock checks live in `core/data/CourseUnlocks.gd` (shared by WorldMap and StoryManager).

Owned courses keep their builds (fixed 2026-11-20 — they used to reset to the preset on every visit).

### Phase 2 Remaining (course visits not yet built)
- Each world course is a pre-built `GameWorld3D` scene loaded read-only
- Player visits, plays a full round, earns prestige + prize money on home course
- `CourseRegistry` autoload: list of all courses, unlock state, best score
- `GameManager` gets `VISITING_COURSE` state
- Save system extended to persist unlock progress + best scores
- Shop/org/media destinations get functional implementations (disc upgrades, WDGA affiliation, Jomex filming deal)

---

## Phase 3 — Storyline / Narrative Campaign ✅ Playable (art pending)

**Goal:** Give players a reason to care beyond the numbers. A narrative arc that motivates building, traveling, and improving.

### Built
- [x] `StoryManager` autoload — chapters 0–6 advance **strictly in order** (no skipped beats), triggers match the table below
- [x] Beat queue — one dialogue at a time, only in gameplay states; world pauses while a beat is open; pending queue persists
- [x] All dialogue written from `STORY.md` (letter, newspaper, memorial-card styles; toast beats for small moments)
- [x] Ch2 Diana buyout choice (Decline / Consider It) + Ch3 Marcus choice — cosmetic, recorded in save
- [x] Newspaper beats (Ch1, Ch3) and Ray's opening letter (Ch0); final memorial card (Ch6)
- [x] Legacy saves migrate silently to the chapter already earned
- [x] Circuit button gated until Ch4 (or if the player already owns a second course)
- [x] Persistence — `[story] data` in `user://settings.cfg`
- [x] Smoke tests (`tools/run_tests.sh`) cover progression, queue, migration, choices, save round-trip

### Remaining
- [x] Ch0 starter holes — Uncle Ray's 3 rough (~2★) holes on a brand-new game
- [x] Player name entry after Ray's letter (default "Coach"); `{name}` in beat text
- [x] Portraits for every on-screen speaker — generated flat-vector set (`tools/gen_portraits.py`)
- [x] Diana's bench toast after Ch5; music fades under the final card
- [x] "Beat 5 circuit courses" = 5 owned circuit courses at WDGA certification (9+ holes, 3.5★, restroom)
- [x] Final character portrait art (generated; commissioned art optional — drop-in same filenames)
- [ ] Optional: NPC asking about Ray's disc bag

### Story Premise
> You inherit a rundown disc golf course from a late family member. Armed with $10,000 and a dream, you rebuild it from an overgrown field into a world-class venue — then take your skills on the road to challenge the best courses on Earth.

### Story Beats (rough arc)

| Chapter | Trigger | Event |
|---|---|---|
| 0 — Inheritance | Game start | Cutscene: inherit the course, $10K, 3 holes already roughed in |
| 1 — First Steps | Complete 6-hole course | Local newspaper writes about reopening; first VIP visit |
| 2 — Word Gets Out | Reach Regional prestige | Rival course owner makes a buyout offer (refuse = story continues) |
| 3 — Going Pro | Host first tournament | State disc golf association invites you to a sanctioned event |
| 4 — Road Trip | First circuit course unlocked (+1 in-game day after Ch3) | Player's first away challenge match at a real-world course |
| 5 — National Stage | Reach National prestige | National championship offer — course must meet standards |
| 6 — World Class | World Class prestige + own 5 circuit courses | Final cutscene: course inducted into world rankings |

### Characters
- **Uncle Ray** (deceased) — left the course + $10K; 3 rough holes already built; disc bag stays on fence
- **Diana Cross** — rival owner; buyout offer in Ch2; becomes background ally after Ch5
- **Marcus Bell** — WDGA regional rep; tournament gateway; recurring ally
- **Jess Nakamura** — first VIP touring pro; social media catalyst; Ch4 World Map invitation
- **Dani Walsh** — local reporter; newspaper beats at Ch1/3/6

Full narrative bible: `STORY.md`

### Implementation Notes
- Story beats triggered via `GoalsSystem` (already has a completion/reward architecture)
- Dialogue/cutscene system: simple `DialogueOverlay` screen — text + character portrait, no voice acting initially
- No branching narrative — linear arc; Ch2 has cosmetic choice (Decline vs Consider It), same outcome
- Add `StoryManager` autoload to track chapter, trigger beats, gate world map access
- `StoryManager` hooks: `first_hole`, `six_holes`, prestige="Regional", `first_tourney`, WorldMap unlock, prestige="National", prestige="World Class"+5 circuit wins

---

## Phase 4 — Steam Release (Windows + Mac)

**Goal:** Ship on Steam. The infrastructure is already partially in place.

### What's Already Done
- `SteamCloudBackend.gd` exists (skeleton — needs GodotSteam addon)
- `LocalSaveBackend.gd` works on desktop
- GL Compatibility renderer = runs on most hardware

### What Remains
- ✅ GodotSteam loads on macOS (quarantine cleared 2026-11-20; local debug config points at the release dylib)
- Install and wire GodotSteam addon (`addons/godotsteam/`)
- Fill in Steam App ID in `project.godot`
- Wire GoalsSystem completions → Steam achievements via `Steam.setAchievement()`
- Steam Cloud save: implement `SteamCloudBackend.sync()` / `load()`
- Steam store assets: capsule art, screenshots, trailer
- Windows export profile (requires Windows runner or CI)
- Mac export profile + code signing (Apple Developer account)
- Steam build upload via Steamworks SDK or Butler
- Beta test branch on Steam before public launch

### Monetization
- One-time purchase (no DLC at launch)
- Future: real-world course packs as paid DLC

---

## Phase 5 — Mobile App (iOS + Android) with Cross-Platform Sync

**Goal:** Mobile version of Flyte that shares save data with the desktop game. Same core experience, touch-optimized UI.

### Sync Architecture (already designed)
```
Desktop save  ←→  Supabase (cloud)  ←→  Mobile save
```
- `SupabaseBackend.gd` exists — configure URL + anon key
- Offline queue (`user://offline_queue.json`) handles no-network sessions
- Conflict resolution: last-write-wins per key (upgrade to merge strategy if needed)

### Mobile-Specific Work
- Touch input: `TouchInputHandler.gd` exists — needs end-to-end testing
  - Drag-to-pan (two-finger)
  - Pinch-to-zoom
  - Tap-to-place tiles (CourseBuilder)
  - Swipe disc throw (play-test mode)
- UI scaling: add `UIScale` setting (1×/1.5×/2× for tablet vs phone)
- Reduced tile grid on mobile? Or keep 100×100 with aggressive LOD
- Battery: cap framerate to 30fps on mobile when idle
- iOS export: Xcode project, provisioning profile, App Store Connect setup
- Android export: keystore, Google Play Console, target API level 34+

### Mobile-Exclusive Features (optional, post-launch)
- Push notifications: "Your tournament completed! +$2,400"
- Widget: daily income snapshot on home screen
- Haptic feedback on disc throw / purchase confirmation

---

## Platform Target Summary

| Platform | Status | Backend | Notes |
|---|---|---|---|
| Windows (Steam) | Phase 4 | Local + Steam Cloud | GodotSteam needed |
| Mac (Steam) | Phase 4 | Local + Steam Cloud | Code signing needed |
| iOS | Phase 5 | Local + Supabase | Touch pass needed |
| Android | Phase 5 | Local + Supabase | Keystore needed |

---

## Architecture Decisions Made in Advance

These are choices already baked into the codebase that will scale to all phases:

| Decision | Reason |
|---|---|
| `GameWorld3D` is a self-contained scene | Lets Phase 2 load any course as a drop-in |
| `InputHandler` swaps Desktop↔Touch | Mobile works without touching game code |
| `SaveSystem` picks backend by platform | Adding Supabase or Steam Cloud is one-line |
| `EventBus` for all cross-system signals | New systems (StoryManager, CourseRegistry) plug in without touching existing code |
| `GoalsSystem` is generic notify/check | Story beats in Phase 3 reuse the same architecture |
| GL Compatibility renderer | Runs on mobile GPU without rewrite |
