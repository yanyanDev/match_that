# Match That! — instructions for Claude

## Project
A Flutter fingerboard party game. The full spec is in `docs/SPEC.md`. **The spec is the source of truth**: it overrides the Figma design and any assumption of yours. If a request conflicts with the spec, say so before writing code.

## The developer
I'm new to Flutter and building this to learn and for my resume. Keep me in the loop:
- Before writing code, explain your approach in a few sentences and name any alternatives. Wait for my go-ahead on anything non-trivial.
- Explain Flutter/Dart concepts the first time they appear (widgets, BuildContext, Cubit, streams, etc.).
- Keep changes small: one build step (spec §10) or less at a time.
- Never commit, push, or add packages without asking.

## Architecture
- `lib/engine/` — game logic in **pure Dart. No `package:flutter` imports.** Deterministic: inject `Random` and feed elapsed time in from outside; the engine never creates a real `Timer`.
- `lib/cubits/` — Cubits (`flutter_bloc`) that wrap the engine and own the real ticker.
- `lib/screens/` — widgets only; no game rules in widgets.
- `assets/tricks.json` — the trick library (read-only data).
- Game state is immutable plain data classes (needed for undo snapshots and future save/resume).

## Testing
- Engine code is written **test-first**: write the failing test, show it to me, then implement.
- Every rule in the spec (R1–R10, T1–T11, P1–P4) should have at least one test.
- Cubits are tested with `bloc_test`.
- Before saying a change is done, run `flutter analyze` and `flutter test` and report the results.

## Conventions
- Follow `flutter_lints`. Prefer `const` constructors.
- UI label "Matched" = `landed` in code.
- Colors: background `#F3F1E9`, accent lime `#D9FF43`. Fonts: Anton (headlines), IBM Plex Mono (labels), Inter (body).
