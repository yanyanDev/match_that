import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubits/game_cubit.dart';
import '../cubits/setup_cubit.dart';
import '../engine/game_config.dart';
import '../engine/trick.dart';
import '../ui/app_colors.dart';
import '../ui/app_text_styles.dart';
import '../ui/widgets/option_box.dart';
import '../ui/widgets/primary_button.dart';
import '../ui/widgets/secondary_button.dart';
import '../ui/widgets/section_label.dart';
import 'game/game_screen.dart';
import 'names_screen.dart';

/// Setup (§7 screen 2, Figma 01): players, game length, difficulty, names,
/// Start game. No ☰ menu or "your own boards" text in v1 (D8); no mode row
/// (Rush is hidden, §7).
///
/// Reads the [SetupCubit] that MyApp provides above MaterialApp, so the
/// setup is kept when this page is left and opened again (D14).
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, required this.library});

  /// The trick library, for the GameCubit that Start game creates.
  final List<Trick> library;

  @override
  Widget build(BuildContext context) {
    final setup = context.read<SetupCubit>();

    return Scaffold(
      // The AppBar adds a back arrow by itself, because there's a page (Home)
      // below this one on the Navigator's stack.
      appBar: AppBar(title: const Text('MATCH THAT!')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: BlocBuilder<SetupCubit, SetupState>(
            builder: (context, state) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Scrolls on small phones; Start game stays at the bottom.
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'SET IT OFF.',
                          style: AppTextStyles.headline,
                        ),
                        const SizedBox(height: 24),
                        const SectionLabel(number: 1, text: 'Players'),
                        Row(
                          children: [
                            // onPressed null disables the button at the
                            // mode's limits (P1, P2).
                            IconButton(
                              tooltip: 'Remove player',
                              onPressed: state.canRemovePlayer
                                  ? setup.removePlayer
                                  : null,
                              icon: const Icon(Icons.remove),
                            ),
                            Expanded(
                              child: Text(
                                '${state.playerCount}',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.display.copyWith(
                                  fontSize: 48,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Add player',
                              onPressed: state.canAddPlayer
                                  ? setup.addPlayer
                                  : null,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        Text(
                          '${state.mode.minPlayers}–${state.mode.maxPlayers} '
                          'players · one phone',
                          style: AppTextStyles.body.copyWith(fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.ink, height: 1),
                        const SizedBox(height: 24),
                        const SectionLabel(number: 2, text: 'Game length'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final length in GameLength.values) ...[
                              if (length != GameLength.values.first)
                                const SizedBox(width: 12),
                              Expanded(
                                child: OptionBox(
                                  title: _lengthTitle(length),
                                  subtitle: '${length.target} TRICKS',
                                  selected: state.length == length,
                                  onTap: () => setup.setLength(length),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
                        const SectionLabel(number: 3, text: 'Difficulty'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final difficulty in Difficulty.values) ...[
                              if (difficulty != Difficulty.values.first)
                                const SizedBox(width: 8),
                              Expanded(
                                child: OptionBox(
                                  title: _difficultyTitle(difficulty),
                                  selected: state.difficulty == difficulty,
                                  onTap: () => setup.setDifficulty(difficulty),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
                        SecondaryButton(
                          label: 'PLAYER NAMES / OPTIONAL',
                          showArrow: true,
                          // push puts the Names page on top of this one;
                          // its Done (or Back) pops it off again.
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const NamesScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.nameErrors.isEmpty
                              ? 'Blank names become Player 1, Player 2, etc.'
                              : 'Fix the player names to start.',
                          style: AppTextStyles.body.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'START GAME',
                  // Only with valid names (A4).
                  onPressed: state.canStart
                      ? () => _startGame(context, state)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the Game screen with a new GameCubit for this setup (D14).
  ///
  /// The GameCubit belongs to the Game page: BlocProvider(create:) makes it
  /// there and closes it when the page is popped (New game), which stops the
  /// clock. The SetupCubit is untouched, so Setup shows the same setup again.
  void _startGame(BuildContext context, SetupState state) {
    final players = state.players!;
    final config = state.config;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider(
          create: (_) =>
              GameCubit(config: config, players: players, library: library),
          child: const GameScreen(),
        ),
      ),
    );
  }
}

String _lengthTitle(GameLength length) => switch (length) {
  GameLength.quickplay => 'QUICK PLAY',
  GameLength.full => 'FULL GAME',
};

String _difficultyTitle(Difficulty difficulty) => switch (difficulty) {
  Difficulty.beginner => 'Beginner',
  Difficulty.intermediate => 'Intermediate',
  Difficulty.advanced => 'Advanced',
};
