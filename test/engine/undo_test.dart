// Spec §10 step 5, round 2 — undo last call (R3, R4, §4b U3–U6).
// Written test-first.
//
// Undo restores the state from just before the last landed()/missed(), then
// takes off the trick time (attempting only) spent since. The engine tracks
// that time with GameState.trickClock, which only ever goes forward.

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/game_state.dart';
import 'package:match_that/engine/turn_based_game.dart';

import '../helpers/game_helpers.dart';

/// No game-start countdown; 1 s reveal; 60 s per trick.
final noCountdown = timed(countdown: Duration.zero);

void main() {
  group('trickClock counts attempting time only (U5)', () {
    test('starts at 0; the countdown does not count', () {
      final (game, start) = startGame(config: timed());
      expect(start.trickClock, Duration.zero);

      final playing = game.tick(start, secs(3));
      expect(playing.phase, GamePhase.attempting);
      expect(playing.trickClock, Duration.zero);

      expect(game.tick(playing, secs(2)).trickClock, secs(2));
    });

    test('a tick through the countdown counts only its attempting part', () {
      final (game, start) = startGame(config: timed());
      expect(game.tick(start, ms(3500)).trickClock, ms(500));
    });

    test('reveal time does not count', () {
      final (game, start) = startGame(config: noCountdown);
      final reveal = game.landed(game.tick(start, secs(10)));
      final s = game.tick(reveal, ms(1500)); // 1 s reveal + 0.5 s of b1

      expect(s.trickClock, ms(10500));
    });

    test('the time that runs a trick out counts too', () {
      final (game, start) = startGame(config: noCountdown);
      // 60 s of b0 (times out) + 1 s reveal + 0.5 s of b1.
      final s = game.tick(start, ms(61500));

      expect(s.lastOutcome, timedOut('b0'));
      expect(s.trickClock, ms(60500));
    });

    test('paused time and resume countdowns do not count', () {
      final (game, start) = startGame(config: timed());
      final playing = game.tick(start, secs(13)); // 10 s of b0
      final paused = game.pause(playing);

      expect(game.tick(paused, secs(30)).trickClock, secs(10));

      final resumed = game.tick(game.resume(paused), secs(3)); // countdown
      expect(resumed.phase, GamePhase.attempting);
      expect(resumed.trickClock, secs(10));
    });
  });

  group('undo restores the state before the call (U5)', () {
    test('a plain miss: same trick, turn and miss count back, clock '
        'unchanged', () {
      final (game, start) = startGame(players: 3, config: noCountdown);
      final missed = game.missed(game.tick(start, secs(10))); // p1, 50 s left
      expect(missed.currentPlayer.seat, 1);
      final later = game.tick(missed, secs(5)); // 45 s left

      final u = game.undo(game.pause(later));
      expect(u.currentTrick!.id, 'b0');
      expect(u.missCount, 0);
      expect(u.currentPlayer.seat, 0);
      expect(u.phase, GamePhase.attempting);
      expect(u.phaseRemaining, secs(45)); // the clock never rewinds (R3)
      expect(u.trickClock, secs(15));
    });

    test('a landing: old trick, scores and count back, minus the time '
        'spent on the new trick (R4)', () {
      final (game, start) = startGame(config: noCountdown);
      final before = game.tick(start, secs(20)); // b0, 40 s left
      final landed = game.landed(before); // p1 +3, reveal of b1
      // 1 s reveal (doesn't count) + 15 s of b1.
      final later = game.tick(landed, secs(16));
      expect(later.currentTrick!.id, 'b1');
      expect(later.phaseRemaining, secs(45));

      final u = game.undo(game.pause(later));
      expect(u.currentTrick!.id, 'b0');
      expect(u.phase, GamePhase.attempting);
      expect(u.phaseRemaining, secs(25)); // 40 − 15
      expect(u.scores, {'p1': 0, 'p2': 0});
      expect(u.landedCount, 0);
      expect(u.currentPlayer.seat, 0);
      expect(u.lastOutcome, isNull);
      expect(u.trickClock, secs(35)); // the clock keeps its current value
    });

    test('a landing: the newly drawn trick goes back in its bag', () {
      final (game, start) = startGame(config: noCountdown);
      final before = game.tick(start, secs(20));
      final later = game.tick(game.landed(before), secs(16));

      final u = game.undo(game.pause(later));
      expect(u.bags, same(before.bags));

      // Landing again draws b1 again; with b1 still drawn it would be b2.
      final playing = game.tick(game.resume(u), secs(3)); // resume countdown
      expect(playing.currentTrick!.id, 'b0');
      expect(game.landed(playing).currentTrick!.id, 'b1');
    });

    test('a landing undone during the reveal: no trick time spent', () {
      final (game, start) = startGame(config: noCountdown);
      final landed = game.landed(game.tick(start, secs(20))); // 40 s left
      final reveal = game.tick(landed, ms(400));
      expect(reveal.phase, GamePhase.reveal);

      final u = game.undo(game.pause(reveal));
      expect(u.currentTrick!.id, 'b0');
      expect(u.phaseRemaining, secs(40));
    });

    test('a miss-out: the discarded trick comes back with its misses, '
        'minus the time spent since', () {
      final (game, start) = startGame(config: noCountdown);
      final three = times(3, game.tick(start, secs(10)), game.missed);
      expect(three.currentPlayer.seat, 1);
      final missOut = game.missed(three); // b0 discarded, reveal of b1
      expect(missOut.lastOutcome, missedOut('b0'));
      final later = game.tick(missOut, secs(6)); // reveal + 5 s of b1

      final u = game.undo(game.pause(later));
      expect(u.currentTrick!.id, 'b0');
      expect(u.bags.discardedIds, isEmpty); // drawable again
      expect(u.missCount, 3); // limit − 1
      expect(u.currentPlayer.seat, 1);
      expect(u.phaseRemaining, secs(45)); // 50 − 5
      expect(u.lastOutcome, isNull);
    });

    test('time split across several attempting stretches all comes off', () {
      final (game, start) = startGame(config: timed());
      final before = game.tick(start, secs(23)); // countdown + 20 s: 40 left
      final landed = game.landed(before);
      // Reveal, then 10 s of b1.
      final first = game.tick(landed, secs(11));
      expect(first.phaseRemaining, secs(50));

      // Pause, resume (3 s countdown doesn't count), 5 s more of b1.
      final resumed = game.tick(game.resume(game.pause(first)), secs(3));
      expect(resumed.phase, GamePhase.attempting);
      final second = game.tick(resumed, secs(5));
      expect(second.phaseRemaining, secs(45));

      final u = game.undo(game.pause(second));
      expect(u.currentTrick!.id, 'b0');
      expect(u.phaseRemaining, secs(25)); // 40 − (10 + 5)
    });
  });

  group('restored trick out of time (U5, G7)', () {
    /// Land with 10 s left, then spend [spent] on the next trick, pause and
    /// undo.
    (TurnBasedGame, GameState) undoAfter(Duration spent) {
      final (game, start) = startGame(config: noCountdown);
      final landed = game.landed(game.tick(start, secs(50))); // 10 s left
      final later = game.tick(game.tick(landed, secs(1)), spent);
      return (game, game.undo(game.pause(later)));
    }

    for (final (label, spent) in [
      ('exactly 0', secs(10)),
      ('below 0', secs(25)),
    ]) {
      test('$label left: it times out at once, and the game stays paused', () {
        final (_, u) = undoAfter(spent);

        expect(u.lastOutcome, timedOut('b0'));
        expect(u.bags.discardedIds, {'b0'});
        expect(u.scores, {'p1': 0, 'p2': 0}); // the landing is still undone
        expect(u.landedCount, 0);
        expect(u.currentPlayer.seat, 1); // advanced from p1, whose turn it was
        expect(u.currentTrick!.id, 'b1');
        expect(u.phase, GamePhase.reveal);
        expect(u.phaseRemaining, secs(1));
        expect(u.paused, isTrue);
        expect(u.canUndo, isFalse); // a timeout can't be undone (U4)
      });
    }

    test('times out with nothing drawable: gameOver, not paused (G9)', () {
      final (game, start) = startGame(
        library: [trick('only', 4)],
        config: noCountdown,
      );
      final landed = game.landed(game.tick(start, secs(50))); // 10 s left
      expect(landed.currentTrick!.id, 'only'); // landed tricks come back
      final later = game.tick(landed, secs(11)); // reveal + 10 s

      final u = game.undo(game.pause(later));
      expect(u.phase, GamePhase.gameOver);
      expect(u.endReason, GameEndReason.noDrawableTricks);
      expect(u.paused, isFalse);
      expect(u.lastOutcome, timedOut('only'));
      expect(u.currentTrick, isNull);
      expect(u.scores, {'p1': 0, 'p2': 0});
      expect(u.canUndo, isFalse);
    });
  });

  group('after an undo (U3, U6)', () {
    test('the game is paused; resume runs the countdown, then the restored '
        'time', () {
      final (game, start) = startGame(config: timed());
      final landed = game.landed(game.tick(start, secs(23))); // 40 s left
      final later = game.tick(landed, secs(16)); // reveal + 15 s

      final u = game.undo(game.pause(later));
      expect(u.paused, isTrue);
      expect(u.phaseRemaining, secs(25));

      final resumed = game.resume(u);
      expect(resumed.phase, GamePhase.countdown);
      expect(resumed.phaseRemaining, secs(3));

      final back = game.tick(resumed, secs(3));
      expect(back.phase, GamePhase.attempting);
      expect(back.currentTrick!.id, 'b0');
      expect(back.phaseRemaining, secs(25));
    });

    test('one step only: a second undo is ignored', () {
      final (game, start) = startGame(config: noCountdown);
      final s = game.missed(game.missed(start));

      final u = game.undo(game.pause(s));
      expect(u.missCount, 1);
      expect(u.canUndo, isFalse);
      expect(game.undo(u), same(u));
    });

    test('the snapshot holds no older snapshot', () {
      final (game, start) = startGame(config: noCountdown);
      final s = game.missed(game.missed(start));

      expect(s.beforeLastCall, isNotNull);
      expect(s.beforeLastCall!.missCount, 1);
      expect(s.beforeLastCall!.beforeLastCall, isNull);
    });

    test('undo leaves the state it was called on untouched', () {
      final (game, start) = startGame(config: noCountdown);
      final p = game.pause(game.missed(game.tick(start, secs(10))));
      final before = summary(p);

      game.undo(p);
      expect(summary(p), before);
      expect(p.canUndo, isTrue);
    });
  });

  group('when undo is available (U3, U4)', () {
    test('only while paused', () {
      final (game, start) = startGame(config: noCountdown);
      final s = game.missed(start);

      expect(s.canUndo, isFalse);
      expect(game.undo(s), same(s));
      expect(game.pause(s).canUndo, isTrue);
    });

    test('not at the start of a game: nothing to undo', () {
      final (game, start) = startGame(config: noCountdown);
      final p = game.pause(start);

      expect(p.canUndo, isFalse);
      expect(game.undo(p), same(p));
    });

    test('pause, resume and time passing keep it', () {
      final (game, start) = startGame(config: timed());
      final s = game.missed(game.tick(start, secs(10)));
      final later = game.tick(game.resume(game.pause(s)), secs(8));

      expect(game.pause(later).canUndo, isTrue);
    });

    test('the next call replaces it: undo reverts only the latest', () {
      final (game, start) = startGame(config: noCountdown);
      final landed = game.tick(game.landed(start), secs(1)); // b1 attempting
      final missed = game.missed(landed);

      final u = game.undo(game.pause(missed));
      expect(u.currentTrick!.id, 'b1');
      expect(u.landedCount, 1); // the landing stays
      expect(u.scores, {'p1': 3, 'p2': 0});
      expect(u.missCount, 0);
      expect(u.canUndo, isFalse);
    });

    test('a timeout clears it', () {
      final (game, start) = startGame(config: noCountdown);
      final missed = game.missed(start);
      final expired = game.tick(missed, secs(60));
      expect(expired.lastOutcome, timedOut('b0'));

      final p = game.pause(expired);
      expect(p.canUndo, isFalse);
      expect(p.beforeLastCall, isNull);
      expect(game.undo(p), same(p));
    });

    test('End game clears it', () {
      final (game, start) = startGame(config: noCountdown);
      // p1 lands +3 (so no tie), p2 misses: there is a call to undo.
      final over = game.endGame(game.pause(play(game, start, 'LM')));

      expect(over.endReason, GameEndReason.endedByPlayers);
      expect(over.canUndo, isFalse);
      expect(over.beforeLastCall, isNull);
      expect(game.undo(over), same(over));
    });

    test('not after a game over with nothing drawable', () {
      final (game, start) = startGame(library: [trick('only', 4)]);
      final over = times(4, start, game.missed); // miss-out, nothing left
      expect(over.endReason, GameEndReason.noDrawableTricks);

      expect(over.canUndo, isFalse);
      expect(game.undo(over), same(over));
    });
  });

  group('undo from the Results screen (U3, U6)', () {
    test('after reaching the target: back to the paused game', () {
      final (game, start) = startGame(config: timed(target: 2));
      final first = game.landed(game.tick(start, secs(3))); // p1 +3
      final playing = game.tick(first, secs(6)); // reveal + 5 s of b1
      final over = game.landed(playing); // p2 +5: target reached
      expect(over.phase, GamePhase.gameOver);
      expect(over.endReason, GameEndReason.targetReached);
      expect(over.canUndo, isTrue); // not paused, but on Results

      final u = game.undo(over);
      expect(u.phase, GamePhase.attempting);
      expect(u.paused, isTrue);
      expect(u.endReason, isNull);
      expect(u.currentTrick!.id, 'b1');
      expect(u.currentPlayer.seat, 1);
      expect(u.landedCount, 1);
      expect(u.scores, {'p1': 3, 'p2': 0});
      expect(u.phaseRemaining, secs(55)); // no trick time since the call
    });
  });
}
