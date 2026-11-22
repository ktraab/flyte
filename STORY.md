# Flyte — Narrative Bible v0.1

Full story content for Phase 3 implementation. See `GOALS.md` Phase 3 for architecture notes and `CLAUDE.md` for `StoryManager` / `DialogueOverlay` implementation guidance.

---

## Cast

### The Player Character
Name: player-defined at start (default "Coach"). Look: male or female portrait, picked with the name
Background: Former amateur disc golfer. City job. Disconnected from the sport for years. The inheritance forces a choice: sell and stay comfortable, or risk everything on a dream your family believed in.

### Uncle Ray *(deceased before game starts)*
Raymond "Ray" Hollis. Never married, poured his life into the land. Built 3 rough holes by hand over 20 years. Never had the money to finish it. Left everything to you because he believed you'd actually do it — and because nobody else in the family plays disc golf.
Key detail: Ray's workbench is still in the shed. His disc bag hangs on the fence near Hole 1. You never take them down.

### Diana Cross *(Rival — antagonist)*
Owner of Cross Pines Golf Club — a traditional ball-golf course 4 miles away. Desperate to convert it to a disc golf venue before you establish yourself, or buy you out and do it on her terms. Smart, charming in public, ruthless in private. Not a villain — she has legitimate reasons to want the land. That's what makes her interesting.
Key detail: She's actually a decent disc golfer. She respects the sport. She just respects money more.

### Marcus Bell *(WDGA Regional Rep)*
Enthusiastic bureaucrat. Runs the regional WDGA circuit from a cluttered office above a sporting goods store. Loves the sport genuinely. Gets you into your first sanctioned tournament. Becomes an ally if you treat the process with respect.

### Jess Nakamura *(First VIP — touring pro)*
Young pro on the circuit. Known for being honest in post-round interviews. Her visit to your course — if it goes well — is the moment word spreads on social media. Her endorsement is unscripted and therefore priceless.
Key detail: She shows up unannounced. The NPC system spawns her randomly once the VIP trigger fires. That's intentional — the player earns it, not schedules it.

### Dani Walsh *(Local reporter)*
Covers the "community" beat for the Lakewood Courier. Shows up at Chapter 1, 3, and 6. Never intrusive — her newspaper stories mark milestones.

### The Narrator
No voice-over. All story delivered via:
- `DialogueOverlay` (character portrait + text, Next button, skip option)
- In-world documents (letter, newspaper clippings, messages)
- Toast notifications for minor beats
- End-of-chapter summary cards

---

## The Opening Letter

*Displayed at new game start, before player names themselves. Handwritten font. Ray's portrait sketch in corner.*

> *To whoever opens this —*
>
> *I always figured you'd show up eventually. Not like this, I know. I'm sorry for that.*
>
> *The land is paid off. Three holes are roughed in — nothing fancy, but they're playable. I left $10,000 in the account; it's not much but it's a start. The shed has everything I collected over the years.*
>
> *I never finished it. Life kept getting in the way, then time ran out.*
>
> *I'm not leaving it to you because you're good at business. I'm leaving it to you because you're the only one in this family who ever picked up a disc and smiled.*
>
> *Don't sell it. Finish it.*
>
> — Ray

---

## Chapter-by-Chapter Beat Sheet

---

### Chapter 0 — Inheritance
**Trigger:** Game start
**Emotional arc:** Grief → reluctant hope
**Player state:** $10,000, 3 rough holes, empty course

**Opening sequence:**
1. Opening letter displayed (above)
2. Camera pans across overgrown course — 3 roughed-in holes, weeds, broken fence near entrance
3. DialogueOverlay — player internal monologue:
   > *"This place looks worse than I remembered. But Ray's basket is still standing."*
4. Tutorial begins naturally: "Let's see what we're working with."

**Scene: First Player Arrives**
After player completes 1 hole, first NPC walks in.
Toast: *"Someone found the place. Word travels fast — or they just saw the gate was open."*

**Closing beat** (after completing 3 holes):
> *"Ray's holes are playable now. It's not much, but it's his. Keep going."*

---

### Chapter 1 — First Steps
**Trigger:** Complete a 6-hole course
**Emotional arc:** Uncertainty → first validation
**Key events:** Local newspaper story + Jess Nakamura VIP visit

**Scene A: The Newspaper**
DialogueOverlay with newspaper image overlay:

> **LAKEWOOD COURIER — LOCAL SECTION**
> *"Hollis Course Reopens After Years of Neglect"*
> *"A family member of the late Raymond Hollis has begun restoring the disc golf course at 44 Timber Creek Road. The six-hole layout is now open to the public..."*
> — Dani Walsh, Staff Reporter

Player internal:
> *"Six holes. Ray would've called it 'a solid start.' I'll take that."*

**Scene B: Jess Nakamura Arrives** *(VIP trigger — fires when first VIP NPC spawns)*
Jess spawns as VIP NPC. After her round, DialogueOverlay with Jess portrait:
> *"This isn't on the circuit yet, but it should be. Whoever designed Hole 4 knows what they're doing. I'm putting it in my recommendations."*

Toast:
> *"She posted about the course. 43 new follows before you closed up for the day."*

**Closing beat:**
> *"Word is out. From here, it goes one of two ways — up, or forgotten. Ray didn't leave you this place to be forgotten."*

---

### Chapter 2 — Word Gets Out
**Trigger:** Reach Regional prestige level
**Emotional arc:** Success → threat → resolve
**Key event:** Diana Cross makes her buyout offer

**Scene: Diana's Letter** *(formal document in DialogueOverlay)*

> **CROSS PINES HOLDINGS**
>
> *Dear [Player Name],*
>
> *Congratulations on what you've built. Raymond would be proud.*
>
> *I'll be direct: Cross Pines is expanding into disc golf, and your location is ideal for our plans. I'm prepared to offer $85,000 for the property and existing infrastructure — well above market.*
>
> *No rush. But the offer doesn't stay open forever.*
>
> *— Diana Cross*

**Player choice** (cosmetic — both continue the story):
- *"Decline"* → Player: *"Ray said don't sell it. That's good enough for me."*
- *"Consider It"* → Player: *"...No. Not after everything. Not yet."*

**Optional flavor beat** *(fires if player has hosted ≥1 VIP before this chapter)*
Diana visits the course herself before sending the letter. She plays a round. Doesn't introduce herself. You only learn who she was when the letter arrives.
Toast: *"You just realized the woman on Hole 7 this afternoon was Diana Cross."*

**Closing beat:**
> *"She'll be back. People like Diana always come back. The only answer she'll accept is a course she can't buy her way past."*

---

### Chapter 3 — Going Pro
**Trigger:** Host first tournament
**Emotional arc:** Legitimacy → pressure → pride
**Key event:** Marcus Bell invites player to WDGA sanctioned circuit

**Scene: Marcus Bell Arrives** *(DialogueOverlay, Marcus portrait — rumpled jacket, clipboard)*
> *"I've been watching what you've built here. The WDGA Regional Circuit has an opening in the spring schedule. I think you're ready — if you want it."*
>
> *"Sanctioned events mean scrutiny. But they also mean your course gets rated on the official ladder. Your call."*

Player response (no real choice — narrative beat):
> *"Let's do it."*

**Scene: The Day Of** *(toast series during tournament event)*
- *"32 players signed up. Biggest day this course has ever seen."*
- *"Hole 6 is backing up — players taking pictures between shots."*
- Final toast: *"Tournament complete. Three players asked when the next one is."*

**Closing beat — Newspaper** (Dani Walsh byline):
> **LAKEWOOD COURIER**
> *"Hollis Course Enters the Big Leagues: WDGA Sanctioned Tournament Draws Regional Players"*
> — Dani Walsh

Player internal:
> *"Ray's name is in a headline. That one's for him."*

---

### Chapter 4 — Road Trip
**Trigger:** World Map unlocked (first world course purchased/unlocked)
**Emotional arc:** Local success → bigger world → humility
**Key event:** First away challenge at Maple Hill

**Scene: The Invitation** *(message from Jess Nakamura)*
> *"Maple Hill is hosting an open challenge week. Low-key, no rankings, just disc golf. I told them about your course. They want you there."*
>
> *"Pack light. These courses will make you rethink everything you built."*

**Opening DialogueOverlay as World Map opens:**
> *"You've built something worth being proud of. Now go see what the rest of the world built."*

**After first away round:**
> *"Humbling. Inspiring. Both at the same time."*
> *"You took notes the whole way around. Half of them were about your own course."*

**Closing beat:**
> *"Ray never left the county. But he built something that led you here. That counts for something."*

---

### Chapter 5 — National Stage
**Trigger:** Reach National prestige level
**Emotional arc:** Recognition → stakes raised → self-doubt → commitment
**Key event:** National championship invitation; Diana returns — not as a threat

**Scene: The Official Offer** *(WDGA letterhead; Marcus Bell listed as recommending official)*
> *"The WDGA National Circuit Committee is pleased to invite Hollis Course to apply as a host venue for the National Championship qualifying round."*
>
> *"Minimum requirements: 18 holes, course rating 4.0+, certified facilities..."*

**Scene: Diana, one last time** *(she appears at the course; sits on bench near Hole 1 — Ray's area)*
> *"I'm not here to make an offer. I just wanted to see it."*
>
> *"You know what Ray told me when he was building this? He said, 'Diana, I don't need it to be famous. I need it to be finished.'"*
>
> *"Looks like you finished it."*
>
> *"Good luck with the nationals."*

She leaves. No more buyout offers. She becomes a background ally — quietly sends one tournament sponsor your way, no explanation.

**Closing beat:**
> *"National-level players will walk Ray's holes. He never got to see it. You'll have to see it for him."*

---

### Chapter 6 — World Class
**Trigger:** World Class prestige + beat 5 world circuit courses
**Emotional arc:** Culmination → legacy → letting go
**Key event:** Course inducted into world rankings. Final cutscene.

**Scene: The Ranking Notification**
Not a letter. Not a newspaper. A single toast:
> *"Hollis Course has been added to the WDGA World Rankings."*

Then silence. Let the player sit with it.

**Final DialogueOverlay** *(player at Ray's bench, near Hole 1)*:
> *"The disc bag is still on the fence. You never moved it."*
>
> *"Ray's three holes are still here — buried inside the full 18 now, but they're here. You can walk them without a map."*
>
> *"You used to wonder if he left you this because he trusted you, or because he had nobody else."*
>
> *"You stopped wondering a long time ago."*
>
> *"Finish it, he said."*
>
> *"Done."*

**Final card** *(static screen; ambient wind/nature audio only — no music)*:
> *In memory of Raymond Hollis.*
> *He built three holes.*
> *That was enough to start.*

---

## Recurring Story Elements

**Dani Walsh (reporter):** Chapters 1, 3, 6. Never intrusive — her bylines mark milestones. In Ch5 she's implicitly present; in Ch6 listed in the world ranking article.

**Ray's disc bag on the fence:** Environmental storytelling. Never interactive. Never moves. Optional side-beat: regular NPC asks about it. Player can respond "It belongs there."

**The shed:** Mentioned in Ray's letter. Pro shop upgrades can use this as flavor text: "You're converting Ray's storage, one upgrade at a time."

**Diana's bench:** After Ch5, if player places a Bench decor tile near Hole 1, toast fires:
> *"You placed a bench where Diana sat. Felt like the right spot."*

---

## Dialogue Tone Guide

- Short sentences. Ray's influence — he was a man of few words.
- Player character observes and reflects quietly. Doesn't preach.
- Diana is never cartoonishly evil. She has a point. She's just not *your* point.
- Marcus is warm but slightly overwhelmed. The sport is bigger than his paperwork.
- Jess is direct in the way athletes are — not rude, just blunt.
- No exclamation points in serious moments. Save them for toast notifications.
- Newspaper headlines: understated local paper voice. Not breathless.
- Internal monologue: second person ("You took notes..."). Present tense.

---

## GoalsSystem Hook Map

| Chapter | Existing hook |
|---|---|
| 0 | `first_hole` |
| 1 | `six_holes` + first VIP spawn |
| 2 | EconomyManager prestige == "Regional" |
| 3 | `first_tourney` |
| 4 | WorldMap first unlock |
| 5 | prestige == "National" |
| 6 | prestige == "World Class" + 5 circuit course wins |

---

## Implementation Checklist

All beat text above lives in `autoloads/StoryManager.gd` → `BEATS` (edit there; no code changes needed).
Chapter triggers as implemented: Ch1 six holes · Ch2 Regional prestige · Ch3 first tournament ·
Ch4 a circuit course unlocked (+1 day after Ch3) · Ch5 National prestige · Ch6 World Class + 5 WDGA-certified circuit courses (9+ holes, 3.5★, restroom).

- [x] `StoryManager` autoload — tracks `_chapter: int`, fires beats, gates World Map until Ch4
- [x] `DialogueOverlay` screen — portrait left, text right, Next button, skip button
- [x] Character portrait assets — original flat-vector set from `tools/gen_portraits.py` (player, Jess, Marcus, Diana, the Regular); Ray/Dani never show one
- [x] Opening letter screen (letter style; handwritten font dropped by design)
- [x] Ch0 camera pan across Ray's holes (`ch0_pan`, style `pan`; Esc/click skips)
- [x] Newspaper overlay (newspaper style with dynamic headline)
- [x] Ch3 tournament-day toast series (sign-ups → Hole 6 backing up → three players asked)
- [x] Ch4 away rounds — World Map → **Play an Away Round** plays the front nine of any unlocked circuit course (`core/data/AwayLayouts.gd`, real routing from each preset) with the Test Course controls; `ch4_first_away` fires after the first completed round; best score per course is saved
- [x] Ch5 Diana's sponsor — after her visit, the next tournament's purse is matched by Cross Pines Holdings (once, min $10,000)
- [x] Final static card screen (black card style; music fades out and an original wind/birds loop plays — `tools/gen_ambient_wind.py`)
- [x] Ch6 epilogue — Dani Walsh's world-rankings article the in-game day after the final card (`ch6_dani`)
- [x] Recurring: Ray's disc bag hangs on the home gate (`PropFactory.make_ray_bag`); a regular asks about it from Ch2 ("It belongs there.")
- [x] Recurring: the shed — first Pro Shop upgrade at home toasts "You're converting Ray's storage, one upgrade at a time."
- [x] Recurring: Diana's bench toast after Ch5
- [x] `EventBus` signals: `story_chapter_started(chapter: int)`, `story_beat_fired(beat_id: String)`, `away_round_started/completed`, `facility_upgraded`
