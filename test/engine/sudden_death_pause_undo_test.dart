// Spec §10 step 6, round 2 — pause, End game and undo in sudden death
// (§3 S7, S8; §4b U1–U6). Written test-first.
//
// Sudden death has no trick timer, so the trick clock never moves in it and
// an undo subtracts nothing (S8). A restored sudden death trick has 0 time
// left but is never treated as timed out.

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/game_state.dart';

import '../helpers/game_helpers.dart';

void main() {
  final timedTie = timed(target: 2);

  group('S7: pause and resume in sudden death', () {
    test('pause in the countdown: no time passes, taps are ignored', () {
      final (game, sd) = tiedGame(config: timedTie);
      final p = game.pause(sd);

      expect(p.paused, isTrue);
      expect(p.inSuddenDeath, isTrue);
      expect(game.tick(p, secs(10)), same(p));
      expect(game.landed(p), same(p));
    });

    test('pause while attempting: taps are ignored', () {
      final (game, sd) = tiedGame(config: timedTie);
      final p = game.pause(toPlay(game, sd));

      expect(p.paused, isTrue);
      expect(game.landed(p), same(p));
      expect(game.missed(p), same(p));
    });

    test('pause in a reveal: no time passes', () {
      final (game, sd) = tiedGame(config: timedTie);
      final reveal = play(game, sd, 'LL');
      expect(reveal.phase, GamePhase.reveal);

      final p = game.pause(reveal);
      expect(game.tick(p, secs(10)), same(p));
    });

    test('resume runs the countdown, then attempting with still no timer', () {
      final (game, sd) = tiedGame(config: timedTie);
      final resumed = game.resume(game.pause(toPlay(game, sd)));
      expect(resumed.phase, GamePhase.countdown);
      expect(resumed.phaseRemaining, secs(3));

      final back = game.tick(resumed, secs(3));
      expect(back.phase, GamePhase.attempting);
      expect(back.phaseRemaining, Duration.zero);
      expect(back.inSuddenDeath, isTrue);
      expect(game.tick(back, secs(30)), same(back));
    });

    test('resume in a reveal goes back to it with the time it had left', () {
      final (game, sd) = tiedGame(config: timedTie);
      final reveal = game.tick(play(game, sd, 'LL'), ms(400));

      final back = game.tick(game.resume(game.pause(reveal)), secs(3));
      expect(back.phase, GamePhase.reveal);
      expect(back.phaseRemaining, ms(600));
    });
  });

  group('S7: End game in sudden death', () {
    test('gameOver with a shared win among the players still in, not by '
        'score', () {
      final (game, sd) = allTied(3);
      final round2 = play(game, sd, 'LML'); // p2 out; all still on 1 point

      final over = game.endGame(game.pause(round2));
      expect(over.phase, GamePhase.gameOver); // no new sudden death
      expect(over.endReason, GameEndReason.endedByPlayers);
      expect(over.paused, isFalse);
      expect(over.inSuddenDeath, isFalse);
      expect(over.scores, {'p1': 1, 'p2': 1, 'p3': 1});
      expect(ids(over.winners), ['p1', 'p3']);
    });

    test('clears the undo', () {
      final (game, sd) = tiedGame();
      final over = game.endGame(game.pause(game.landed(sd)));

      expect(over.canUndo, isFalse);
      expect(over.beforeLastCall, isNull);
      expect(game.undo(over), same(over));
    });
  });

  group('S8: undo in sudden death', () {
    test('a call mid-round: same trick, the player and their call are back, '
        'paused, no timeout', () {
      final (game, sd) = tiedGame();
      final landed = game.landed(sd); // p1 L: p2's turn

      final u = game.undo(game.pause(landed));
      expect(u.paused, isTrue);
      expect(u.phase, GamePhase.attempting);
      expect(u.phaseRemaining, Duration.zero);
      expect(u.inSuddenDeath, isTrue);
      expect(u.currentTrick!.id, 't2');
      expect(u.currentPlayer.id, 'p1');
      expect(u.suddenDeath!.landed, isEmpty);
      expect(u.suddenDeath!.missed, isEmpty);
      expect(u.lastOutcome, sd.lastOutcome);
      expect(u.bags.discardedIds, isEmpty);
      expect(u.canUndo, isFalse); // one step only
    });

    test('the call that ended a round where nobody landed: the discard is '
        'undone and the new trick goes back in its bag', () {
      final (game, sd) = tiedGame();
      final missed = game.missed(sd); // p1 M
      final round2 = game.missed(missed); // p2 M: t2 discarded, t3 drawn
      expect(round2.bags.discardedIds, {'t2'});

      final u = game.undo(game.pause(round2));
      expect(u.currentTrick!.id, 't2');
      expect(u.bags, same(missed.bags));
      expect(u.currentPlayer.id, 'p2');
      expect(u.suddenDeath!.roundStarter, 0);
      expect(u.suddenDeath!.missed, {0});
      expect(u.phase, GamePhase.attempting);
    });

    test('the call that knocked players out: they are back in', () {
      final (game, sd) = allTied(3);
      final round2 = play(game, sd, 'LML'); // p2 out, p3 starts round 2
      expect(round2.turnOrder.seats, [0, 2]);

      final u = game.undo(game.pause(round2));
      expect(u.turnOrder.seats, [0, 1, 2]);
      expect(ids(u.remainingPlayers), ['p1', 'p2', 'p3']);
      expect(u.currentPlayer.id, 'p3');
      expect(u.suddenDeath!.roundStarter, 0);
      expect(u.suddenDeath!.landed, {0});
      expect(u.suddenDeath!.missed, {1});
      expect(u.currentTrick!.id, 't3');
    });

    test('undone during the next round\'s reveal: no timeout either', () {
      final (game, sd) = tiedGame(config: timedTie);
      final reveal = game.tick(play(game, sd, 'MM'), ms(400));
      expect(reveal.phase, GamePhase.reveal);

      final u = game.undo(game.pause(reveal));
      expect(u.phase, GamePhase.attempting);
      expect(u.currentTrick!.id, 't2');
      expect(u.bags.discardedIds, isEmpty);
    });

    test('after an undo, resume and the same call give the same result', () {
      final (game, sd) = tiedGame();
      final once = game.missed(sd);

      final u = game.undo(game.pause(once));
      final again = game.missed(game.resume(u)); // 0 countdown: straight back
      expect(summary(again), summary(once));
    });

    test('pause, resume and taps-free time keep the undo', () {
      final (game, sd) = tiedGame(config: timedTie);
      final s = game.landed(toPlay(game, sd));
      final later = game.tick(game.resume(game.pause(s)), secs(20));

      expect(game.pause(later).canUndo, isTrue);
    });
  });

  group('S8: undo across the start of sudden death', () {
    test('the call that started it: back to normal play, nothing '
        'subtracted', () {
      final (game, start) = startGame(
        library: equalLibrary(6),
        config: timedTie,
      );
      final first = game.landed(game.tick(start, secs(3))); // p1 +1
      final before = game.tick(first, secs(21)); // reveal + 20 s: 40 s left
      final sd = game.landed(before); // p2 +1: 1–1, sudden death
      expect(sd.inSuddenDeath, isTrue);
      // The sudden death countdown, then 30 s with no timer.
      final later = game.tick(game.tick(sd, secs(3)), secs(30));

      final u = game.undo(game.pause(later));
      expect(u.suddenDeath, isNull);
      expect(u.inSuddenDeath, isFalse);
      expect(u.paused, isTrue);
      expect(u.phase, GamePhase.attempting);
      expect(u.currentTrick!.id, 't1');
      expect(u.phaseRemaining, secs(40));
      expect(u.currentPlayer.id, 'p2');
      expect(u.turnOrder.seats, [0, 1]);
      expect(u.scores, {'p1': 1, 'p2': 0});
      expect(u.landedCount, 1);
      expect(u.bags, same(before.bags)); // sudden death's draw goes back
    });

    test('started by End game: nothing to undo before the first sudden '
        'death call', () {
      final (game, start) = startGame(library: equalLibrary(6));
      final sd = game.endGame(game.pause(play(game, start, 'LL')));

      final p = game.pause(sd);
      expect(p.canUndo, isFalse);
      expect(game.undo(p), same(p));
    });
  });

  group('S8, U3: undo from Results after sudden death is decided', () {
    test('the deciding call can be undone: back to the paused round', () {
      final (game, sd) = tiedGame();
      final over = play(game, sd, 'LM'); // p1 wins
      expect(over.endReason, GameEndReason.suddenDeathWon);
      expect(over.canUndo, isTrue); // not paused, but on Results

      final u = game.undo(over);
      expect(u.phase, GamePhase.attempting);
      expect(u.paused, isTrue);
      expect(u.endReason, isNull);
      expect(u.inSuddenDeath, isTrue);
      expect(ids(u.remainingPlayers), ['p1', 'p2']);
      expect(u.currentPlayer.id, 'p2');
      expect(u.currentTrick!.id, 't2');
      expect(u.suddenDeath!.landed, {0});
      expect(u.canUndo, isFalse); // one step only
      expect(game.undo(u), same(u));
    });

    test('resume after it runs the countdown, then the round goes on', () {
      final (game, sd) = tiedGame(config: timedTie);
      final over = play(game, sd, 'LM');

      final resumed = game.resume(game.undo(over));
      expect(resumed.phase, GamePhase.countdown);
      final back = game.tick(resumed, secs(3));
      expect(back.phase, GamePhase.attempting);
      expect(back.currentPlayer.id, 'p2');
      // This time p2 lands too: the round ends with nobody out.
      final round2 = game.landed(back);
      expect(round2.lastOutcome, roundEnded('t2', []));
      expect(ids(round2.remainingPlayers), ['p1', 'p2']);
    });

    test('not after End game or running out of tricks in sudden death', () {
      final (game, sd) = tiedGame();
      final ended = game.endGame(game.pause(sd));
      expect(ended.canUndo, isFalse);

      final (game2, sd2) = allTied(3, tricks: 3);
      final noTricks = play(
        game2,
        sd2,
        'LLM'
        'MM'
        'MM'
        'MM',
      );
      expect(noTricks.endReason, GameEndReason.noDrawableTricks);
      expect(noTricks.canUndo, isFalse);
    });
  });
}
