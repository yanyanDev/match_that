import 'package:flutter/material.dart';

class GameSettingsScreen extends StatelessWidget {
  const GameSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Settings'),
        // Flutter automatically adds a back button here!
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Configure Your Game',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // A button inside this screen to take you back manually if needed
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Save & Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
