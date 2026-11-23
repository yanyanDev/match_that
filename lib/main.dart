import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:match_that/cubits/trick_library_loader.dart';
import 'package:match_that/screens/home_screen.dart';
import 'package:match_that/screens/library_error_screen.dart';
import 'package:match_that/ui/app_theme.dart';

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
      // One theme for every screen: colors, fonts, AppBar (lib/ui/).
      theme: buildAppTheme(),
      home: switch (library) {
        TrickLibraryLoaded(:final tricks) => HomeScreen(library: tricks),
        TrickLibraryFailed(:final errors) => LibraryErrorScreen(errors: errors),
      },
    );
  }
}
