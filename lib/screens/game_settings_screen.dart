import 'package:flutter/material.dart';

class GameSettingsScreen extends StatelessWidget {
  const GameSettingsScreen({super.key});
// TODO: Figure out why header row is not following Scaffold color
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF3F1E9),
      appBar: AppBar(
        title: const Text('MATCH THAT!'),
        // Flutter automatically adds a back button here!
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'SET IT OFF.',
              style: TextStyle(fontSize: 50, fontFamily: "Anton"),
            ),
            const SizedBox(height: 20),
            
            // Once fields are entered, pres to start game
            ElevatedButton(
              onPressed: () {
                //starts game
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFD9FF43),
                shadowColor: Colors.black,
                elevation: 5,
              ),
              child: const Text(
                'PLAY!',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
