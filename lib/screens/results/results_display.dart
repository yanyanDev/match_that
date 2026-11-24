/// What the Results screen shows (spec §7 D7, D15): the headline and the
/// ranked standings. Plain functions, no widgets, so they're unit-tested
/// directly and the widgets stay free of game rules (CLAUDE.md).
library;

import '../../engine/game_config.dart';
import '../../engine/game_state.dart';
import '../../engine/players.dart';
import '../game/game_display.dart';

/// The headline (D7): "ALEX WINS!", "ALEX WINS IN SUDDEN DEATH!" or
/// "ALEX & SAM SHARE THE WIN!". Winners come from the engine (G10, S4, S7).
String resultsHeadline(GameState over) {
  final names = [for (final p in over.winners) p.name.toUpperCase()];
  if (names.length >= 2) return '${joinNames(names)} SHARE THE WIN!';
  return over.endReason == GameEndReason.suddenDeathWon
      ? '${names.single} WINS IN SUDDEN DEATH!'
      : '${names.single} WINS!';
}

/// One row of the final standings.
class Standing {
  const Standing({
    required this.player,
    required this.score,
    required this.rank,
    required this.isWinner,
    required this.wonSuddenDeath,
  });

  final Player player;
  final int score;

  /// 1-based. Equal scores in the same group share a rank (D15).
  final int rank;

  /// Filled with the player's color on Results (D15).
  final bool isWinner;

  /// Marked "SUDDEN DEATH" on Results: the one player who won it (S4).
  final bool wonSuddenDeath;
}

/// Every player, best first, with ranks (D15).
///
/// Winners come first, then by score (highest first), then by seat. A
/// sudden-death winner has the same points as the players they knocked out
/// (no points in sudden death, S5), and still ranks above them. Equal
/// scores share a rank only within the same group (winners / the rest), and
/// the next rank skips: 3, 3, 1 points → 1, 1, 3.
List<Standing> standings(GameState over) {
  final winnerIds = {for (final p in over.winners) p.id};
  final suddenDeathWon = over.endReason == GameEndReason.suddenDeathWon;
  int scoreOf(Player p) => over.scores[p.id] ?? 0;

  final sorted = [...over.players]
    ..sort((a, b) {
      final aWon = winnerIds.contains(a.id);
      if (aWon != winnerIds.contains(b.id)) return aWon ? -1 : 1;
      final byScore = scoreOf(b).compareTo(scoreOf(a));
      return byScore != 0 ? byScore : a.seat.compareTo(b.seat);
    });

  final rows = <Standing>[];
  for (var i = 0; i < sorted.length; i++) {
    final player = sorted[i];
    final isWinner = winnerIds.contains(player.id);
    final previous = rows.isEmpty ? null : rows.last;
    // Sorted, so equal (group, score) players are next to each other: a
    // tie keeps the previous rank, anything else takes its position.
    final tied =
        previous != null &&
        previous.isWinner == isWinner &&
        previous.score == scoreOf(player);
    rows.add(
      Standing(
        player: player,
        score: scoreOf(player),
        rank: tied ? previous.rank : i + 1,
        isWinner: isWinner,
        wonSuddenDeath: suddenDeathWon && isWinner,
      ),
    );
  }
  return rows;
}

/// The game length under the headline: "QUICK PLAY", "FULL GAME" (D15).
/// Any other target (only in tests) shows as "N TRICKS".
String lengthLabel(int target) {
  for (final length in GameLength.values) {
    if (length.target == target) {
      return switch (length) {
        GameLength.quickplay => 'QUICK PLAY',
        GameLength.full => 'FULL GAME',
      };
    }
  }
  return '$target TRICKS';
}
