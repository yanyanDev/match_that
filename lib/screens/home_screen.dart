import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:match_that/cubits/game_cubit.dart';
import 'package:match_that/cubits/setup_cubit.dart';
import 'package:match_that/engine/trick.dart';
import 'package:match_that/screens/game/game_screen.dart';
import 'package:match_that/screens/game_settings_screen.dart';
import 'package:match_that/ui/app_text_styles.dart';
import 'package:match_that/ui/widgets/primary_button.dart';

/// Home: title and START (§7 screen 1, Figma "Match It welcome").
///
/// No backgroundColor here: the Scaffold gets cream from the app theme.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.library});

  final List<Trick> library;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                // HEADER ROW
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '*',
                    style: AppTextStyles.headline.copyWith(
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Flexible: on a narrow screen or with large system text
                  // the tagline wraps instead of overflowing the row.
                  const Flexible(
                    child: Text(
                      'SMALL BOARD. BIG GAME.',
                      style: AppTextStyles.label,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              const Text('MATCH THAT!', style: AppTextStyles.display),

              const SizedBox(height: 15),

              // TODO 3: Position and style the subtitle and supporting sentence.
              const Text('A FINGERBOARD GAME', style: AppTextStyles.label),
              const SizedBox(height: 15),
              Text(
                'Get a trick. One-up your homies.',
                // Home's line is letter-spaced; other body text isn't.
                style: AppTextStyles.body.copyWith(letterSpacing: 2),
              ),

              // TODO 4: Add the skateboard/fingerboard graphic here. Give it a
              // bounded-height area so it fits between the text and the button.
              const SizedBox(height: 10),

              PrimaryButton(
                label: 'START',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GameSettingsScreen(),
                  ),
                ),
              ),

              // TEMPORARY (step 8b): plays the default setup (2 players,
              // Quickplay, Beginner) until Setup can start a game in 8c (D9).
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    // BlocProvider(create:) makes the Cubit and closes it when
                    // this page is popped, which stops the game clock.
                    builder: (context) => BlocProvider(
                      create: (_) {
                        final setup = SetupState.initial();
                        return GameCubit(
                          config: setup.config,
                          players: setup.players!,
                          library: library,
                        );
                      },
                      child: const GameScreen(),
                    ),
                  ),
                ),
                child: const Text('DEBUG GAME', style: AppTextStyles.button),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
