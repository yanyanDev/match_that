import 'package:flutter/material.dart';

import '../ui/app_text_styles.dart';

/// One section of the rules: a heading and its lines. Each line becomes its
/// own paragraph.
class _Section {
  const _Section(this.heading, this.lines);

  final String heading;
  final List<String> lines;
}

/// The Default-mode rules in plain words (spec §7 D8, D16). The developer
/// approved this wording; change it only with their OK.
const _sections = [
  _Section('THE IDEA', [
    'One phone, your board. The phone shows a trick and everyone takes '
        'turns trying to land it. Land it and you score its points.',
  ]),
  _Section('TAKING TURNS', [
    'A random player goes first, then turns follow the order you set up. '
        "Each turn is one try. After your try, tap MATCHED if you landed it "
        "or MISSED if you didn't. Either way, the turn passes to the next "
        'player.',
  ]),
  _Section('SCORING', [
    'Landing a trick scores the points shown on its card, and a new trick '
        'comes up. Harder tricks are worth more.',
  ]),
  _Section('THE TIMER', [
    'Each trick gets one 60-second clock, shared by everyone. It starts '
        'after a 3-2-1 countdown. If time runs out, nobody scores, the trick '
        'is dropped for the rest of the game, and a new one comes up.',
  ]),
  _Section('TOO HARD?', [
    'If everyone misses a trick twice (two full rounds), it\'s dropped for '
        'the rest of the game and a new one comes up.',
  ]),
  _Section('WINNING', [
    'Only landed tricks count toward the goal: the game ends when your crew '
        'has landed 10 tricks (Quick play) or 30 (Full game). The highest '
        'score wins.',
  ]),
  _Section('PAUSE, UNDO, END GAME', [
    "Tap pause (or your phone's Back button) to stop the clock. From the "
        'menu you can:',
    '• Resume after a 3-2-1.',
    "• Undo last call to fix a wrong tap. It goes one step back only, and "
        "it doesn't give time back.",
    '• End game: the current scores decide, and a tie still goes to sudden '
        'death.',
    'If the call that won the game was a mistake, you can also undo it from '
        'the results.',
  ]),
  _Section('SUDDEN DEATH', [
    'A tie for first place goes to sudden death. Each tied player gets one '
        'try at the same trick, with no timer. Land it and you stay in. Miss '
        "and you're out, unless nobody lands it, and then everyone stays. "
        'Each round brings a new trick, until one player is left. No points '
        'are scored in sudden death. Ending the game during sudden death '
        'gives everyone still in a shared win.',
  ]),
];

/// How to play (D8, D16): a scrolling text screen, opened from Setup.
///
/// The AppBar adds a back arrow by itself, because this page was pushed on
/// top of Setup and the Navigator can pop it.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HOW TO PLAY')),
      // ListView builds the sections lazily as they scroll into view.
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          for (final section in _sections) ...[
            const SizedBox(height: 16),
            Text(section.heading, style: AppTextStyles.label),
            for (final line in section.lines) ...[
              const SizedBox(height: 8),
              Text(line, style: AppTextStyles.body),
            ],
          ],
        ],
      ),
    );
  }
}
