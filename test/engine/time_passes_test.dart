// Spec §10 step 7, round 2 — GameState.timePasses (§4c A1; G2, U1, S3).
// Written test-first.
//
// The GameCubit runs its clock exactly while timePasses is true. It must
// agree with tick(): wherever it is false, a tick returns the very same
// state, so stopping the clock there loses nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/game_state.dart';
import 'package:match_that/engine/turn_based_game.dart';

import '../helpers/game_helpers.dart';

/// Checks that time passing really changes nothing in [s].
void expectTickIgnored(TurnBasedGame game, GameState s) {
  expect(s.timePasses, isFalse);
  expect(identical(game.tick(s, secs(1)), s), isTrue);
}

void main() {
  group('time passes', () {
    test('in the game-start countdown', () {
      final (_, start) = startGame(config: timed());

      expect(start.phase, GamePhase.countdown);
      expect(start.timePasses, isTrue);
    });

    test('while attempting', () {
      final (game, start) = startGame(config: timed());

      expect(toPlay(game, start).timePasses, isTrue);
    });

    test('in a reveal', () {
      final (game, start) = startGame(config: timed());
      final reveal = game.landed(toPlay(game, start));

      expect(reveal.phase, GamePhase.reveal);
      expect(reveal.timePasses, isTrue);
    });

    test('in a resume countdown', () {
      final (game, start) = startGame(config: timed());
      final resumed = game.resume(game.pause(toPlay(game, start)));

      expect(resumed.phase, GamePhase.countdown);
      expect(resumed.timePasses, isTrue);
    });

    test('in the sudden death countdown and reveals (S2, S3)', () {
      final (game, sd) = tiedGame(config: timed(target: 2));
      expect(sd.inSuddenDeath, isTrue);
      expect(sd.phase, GamePhase.countdown);
      expect(sd.timePasses, isTrue);

      // Both miss: nobody is out, a new trick is revealed (S4).
      final reveal = play(game, sd, 'MM');
      expect(reveal.phase, GamePhase.reveal);
      expect(reveal.timePasses, isTrue);
    });
  });

  group('time does not pass', () {
    test('while paused (U1)', () {
      final (game, start) = startGame(config: timed());

      expectTickIgnored(game, game.pause(toPlay(game, start)));
      expectTickIgnored(game, game.pause(start)); // paused in the countdown
    });

    test('in gameOver', () {
      final (game, start) = startGame(config: timed(target: 1));
      final over = game.landed(toPlay(game, start));

      expect(over.phase, GamePhase.gameOver);
      expectTickIgnored(game, over);
    });

    test('during a sudden death attempt: no timer (S3)', () {
      final (game, sd) = tiedGame(config: timed(target: 2));
      final attempting = toPlay(game, sd);

      expect(attempting.phase, GamePhase.attempting);
      expectTickIgnored(game, attempting);
    });
  });
}
