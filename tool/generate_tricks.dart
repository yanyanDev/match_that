// Regenerates assets/tricks.json from data/trick_rules.json (spec T1).
//
// Run from the project root:
//   dart run tool/generate_tricks.dart
//
// All the logic lives in lib/engine/trick_generator.dart (and is tested
// there); this script only does file I/O.

import 'dart:io';

import 'package:match_that/engine/trick.dart';
import 'package:match_that/engine/trick_generator.dart';

const rulesPath = 'data/trick_rules.json';
const outputPath = 'assets/tricks.json';

void main() {
  final rulesFile = File(rulesPath);
  if (!File('pubspec.yaml').existsSync() || !rulesFile.existsSync()) {
    stderr.writeln('Run this from the project root (no $rulesPath here).');
    exitCode = 1;
    return;
  }

  final String json;
  final TrickLibrary library;
  try {
    library = generateTricks(rulesFile.readAsStringSync());
    json = encodeTricksJson(library);
  } on TrickRulesException catch (e) {
    stderr.writeln('$rulesPath is invalid: ${e.message}');
    stderr.writeln('$outputPath was not changed.');
    exitCode = 1;
    return;
  }

  final outputFile = File(outputPath);
  // Git may check the file out with CRLF line endings on Windows.
  final current = outputFile.existsSync()
      ? outputFile.readAsStringSync().replaceAll('\r\n', '\n')
      : null;

  if (current == json) {
    stdout.writeln('$outputPath is already up to date.');
  } else {
    outputFile.writeAsStringSync(json);
    stdout.writeln('Wrote $outputPath.');
  }

  final counts = [
    for (final tier in Difficulty.values)
      '${library.tricks.where((t) => t.difficulty == tier).length} ${tier.name}',
  ];
  stdout.writeln('${library.tricks.length} tricks: ${counts.join(', ')}.');
}
