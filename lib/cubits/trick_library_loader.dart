/// Loads the trick library once at app start (spec §4c A3).
library;

import 'package:flutter/services.dart';

import '../engine/trick.dart';
import '../engine/trick_parser.dart';

/// Outcome of [loadTrickLibrary]: the whole library, or why it can't be used.
sealed class TrickLibraryResult {
  const TrickLibraryResult();
}

/// Every trick in the file parsed cleanly.
final class TrickLibraryLoaded extends TrickLibraryResult {
  TrickLibraryLoaded(List<Trick> tricks) : tricks = List.unmodifiable(tricks);

  final List<Trick> tricks;
}

/// The file couldn't be read, had any parse error, or had no tricks. Any of
/// these is a bug in the bundled data, so the app shows an error screen
/// rather than a game with part of the library (A3).
final class TrickLibraryFailed extends TrickLibraryResult {
  TrickLibraryFailed(List<String> errors) : errors = List.unmodifiable(errors);

  final List<String> errors;
}

/// The path of the bundled library (T6).
const tricksAssetPath = 'assets/tricks.json';

/// Reads and parses the trick library. Never throws.
///
/// [read] returns the file's contents; it defaults to the bundled asset.
/// Tests pass their own so they can use a JSON string.
Future<TrickLibraryResult> loadTrickLibrary({
  Future<String> Function()? read,
}) async {
  final String source;
  try {
    source = await (read ?? () => rootBundle.loadString(tricksAssetPath))();
  } catch (e) {
    return TrickLibraryFailed(['could not read $tricksAssetPath: $e']);
  }

  final parsed = parseTricks(source);
  if (parsed.errors.isNotEmpty) {
    return TrickLibraryFailed([for (final e in parsed.errors) e.toString()]);
  }
  if (parsed.tricks.isEmpty) {
    return TrickLibraryFailed(['$tricksAssetPath has no tricks']);
  }
  return TrickLibraryLoaded(parsed.tricks);
}
