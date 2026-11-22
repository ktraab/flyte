# Flyte — Development Log

Running record of what exists, what was built each session, and what's next. Updated after every meaningful work block.

---

## Current State (2026-11-21, part 11) — playthrough design fixes

All 4 recommendations accepted by the user:
- **Ch2 waits a day after Ch1.** The two chapters no longer fire together (`869e08a`).
- **Putts can miss.** The make chance falls with distance; a miss lands near the basket for a tap-in. Measured in game: 3 m 19/20, 6 m 16/20, 10 m 10/20, 20 m 9/20 (`4cda2ac`).
- **Empire money** (`f08ba5a`):
  - World Map "Invest half of course funds" button.
  - Courses you're away from split earnings 20% empire / 80% own balance (was 100% to the pool).
  - Background time counts game time, so 2× pays 2×.
- **Speed remembered** after builder/map trips (`2× stays 2×`).
- **Found along the way:** loading story state while a beat was showing left the world paused with nothing on screen (`4cc611d`). It surfaced as an order-dependent test failure.
- Tests: 116

---

## Current State (2026-11-21, part 10) — hole scoring rework

- **One scorer:** `core/simulation/HoleScore.gd` replaces the length-gated star formula. The star rating, the Analytics per-hole cards and the Hole Architect all read it, so they can no longer disagree.
- **Hole stars reward design for par.** Five parts, worth up to 1.0 each, plus a fairness penalty:
  - **length fits par:** par 3 = 45–100 m, par 4 = 100–170 m, par 5 = 170–240 m;
  - **fairway** and **framing**, both scaled to hole length;
  - **challenge:** two hazard types needed for full marks;
  - **shape:** straight 0.5 (cap 4.5★), angled 0.75, dogleg/elevation 1.0;
  - **fairness penalty:** for an unreachable or boxed-in basket.
- Each hole gets tips, e.g. "Length: 150 m is long for par 3 — make it par 4".
- **Course ★** = average hole ★ + up to +0.3 bonus for variety (mix of pars and lengths) and amenities (restrooms, food, decor). The per-hole restroom and decor bonuses are gone.
- **Par** is auto-suggested from length when a tee or basket is placed. The Hole Manager can override it.
- **5★ goal** at 4.8. **Certification** is remembered once earned (`[courses] certified`).
- Uncle Ray's starter course: 2.41★ (was ~2.2).
- **Bot sanity run:**
  - Ch1+2 on day 9, Ch3 on day 11, Ch4 on day 12, Ch5 on day 51 — unchanged.
  - 0 script errors.
  - 3★ goal ~day 55 (old ~22). The bot never adds hazards or shape, which the new scoring rewards.
  - New circuit courses start slower: a bare hole in a forest used to score 4.2★ because trees counted as hazards; now trees are framing only. Winthrop Gold stalled at 4 holes because the bot spends before saving.
  - Open balance question for the user (certification bar / starting cash) — see chat.
- **Woods hazard (follow-up, user OK):** trees within 2 cells of the line count as a hazard type, and trees further out count as framing. Bare away-round holes on real terrain now score 3.2–3.65★ (Idlewild/Krokhol challenge 0.58–0.72 from trees alone).
- Test runner filter now matches `suite::name`.
- Tests: 110

---

## Current State (2026-11-21, part 9) — automated playthrough + 4 bug fixes

A scripted bot played from a brand-new save in a real window at 12× speed. It used the builder's own paint tool at real prices, plus facilities, staff, tournaments, an away round with real throws, and buying and certifying circuit courses. Script: session scratchpad `bot.gd`, not committed.

**Bugs found and fixed:**
- **NPC pathfinding stutter** (`cbd7ad9`): ~20–32 ms BFS after every throw. Discs resting on sand forced a full-map scan plus a second search. Now a packed-array BFS with the same paths: worst case ~5 ms, typical hops <1 ms.
- **Ghost players** (`77fe70f`): leaving the course view freed NPCs without `npc_left`, so EconomyManager kept charging green fees for them (9 → 160 "players" by day 50). Players could farm money by toggling the builder.
- **Empire pool** (`b64e1c8`): only one-off payments fed the "20% of course income"; per-second income didn't. It now flows via `EventBus.rate_income_ticked`.
- **Circuit courses had no entrance** (`249c692`, `bd29740`): no gate → no holes built → zero players, forever (−$32k). Now `ensure_entrance()` runs on first preset load, with an access path carved through forest, and a toast fires for old saves. Course switch also refreshes upkeep, which used to charge the previous course's hole count.

**Final run (all fixes): 0 script errors, 11/12 goals.**
- Chapters: Ch1+Ch2 day 9, Ch3 day 11, Ch4 day 12, Ch5 day 51.
- Circuit courses: Maple Hill certified in 32 of its days, Winthrop Gold in 36, Disc Side of Heaven in 42.
- Idlewild and Krokhol got players through the auto entrance, 9 holes at ~3.9★, but no restroom: the bot only builds on grass or rough, and those maps are forest. That's a bot limitation.
- Ale White needs a 5★ home course (bot plateaued at 4.36★).
- Home reached prestige 92, 4.36★, 92% happiness. Ch6 ending paths are covered by `test_story`.

**Open design questions for the user (not changed):**
1. Ch1 and Ch2 fire at the same moment: a new game starts at prestige 21.9 and Ch2 needs 25.
2. Putts never miss: putter deviation 0 plus aim snap. The bot shoots par or under on its first try.
3. Spare course money can't fund the empire pool ($500k sat idle). Also, a course pays 100% of its net into the pool while you're away vs 20% while present, so leaving home is optimal.
4. Game speed resets to 1× after visiting the builder.
5. Background income counts real seconds, so it's under-credited at 1.5×/2×.
6. Pacing: Ch0–4 come in ~12 in-game days (~12 minutes at 1×).

- Tests: 95

---

## Current State (2026-11-21, part 8) — release prep + fallback colours

- MIT `LICENSE`, `CREDITS.md`, player-facing `README.md`, Windows/Linux/macOS export presets (exclude tests/tools/GodotSteam). Release zips build to `build/release/` (git-ignored).
- The project renders with **Forward+** (old docs wrongly said GL Compatibility). User chose to keep it. Weak GPUs auto-fall back to Compatibility, which used to look washed out on Medium/High: a shadow-casting sun is drawn in an extra pass that brightens and oversaturates, and the HDRI sky came out darker. Fixed for Compatibility only (sun 1.0, ambient 0.35, saturation 0.80 when shadows are on; sky energy 1.25), fitted against Forward+ screenshots: error 0.29 → 0.085, mean colour within ~1 %. Forward+ pixels are unchanged.
- Tests: 90

---

## Current State (2026-11-21, part 7) — simpler trees on Low

- **User decision (revised):** Low doesn't need full-detail trees. Medium/High stay full detail.
- Low now swaps every tree model for a simplified copy (Godot's mesh simplifier, the most detailed level at or under 35% of the triangles). It's built once on first use (~0.1 s), and the switch is instant after that. Same trees, same places, same colours; only the mesh changes. Leaf-card surfaces that can't be simplified stay as they are.
- **Maple Hill on Low:** 19.7M → 7.5M triangles per frame (−62%). Home course Low: 2.0M → 0.94M.
- Settings → Graphics → Custom gained a **Tree Detail** row (Full / Simplified). The auto guard uses "simpler trees" as one of its steps for Custom setups.
- Screenshots: the far forest from the tee looks the same; up close, trunks and canopies are a little blockier, with no holes.
- Tests: 89

---

## Current State (2026-11-21, part 6) — self-adjusting graphics

- **User decision (superseded in part 7):** no tree LOD on any preset.
- **Auto guard (on by default):** if play/build runs under 70% of its FPS target for ~8 s (median of 1 s samples, so single hitches don't count), graphics step down one notch: High → Medium → Low, then 30 FPS cap and render scale 75 → 60 → 50 %. A toast says what changed. It never raises settings and never touches trees. Settings → Graphics → "Auto Adjust" switch turns it off. Choices persist (`[graphics] auto`).
- Verified live: at a real 60 FPS on Maple Hill, nothing changes; with frames forced to 10 FPS it dropped Medium → Low within 14 s and showed the toast.
- Render-scale list gained 50%.
- Checked the tree meshes for zero-area triangles to strip losslessly: none. The stylized pack is authored at ~4 cm scale, so an absolute-area check falsely flagged real triangles; a size-relative check finds 0.
- Tests: 88

---

## Current State (2026-11-21, part 5) — runs on more hardware

- **CPU:**
  - Course stats used to re-scan all 22,500 tiles on every call: 6–19 ms each, several times a second from the HUD, economy and staff. They are now cached per layout, with the layout key being a C++ `Dictionary.hash()` (~0.15 ms). The HUD refresh went from ~25 ms every 0.25 s to under 1 ms.
  - The minimap's terrain layer is redrawn only when the course changes.
- **GPU:**
  - `PropBatch` splits each part into 3×3 map chunks with fixed culling boxes, so off-screen chunks and chunks outside the shadow range are skipped, as tree nodes were before batching. Medium Maple Hill: 40M → 34M triangles per frame.
  - New render-scale setting (bilinear 3D scaling, UI stays sharp) and a grass-tuft toggle.
  - The Low preset now uses 75% scale and no tufts; Low at home is 3.7M → 2.0M triangles.
- **Auto preset:** first launch picks Low on phones, integrated non-Apple GPUs and software renderers, and Medium otherwise.
- **Fix:** picking Low/Medium/High in Settings used to flip to "Custom", because the sync fired toggle signals.
- **Builder painting:**
  - Every paint stroke used to rebuild a full-grid sloped terrain mesh that was never drawn (hidden; tile boxes draw the ground), so it was removed.
  - Edge fill now uses a flat type array with a quick reject; output is identical on 3 courses (same triangles and checksum).
  - The water shader is reused instead of recompiled on every paint.
  - Overlay rebuilds are throttled to every 0.2 s while drag-painting.
  - Big courses: 130 ms → 25 ms per rebuild.
- **Floor:** with the whole Maple Hill forest in view, it's ~20M triangles at full tree detail. Only tree LOD would cut that, and the user rule says no (raised with the user).
- Tests: 86 (new `test_perf.gd`)

---

## Current State (2026-11-21, part 4) — big-course performance

- **Root cause (measured):** most of the cost was rough grass, not trees. Each rough tile was 8 separate blade meshes (64-segment cylinders) and each sand tile 12 spheres; Maple Hill had ~44k blade draw calls. Trees added ~12k more.
- **Fix:** new `PropBatch.gd` draws trees, rough grass and sand as MultiMesh instances, one draw per mesh part, with swap-remove slots so builder painting stays O(1). Every tree is still drawn at full detail (no LOD/culling).
  - Tree FBX surfaces are split into bark/leaf parts, so trunks are brown now (they used to be tinted green with the leaves).
  - Grass blades and sand grains use 6–8 radial segments; they are 1–4 cm wide, so it looks the same.
  - Camera-occlusion fade uses `world.get_tree_positions_in()` + `set_tree_hidden()`, scanning only the sightline box instead of all 6.6k trees every frame.
- **Results (Maple Hill):**

  | | Before | After |
  |---|---|---|
  | Throwing view (frame time) | 715 ms | 23 ms |
  | Throwing view (draw calls) | 54k | 245 |
  | Course view (frame time) | 34 ms | 17 ms |
  | Away-round load | 4.5 s | 0.3 s |

- Tests: 77 (new `test_prop_batch.gd`)

---

## Current State (2026-11-21, part 3) — disc physics + graphics

- **Disc flight** rebuilt in `DiscProjectile.gd`:
  - Flight shape: eased speed, asymmetric arc, turn/fade with bank. S-curves are 2–3× stronger, and drives fly up to 12 m high.
  - Wind: headwind adds turn, tailwind adds fade.
  - Throw view: a dotted flight-path preview.
- **Interactions:**
  - The chains catch the disc; the old 2 m auto-hole is gone. The rim and pole spit it out.
  - Trees knock it away, rocks bounce it, hills block low throws.
  - Water splashes cost +1, with the throw replayed from the last dry point.
  - After landing the disc skips by surface and rolls downhill.
  - OB is judged where the disc comes to rest. Rough/sand still costs +1 (user decision).
  - New generated impact sounds (`tools/gen_sfx.py`).
- **Graphics:**
  - Root cause of the washed-out look: tile vertex colours were treated as linear. Fixed with `vertex_color_is_srgb`.
  - Fog is on only in the perspective camera, and the sky is blue again.
  - Grass-coloured ground runs past the map edge.
  - Stair-step edges are smoothed with corner fills, and trees get contact shadows.
- **Found, raised, not fixed:** away rounds on big courses run ~750 ms/frame in the throwing camera because there are thousands of individual tree draw calls. Proposed fix: MultiMesh-instanced trees, which keeps the no-LOD/no-culling rule.
- Tests: 71 (new `test_disc.gd`)

---

## Current State (2026-11-21, part 2) — portraits

- **Original portrait set** — `tools/gen_portraits.py` draws every on-screen speaker (player, Jess, Marcus, Diana, the Regular) from one shared bust template: same head, upper-left lighting, rolling-hill backdrop, plus a per-character layer. Not AI-generated, so there's nothing to disclose on Steam. To change art, edit the script and re-run it; don't hand-edit the SVGs. Dialogue portrait slot is 112px (was 72), set by `DialogueOverlay.PORTRAIT_SIZE`
- **Male or female look for the player** — the name prompt shows both portraits beside the name field; the pick is stored in `StoryManager.player_look` and saved (old saves get the male look). `StoryManager.get_portrait(char_id)` resolves the player's portrait. Decision: the pick is final, with no option to change it in Settings
- Uncle Ray and Dani keep their old placeholders. They never show on screen: letters and newspapers have no portrait slot
- Remaining user-owned: Steam App ID + `steam_appid.txt`, playtest. Commissioned art is optional and drops in under the same filenames
- Tests: 54

---

## Current State (2026-11-21) — story complete

Every beat and recurring element in `STORY.md` is now in the game:
- **Ch0 camera pan** — `ch0_pan` beat (style `pan`) tours Ray's 3 holes after the name prompt; `CourseCamera3D.play_tour()` tween runs while paused; Esc/click skips
- **Ch3 tournament toasts** — full series on the first tournament (sign-ups → "Hole 6 is backing up" on first round → "Three players asked…" on completion)
- **Ch4 away rounds** — World Map → *Play an Away Round* on unlocked circuit courses. `core/data/AwayLayouts.gd` holds the front nine of each course taken from the presets' real fairway routing; `resolve()` snaps ends that land in ponds/groves to dry ground. `GameManager.start_away_round/end_away_round` snapshot + restore the real course; economy frozen, no NPCs, saves/stats use the real course, leaving play abandons the round. Uses the Test Course controls (title "AWAY ROUND — …", "Head Home"). Best score per course persisted. `ch4_first_away` now fires after the first *completed* away round (not on course purchase)
- **Ch5 Diana's sponsor** — after her visit, the next tournament purse is matched by Cross Pines Holdings (once, min $10k)
- **Final card audio** — `GameAudio.set_ambient_only()` fades + pauses music and plays an original wind/birds loop (`tools/gen_ambient_wind.py` → `assets/audio/ambient/wind_loop.wav`)
- **Ch6 epilogue** — Dani Walsh's world-rankings newspaper (`ch6_dani`) the day after the final card
- **Recurring** — Ray's disc bag hangs on the home gate (`PropFactory.make_ray_bag`); a regular asks about it from Ch2 ("It belongs there.", new `visitor` placeholder portrait); first Pro Shop upgrade at home → shed toast (new `EventBus.facility_upgraded`)
- **Naming** — the first circuit course is "Maple Hill" everywhere (id stays `maple_ridge` for save compatibility)
- Tests: 53 (new `test_away.gd` + story tests for every new beat)

---

## Current State (2026-11-20, part 3)

- **GodotSteam loads on macOS** — user cleared the dylib quarantine; local gdextension uses the release dylib for debug runs
- **Built-in basket** — `PropFactory.basket_mesh()` (~3k tris, one cached mesh for all holes) replaces the unlicensed 341k-vertex GLB, which moved to `asset_library/`. No free licensed game-ready disc golf basket was found online
- **Starting balance $10,000** (was $25k) — matches Ray's letter; simulated idle start earns ~$300–600/day so it can't soft-lock
- Decisions: no handwritten font; portraits stay placeholder until the user circles back; Steam App ID + playtest pending on the user

---

## Current State (2026-11-20, part 2)

- **Owned courses keep their builds** — since 0fec465 every bought course reset to its preset on each visit. Snapshots are now stamped with `course_id` and only restored into the matching course (the real fix for the original home-tiles-on-Maple-Hill bug)
- **WDGA certification** — 9+ holes, 3.5★, a restroom; World Circuit panel shows progress; Ch6 needs 5 certified circuit courses + World Class
- **Uncle Ray's land** — new games start with his 3 rough holes (loop, pond, overgrown field), tuned to ~2★ so the 3★ goal / Maple Hill unlock aren't instant
- **Player name** prompt after Ray's letter; `{name}` placeholders; SVG placeholder portraits for all characters
- **Dialogue no longer hides the HUD**; newest screen always drawn/handled on top
- Diana's bench toast (post-Ch5), music fades under the memorial card, basket LOD bias 0.5
- **CourseBuilder split** — HoleCritique (pure), HoleManagerPanel, LayoutSlots, ArchitectOverlay (1.6k → 0.9k lines)
- Tests: 42, all green; runner now does an import pass first

---

## Current State (2026-11-20)

Returning after ~4 months. Review → fixes → tests → balance → refactor, all in one session.

### Story campaign (Phase 3) — now playable
- **StoryManager rewritten** — chapters advance strictly in order (prestige jumps used to skip Ch3/Ch4 beats entirely); triggers now match STORY.md: Ch1 six holes, Ch2 Regional, Ch3 first tournament, Ch4 circuit course unlocked (+1 day so it doesn't stack on Ch3), Ch5 National, Ch6 World Class + 5 owned circuit courses
- **Beat queue** — one overlay at a time (two beats in one frame used to overwrite each other and mark the first as seen); only shown in gameplay states; world pauses while open; pending queue + choices + chapter persisted under `[story] data`
- **Legacy-save migration** — saves without story data jump silently to the earned chapter and show only that chapter's opener (previously: stuck at Ch0, Circuit hidden from players who already owned courses)
- **All dialogue written** from STORY.md — Ray's letter, newspapers (Dani Walsh), Diana's buyout letter with Decline/Consider choice, Marcus, Jess, WDGA letter, final memorial card; toast beats for small moments
- **DialogueOverlay rebuilt** — letter / newspaper / card / dialogue styles, choices, page counter, sizes to content (verified via rendered screenshots)
- `core/data/CourseUnlocks.gd` shared by WorldMap + StoryManager

### Bugs fixed
- Hidden (cached) DialogueOverlay caught ESC → pause menu closed instantly after the first story beat
- Pause menu never paused anything (sim, NPCs, economy kept running) → reference-counted `GameManager.set_pause_reason()`; UI + audio run while paused; ESC closes the pause menu
- Prestige "goals" component always 0 (read `completed`, goals use `done`)
- `LevelSystem.gd` was autoloaded but never committed (fresh clones broke)
- Membership dues paid twice (per-second + daily)
- Spawn interval computed once on entering gameplay — happiness/marketing/events/fees never changed it

### Balance pass (see commit 8d7f6e2 for numbers)
- Disc Pro and Concessions lost money at every tier → now pay back in ~1–2 weeks of game days
- Green fee slider had no downside → arrivals scale with fee^-1.5, mood penalty above 1×
- Green fee scales with course rating (0.7 + 0.15/star)
- Food stand + Pro Shop upgrade paybacks fixed; decor bonus weighted by piece cost; early goal rewards raised

### Tooling / repo
- **Headless smoke tests** — `tools/run_tests.sh` (30 tests: boot, pause, story, save, economy/balance, props, panels). Isolated HOME, fails on any script error
- **Refactor** — `PropFactory.gd` out of GameWorld3D (3.8k → 3.1k lines); Gameplay overlay panels → `scenes/ui/screens/gameplay/` (2.4k → 1.3k lines)
- **Assets** — basket GLB textures capped at 512px (83 → 26 MB); referenced assets committed; 183 unused FBX moved out of `res://` to git-ignored `asset_library/`; `*.import` and `*.uid` now tracked

### Blocked / needs the user
- **GodotSteam macOS** — only the release dylib exists and it's Gatekeeper-quarantined; pointing debug at it hangs Godot on a security prompt. Get the official macOS build and clear quarantine yourself
- **GLB optimisation** — `npx @gltf-transform` download was blocked by the permission system; basket is still ~341k verts (decimate in Blender)

### What's next
(items 2–4 and 6 from this list were done in part 2 above; Ch6 now uses WDGA certification)
1. Final character portrait art (placeholders in `assets/portraits/`)
5. Optional: playable away rounds at circuit courses

---

## Current State (2026-07-13)

### Phase 3 Narrative Infrastructure — Built This Session

- **`StoryManager` autoload** (`autoloads/StoryManager.gd`) — chapter state machine (0–6); `CHARACTERS` + `BEATS` constants (all 9 beats stubbed); chapter advances on `goal_completed` (first_hole→Ch1, six_holes→Ch2, first_tourney→Ch4) and `prestige_changed` (≥25→Ch3, ≥50→Ch5, ≥75→Ch6); `vip_arrived` fires `ch1_vip_visit` beat at Ch1; `serialize()/deserialize()` for persistence
- **`DialogueOverlay` screen** (`scenes/ui/screens/DialogueOverlay.gd/.tscn`) — pushed as overlay via UIManager; reads beat from `StoryManager.BEATS`; per-character colored portrait placeholder (real art: set `portrait` path in `StoryManager.CHARACTERS`); multi-line text with Next/Finish/Skip buttons + ESC; auto-pops on finish
- **EventBus signals** — `story_chapter_started(chapter: int)`, `story_beat_fired(beat_id: String)`
- **Gameplay gating** — Circuit button hidden until Ch4; `_on_story_chapter_started` refreshes visibility live; Ch0 intro beat fires on first Gameplay entry
- **WorldMap hook** — `ch4_world_map` beat fires on first World Map entry (StoryManager deduplicates)
- **Persistence** — chapter + fired beats saved/loaded via `GameManager._save_course_meta()` / `_load_course_meta()` in `user://settings.cfg`

### What's Next (Phase 3 remaining)
1. Write real dialogue for all 9 beats in `StoryManager.BEATS` (replace `[PLACEHOLDER]` strings)
2. Character portrait art → `assets/portraits/`; set `portrait` paths in `StoryManager.CHARACTERS`
3. Uncle Ray's 3 starter holes — pre-built terrain on new game
4. Diana Cross Ch2 cosmetic choice UI (Decline / Consider It)
5. Newspaper clipping milestone UI (Ch1/3/6 beats)

---

## Current State (2026-05-26)

### Fully Working (additions this session)
- **NPC spawn regression fixed** — two root causes: (1) `active_course_id` persisted as non-home course on quit → `restore_active_course()` now always forces home on restart; (2) JSON round-trip returns tile type values as `float` — GDScript `match TileType.TEE:` (int) silently failed on `6.0`; fixed with `match int(_tiles[key]):` at all three match sites in `GameWorld3D.gd`
- **Forehand throw in test mode** — `[F]` toggles backhand/forehand; forehand negates `_turn` and `_fade` for mirror S-curve; button shows `[F] Backhand ↗` / `[F] Forehand ↙` (amber when active)
- **Save/load layouts** — CourseBuilder has 5-slot system; 📁 Layouts button; load/save/delete per slot; stored at `user://layouts/`
- **Hole preview thumbnails** — pixel-art minimap per hole in Hole Manager overlay; bounding box tee↔basket ± 4 cells; max 128×128; `TEXTURE_FILTER_NEAREST`
- **Season-aware music** — `GameAudio.gd` scans `assets/audio/music/`; filename prefix `spring_`/`summer_`/`fall_`/`winter_` routes tracks per season; unprefixed tracks play all seasons; `Morning_in_the_Fairway.mp3` active (fallback hardcoded)
- **GodotSteam initialized** — `GameManager._init_steam()` calls `Steam.steamInitEx(true, STEAM_APP_ID)`; `is_steam_active()` gate; `STEAM_APP_ID := 0` placeholder (replace before ship)
- **Steam achievements wired** — `GoalsSystem._unlock_steam_achievement(goal_id)` fires on every goal completion; API names match goal IDs
- **Accessibility tab** — Settings screen: UI Scale (75/100/125/150/200%), Colorblind Mode (None/Protanopia/Deuteranopia/Tritanopia); persisted to `user://settings.cfg`
- **Mobile touch pan fixed** — `TouchInputHandler` was returning `event.relative.normalized()` (lost drag magnitude); now returns raw `event.relative`; cameras apply `TOUCH_PAN_SCALE = 0.04` to convert pixel delta to normalized-equivalent (25px = full speed, slow drags stay slow)
- **Touch target audit** — all interactive buttons bumped to ≥ 44px height: Gameplay HUD row (was 36px), CourseBuilder tab row (was 26px), all overlay close/action buttons throughout Gameplay.gd and CourseBuilder.gd
- **Narrative bible complete** — full 7-chapter story in `STORY.md`: cast, opening letter, scene-by-scene beats, dialogue tone guide, GoalsSystem hook map, implementation checklist

### Phase 1 status: COMPLETE
All Phase 1 items in GOALS.md are checked. Phase 3 narrative content written and ready for implementation.

---

## Current State (2026-05-25)

### Fully Working
- **6 real-life courses** — Maple Ridge (MA), Winthrop Gold (MN), Idlewild (KY), Disc Side of Heaven (MO), Krokhol (Norway), Ale White (Sweden); each with terrain preset, unlock condition, and empire balance purchase price
- **Unlock + purchase gating** — conditions (3★ rating, first tournament, VIP visit, 50 players, $50k balance, 5★ rating) must be met AND empire balance ≥ price; GoalsSystem completion now persists to disk across restarts
- **Per-course economy** — each course has isolated EconomyManager state; empire pool (`_empire_balance`) funds purchases and accumulates background income
- **Affiliate tiers** — Disc Depot, Bag Shack, WDGA HQ, Bromez each have 3 purchasable tiers with progressive income/effect boosts
- **Decor tiles** — Bench ($150), Flower Bed ($80), Sculpture ($600) placeable in CourseBuilder; anti-abuse: binary per-hole rating bonus + global 20-piece happiness cap
- **Course Analytics overlay** — 📊 button in HUD; 3 deep sections: Rating (per-hole star cards with sub-scores + improvement tips), Happiness (5 weighted component bars), Prestige (tier ladder + 5 component bars + next-tier gap)
- **Autosave actually saves** — `save_requested` now wired to `GameManager._save_active_course()`; every 5-min autosave writes tiles + economy + meta to disk

### Architecture
- **Persistence path**: `user://settings.cfg` (owned courses, empire balance, shop tiers, GoalsSystem state) + `user://courses/{id}.json` (world tiles + economy per course)
- **SaveSystem stub**: `_gather()` / `_apply()` are empty; real persistence is all in GameManager
- **TileType gaps**: 16/17 = TOOL_RAISE/TOOL_LOWER constants; decor placed at 20/21/22 to avoid collision

---

## Current State (2026-05-24)

### Fully Working
- **Multi-course empire** — own and switch between multiple disc golf courses; each persists independently; background income accrues while away
- **World Circuit map** — filter tabs, difficulty indicators, unlock progress bars, live home-course stats, buy/switch/manage per course
- **Maple Ridge terrain preset** — `MapleHillPreset.gd` paints 150×150 Maple Hill layout (wooded hills, Southwick Pond, 18 fairway corridors, sand traps, paths) when course is purchased
- **Minimap click** → hole analytics overlay (rounds played, avg throws, avg score vs par per hole)
- **Autosave** every 5 minutes with animated indicator
- **Per-hole stat tracking** (`_hole_stats`) populated from `hole_scored` signal
- Isometric tile grid (150×150, 300×300 world units), 15 tile types including sand, rock, OB zones
- Elevation raise/lower, tree placement with 3 size variants
- Full disc projectile arc with wind, terrain penalties (sand, OB, rock deflect)
- Tree height-aware flight blocking
- Per-hole star rating system (length + terrain variety + obstacle count)
- NPC player spawning with 3 skill tiers (Beginner / Amateur / Pro)
- NPC needs system (hunger/thirst/bathroom) — NPCs leave early without facilities
- VIP touring pros with 3× income, gold dot, staff-gated spawn chance
- EconomyManager: real-time income/expense, day/season cycle, facility bonuses
- Staff system: Groundskeeper / Disc Pro / Concessions (hire cost + ongoing salary)
- Tournament system: 90s event, burst NPCs, prize formula, 8-min cooldown
- GoalsSystem autoload: 12 goals with live HUD progress counters
- Goals panel: full objectives list (all 12), completed/upcoming sections, live progress bars
- HUD: balance, players, income rate, wind, star rating, happiness, day/season, active goal with progress
- Toast notification system (green/orange/red)
- Camera tilt (PageUp/PageDown), pan, zoom
- Water tile shimmer animation
- Local save + Supabase cloud sync + Steam Cloud sync architecture
- Offline queue for cloud sync
- Kenney asset packs integrated (audio, sprites, 3D models, font)
- GameTheme.tres applied

### Architecture
- **EventBus** — all cross-system signals, no direct node refs
- **GameManager** — state machine (LOADING → MAIN_MENU → GAMEPLAY → COURSE_BUILDER → PAUSED)
- **UIManager** — screen stack with push/pop, toast notifications
- **InputHandler** — swaps Desktop ↔ Touch at runtime; game code never calls `Input.*` directly
- **SaveSystem** — picks backend by platform, always writes local first

---

## Session History

### Session: Multi-Course Empire (2026-05-24)

**Multi-course ownership system**
- `GameManager`: `active_course_id`, `owned_courses: Array[String]`, `COURSE_PRICES` dict
- `buy_course(id)`: deducts price, adds to owned list, switches immediately; persists to `user://settings.cfg`
- `switch_to_course(id)`: snapshots current world state → restores new course state (or applies terrain preset for first visit) → accrues background income for time away
- `_course_snapshots: Dictionary` — in-memory per-session; course states survive course switches
- `_course_bg_start: Dictionary` — records net income rate + timestamp when switching away
- `_apply_course_preset("maple_ridge")` — calls `MapleHillPreset.build()` on first ownership

**GameWorld3D state portability**
- `export_full_state() → Dictionary` — snapshots all 14 tile/hole/overlay dicts (tiles, heights, hole_num, orientations, par, custom colors, facility data, waypoints, variants, ob_zones, rock_overlays)
- `import_full_state(state)` — stops NPC system, clears visuals, restores all dicts, repaints every tile, rebuilds water, restarts NPC system with new hole layout
- `clear_all_tiles()` — full wipe (used before applying a fresh preset to a new course)
- `_clear_tile_visuals()` — frees all props, flags, OB/rock overlay visuals; resets MultiMesh instances to flat grass

**EventBus signal update**
- Replaced `circuit_visit_requested` / `circuit_visit_ended` with `course_switched(course_id)` + `course_purchased(course_id)`

**World Circuit (WorldMap) UI**
- Action button now shows three states per course:
  - Locked: shows unlock requirement + progress bar
  - Unlocked + not owned: "Own for $X" button (grayed if insufficient funds)
  - Owned + not active: "Switch to This Course"
  - Owned + active: "Manage This Course"

**Gameplay HUD**
- Course name label added next to Circuit button (shows "📍 Maple Ridge" etc.)
- `_on_course_switched()` resets active player count + refreshes labels
- Removed visit banner system; autosave now runs on all owned courses

**Main.gd simplified**
- Removed hub-world swap logic; single `GameWorld3D` in tree, never destroyed

---

### Session: World Circuit + Analytics + Main Menu Polish (2026-05-24)

**Main menu**
- Removed "Course Builder" and "World Circuit" buttons from first-load screen
- Main menu now shows only: Play / Settings / Quit

**World Circuit (WorldMap) rewrite**
- Filter tabs: All / Courses / Shops & More
- Difficulty indicators per course: Starter / Intermediate / Expert / Elite (colored dot)
- Unlock progress bars on locked cards (shows how close player is)
- Home course card: live star rating pulled from `GameWorld3D.get_course_rating()`
- Detail panel scrollable with live stats (rating, holes, happiness, prestige)
- Back button memory: returns to previous state (MAIN_MENU or GAMEPLAY)
- LOCATIONS data: 6 courses + 2 shops + 1 org + 1 media; each with difficulty, unlock_key, flavor text

**Maple Ridge terrain preset** (`core/data/MapleHillPreset.gd`)
- Based on satellite + tournament graphics analysis of Maple Hill Disc Golf Course
- Fills 150×150 grid: wooded hillside (TREE base), left clearing (GRASS/ROUGH), orchard rough (periodic tree rows), Southwick Pond two-lobe (WATER ellipses + bridge), lower + bottom-right ponds, sand rings around water + isolated traps, Walbridge Rd (PATH left edge), 18 fairway corridors with rough borders, inter-hole walking paths
- `_paint_fairway` (Bresenham + square brush), `_fill_ellipse`, `_fill_rect`, `_sand_ring` helpers

**Gameplay HUD additions**
- Minimap click opens hole analytics overlay: per-hole rounds played, avg throws, avg score vs par
- Autosave every 5 minutes (300s) with "💾 Saving..." fade indicator; skips when on non-home course
- Per-hole stat tracking: `_hole_stats` dict populated from `hole_scored` signal

---

### Session: Initial Foundation
- Godot 4.6.2 project scaffold
- Autoload singletons: EventBus, GameManager, UIManager, InputHandler, SaveSystem
- Screen stack system (UIManager push/pop)
- Main menu, placeholder gameplay screen
- Desktop + Touch input abstraction layer
- Save backends: Local, Steam Cloud, Supabase with offline queue
- PlatformDetector autoload

### Session: Course Builder
- GameWorld3D: 100×100 isometric tile grid with MultiMesh terrain
- TileType enum (Fairway through Pro Shop)
- CourseCamera3D: pan, zoom
- CourseBuilder UI: tile palette, brush size, erase
- Tile paint system with cost deduction
- Elevation raise/lower tools
- Tree placement with MultiMeshInstance3D
- Hole info: tee pads, baskets, path routing

### Session: Disc Physics + NPC Foundation
- DiscProjectile: arc simulation, wind influence, gravity
- Terrain-aware landing (rough penalty, tree blocking)
- NPCPlayer: spawns, plays through holes, earns green fees
- EconomyManager v1: balance, income from NPCs, base expenses, per-hole expense
- Per-hole quality rating (length, terrain, obstacles → 1–5 stars)

### Session: Per-Hole Star Ratings + Happiness
- `get_hole_rating()` per hole based on terrain variety, length, obstacle count
- `get_course_rating()` = average of all holes
- `get_course_happiness()` = facility coverage score
- EconomyManager: happiness multiplier on income rates
- HUD: star rating display, happiness % with mood emoji

### Session: Under Par Gap Analysis → Full Feature Batch
Implemented all features identified from competitive analysis:

**Terrain hazards**
- Sand (TileType 13): penalty stroke on landing
- Rock (TileType 14): random deflection, no penalty
- OB Zone (TileType 15): disc returns to last valid position + 1 penalty
- Updated TOOL_RAISE→16, TOOL_LOWER→17, TOOL_SELECT→18 to avoid enum collision
- CourseBuilder UI: Sand/Rock/OB buttons added

**Tree size variants**
- 3 sizes: small (0.55×), medium (1.0×), tall (1.45×)
- Per-tile size stored in `_tile_tree_size` dictionary
- `get_tree_fly_height()` returns threshold based on tile's tree size
- CourseBuilder: TreeSizeOption added to side panel

**NPC needs system**
- Hunger (0.22/s), thirst (0.30/s), bathroom (0.15/s) drain rates
- Warns at 80%, abandons round at 100% if no facility nearby
- `has_facility_near()` queries Food Stand (8-tile radius), Restroom (10-tile)
- `player_needs_failed` signal emitted on abandonment

**VIP touring pros**
- 12% base spawn chance when happiness ≥ 0.60
- +5% per Disc Pro staff member
- 3× green fee, larger gold dot, `vip_arrived` / `vip_left` signals

**Staff system** (EconomyManager)
- StaffType: GROUNDSKEEPER=0, DISC_PRO=1, CONCESSIONS=2
- Hire costs: $500 / $1,200 / $800
- Salaries: $1.5/s / $3.5/s / $2.5/s
- Groundskeeper: reduces maintenance by $0.80/s each (max $3.00 discount)
- Concessions: adds $1.50/s flat income each
- Staff panel in Gameplay HUD (hire/fire buttons)

**Tournaments**
- Requires 6+ holes and 2.0+ star rating
- Burst-spawns 8 extra NPCs
- Auto-completes after 90 real seconds
- Prize = $500 + (holes × $80) + (rating × $200)
- 8-minute cooldown between tournaments
- Tournament button in HUD with live countdown

**GoalsSystem autoload**
- 12 goals: first hole, 6 holes, 9 holes, 18 holes, 10 players, 50 players, first staff, 3-star, 5-star, first VIP, first tournament, $100K balance
- Cash reward on each completion
- `get_active_goal()` returns next incomplete goal
- `get_current_value(type)` enables live progress display

**Environment**
- Water shimmer: emission pulse on `_water_material` in `_process()`
- Camera tilt: PageUp/PageDown adjust `rotation.x` (−0.30 to −1.20 rad)
- Vibrant color pass on all tile types

**HUD improvements**
- Goals row (Row3) with live `(current/target)` progress counter
- Goal color lerps purple → green as progress increases
- Tournament button with live countdown (updates every 0.25s)
- Subtle HSeparator between Row2 and Row3
- Rating + goal refresh on 0.25s tick (no longer requires balance event)

**Bug fixes**
- GoalsSystem `get_all_goals()` type inference error: `var entry := g.duplicate()` → explicit `var gd: Dictionary` cast
- GoalsSystem `get_active_goal()` return type mismatch fixed
- EventBus `goal_completed` signal corrected to 3 params (goal_id, text, reward)
- Gameplay.gd `_on_goal_completed` handler updated to match 3-param signature

---

### Session: OB/Rock Overlays, Undo, Staff Fix, Trees, Round Summary (2026-05-22)

**OB zones as per-hole overlays**
- OB no longer replaces the underlying tile — it paints on top of any terrain
- Stored separately in `_ob_zones[cell] = hole_num` (1-indexed)
- Paint OB on the same hole again to remove it (toggle)
- Each hole can have its own independent OB boundary
- `is_ob_at(world_pos, hole_idx_0based)` checks at runtime — DiscProjectile uses this
- `hole_num` set on DiscProjectile by NPCPlayer before launch so per-hole check works

**Rock as overlay**
- Rock prop now overlays on top of any existing terrain tile (fairway, rough, etc.)
- `is_rock_at(world_pos)` — DiscProjectile deflects off rock overlay, not tile type
- Costs $10 to place; toggle to remove

**Undo/redo (Ctrl+Z in CourseBuilder)**
- 60-entry stack capturing full cell state before each paint (tile, height, all overlays)
- Ctrl+Z restores previous state including OB and rock overlays

**Staff walking fix**
- Staff were spawning at y=0 (underground on elevated terrain) — fixed to use `get_ground_y()`
- StaffMember now snaps to terrain surface every frame while wandering
- `physics_object_picking = true` enabled on viewport when Gameplay screen is active — NPC click-inspect now works

**Trees all full grown**
- Default tree size changed from medium (1.0×) to tall (1.45×)
- `get_tree_fly_height` fallback also updated to tall height

**Round complete notifications**
- Toast notification after every NPC round: "Round complete! N holes +$X"
- VIP rounds show "VIP round complete!" prefix

---

### Session: Staff Visuals, NPC Inspect, Builder UX (2026-05-22)

**Staff walk around**
- `StaffMember.gd` new scene — procedural mesh, type-colored shirt + badge dot, floating name label
- Groundskeeper (green): wanders fairway/rough/path tiles
- Disc Pro (blue): wanders tee pads, baskets, pro shop
- Concessions Worker (orange): stays near food stands + parking
- Spawns immediately on hire, disappears on fire
- Re-spawns correctly when returning from CourseBuilder to Gameplay
- `get_tiles_of_type(tile_type)` added to GameWorld3D for wander queries
- `staff_fired` signal added to EventBus + EconomyManager

**Click-to-inspect any NPC or staff**
- Area3D (collision layer 2, sphere r=0.55) added to each NPCPlayer and StaffMember
- Clicking fires `EventBus.npc_inspect_requested(info)` 
- Bottom-right info panel in Gameplay HUD shows:
  - Player: type badge (VIP/Pro/Amateur/Beginner), current action + hole progress, hunger/thirst/bathroom progress bars (green→yellow→red)
  - Staff: name and current task description
- Panel stays until closed — close button or re-click another NPC replaces content

**CourseBuilder UX fixes**
- "< Menu" back button was wrongly going to MAIN_MENU — fixed to GAMEPLAY
- Renamed to **"Play >"** with green tint (clear call to action)
- Balance label (gold) added to TopBar — always visible while building, updates live

---

## Known Issues / Tech Debt
- ~~Undo/redo for tile placement~~ (done 2026-05) · ~~Mini-map overlay~~ (done 2026-05)
- Hover tooltips on CourseBuilder toolbar buttons — not yet implemented
- CourseCamera3D tilt not yet wired to mobile pinch-tilt gesture
- NPC inspect panel shows snapshot on click, not live-updating (acceptable for now)
- OB toggle on "all holes" (hole_num=0) not exposed in UI — always per active hole
- Undo does not support Pro Shop (3×3 building) — complexity deferred
- `_try_spawn_npc()` burst in tournament calls `call_deferred` — if world unloads mid-tournament, timer callback will error (low priority)
- Git committer identity auto-configured from hostname — run `git config --global user.name/email` to fix

---

---

### Session: 5 Management Systems + Staff Dashboard (2026-05-23)

**Staff tier upgrades**
- 3 tiers per staff type (Basic → Trained → Expert) with upgrade costs
- Groundskeeper tiers: 0.9 / 1.5 / 2.4 %/day decay reduction per worker
- Disc Pro tiers: VIP chance baseline + 5% / 10% income multiplier per worker
- Concessions tiers: $1.5 / $2.5 / $4.0 food income per worker; food stand multiplier ×1.0 / ×1.4 / ×1.8

**Marketing / ad spend**
- Weekly budget slider ($0–$500/week) in Fees overlay
- Up to 1.75× NPC spawn rate multiplier
- Deducted daily (budget ÷ 7 per game day); affects `_spawn_timer.wait_time` in GameWorld3D

**Financial history chart**
- 14-day rolling net balance delta, pushed each game day
- Mini bar chart in Stats overlay — green = profit, red = loss, height-scaled to max

**Events calendar**
- 4 event types: Discount Day (free), Pro Invitational ($500, needs Pro Shop), Night Golf ($200, needs Restroom+Food), Charity Round ($300, 2-day, needs 9 holes, +10 prestige on complete)
- New "Events" button in HUD opens centered overlay
- Cooldowns tracked in real seconds, requirements checked live

**Course condition system**
- 0–100%; decays 3.5%/day; Groundskeeper tiers slow decay (0.9/1.5/2.4% per GK per day)
- Income multiplier penalty when below 75% (down to 0.60× at 0%)
- Warning notifications at <50% and <25%
- Repair Course button in Staff panel — $500 + $100/hole, restores to 100%

**Active Effects Dashboard**
- Staff panel now opens to a live dashboard before the hire/fire controls
- Shows: Net Income, Income Rate, Expense Rate, Condition %, Spawn Rate, VIP Chance %, Decay Rate/day, Active Event
- Per-staff-type: current tier benefit text, worker contribution (calculated), next-tier upgrade preview

**EventBus additions**
- `staff_upgraded(type, tier)`, `course_condition_changed(pct)`, `event_started(name)`, `event_completed(name)`, `marketing_changed(budget)`

---

---

### Session: Bug Batch + Map Expansion (2026-05-23)

**NPC water/tree loop fix**
- NPCs walked through water because BFS pathfinding returned empty and fell back to direct line — now `find_walkable_path` searches for nearest walkable cell (up to radius 10) before falling back to direct line
- `_find_nearest_walkable(center, max_radius)` added to GameWorld3D
- Tree-hit disc now lands at `_last_valid` (last non-hazard position) instead of the tree tile — eliminates the "NPC stands in tree, throws forever" loop

**Builder prop preview**
- Hovering TEE, BASKET, TREE, PARKING, RESTROOM, FOOD_STAND, PRO_SHOP in builder now shows a semi-transparent 3D prop at cursor position (65% opacity via material duplication with TRANSPARENCY_ALPHA)
- Previous hover was just a colored tile tint; now shows actual placed object
- `_preview_prop`, `_preview_prop_cell`, `_preview_prop_tool` state vars track current preview; cleared on paint or tool change

**Basket catch improvements**
- Catch radius 2.8 → 5.0 world units
- Close-miss radius 6.0 → 9.0 world units
- Added angular aim snap: when player aims within ~35° of basket and basket is in range, shot target snaps to basket center — prevents "aiming right at it, misses anyway"

**Power bar reliability**
- Added 0.18s minimum hold time before commit accepted — eliminates accidental double-click commits before bar appears
- `_animate_power_bar` rebuilds panel if it was freed between frames

**Disc distances doubled**
- Putter: 22→44, Midrange: 38→76, Fairway: 55→110, Distance Driver: 72→145 world units
- Distances now feel proportional to visible world scale on 150×150 grid

**Map expanded**
- Grid 100×100 → 150×150 cells (300×300 world units) — fits 18 holes + amenities

**Starting cash**
- Balance 10,000 → 25,000 — player can afford 2 holes + amenities without grinding

**Tee pad arrow direction**
- Default course generated with orientation=2 (south-facing) so arrow points toward basket

**FPS display**
- Added FPS counter (top-right in Play Test mode, bottom-left in Gameplay HUD)

**Save mechanic confirmation**
- LocalSaveBackend uses `user://` — fully functional in all exported builds; no changes needed

---

### Session: World Circuit Hub (2026-05-23)

**World Circuit map screen**
- New `GameState.WORLD_MAP` state in GameManager; WorldMap screen registered in UIManager
- `WorldMap.gd` + `WorldMap.tscn` — full all-code UI, no heavy scene dependency
- 3-column location grid with detail panel on right (click any card to inspect)
- 11 locations across 4 types: courses, shops, organizations, media
- Cards show: icon, name, region, holes/par (courses), flavor text or unlock requirement
- Unlocked cards: colored by location, selectable, detail panel shows action button
- Locked cards: greyed with 🔒, unlock condition shown in amber
- Detail panel: large icon, stats, description, type badge, action button (or lock info)
- Back button → Main Menu; Circuit button in Gameplay HUD; World Circuit button in Main Menu

**Locations (all Flyte-original names, real disc golf inspirations):**
- Maple Ridge (Maple Hill MA), Smuggler's Pass (Smugglers' Notch VT), La Veaga Bluffs (DeLaveaga CA), Hawk's Meadow (Hawk's Prairie WA), Idlebrook (Idlewild KY), Hornet's Hollow (Hornet's Nest NC)
- Disc Depot (disc gear shop), The Bag Shack (accessories), WDGA Tour HQ (PDGA equivalent)
- **Jomex** (Jomez Pro equivalent — premier disc golf media company; unlock: Regional prestige)

**Unlock conditions derive from existing GoalsSystem + EconomyManager — no new save state needed**

**GoalsSystem:** added `is_goal_complete(id) -> bool` public helper

---

### Session: Environment Polish + Goals Panel (2026-05-23, continued)

**Warmer environment colors**
- Exposure reduced 1.05 → 0.88 — eliminates washed-out overexposure
- HDRI panorama energy multiplier 0.8 → 0.55 — HDRI was the primary overexposure source
- Ambient light switched from SKY source to a warm color `Color(1.0, 0.93, 0.82)` at 0.70 energy
- Glow intensity 0.6 → 0.4, strength 1.2 → 0.9, bloom 0.10 → 0.06, HDR threshold 0.85 → 1.0 — reduces bloom blowout without killing depth
- Color adjustment pass enabled: brightness 0.97, contrast 1.02, saturation 1.05 — keeps image punchy at lower exposure
- Fog shifted from cool blue-grey to warm tan `Color(0.88, 0.82, 0.72)`; sun scatter raised to 0.30
- Fill light desaturated and dimmed: `Color(0.78, 0.82, 0.90)` at 0.22 energy (was cold blue 0.30)
- Procedural sky horizon warmed to hazy grey-blue `Color(0.72, 0.78, 0.88)`

**Fullscreen UI scaling**
- Added `[display]` section to project.godot: viewport 1920×1080, `canvas_items` stretch mode, `expand` aspect
- Main menu and all UI screens now scale correctly at any resolution/fullscreen

**Camera pan bounds fixed (150×150 grid)**
- `CAM_X_MAX` 155 → 255, `CAM_Z_MAX` 210 → 365
- Grid expanded to 150×150 (300 world units) last session but camera limits were still sized for the old 100×100 (200 unit) world — player couldn't reach the north end of the map

**Goals / Objectives panel**
- New "Goals" button in HUD Row1 (next to Events)
- Centered overlay (600×740) with scrollable list of all 12 goals
- **Active & Upcoming** section: active goal highlighted in blue with ▶ icon + progress bar (current/target) + reward in gold; upcoming goals shown dimmed with ○ icon
- **Completed** section: ✓ green icon, muted text, reward shown faded
- Panel auto-refreshes when a goal completes while open

---

### Session: Proactive Improvements (2026-05-23, continued)

**NPC throw physics variety**
- Set `_turn` and `_fade` on NPC DiscProjectile based on throw distance — drivers get ~5.5 turn/4.0 fade, fairways ~1–3 turn/moderate fade; putter stays straight
- NPC throws now show realistic S-curve trajectories matching player experience

**NPC throw safety**
- `SKILL_MAX_THROWS` (5/4/3 per skill tier) was defined but never enforced — NPCs could loop infinitely on a hard hole; now forces a putt on max throw count
- `_calc_throw_target` resamples up to 4 times to avoid landing in water; falls back to 70% straight-line if all samples hit water

**Hole-building robustness**
- `_build_all_holes` used `break` when a tee path failed — dropped all subsequent holes; changed to `continue` + nearest-walkable-neighbor fallback
- Exit path generation now tries nearest walkable near entrance and falls back to a direct world-space line — NPCs always exit regardless of layout

**Play test polish**
- WASD movement now clamped to grid bounds (0..300m) — player can't walk off the map edge
- `_aim_yaw` wrapped with `wrapf(-PI, PI)` to prevent float drift on long play sessions

**Builder prop preview FBX fix**
- `_apply_preview_transparency` previously silently skipped FBX/GLB tree nodes (no `material_override`); now applies a green-tinted translucent override so all previewed props appear ghosted

---

### Session: Hub World Polish + Scorecard Overhaul (2026-05-23, continued)

**Hub world — spinning portal discs**
- Unlocked portals grow a emissive disc on their crossbar that spins continuously
- `_portal_discs` array stores MeshInstance3D refs for each unlocked portal arch
- `_spin_portal_discs(delta)` rotates each disc `delta * 2.4` rad/s in `_process()`

**Hub world — shift-to-run**
- Holding Shift multiplies walk speed by 1.85 (`WALK_SPEED * 1.85 = ~20.4 m/s`)
- `_play_anim("Run")` triggers on sprint; walk anim resumes on release
- `Input.is_key_pressed(KEY_SHIFT)` checked each physics frame (not polled via InputHandler)

**Hub world — portal entry flash**
- `_entering: bool` flag prevents double-entry while tween runs
- `_flash_rect`: full-screen ColorRect added to HUD canvas, alpha 0 normally
- On portal enter: tween alpha 0→1 over 0.30s, then calls `_do_travel(id)`, then 1→0
- `_do_travel`: home → `GameManager.change_state(GAMEPLAY)`, others → toast + reverse flash

**Hub world — wandering NPCs**
- `_build_hub_npcs()`: spawns 10 NPCs across hub grounds with FBX or capsule fallback
- Each NPC has a floating Label3D name tag (golfer names + a few niche disc golf references)
- State stored via `set_meta()` on node: target Vector3, wander_t, wander_interval, body ref, anim ref
- `_update_hub_npcs(delta)`: moves at 3.5 m/s toward wander target; picks new random target every 4–8s
- `_play_anim_on(anim_player, want)`: animation helper; gracefully skips if anim not found

**Scorecard overhaul (PlayTestController.gd)**
- Panel widened 480 → 620px, taller 720 → 720px with ScrollContainer for 18-hole rows
- 5-column rows: Hole | Par | Score | +/- | Rating (score name e.g. Birdie, Eagle, Ace)
- Score names: Condor (−4), Albatross (−3), Eagle (−2), Birdie (−1), Par, Bogey (+1), Double Bogey (+2), Triple+ ("Triple+" text)
- Per-row background tint: subtle 12% color panel; best hole gets a distinct left-border highlight
- Tally summary section below totals: colored count boxes per score type (Eagle=gold, Birdie=green, Bogey=amber, etc.)
- Best hole detection: lowest (score - par) diff determines the highlighted row
- Side-by-side Play Again / Exit buttons replace stacked layout

---

### Session: Phase 2 Complete — Real Courses, Decor, Analytics, Save Hardening (2026-05-25)

**Real-life course roster (replaces placeholder IDs)**
- 5 new terrain presets: `WinthropGoldPreset.gd` (MN prairie, shelterbelts, central pond), `IdlewildPreset.gd` (KY hardwood corridors, creek), `DiscSideOfHeavenPreset.gd` (MO ridgeline/valley bands), `KrokholPreset.gd` (Norwegian boreal tunnels, glacial lake), `AleWhitePreset.gd` (Swedish links, bunkers, 3 water hazards)
- `GameManager.COURSE_PRICES`: maple_ridge=$25K, winthrop_gold=$30K, idlewild=$35K, disc_side_of_heaven=$40K, krokhol=$45K, ale_white=$50K
- `WorldMap.gd` LOCATIONS updated with real IDs, regions, difficulty ratings

**Unlock + purchase gating**
- Unlock conditions: `three_star` (Maple Ridge), `first_tourney` (Winthrop Gold), `vip_visit` (Idlewild), `fifty_players` (Disc Side), `balance_50k` (Krokhol), `five_star` (Ale White)
- Both gates required: unlock condition AND empire balance ≥ price
- Buy button disabled (not hidden) when unlocked but balance insufficient — shows price + current empire balance
- **GoalsSystem persistence**: `_save_course_meta()` now serializes GoalsSystem state (completed dict + player/vip/tournament/staff totals) to `settings.cfg`; `_load_course_meta()` restores on startup — unlock conditions now survive restarts

**Per-course economy + empire**
- Each course has isolated EconomyManager state (serialized to `user://courses/{id}.json` on switch/save/quit)
- Empire pool (`_empire_balance`) separate from per-course balance; funds purchases; accumulates background income
- `GameManager._empire_balance`, `get_empire_balance()`, `_shop_tiers` dict
- `buy_course()` deducts from empire; `buy_shop_tier()` validates sequential tier unlock

**Affiliate locations (Disc Depot, Bag Shack, WDGA HQ, Bromez)**
- 4 locations with 3 purchasable tiers each using empire balance
- Effects: income multipliers, happiness boosts, media daily income, tournament prize multipliers
- `GameManager.SHOP_TIER_DATA` const; getters: `get_pro_shop_income_mult()`, `get_happiness_mult()`, `get_tournament_prize_mult()`, `get_media_daily_income()`
- WorldMap `_build_affiliate_buttons()` renders tier purchase UI in detail panel

**Decor tiles (CourseBuilder)**
- 3 new TileTypes: BENCH=20 ($150), FLOWER_BED=21 ($80), SCULPTURE=22 ($600)
- Added to `GameWorld3D.gd`: tile costs, colors, `_make_bench()`, `_make_flower_bed()`, `_make_sculpture()` procedural mesh builders
- Anti-abuse: `get_hole_rating()` uses binary decor check (not count) +0.1 per hole; `get_course_happiness()` decor component capped at 20 pieces globally (5% weight)
- `CourseBuilder.tscn`: DecorGroup with BenchBtn/FlowerBedBtn/SculptureBtn added after TerraformGroup
- `CourseBuilder.gd`: `TOOL_BENCH=20/21/22`, `_decor_tool_buttons` dict, highlight extension

**Course Analytics overlay (Gameplay)**
- 📊 Analytics button added to Row1Btns in `Gameplay.tscn`
- `AnalyticsOverlay` PanelContainer (760×680, centered) in `Gameplay.tscn`
- `Gameplay.gd`: `_on_analytics_pressed()`, `_build_analytics()`, `_make_small_hint()`
- **Rating section**: overall stars display, holes ≥4★ / <3★ counts, per-hole cards (sub-scores + actionable tip for weak holes)
- **Happiness section**: 5 weighted bars (Quality 48%, Restrooms 19%, Food 14%, Pro Shop 14%, Decor 5%) with per-component tips when below 70%; facility counts
- **Prestige section**: overall bar + tier ladder (Local → Regional → National → World Class), 5 component bars with tips, "need X more to unlock next tier" message
- Analytics overlay added to modal backdrop, scroll-block, and `on_screen_exited()` cleanup

**Save hardening**
- `EventBus.save_requested` now connected to `GameManager._on_save_requested()` (renamed `_save_active_course()` internally)
- Every autosave (every 5 min) now writes active course tiles + economy + meta to disk — previously wrote empty JSON stub
- `_on_quit_requested()` calls `_save_active_course()` directly before emitting `save_requested` for LocalSaveBackend
- `COURSE_DISPLAY_NAMES` in `Gameplay.gd` updated to real course IDs (was stale with old fake IDs)

**Runtime bug fixes**
- `HubWorld3D._build_camera()`: moved `add_child(_camera)` before `look_at()` — fixed "node not in scene tree" error
- `EconomyManager.get_net_income_rate()` added (was missing, caused error in stats panel)

---

### Session: GPU Performance + Graphics Settings + Dev Tooling (2026-05-24)

**GPU performance — graphics quality system**
- M2 Max was fully throttling after glow/HDRI/shadows were added previous session
- Root causes: glow post-process, 21MB HDRI EXR panoramic sky, 2-cascade directional shadows, flag wave every `_process()` frame
- Added 3-preset graphics system: Low (glow off, procedural sky, shadows off, 30fps, flags off) / Medium (glow off, HDRI, 1-cascade 80m, 60fps, flags on) / High (glow on, HDRI, 2-cascade 180m, 60fps, flags on)
- Added Custom option: user can individually set glow, shadows, sky type, FPS cap, flag animation
- `GameManager.gd`: `graphics_preset`, `gfx_glow`, `gfx_shadows`, `gfx_sky`, `gfx_fps_cap`, `gfx_flags`; `_GFX_PRESETS` const; `apply_graphics_preset()` / `apply_custom_graphics()`; `_load_graphics_config()` / `_save_graphics_config()` via ConfigFile at `user://settings.cfg`; default is **Medium**
- `GameWorld3D.gd`: `_world_env_node`, `_sun`, `_sky`, `_hdri_sky_mat`, `_proc_sky_mat` refs stored; `_apply_graphics_settings()` applies env.glow_enabled, shadow mode/distance, sky material; connected to `EventBus.graphics_quality_changed`; flag animation gated by `GameManager.gfx_flags`
- `EventBus.gd`: added `signal graphics_quality_changed(settings: Dictionary)`
- `Settings.tscn / Settings.gd`: new "Graphics" tab with preset OptionButton + CustomSection (visible only on Custom); individual controls for all 5 settings; synced to GameManager state on `on_screen_entered()`

**Dev tooling**
- 7 project-specific slash commands: `/gdcheck`, `/game-perf`, `/balance`, `/gd-review`, `/scene-map`, `/new-feature`, `/bug-hunt` — all in `.claude/commands/`
- MCP: sequential-thinking server installed (`@modelcontextprotocol/server-sequential-thinking`)
- GitHub plugins: `multica-ai/andrej-karpathy-skills`, `obra/superpowers`
- AgentMemory MCP fixed: `~/.claude.json` had `${AGENTMEMORY_URL}` literal, now hardcoded `http://localhost:3111`; launchd service `com.agentmemory.worker` added at `~/Library/LaunchAgents/` for auto-start on login

---

## Phase 1 Backlog (current focus — single course perfection)

### Management
- [ ] Staff scheduling (morning/evening shifts)
- [ ] Facility upgrade tiers (Restroom → Deluxe Restroom, etc.)
- [ ] Loan/financing system for expensive builds

### Builder
- [ ] Save/load multiple course layouts (slot system)
- [ ] Hole preview thumbnail in CourseBuilder
- [ ] Better terrain blending at tile edges

### Gameplay / Play-Test
- [ ] Full 18-hole round scorecard screen
- [ ] Disc customization persistence
- [ ] Replay last throw

### Polish
- [ ] Background ambient music (season-aware)
- [ ] SFX: disc impacts, crowd reactions, ambient birds
- [ ] Settings: control remapping, graphics quality presets
- [ ] Accessibility: UI scale slider, colorblind palette
- [ ] Mobile touch optimization pass (drag-pan, pinch-zoom end-to-end)
- [ ] Steam achievements wired to GoalsSystem

---

## Long-Term Goals (phases 2–5)

See `GOALS.md` for full detail. Do not implement until Phase 1 core is polished.

| Phase | Goal |
|---|---|
| 2 | World map + 5–8 real-life disc golf courses (Maple Hill, Smugglers' Notch, etc.) |
| 3 | Narrative campaign — 6-chapter storyline, inherit a rundown course, rebuild to world class |
| 4 | Steam release — GodotSteam addon, achievements, Steam Cloud save, store assets |
| 5 | Mobile (iOS + Android) + Supabase cross-platform sync with desktop save |

**Copy-paste strategy for Phase 2:** `GameWorld3D` is already a self-contained scene. Each real-world course is a pre-built `GameWorld3D` scene loaded read-only. A new `CourseRegistry` autoload tracks unlock state. The builder, EconomyManager, and all systems apply unchanged.
