import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:match_that/cubits/trick_library_loader.dart';
import 'package:match_that/engine/trick.dart';
import 'package:match_that/screens/debug_game_screen.dart';
import 'package:match_that/screens/game_settings_screen.dart';
import 'package:match_that/screens/library_error_screen.dart';

Future<void> main() async {
  debugPaintSizeEnabled =
      false; // to visualize widget layout; "false" to disable
  // Flutter's services (here: reading bundled assets) need the binding
  // before runApp has created it.
  WidgetsFlutterBinding.ensureInitialized();
  // Loaded once at app start (A3); the asset is small, so this takes ms.
  final library = await loadTrickLibrary();
  runApp(MyApp(library: library));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.library});

  final TrickLibraryResult library;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: switch (library) {
        TrickLibraryLoaded(:final tricks) => HomeScreen(library: tricks),
        TrickLibraryFailed(:final errors) => LibraryErrorScreen(errors: errors),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.library});

  final List<Trick> library;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF3F1E9),
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
                    "*",
                    style: TextStyle(
                      fontSize: 50,
                      fontFamily: "Anton",
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "SMALL BOARD. BIG GAME.",
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: "IBM Plex Mono",
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),

              SizedBox(
                height: 25,
              ), // vertical space between the two text widgets

              Text(
                "MATCH THAT!",
                style: TextStyle(fontSize: 116, fontFamily: "Anton", height: 1),
              ),

              SizedBox(height: 15),

              // TODO 3: Position and style the subtitle and supporting sentence.
              Text(
                "A FINGERBOARD GAME",
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: "IBM Plex Mono",
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 15),
              Text(
                "Get a trick. One-up your homies.",
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: "Inter",
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

              // THROWAWAY (A5): deleted with the debug screen in step 8.
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DebugGameScreen(library: library),
                  ),
                ),
                child: const Text(
                  'DEBUG GAME',
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: "IBM Plex Mono",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
