// THROWAWAY (spec §4c A5): plays a game through the GameCubit with plain
// buttons and a text readout. Deleted in step 8. Not unit-tested.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubits/game_cubit.dart';
import '../cubits/setup_cubit.dart';
import '../engine/game_state.dart';
import '../engine/players.dart';
import '../engine/trick.dart';

/// A default setup (2 players, Quickplay, Beginner) played on the real
/// clock.
class DebugGameScreen extends StatelessWidget {
  const DebugGameScreen({super.key, required this.library});

  final List<Trick> library;

  @override
  Widget build(BuildContext context) {
    final setup = SetupState.initial();
    // BlocProvider creates the Cubit and makes it available to every widget
    // below it. When this screen is popped, it closes the Cubit, which stops
    // the clock.
    return BlocProvider(
      create: (_) => GameCubit(
        config: setup.config,
        players: setup.players!,
        library: library,
      ),
      // A separate widget, so its `context` is below the BlocProvider and
      // can find the Cubit.
      child: const _DebugGameView(),
    );
  }
}

class _DebugGameView extends StatelessWidget {
  const _DebugGameView();

  @override
  Widget build(BuildContext context) {
    // read: get the Cubit once, without rebuilding when it emits. Right for
    // button taps.
    final game = context.read<GameCubit>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F1E9),
      appBar: AppBar(
        title: const Text('DEBUG GAME'),
        backgroundColor: const Color(0xFFF3F1E9),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              // BlocBuilder rebuilds this part every time the Cubit emits a
              // new state.
              child: BlocBuilder<GameCubit, GameState>(
                builder: (context, state) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final line in _readout(state))
                      Text(
                        line,
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _button('Matched', game.matched),
                  _button('Missed', game.missed),
                  _button('Pause', game.pause),
                  _button('Resume', game.resume),
                  _button('Undo', game.undo),
                  _button('End game', game.endGame),
                  _button('Rematch', game.rematch),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(String label, VoidCallback onPressed) =>
      ElevatedButton(onPressed: onPressed, child: Text(label));
}

/// The text readout, one line per item (A5).
List<String> _readout(GameState s) {
  String name(String id) => s.players.firstWhere((p) => p.id == id).name;
  String names(Iterable<Player> players) =>
      players.map((p) => p.name).join(', ');
  final trick = s.currentTrick;
  final sd = s.suddenDeath;
  final noTimer = s.inSuddenDeath && s.phase == GamePhase.attempting;

  return [
    'phase:     ${s.phase.name}${s.paused ? ' (PAUSED)' : ''}',
    'time left: ${noTimer ? 'no timer' : '${_secondsUp(s.phaseRemaining)} s'}',
    'landed:    ${s.landedCount}',
    'misses:    ${s.missCount} / ${s.missLimit}',
    if (s.phase != GamePhase.gameOver) ...[
      'player:    ${s.currentPlayer.name}',
      'up next:   ${s.upNext.name}',
    ],
    'trick:     ${trick == null ? '-' : '${trick.name} (${trick.points} pts, '
              '${trick.difficulty.name})'}',
    'scores:    ${[for (final p in s.players) '${p.name} ${s.scores[p.id]}'].join(', ')}',
    'last:      ${switch (s.lastOutcome) {
      null => '-',
      LandedBy(:final playerId, :final points) => '+$points ${name(playerId)}',
      TimedOut() => "TIME'S UP",
      MissedOut() => 'MISSED OUT',
      RoundEnded(:final outIds) => outIds.isEmpty ? 'round: nobody out' : 'round: ${outIds.map(name).join(', ')} out',
    }}',
    'can undo:  ${s.canUndo}',
    if (sd != null) ...[
      '',
      'SUDDEN DEATH',
      'still in:  ${names(s.remainingPlayers)}',
      'landed:    ${names(s.players.where((p) => sd.landed.contains(p.seat)))}',
      'missed:    ${names(s.players.where((p) => sd.missed.contains(p.seat)))}',
    ],
    if (s.phase == GamePhase.gameOver) ...[
      '',
      'GAME OVER: ${s.endReason?.name}',
      'winners:   ${names(s.winners)}',
    ],
  ];
}

/// Time left rounded up to whole seconds (G3): 0.1 s shows as 1.
int _secondsUp(Duration d) => (d.inMilliseconds + 999) ~/ 1000;
