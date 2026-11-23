import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  // Portrait only (D12). SystemChrome talks to the OS (Android/iOS) about
  // things outside Flutter's own drawing: orientation, status bar, etc.
  // The native configs (AndroidManifest, Info.plist) also say portrait, so
  // the app doesn't flash in landscape before this line runs.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
