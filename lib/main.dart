import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

void main() {
  debugPaintSizeEnabled = true; // to visualize widget layout; "false" to disable
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "SMALL BOARD. BIG GAME.",
                style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                ),
              ),

              SizedBox(height: 50), // vertical space between the two text widgets

              Text(
                "MATCH THAT!",
                style: TextStyle(
                fontSize: 100,
                fontFamily: "Anton",
                height: 1,
                ),
              ),

              SizedBox(height: 10),

              Text(
                "A FINGERBOARD GAME",
                style: TextStyle(
                fontSize: 12,
                letterSpacing: 2
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}