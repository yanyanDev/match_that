# Match That! — Game Spec (v1)

Decided through a grill-me session on 2026-11-17. Each decision lists its reason so it can be revisited deliberately rather than drifted from.

## 1. Overview

A pass-free, shared-phone fingerboard game. The phone sits on the table, shows a random trick, and players compete to land it. Two modes share one engine:

- **Default (turn-based):** players take single attempts in order. High pressure.
- **Rush:** everyone attempts at once; first to land scores. High urgency. *(Details deferred — see §9.)*

## 2. Core rules — Default mode

| # | Rule | Why |
|---|------|-----|
| R1 | Each attempt ends with one tap: **Landed** or **Missed**. One attempt per turn; the turn advances on every tap. | App can't see the board, so it needs explicit input; one attempt per turn creates pressure. |
| R2 | No automatic pauses. A **Pause** button stops the timer and opens a menu: **Resume**, **Undo last call**, **End game**. | Keeps the game fast; undo lives in the menu to keep the play screen clean. |
| R3 | Undo is **one step** and **never rewinds the timer**. | Prevents undo from being used to buy time. |
| R4 | Undoing a **Landed** restores the previous trick with `remaining_at_tap − time_elapsed_on_new_trick`. If ≤ 0, the restored trick is treated as expired. Undoing a **Missed** restores the turn and miss counter; the clock is untouched. | One continuous clock, consistent with R3. |
| R5 | A trick ends when it is **landed**, its **timer expires**, or after **two full rounds of misses** (miss count ≥ 2 × players). | Timer adds tension; miss limit stops unlandable tricks dragging, especially with 2 players. Two rounds = leniency. |
| R6 | Landing awards the trick's points to the active player and generates a new trick. | — |
| R7 | **Turn order never breaks.** After any trick ends, the next player in order starts the new trick. | Simple; fairness evens out over a game. |
| R8 | Only **landed** tricks count toward the target (Quickplay 10 / Full 30). | Original design intent. |
| R9 | **End game** (pause menu) ends any game immediately; current scores decide the winner. | Escape hatch for games that stall (R8 can otherwise never terminate on a too-hard difficulty). |
| R10 | Ties go to **sudden death** (see §3). | Decisive finish. |

## 3. Sudden death

- Only tied players participate. Each round, every remaining player gets **one attempt at the same trick**, in turn order.
- Landers advance; missers are eliminated. **If everyone misses, nobody is eliminated** and a new trick is drawn.
- Repeat until one player remains. If several land, they play another round.
- Tricks come from the game's difficulty (assumed — confirm).
- **End game** during sudden death → shared win among remaining players.

## 4. Timer & app lifecycle

- Each trick has a timer; length depends on difficulty. **Start value: 60 s for all difficulties**, tune in playtesting.
- **3-2-1 countdown** at game start (shows the starting player). The timer starts after "1".
- **Trick reveal (~1 s)** before every subsequent trick, in the next player's color: "NEW TRICK", or "TIME'S UP" / "MISSED OUT" when the previous trick was discarded. The trick timer starts **after** the reveal. Engine models this as a transition state with a configurable duration (0 in tests).
- Pause stops the timer. **Resume runs the 3-2-1 countdown.**
- App going to background → **auto-pause** (resume via pause menu, with countdown).
- Screen kept awake during play (wakelock).
- Engine design note: the engine does **not** own a real `Timer`. It receives elapsed time (ticks) from outside, so timer logic is deterministic and unit-testable.

## 5. Trick library

| # | Rule | Why |
|---|------|-----|
| T1 | A **flat list** of tricks, but each trick stores its **components** as separate fields: `stance`, `trick`, `modifier` (optional). | Playable now; combo generation later without data migration. |
| T2 | **Flatground only** for v1. | No obstacle setup needed. |
| T3 | **Points = base(trick) + stance bonus + modifier bonus**, with an optional per-trick `pointsOverride`. | Consistent scoring; ready for generated combos. |
| T4 | **Difficulty is derived from final points** (after override) via thresholds. | One number drives both score and bag — they can't disagree. |
| T5 | Trick display is **name only** (no descriptions). | Audience knows trick names; description field can be added later. |
| T6 | Library is a bundled, read-only **`assets/tricks.json`**, validated on load (malformed entries rejected). | Data separate from code; easy tuning. |
| T7 | Target library size: **≥ 15–20 tricks per difficulty tier.** | Keeps bag exhaustion (T10) rare. |

### Drawing tricks

| # | Rule |
|---|------|
| T8 | **Weighted mix** centered on game difficulty. Start weights (Beginner/Intermediate/Advanced tricks): Beginner game **80/20/0**, Intermediate **20/60/20**, Advanced **10/30/60**. |
| T9 | **One shuffle bag per tier.** The weighted roll picks a tier; draw from that tier's bag without replacement; reshuffle when empty. |
| T10 | A **discarded** trick (timer expiry or miss-out) is **removed for the rest of the game**, even across reshuffles. |
| T11 | If a tier's pool is empty, its weight is **redistributed proportionally** to non-empty tiers. If all tiers are empty, the game **ends automatically** (as End game). |

## 6. Players & setup

| # | Rule |
|---|------|
| P1 | Player limits: **Default 2–8**, **Rush 2–4**. No solo. |
| P2 | Setup order: **mode first**, then players, difficulty, length. Player limit follows the mode, so invalid setups are impossible. |
| P3 | Players get **editable default names** ("Player 1…") and an **auto-assigned color**. |
| P4 | **Random first player** at game start (and on rematch); turns then follow setup order. |

## 7. Screens

**Precedence rule: this spec overrides the Figma design.** Where they conflict, the design is updated to match the spec.

1. **Home** — title, Start.
2. **Setup** — players (stepper, 2–8) → game length → difficulty → player names (separate Names screen) → Start game. **Mode row hidden in v1**; the settings model still has `mode` (defaults to Default) and limits derive from it. When Rush ships, add "00 / MODE" at the top.
3. **Names** — editable default names, each with its **auto-assigned color** (P3).
4. **Countdown** — 3-2-1 with current player; used at game start and on Resume.
5. **Game** — progress label (counts **landed** tricks, R8), score cards for all players (must fit **up to 8** — scrolling row or compact layout), current turn + up next, trick card (difficulty, points, **name only — no description**, T5), timer + bar, **Missed** / **Matched** buttons, Pause. "Matched" is the UI label for Landed.
6. **Trick reveal** — ~1 s transition (see §4).
7. **Pause menu** — Resume, Undo last call, End game.
8. **Sudden death** — game screen variant with banner; tied players only.
9. **Results** — winner (or sudden-death winner / shared win), final standings, **Play again** (= Rematch, same setup) / **New game** (back to Setup).

Design follow-ups (not spec-dictated, decide during step 8): make Missed/Matched taller with a gap (tapped from across a table); "How to play" content; contents of Setup's ☰ menu; "your own boards" helper copy only applies to Rush.

## 8. Persistence, platforms, tech, testing

- **Persistence:** remember the **last setup** (players, colors, mode, difficulty, length) via `shared_preferences`. No mid-game saves in v1, but engine state is plain data objects so it's possible later.
- **Platforms:** Android first (emulator), plus a **Flutter web build** hosted for a resume demo link. Android + iOS store releases later (iOS needs a Mac or cloud macOS CI).
- **State management:** **Cubit** (`flutter_bloc`).
- **Architecture:** game engine in **pure Dart, no Flutter imports**. Cubit is the thin layer between engine and widgets. Shared across modes: trick library, bags, scoring, players, undo. Mode-specific: turn/timer rules.
- **Testing:** engine **unit tests** (test-first, one per rule above) + **Cubit tests** with `bloc_test`. Widget tests deferred until screens stabilize.

## 9. Deferred (and why it's safe)

| Item | Why deferring is safe |
|------|----------------------|
| Rush mode details (timer length, button layout, nobody-lands case) | Shares the engine; only adds a mode-specific rule set. |
| Generated combos | Components already stored separately (T1); points formula already component-based (T3). |
| Trick descriptions | Additive optional field. |
| Mid-game save/resume | Engine state is plain data; becomes serialization work, not redesign. |
| Custom tricks | JSON format already defined; needs editor UI + validation. |
| Saved player profiles | Extends last-setup persistence. |
| Results summary ("7 landed, 3 discarded") | Engine already knows trick outcomes. |
| Speed bonus / scoring variants | Scoring is one function. |
| Widget tests | Screens still changing. |
| iOS release | No code changes expected; needs Mac/cloud CI. |
| **Tuning values:** timer per difficulty, base/stance/modifier points, difficulty thresholds, tier weights | All data/config — set by playtesting. |

## 10. Build order

Each step is small, testable, and ends with a commit.

0. **Project setup:** add `flutter_bloc`, `bloc_test`, `shared_preferences`, `wakelock_plus`; create `lib/engine/`, `lib/cubits/`, `lib/screens/`, `assets/tricks.json`; add a `CLAUDE.md` with conventions; commit this spec as `docs/SPEC.md`.
1. **Trick model:** components, points formula, override, derived difficulty, JSON parsing + validation. *(tests first)*
2. **Trick bags:** weighted tier roll, per-tier shuffle bags, discard removal, weight redistribution, all-empty signal. Use an injected seeded `Random`. *(tests first)*
3. **Players & turns:** player list, random first player, turn advancement. *(tests first)*
4. **Trick lifecycle (Default mode):** Landed/Missed, 2-round miss limit, tick-driven timer expiry, landed-count target, game over. *(tests first)*
5. **Pause, undo, end game:** single snapshot, continuous-clock undo (R4), end game. *(tests first)*
6. **Sudden death.** *(tests first)*
7. **GameCubit:** wraps the engine, owns the real ticker; `bloc_test` coverage.
8. **Screens:** Setup (no mode row in v1), Names, Countdown, Game, Trick reveal, Pause menu, Results with Play again / New game. Follow the Figma design except where §7 says otherwise.
9. **Lifecycle:** auto-pause on background, wakelock.
10. **Persist last setup.**
11. **Web build + hosting** (e.g. GitHub Pages) → resume link.
12. **Rush mode** — grill its details first.
