# Match That! 🛹

**A pass-and-play party game for fingerboarders.** The phone sits on the table and shows a random trick. Players take turns trying to land it before the timer runs out.

<!-- Replace with a short GIF from the playtest or a screen recording -->
![Match That! gameplay](docs/media/gameplay.gif)

> **Status:** Android build playtested with real players 🎉 · Web demo coming soon

---

## How it plays

- **2–8 players** share one phone on the table.
- The app shows a random **trick** with its **points** and a **timer**.
- On your turn you get **one attempt**, then tap **Matched** or **Missed**.
- Land it and you score the points, and a new trick comes up for the next player.
- The trick is **discarded** if the timer runs out, or after **two full rounds of misses**.
- The first game to **10** (Quick Play) or **30** (Full Game) landed tricks ends, and the highest score wins.
- If players are tied at the end, they go to **sudden death**: everyone gets one attempt at the same trick, and anyone who misses is out.
- **Pause** at any time to resume, **undo the last call**, or end the game.

Players choose a **difficulty** (Beginner, Intermediate or Advanced). Each difficulty mixes in some tricks from the other tiers, so every game has some variety.

## How it's built

| | |
|---|---|
| **Framework** | Flutter (Android first, web next, iOS later) |
| **State** | Cubit (`flutter_bloc`) |
| **Game engine** | Pure Dart, **no Flutter imports**. It's immutable plain data, where every input returns a new state |
| **Time** | The engine never reads a real clock. It receives elapsed time from the Cubit, so the timer is fully deterministic and unit-testable |
| **Tricks** | Generated from rules, not hand-written (see below) |

```
lib/
  engine/    # pure Dart game rules: tricks, bags, turns, timer, undo, sudden death
  cubits/    # thin layer between the engine and the UI, owns the real clock
  screens/   # Flutter UI
data/
  trick_rules.json   # base tricks, stances, modifiers, naming rules
tool/
  generate_tricks.dart  # expands the rules into the flat trick library
assets/
  tricks.json        # generated: 324 tricks, read by the app
docs/
  SPEC.md            # the full game spec, every rule with its reason
```

### Tricks as data

The trick library isn't written by hand. `data/trick_rules.json` describes base tricks, stances (Regular, Fakie, Nollie, Switch), rotations and reverts, which combinations are allowed, and custom names (for example, Fakie + BS180 Kickflip = *Halfcab Flip*). `tool/generate_tricks.dart` expands these into **324 tricks**, each with its points and difficulty tier.

Because of this, **rebalancing the game is a data change, not a code change.** Edit the rules and regenerate. A golden test makes sure the committed `assets/tricks.json` always matches the generator's output.

## How I worked

This project is also a practice run at **AI-assisted development done properly**. I worked with [Claude](https://claude.ai) as a pair programmer, using two rules:

1. **Spec first.** Before writing any code, Claude grilled me on every rule (*what happens on a tie? can undo buy extra time?*) until each decision was written down **with its reason**. The result is [`docs/SPEC.md`](docs/SPEC.md). When the spec and the Figma design disagree, the spec wins.
2. **Red-green-refactor.** Every rule in the spec went through the cycle: a failing test first, the smallest change to pass it, then a cleanup with the tests still green. The work was done in small steps, each ending in a commit.

Engine rules have **unit tests**, the Cubits have **`bloc_test`** tests with a fake clock, and each screen has a **smoke widget test**. Project conventions for the AI pair live in [`CLAUDE.md`](CLAUDE.md).

## Run it

```bash
flutter pub get
flutter run                          # run on a device or emulator
flutter test                         # run all tests
dart run tool/generate_tricks.dart   # regenerate assets/tricks.json after editing data/trick_rules.json
```

## Playtest #1: what I learned

**Worked**
- It got competitive fast: score tracking, celebrations and groans within minutes.
- The trick variety surprised people. The generator brings up niche combinations nobody expected.

**Didn't**
- Players kept asking how many points the current trick was worth, so the points need to stand out more.
- Players disagreed about some point values. These are being tuned through the rules file.

## Roadmap

- [x] Trick library and generator
- [x] Game engine: turns, timer, miss limit, pause and undo, sudden death
- [x] Cubits and all screens (Home, Setup, Names, Game, Results, How to play)
- [x] First playtest
- [ ] Make trick points more visible (from playtest feedback)
- [ ] Tune point values from playtest feedback
- [ ] Auto-pause when the app goes to the background, keep the screen awake
- [ ] Remember the last setup
- [ ] **Web build**, playable in your browser
- [ ] **Rush mode**: everyone attempts at once, first to land scores

## License

<!-- Pick one: MIT if others may reuse the code; omit or "All rights reserved" if you want to keep the game yours -->
TBD
