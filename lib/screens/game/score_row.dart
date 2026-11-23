import 'package:flutter/widgets.dart';

import '../../engine/players.dart';
import '../../ui/widgets/score_card.dart';

/// Every player's score card in a horizontal scrolling row (D3). When the
/// turn moves, the active card scrolls into view.
///
/// A StatefulWidget: unlike a StatelessWidget, it has a [State] object that
/// lives on between rebuilds. Here that State holds one key per card, and
/// reacts when the active seat changes ([didUpdateWidget]).
class ScoreRow extends StatefulWidget {
  const ScoreRow({
    super.key,
    required this.players,
    required this.scores,
    required this.activeSeat,
  });

  final List<Player> players;
  final Map<String, int> scores;
  final int activeSeat;

  @override
  State<ScoreRow> createState() => _ScoreRowState();
}

class _ScoreRowState extends State<ScoreRow> {
  /// A GlobalKey lets us find a specific widget's place on screen later
  /// (its `currentContext`), here to scroll a card into view.
  final Map<int, GlobalKey> _cardKeys = {};

  GlobalKey _keyFor(int seat) => _cardKeys.putIfAbsent(seat, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _scrollToActiveAfterFrame(animate: false); // random first player (P4)
  }

  /// Called when the parent rebuilds this widget with new values.
  @override
  void didUpdateWidget(ScoreRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeSeat != widget.activeSeat) {
      _scrollToActiveAfterFrame(animate: true);
    }
  }

  /// Scrolling needs the cards laid out, so it waits until the frame is
  /// drawn.
  void _scrollToActiveAfterFrame({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final card = _cardKeys[widget.activeSeat]?.currentContext;
      if (!mounted || card == null) return;
      Scrollable.ensureVisible(
        card,
        alignment: 0.5, // center it where possible
        duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // At most 8 cards (P1), so a plain Row in a scroll view builds them all;
    // a lazy ListView wouldn't build off-screen cards, so they couldn't be
    // scrolled to.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final player in widget.players) ...[
            if (player != widget.players.first) const SizedBox(width: 8),
            ScoreCard(
              key: _keyFor(player.seat),
              name: player.name,
              score: widget.scores[player.id] ?? 0,
              color: player.color,
              active: player.seat == widget.activeSeat,
            ),
          ],
        ],
      ),
    );
  }
}
