// Spec §10 step 7, round 2 — GameCubit (§4c A1, A2, A6).
// Written test-first.
//
// The Cubit wraps the engine: each method hands the current state to the
// engine and emits what comes back, unless it is the very same object
// (nothing changed). It owns the clock and runs it exactly while
// state.timePasses is true. Tests inject a FakeClock and move time with
// clock.elapse(...), so nothing waits for real time.
//
// Plain `test`s read cubit.state and clock.isRunning directly (both update
// synchronously). `blocTest`s check the exact list of emitted states.

import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/cubits/game_cubit.dart';
import 'package:match_that/engine/game_config.dart';
import 'package:match_that/engine/game_state.dart';
import 'package:match_that/engine/trick.dart';

import '../helpers/fake_clock.dart';
import '../helpers/fake_random.dart';
import '../helpers/game_helpers.dart';

/// A `Random` that returns [scripted] values first, then 0 forever.
class ThenZeroRandom implements Random {
  ThenZeroRandom(this.scripted);

  final List<int> scripted;
  int _next = 0;

  @override
  int nextInt(int max) => _next < scripted.length ? scripted[_next++] : 0;

  @override
  double nextDouble() => throw UnimplementedError();

  @override
  bool nextBool() => throw UnimplementedError();
}

late FakeClock clock;

/// A GameCubit on [clock]. ZeroRandom by default: seat 0 (p1) starts and
/// tricks come out in library order (b0, b1, b2 for [library3]).
GameCubit makeCubit({
  GameConfig? config,
  int players = 2,
  List<Trick>? library,
  Random? random,
}) => GameCubit(
  config: config ?? timed(),
  players: makePlayers(players),
  library: library ?? library3,
  random: random ?? ZeroRandom(),
  clock: clock,
);

Matcher inPhase(GamePhase phase, {bool paused = false}) => isA<GameState>()
    .having((s) => s.phase, 'phase', phase)
    .having((s) => s.paused, 'paused', paused);

Matcher left(Duration time) =>
    isA<GameState>().having((s) => s.phaseRemaining, 'phaseRemaining', time);

Matcher turnOf(String playerId) =>
    isA<GameState>().having((s) => s.currentPlayer.id, 'current', playerId);

Matcher outcome(Matcher matcher) =>
    isA<GameState>().having((s) => s.lastOutcome, 'lastOutcome', matcher);

void main() {
  setUp(() => clock = FakeClock());

  group('A2: wraps the engine', () {
    test('exposes the game config (the Game screen needs its timings)', () {
      final config = timed(reveal: ms(800));
      expect(makeCubit(config: config).config, same(config));
    });

    test('starts with the engine\'s new game: countdown, b0, p1', () {
      final s = makeCubit().state;

      expect(s, inPhase(GamePhase.countdown));
      expect(s.phaseRemaining, secs(3));
      expect(s.currentTrick!.id, 'b0');
      expect(s.currentPlayer.id, 'p1');
    });

    blocTest<GameCubit, GameState>(
      'matched = the engine\'s landed: points, next trick, next player',
      build: () => makeCubit(config: instant()),
      act: (c) => c.matched(),
      expect: () => [allOf(outcome(landedBy('b0', 'p1', 3)), turnOf('p2'))],
      verify: (c) => expect(c.state.scores, {'p1': 3, 'p2': 0}),
    );

    blocTest<GameCubit, GameState>(
      'missed: miss count 1, same trick, next player',
      build: () => makeCubit(config: instant()),
      act: (c) => c.missed(),
      expect: () => [
        allOf(
          isA<GameState>().having((s) => s.missCount, 'missCount', 1),
          turnOf('p2'),
        ),
      ],
      verify: (c) => expect(c.state.currentTrick!.id, 'b0'),
    );

    blocTest<GameCubit, GameState>(
      'pause, then resume runs the countdown (U2)',
      build: () => makeCubit(),
      act: (c) {
        clock.elapse(secs(3));
        c
          ..pause()
          ..resume();
      },
      expect: () => [
        inPhase(GamePhase.attempting),
        inPhase(GamePhase.attempting, paused: true),
        allOf(inPhase(GamePhase.countdown), left(secs(3))),
      ],
    );

    blocTest<GameCubit, GameState>(
      'undo restores the state before the call, paused (U5, U6)',
      build: () => makeCubit(config: instant()),
      act: (c) => c
        ..matched()
        ..pause()
        ..undo(),
      skip: 2,
      expect: () => [
        allOf(
          inPhase(GamePhase.attempting, paused: true),
          turnOf('p1'),
          isA<GameState>().having((s) => s.landedCount, 'landed', 0),
        ),
      ],
    );

    blocTest<GameCubit, GameState>(
      'endGame while paused: gameOver, ended by players (U7)',
      build: () => makeCubit(config: instant()),
      act: (c) => c
        ..matched()
        ..pause()
        ..endGame(),
      skip: 2,
      expect: () => [
        allOf(
          inPhase(GamePhase.gameOver),
          isA<GameState>().having(
            (s) => s.endReason,
            'endReason',
            GameEndReason.endedByPlayers,
          ),
        ),
      ],
      verify: (c) => expect(ids(c.state.winners), ['p1']),
    );
  });

  group('A2: rematch (P4)', () {
    test('after gameOver: a new game, random first player again', () {
      // start uses Random 3 times (first player + one draw); the rematch's
      // first call picks its first player: seat 1.
      final c = makeCubit(
        config: timed(target: 1),
        random: ThenZeroRandom([0, 0, 0, 1]),
      );
      clock.elapse(secs(3));
      c.matched();
      expect(c.state.phase, GamePhase.gameOver);

      c.rematch();

      expect(c.state, inPhase(GamePhase.countdown));
      expect(c.state.currentPlayer.id, 'p2');
      expect(c.state.scores, {'p1': 0, 'p2': 0});
      expect(c.state.landedCount, 0);
      expect(c.state.endReason, isNull);
      expect(c.state.lastOutcome, isNull);
      expect(c.state.canUndo, isFalse);
      expect(ids(c.state.players), ['p1', 'p2']);
      expect(clock.isRunning, isTrue);
    });

    test('a rematch gets fresh bags: discards are back', () {
      final c = makeCubit(config: timed(target: 1));
      clock.elapse(secs(3 + 60)); // b0 times out and is discarded (T10)
      expect(c.state.bags.discardedIds, contains('b0'));
      clock.elapse(secs(1)); // reveal
      c.matched();
      expect(c.state.phase, GamePhase.gameOver);

      c.rematch();

      expect(c.state.bags.discardedIds, isEmpty);
      expect(c.state.currentTrick!.id, 'b0');
    });

    blocTest<GameCubit, GameState>(
      'ignored outside gameOver (A2)',
      build: () => makeCubit(config: instant()),
      act: (c) => c.rematch(),
      expect: () => [],
    );
  });

  group('A1: real elapsed time goes to tick', () {
    blocTest<GameCubit, GameState>(
      'each tick sends exactly the time the clock measured, not 100 ms',
      build: () => makeCubit(),
      act: (c) => clock
        ..elapse(secs(3))
        ..elapse(ms(137))
        ..elapse(ms(98)),
      expect: () => [
        allOf(inPhase(GamePhase.attempting), left(secs(60))),
        left(secs(60) - ms(137)),
        left(secs(60) - ms(235)),
      ],
    );

    blocTest<GameCubit, GameState>(
      'one long tick carries over through several phases (G3)',
      build: () => makeCubit(),
      // 3 s countdown, 60 s of b0 (times out), 1 s reveal, 0.5 s of b1.
      act: (c) => clock.elapse(ms(64500)),
      expect: () => [
        allOf(
          inPhase(GamePhase.attempting),
          left(ms(59500)),
          outcome(timedOut('b0')),
        ),
      ],
    );
  });

  group('A1: the clock runs only while time passes', () {
    test('running from the start (countdown)', () {
      makeCubit();
      expect(clock.isRunning, isTrue);
    });

    test('pause stops it; resume starts it again, once', () {
      final c = makeCubit();
      clock.elapse(secs(3));

      c.pause();
      expect(clock.isRunning, isFalse);

      c.resume();
      expect(clock.isRunning, isTrue);
      expect(clock.starts, 2);
    });

    blocTest<GameCubit, GameState>(
      'time while paused is never sent: no ticks, no states',
      build: () => makeCubit(),
      act: (c) {
        clock.elapse(secs(3));
        c.pause();
        clock.elapse(secs(30));
      },
      skip: 1,
      expect: () => [inPhase(GamePhase.attempting, paused: true)],
    );

    test('a call that reaches the target stops it', () {
      final c = makeCubit(config: timed(target: 1));
      clock.elapse(secs(3));

      c.matched();

      expect(c.state.phase, GamePhase.gameOver);
      expect(clock.isRunning, isFalse);
    });

    test('undo from Results: paused, still stopped; resume starts it', () {
      final c = makeCubit(config: timed(target: 1));
      clock.elapse(secs(3));
      c.matched();

      c.undo();
      expect(c.state, inPhase(GamePhase.attempting, paused: true));
      expect(clock.isRunning, isFalse);

      c.resume();
      expect(clock.isRunning, isTrue);
    });

    test('End game with a clear winner stops it', () {
      final c = makeCubit();
      clock.elapse(secs(3));
      c
        ..matched() // p1: 3 points
        ..pause()
        ..endGame();

      expect(c.state.phase, GamePhase.gameOver);
      expect(clock.isRunning, isFalse);
    });

    test('End game on a tie: sudden death countdown, running (S1, S2)', () {
      final c = makeCubit();
      clock.elapse(secs(3));
      c
        ..pause()
        ..endGame(); // 0–0

      expect(c.state.inSuddenDeath, isTrue);
      expect(c.state, inPhase(GamePhase.countdown));
      expect(clock.isRunning, isTrue);
    });

    test(
      'sudden death: runs in countdown and reveals, not in attempts (S3)',
      () {
        // 2 players, target 2, 1-point tricks: p1 and p2 land → 1–1.
        final c = makeCubit(config: timed(target: 2), library: equalLibrary(6));
        clock.elapse(secs(3));
        c.matched();
        clock.elapse(secs(1));
        c.matched();
        expect(c.state.inSuddenDeath, isTrue);
        expect(c.state, inPhase(GamePhase.countdown));
        expect(clock.isRunning, isTrue);

        clock.elapse(secs(3));
        expect(c.state, inPhase(GamePhase.attempting));
        expect(clock.isRunning, isFalse);

        c
          ..missed()
          ..missed(); // nobody landed: nobody out, new trick (S4)
        expect(c.state, inPhase(GamePhase.reveal));
        expect(clock.isRunning, isTrue);

        clock.elapse(secs(1));
        expect(c.state, inPhase(GamePhase.attempting));
        expect(clock.isRunning, isFalse);
      },
    );
  });

  group('no state is emitted when nothing changed', () {
    blocTest<GameCubit, GameState>(
      'matched during the countdown, as the very first action',
      build: () => makeCubit(),
      act: (c) => c.matched(),
      expect: () => [],
    );

    blocTest<GameCubit, GameState>(
      'pause twice emits once',
      build: () => makeCubit(config: instant()),
      act: (c) => c
        ..pause()
        ..pause(),
      expect: () => [inPhase(GamePhase.attempting, paused: true)],
    );

    blocTest<GameCubit, GameState>(
      'resume when not paused',
      build: () => makeCubit(config: instant()),
      act: (c) => c.resume(),
      expect: () => [],
    );

    blocTest<GameCubit, GameState>(
      'undo with nothing to undo',
      build: () => makeCubit(config: instant()),
      act: (c) => c
        ..pause()
        ..undo(),
      skip: 1,
      expect: () => [],
    );

    blocTest<GameCubit, GameState>(
      'endGame when not paused',
      build: () => makeCubit(config: instant()),
      act: (c) => c.endGame(),
      expect: () => [],
    );

    blocTest<GameCubit, GameState>(
      'a zero-length tick',
      build: () => makeCubit(),
      act: (c) => clock.elapse(Duration.zero),
      expect: () => [],
    );
  });

  group('a whole game through the Cubit', () {
    /// Checks the key state after a step, and whether the clock runs.
    void check(
      GameCubit c, {
      required GamePhase phase,
      bool paused = false,
      required int landed,
      required Map<String, int> scores,
      required bool running,
    }) {
      expect(c.state, inPhase(phase, paused: paused));
      expect(c.state.landedCount, landed);
      expect(c.state.scores, scores);
      expect(clock.isRunning, running, reason: 'clock running');
    }

    test('2-player Quickplay, countdown to gameOver', () {
      // The production settings (3 s countdown, 1 s reveal, 60 s per trick,
      // target 10) and a seeded Random, so who starts and which trick comes
      // up aren't scripted: the test reads them from the state as it goes.
      // Tricks are worth 1–6, and from step 8 on only A lands, so A ends
      // with at least 9 points and B with at most 6: no tie.
      final c = GameCubit(
        config: GameConfig.forSetup(Difficulty.beginner, GameLength.quickplay),
        players: makePlayers(2),
        library: [for (var i = 0; i < 6; i++) trick('t$i', i + 1)],
        random: Random(7),
        clock: clock,
      );
      final scores = {'p1': 0, 'p2': 0};

      // 1. Countdown.
      check(
        c,
        phase: GamePhase.countdown,
        landed: 0,
        scores: scores,
        running: true,
      );
      expect(c.state.phaseRemaining, secs(3));

      // 2. The countdown ends: A's first trick, full timer.
      clock.elapse(secs(3));
      check(
        c,
        phase: GamePhase.attempting,
        landed: 0,
        scores: scores,
        running: true,
      );
      expect(c.state.phaseRemaining, secs(60));
      final a = c.state.currentPlayer.id;
      final b = a == 'p1' ? 'p2' : 'p1';

      // 3. A lands it after 10 s: points, reveal, B's turn.
      clock.elapse(secs(10));
      final first = c.state.currentTrick!;
      c.matched();
      scores[a] = first.points;
      check(
        c,
        phase: GamePhase.reveal,
        landed: 1,
        scores: scores,
        running: true,
      );
      expect(c.state.lastOutcome, landedBy(first.id, a, first.points));

      // 4. B misses: same trick, A's turn, clock still going.
      clock.elapse(secs(1));
      expect(c.state.currentPlayer.id, b);
      final timingOut = c.state.currentTrick!;
      c.missed();
      check(
        c,
        phase: GamePhase.attempting,
        landed: 1,
        scores: scores,
        running: true,
      );
      expect(c.state.missCount, 1);
      expect(c.state.currentPlayer.id, a);

      // 5. Nobody calls; the timer runs out: discarded, B's turn (G7).
      clock.elapse(secs(60));
      check(
        c,
        phase: GamePhase.reveal,
        landed: 1,
        scores: scores,
        running: true,
      );
      expect(c.state.lastOutcome, timedOut(timingOut.id));
      expect(c.state.bags.discardedIds, contains(timingOut.id));

      // 6. Pause mid-trick: the clock stops, paused time changes nothing;
      //    resume runs the countdown, then the same time left.
      clock.elapse(secs(1));
      clock.elapse(secs(5));
      c.pause();
      check(
        c,
        phase: GamePhase.attempting,
        paused: true,
        landed: 1,
        scores: scores,
        running: false,
      );
      clock.elapse(secs(30));
      expect(c.state.phaseRemaining, secs(55));
      c.resume();
      check(
        c,
        phase: GamePhase.countdown,
        landed: 1,
        scores: scores,
        running: true,
      );
      clock.elapse(secs(3));
      check(
        c,
        phase: GamePhase.attempting,
        landed: 1,
        scores: scores,
        running: true,
      );
      expect(c.state.phaseRemaining, secs(55));

      // 7. B lands, then the players undo it: back to B's trick, paused.
      expect(c.state.currentPlayer.id, b);
      final undone = c.state.currentTrick!;
      c.matched();
      check(
        c,
        phase: GamePhase.reveal,
        landed: 2,
        scores: {...scores, b: undone.points},
        running: true,
      );
      c.pause();
      expect(clock.isRunning, isFalse);
      c.undo();
      check(
        c,
        phase: GamePhase.attempting,
        paused: true,
        landed: 1,
        scores: scores,
        running: false,
      );
      expect(c.state.currentTrick!.id, undone.id);
      expect(c.state.currentPlayer.id, b);

      // ...and B lands it again for real.
      c.resume();
      clock.elapse(secs(3));
      c.matched();
      scores[b] = undone.points;
      check(
        c,
        phase: GamePhase.reveal,
        landed: 2,
        scores: scores,
        running: true,
      );

      // 8. Play on: B misses, A lands, until 10 tricks are landed.
      while (c.state.phase != GamePhase.gameOver) {
        clock.elapse(secs(1)); // reveal
        expect(c.state, inPhase(GamePhase.attempting));
        if (c.state.currentPlayer.id == b) c.missed();
        final landing = c.state.currentTrick!;
        c.matched();
        scores[a] = scores[a]! + landing.points;
        expect(c.state.scores, scores);
      }

      // 9. Game over: A wins on points, the clock is stopped, and the
      //    deciding call can still be undone from Results (U3).
      check(
        c,
        phase: GamePhase.gameOver,
        landed: 10,
        scores: scores,
        running: false,
      );
      expect(c.state.endReason, GameEndReason.targetReached);
      expect(ids(c.state.winners), [a]);
      expect(c.state.canUndo, isTrue);
      clock.elapse(secs(10));
      expect(c.state.phase, GamePhase.gameOver);
    });
  });

  group('close', () {
    blocTest<GameCubit, GameState>(
      'stops the clock; later time emits nothing',
      build: () => makeCubit(),
      act: (c) async {
        await c.close();
        clock.elapse(secs(1));
      },
      expect: () => [],
      verify: (_) => expect(clock.isRunning, isFalse),
    );
  });
}
