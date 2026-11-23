import 'package:flutter/material.dart';

/// Shown instead of the app when the trick library can't be loaded (A3).
/// That's a bug in the bundled data, so it lists the errors for whoever
/// fixes it rather than letting a broken game start.
class LibraryErrorScreen extends StatelessWidget {
  const LibraryErrorScreen({super.key, required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F1E9),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'TRICK LIBRARY ERROR',
              style: TextStyle(fontSize: 36, fontFamily: 'Anton'),
            ),
            const SizedBox(height: 12),
            const Text(
              'assets/tricks.json could not be loaded. '
              'The game cannot start until it is fixed.',
              style: TextStyle(fontFamily: 'Inter'),
            ),
            const SizedBox(height: 16),
            for (final error in errors)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  error,
                  style: const TextStyle(fontFamily: 'IBM Plex Mono'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
