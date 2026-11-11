import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:match_that/screens/game_settings_screen.dart';

void main() {
  debugPaintSizeEnabled =
      true; // to visualize widget layout; "false" to disable
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomeScreen());
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TODO 1: Build the top header row (mark on the left, small tagline
            // on the right). The text below is the existing tagline.
            Text(
              "SMALL BOARD. BIG GAME.",
              style: TextStyle(
                fontSize: 12,
                fontFamily: "IBM Plex Mono",
                letterSpacing: 2,
              ),
            ),

            SizedBox(height: 50), // vertical space between the two text widgets

            // TODO 2: Style and position the large, left-aligned two-line title.
            Text(
              "MATCH THAT!",
              style: TextStyle(fontSize: 50, fontFamily: "Anton", height: 1),
            ),

            SizedBox(height: 10),

            // TODO 3: Position and style the subtitle and supporting sentence.
            Text(
              "A FINGERBOARD GAME",
              style: TextStyle(
                fontSize: 12,
                fontFamily: "IBM Plex Mono",
                letterSpacing: 2,
              ),
            ),
            Text(
              "Get a trick. One-up your homies.",
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                color: Color(0xFF696861),
              ),
            ),

            // TODO 4: Add the skateboard/fingerboard graphic here. Give it a
            // bounded-height area so it fits between the text and the button.

            SizedBox(height: 10),

            // TODO 5: Make this a full-width lime button with START on the left
            // and a right arrow on the right. Keep its navigation callback.
            ElevatedButton(
              onPressed: () {
                // lead to game settings page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GameSettingsScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFD9FF43),
                shadowColor: Colors.black,
                elevation: 5,
              ),
              child: const Text(
                'START',
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: "IBM Plex Mono",
                ),
              ),
            ),
            // TODO 6: Add the small muted footer line below the button.
          ],
        ),
        ),
      ),
    );
  }
}
