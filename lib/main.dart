import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:match_that/screens/game_settings_screen.dart';

void main() {
  debugPaintSizeEnabled =
      false; // to visualize widget layout; "false" to disable
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
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "SMALL BOARD. BIG GAME.",
                style: TextStyle(fontSize: 12, letterSpacing: 2),
              ),

              SizedBox(
                height: 50,
              ), // vertical space between the two text widgets

              Text(
                "MATCH THAT!",
                style: TextStyle(fontSize: 50, fontFamily: "Anton", height: 1),
              ),

              SizedBox(height: 10),

              Text(
                "A FINGERBOARD GAME",
                style: TextStyle(fontSize: 12, letterSpacing: 2),
              ),
              Text(
                "Get a trick. One-up your homies.",
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2,
                  color: Color(0xFF696861),
                ),
              ),

              SizedBox(height: 10),

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
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
    );
  }
}
