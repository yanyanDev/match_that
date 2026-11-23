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

## 3. Sudden death (step 6)

| # | Rule |
|---|------|
| S1 | **Trigger:** when the game would end with **2+ winners** (G10) by reaching the target or by End game, sudden death starts among the tied players instead of `gameOver`. If it ended because **nothing is drawable** (G9), there's nothing to play: it's a **shared win**. When End game starts sudden death, round 1 gets a **freshly drawn** trick; the unfinished one is not discarded. |
| S2 | Sudden death starts with the **countdown**; each later round's trick gets the **reveal**. |
| S3 | **Rounds:** every remaining player gets **exactly one attempt** at the **same trick**, one call each (Matched or Missed). **No timer** in sudden death: ticks only run the countdown and reveal. |
| S4 | **End of a round** (everyone remaining has called): landers stay, missers are out. **If nobody landed, nobody is out.** If exactly one player remains, they **win** (`gameOver`). Otherwise a new round starts with a **new trick**. |
| S5 | **Tricks** are drawn with the **same weights as the game**, from the **same bags** (discards still apply). A trick everyone missed is **discarded** (T10); a trick someone landed is not. **No points** are scored in sudden death — scores stay as they were. |
| S6 | **Order:** round 1 starts with the tied player who is **next in the game's turn order** when sudden death begins (after a deciding landing: the first tied player after the lander; after End game: the player whose turn it was if they're tied, otherwise the first tied player after them). Each later round starts with the **next remaining player after the previous round's starter** (wrapping, skipping eliminated players), so the start rotates. |
| S7 | **Pause, Resume and End game** work as in §4b. **End game during sudden death** → `gameOver` with a **shared win** among the remaining players. |
| S8 | **Undo** works as in §4b (one step; no trick clock in sudden death, so nothing is subtracted). It can undo a call that ended a round, and the call that **started** sudden death (back to normal play). From **Results**, it can undo the call that **decided** sudden death. |
| S9 | If **nothing is drawable** during sudden death → `gameOver` with a **shared win** among the remaining players. |

## 4. Timer & app lifecycle

- Each trick has a timer; length depends on difficulty. **Start value: 60 s for all difficulties**, tune in playtesting.
- **3-2-1 countdown** at game start (shows the starting player). The timer starts after "1".
- **Trick reveal (~1 s)** before every subsequent trick, in the next player's color: "NEW TRICK", or "TIME'S UP" / "MISSED OUT" when the previous trick was discarded. The trick timer starts **after** the reveal. Engine models this as a transition state with a configurable duration (0 in tests).
- Pause stops the timer. **Resume runs the 3-2-1 countdown.**
- App going to background → **auto-pause** (resume via pause menu, with countdown).
- Screen kept awake during play (wakelock).
- Engine design note: the engine does **not** own a real `Timer`. It receives elapsed time (ticks) from outside, so timer logic is deterministic and unit-testable.

## 4a. Game engine flow — Default mode (step 4)

| # | Rule |
|---|------|
| G1 | **Settings:** mode (only `turnBased` playable in v1), difficulty, length (**Quickplay 10 / Full 30** landed tricks). Timer per difficulty is config with default **60 s**; countdown **3 s** and reveal **1 s** are config too (0 allowed in tests). |
| G2 | **Phases:** `countdown` → `attempting` ⇄ `reveal` → `gameOver`. The trick timer runs **only in `attempting`**. Pause (step 5) is separate. |
| G3 | **Time input:** the engine receives `tick(Duration elapsed)` in milliseconds from the Cubit. Leftover time **carries over**: a tick longer than what's left of a phase finishes it and spends the rest in the next phase. The UI rounds remaining time **up** to whole seconds for display. |
| G4 | **Inputs** are `landed()` and `missed()`. They only count in `attempting`; at any other time (countdown, reveal, game over, or after a tick already expired the trick) they are **ignored** and the state is unchanged. |
| G5 | **Landed:** the current player gets the trick's points; landed count +1. If the target is reached → `gameOver`. Otherwise draw a new trick, advance the turn, and show the reveal. |
| G6 | **Missed:** miss count +1 and the turn advances; the same trick continues with the clock still running. At **2 × player count** misses the trick is discarded (T10), the turn advances, and a new trick is revealed. |
| G7 | **Timer expiry:** the trick is discarded (T10); the turn advances from the player whose turn it was; a new trick is revealed. |
| G8 | The state exposes the **last outcome** (landed by player X for N points / timed out / missed out) so the UI can show "+3 ALEX", "TIME'S UP" or "MISSED OUT" during `reveal`. It is kept until the next trick ends. |
| G9 | If a draw returns "no drawable tricks" (T11), the game goes to `gameOver` (as End game). |
| G10 | `gameOver` exposes final scores and the **winner list** (everyone tied for the highest score). A tie with 2+ winners is resolved by sudden death in step 6; step 4 only reports it. |
| G11 | The game state is **immutable plain data** (every input returns a new state) built from the step 1–3 pieces: `TrickBags`, `TurnOrder`, players. The rules object holds what never changes during a game: config (including `DrawWeights`), the trick library and the injected `Random`. |

## 4b. Pause, undo, end game (step 5)

| # | Rule |
|---|------|
| U1 | **Pause** is allowed in `countdown`, `attempting` and `reveal` (not `gameOver`). While paused, no phase time passes: ticks change nothing and taps are ignored (G4). |
| U2 | **Resume** runs the 3-2-1 countdown (`config.countdown`), then returns to the paused phase with the time it had left. If the game was paused **during a countdown**, resuming just runs a full countdown, then `attempting`. If it was paused **during a resume countdown**, resuming runs a full countdown, then returns to the originally paused phase with the time it had left. |
| U3 | **Undo last call** reverses the most recent `landed()` or `missed()`. It is available **while paused** (pause menu) and in `gameOver` **only when the game ended by a call** — reaching the target, or the call that decided sudden death (S8) (Results screen). One step only: after an undo there is nothing more to undo. |
| U4 | The undo is **cleared** by the next call, a timeout, End game, or using it. A timeout is not a call and can't be undone. |
| U5 | Undo restores the state from **just before the call** (trick, scores, landed count, miss count, turn, bags — a newly drawn trick goes back in its bag and a miss-out discard is undone), then **subtracts the trick time spent since the call** (R3, R4). Only time in `attempting` counts — reveal, countdown and paused time do not. If that leaves the restored trick with ≤ 0 time, it **times out** immediately (G7). This one rule covers all three cases: a plain miss (same trick, clock unchanged), a landing, and a miss-out. |
| U6 | After an undo the game is **paused**; Resume continues with the countdown. Undo from the Results screen returns to the paused game. |
| U7 | **End game** (pause menu) goes to `gameOver` with reason "ended by players"; winners per G10 (a tie goes to sudden death, step 6). |

## 4c. App layer: Cubits (step 7)

| # | Rule |
|---|------|
| A1 | **Clock:** the `GameCubit` owns the real clock: `Timer.periodic` every **100 ms** plus a `Stopwatch`, passing the **actually elapsed** time to `tick` (G3), not an assumed 100 ms. The clock is **injectable**, so tests drive time without real waiting. It only runs while time matters: not while paused, in `gameOver`, or during a sudden-death attempt (no timer, S3). When the clock stops (pause, game over, sudden-death attempt), the up to 100 ms since the last tick isn't counted. |
| A2 | **GameCubit:** one per game, created by Start game with the settings, players and trick library. Its state is the engine's `GameState`. Its methods map 1:1 to the engine: `matched`, `missed`, `pause`, `resume`, `undo`, `endGame`, plus `rematch` (same settings and players, new game, random first player again — P4), which works **only from `gameOver`** (ignored otherwise). Closing it stops the clock. `Random` is injected (production: `Random()`). |
| A3 | **Trick library loading:** `assets/tricks.json` is loaded **once at app start** and parsed with `parseTricks`. Any parse error is a bug in the data: show an error screen rather than a broken game. The loader is injectable so tests use a JSON string. |
| A4 | **SetupCubit:** holds player count (stepper, limits from `GameMode.turnBased` in v1), length, difficulty, raw names, and per-seat name errors from `buildPlayers`. **Start game** is only possible when the names are valid. Defaults: **2 players, Quickplay, Beginner**. Lowering the count drops the last seat; raising it adds a blank seat and keeps existing names. Designed so step 10 can start it from a saved setup. |
| A5 | **Debug screen (throwaway):** plain buttons (Matched, Missed, Pause, Resume, Undo, End game, Rematch) and a text readout (phase, time left rounded **up** to whole seconds, current player, up next, trick and points, scores, last outcome, sudden-death info). Reachable from Home. **Deleted in step 8.** Not unit-tested. |
| A6 | **Tests:** both Cubits are tested with `bloc_test` and a fake clock. The engine stays pure Dart; only `lib/cubits/` and `lib/screens/` import Flutter. |

## 5. Trick library

| # | Rule | Why |
|---|------|-----|
| T1 | Trick rules live in **`data/trick_rules.json`** (base tricks, stances, modifiers, allowed combinations, custom names — from `MATCH_THAT_Tricks.pdf`). A Dart script, **`tool/generate_tricks.dart`**, expands them into the **flat list** `assets/tricks.json` the app reads. Each entry keeps its components: `trick`, `stance`, `modifier` (optional). | Rules stay editable as rules; the app stays simple; ~320 combos without hand-writing them. |
| T2 | **Flatground only** for v1. | No obstacle setup needed. |
| T3 | **Points = base(trick) + stance bonus + modifier bonus**, computed by the generator and stored in `tricks.json`. A trick has at most **one modifier** (rotation or revert). | Consistent scoring across all combos. |
| T4 | **Difficulty is derived from final points** (after override) via thresholds. | One number drives both score and bag — they can't disagree. |
| T5 | Trick display is **name only** (no descriptions). | Audience knows trick names; description field can be added later. |
| T6 | `assets/tricks.json` is bundled and read-only. The parser returns tricks **plus a list of errors** (good entries still load); a test asserts the real file has **zero errors**. | Data typos fail a test, not a game. |
| T6a | Trick rules (from the PDF): flatground only; no manuals, grinds, slides, grabs or footplants (except No-Comply Ollie). Body-360 rotations: **Backside 360 only** for Regular/Fakie/Nollie; **Frontside 360 only** for Switch. Custom names with a stance (e.g. Fakie + BS180 = "Halfcab Flip") fully override; custom names without a stance (e.g. Revert Hardflip = "Ghetto Bird") keep the stance prefix ("Nollie Ghetto Bird"). Naming order: stance · rotation · trick · revert. | Encoded as data in `trick_rules.json`. |
| T7 | Target library size: **≥ 15–20 tricks per difficulty tier.** Current generated library: 324 tricks (70 / 138 / 116 at thresholds 5 / 8). | Keeps bag exhaustion (T10) rare. |

### Drawing tricks

| # | Rule |
|---|------|
| T8 | **Weighted mix** centered on game difficulty. Start weights (Beginner/Intermediate/Advanced tricks): Beginner game **80/20/0**, Intermediate **20/60/20**, Advanced **10/30/60**. |
| T8a | Weights live in a Dart config object (`DrawWeights`) with the values above as defaults, passed into the draw; tests supply their own. Weights must be ≥ 0 and not all 0. |
| T9 | **One shuffle bag per tier.** The weighted roll picks a tier; draw from that tier's bag without replacement; reshuffle when empty. |
| T9a | After a reshuffle, the first trick drawn is never the same as the trick drawn just before it (unless it is the only trick left in that tier). |
| T9b | Draw state is **immutable**: drawing returns the trick plus a new state, so undo can restore the exact previous state. `Random` is injected (seeded in tests). |
| T10 | A **discarded** trick (timer expiry or miss-out) is **removed for the rest of the game**, even across reshuffles. |
| T11 | A tier is **unavailable** when all its tricks are discarded **or its weight is 0**. Unavailable tiers' weight is **redistributed proportionally** to available tiers. If no tier is available, the draw reports "no drawable tricks" and the game **ends automatically** (as End game). Landed tricks are not removed; they return at the next reshuffle. |

## 6. Players & setup

| # | Rule |
|---|------|
| P1 | Player limits: **Default 2–8**, **Rush 2–4**. No solo. Limits are defined on a `GameMode` enum in the engine. |
| P2 | Setup order: **mode first**, then players, difficulty, length. Player limit follows the mode, so invalid setups are impossible. |
| P3 | Players get **editable default names** ("Player 1…") and an **auto-assigned color**. |
| P3a | Names are **trimmed**; a blank name becomes "Player N" (N = seat number). Max **12 characters**. **Duplicates are blocked**, compared trimmed and case-insensitive (this includes a typed name that equals another seat's default, e.g. "player 2"). |
| P3b | Colors come from a **fixed palette of 8**, assigned **by seat** (seat 1 = color 1). Not changeable in v1. The engine stores a `PlayerColor` value (no Flutter `Color`); the UI maps it to real colors. |
| P5 | Players have an internal **id** separate from their name. Turn order is a list of seats; "next player" wraps around. Design it so a **subset** of players (sudden death, §3) can take turns in the same order. |
| P4 | **Random first player** at game start (and on rematch); turns then follow setup order. |

## 7. Screens

**Precedence rule: this spec overrides the Figma design.** Where they conflict, the design is updated to match the spec.

1. **Home** — title, Start.
2. **Setup** — players (stepper, 2–8) → game length → difficulty → player names (separate Names screen) → Start game. **Mode row hidden in v1**; the settings model still has `mode` (defaults to Default) and limits derive from it. When Rush ships, add "00 / MODE" at the top.
3. **Names** — editable default names, each with its **auto-assigned color** (P3).
4. **Countdown** — 3-2-1 with current player; used at game start and on Resume.
5. **Game** — progress label (counts **landed** tricks, R8), score cards for all players (scrolling row, D3), current turn + up next, trick card (difficulty, points, **name only — no description**, T5), timer + bar, **Missed** / **Matched** buttons, Pause. "Matched" is the UI label for Landed.
6. **Trick reveal** — ~1 s transition (see §4).
7. **Pause menu** — Resume, Undo last call, End game.
8. **Sudden death** — game screen variant with banner; tied players only.
9. **Results** — winner (or sudden-death winner / shared win), final standings, **Play again** (= Rematch, same setup) / **New game** (back to Setup).

### Design decisions (step 8)

| # | Rule |
|---|------|
| D1 | **Player palette** (P3b), seat 1–8: Lime `#D9FF43`, Sky `#7CC8FF`, Tangerine `#FFA24C`, Pink `#FF8FC7`, Mint `#5EE6B0`, Lavender `#B9A6FF`, Sun `#FFD84D`, Coral `#FF7A6B`. Black text (`#1A1A1A`) on every one is ≥ 6.8 : 1 contrast. They are all close to the cream background, so colored surfaces keep a **1 px black border**. Seat 1 = Lime matches the Figma. |
| D2 | The **active player's score card fills with that player's color**; other cards are cream with a black border. The current-turn name and the reveal use the player's color too. Lime stays the UI accent (Matched, Start, primary buttons). |
| D3 | **Score cards** sit in a **horizontal scrolling row** (same card as Figma); the active card scrolls into view automatically. |
| D4 | **Game screen:** progress label "LANDED n/10" (R8); trick card with difficulty, points, **name only** (T5), time left rounded **up** (G3) and a progress bar; **Missed** and **Matched** at least **72 dp** tall with a **16 dp** gap; Pause top-right. It rebuilds the timer only when the shown second or bar changes (`buildWhen`), not on every 100 ms tick. |
| D5 | Screens not in the Figma — **trick reveal, pause menu, sudden-death banner, tie / shared-win results, library error** — are designed by Claude Code in the Figma's style (cream background, black ink, lime accent, Anton / IBM Plex Mono / Inter, square-cornered outlined boxes) and reviewed on the emulator. |
| D6 | **Navigation:** Flutter's plain `Navigator` (push/pop), no router package. Flow: Home → Setup → Names → Game (countdown, reveal, pause menu and sudden death happen **inside** the game screen) → Results. Play again = `rematch` on the same Cubit; New game → back to Setup with the setup kept for this session (saving it across launches is step 10). |
| D7 | **Results:** headline names the winner ("ALEX WINS!", "ALEX WINS IN SUDDEN DEATH!", or "ALEX & SAM SHARE THE WIN!"); standings sorted by score; **Play again**, **New game**, and **Undo last call** only when `canUndo` (U3, S8). |
| D8 | **Setup cleanup for v1:** remove the ☰ menu and the "your own boards" helper text (Rush only). **How to play** opens a simple text screen with the Default-mode rules in plain words. |
| D9 | **Debug screen** (A5) is deleted once Setup can start a real game. |
| D10 | **Widget tests:** each screen gets a small smoke test (renders without errors; its main buttons call the right Cubit method). No screenshot/golden tests in v1. |


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
| Custom challenges (multi-trick sequences) | Stored under `deferred` in `trick_rules.json`; need rules for scoring and one-attempt turns. |
| Spice-up modifiers ("Eyes Closed!", "Back Me Up!", etc.) | Stored under `deferred`; "Back Me Up!" changes scoring (R6), so it needs its own grill. |
| Rare modifiers, body varials | PDF defines a (rare) marker and mentions body varials, but none are used yet. |
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
1. **Trick model** *(tests first)*:
   - 1a. `Trick` model + parser for `assets/tricks.json`: derived difficulty from thresholds, validation errors list, "real file has zero errors" test.
   - 1b. `tool/generate_tricks.dart`: expands `data/trick_rules.json`; tests for stance/rotation bans, custom-name rules, points formula; golden test that its output matches the committed `assets/tricks.json`.
2. **Trick bags:** weighted tier roll, per-tier shuffle bags, discard removal, weight redistribution, all-empty signal. Use an injected seeded `Random`. *(tests first)*
3. **Players & turns:** player list, random first player, turn advancement. *(tests first)*
4. **Trick lifecycle (Default mode):** Landed/Missed, 2-round miss limit, tick-driven timer expiry, landed-count target, game over. *(tests first)*
5. **Pause, undo, end game:** single snapshot, continuous-clock undo (R4), end game. *(tests first)*
6. **Sudden death.** *(tests first)*
7. **Cubits (§4c):** GameCubit (wraps the engine, owns the 100 ms clock), SetupCubit, trick library loading, and a throwaway debug screen; `bloc_test` coverage.
8. **Screens (§7, D1–D10)**, one PR each:
   - 8a. Theme and shared widgets: colors, palette (D1), fonts, buttons, score card.
   - 8b. Game screen with countdown, reveal, pause menu and sudden death, opened from the debug entry with the default setup.
   - 8c. Setup and Names wired to `SetupCubit`; Home → Setup → Names → Game; delete the debug screen (D9).
   - 8d. Results (D7) and How to play (D8).
9. **Lifecycle:** auto-pause on background, wakelock.
10. **Persist last setup.**
11. **Web build + hosting** (e.g. GitHub Pages) → resume link.
12. **Rush mode** — grill its details first.
