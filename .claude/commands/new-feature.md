Plan and implement a new feature for Flyte: A Disc Golf Course Builder and Manager.

Feature: $ARGUMENTS

Before writing any code:
1. Check GOALS.md — confirm this fits Phase 1 scope (single-course builder/manager core loop). If it belongs in Phase 2+, say so and ask for confirmation.
2. Identify which existing systems this touches (EventBus signals needed? EconomyManager changes? New UI screen or existing screen extension?)
3. List every file that needs changes. Estimate: small (1–2 files) / medium (3–5) / large (6+).
4. Check for conflicts: does this overlap with any Known Issues or Deferred Work in CLAUDE.md?
5. Propose the minimal implementation — no gold-plating, no future-proofing beyond what's asked.

Present the plan in 3–5 bullet points. Wait for confirmation before writing code.

When implementing:
- Follow all CLAUDE.md architecture rules (EventBus for cross-system, InputHandler not Input.*, etc.)
- Add signals to EventBus.gd first if needed
- Economy changes via EconomyManager.earn() / spend() only
- Run /gdcheck when done
- No new autoloads unless truly necessary
