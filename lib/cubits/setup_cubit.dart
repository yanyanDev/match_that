/// The game setup: player count, names, length and difficulty (spec §4c A4).
library;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/game_config.dart';
import '../engine/players.dart';
import '../engine/trick.dart';

/// One moment of the setup. Immutable: every change makes a new one.
///
/// Names are validated once, when the state is built, with [buildPlayers]
/// (P3a), so the getters below are cheap for the UI to call on every build.
class SetupState {
  /// Throws [ArgumentError] if the number of [names] is outside [mode]'s
  /// limits. The stepper makes that impossible (P2), so it means a bug.
  SetupState({
    this.mode = GameMode.turnBased,
    required List<String> names,
    this.length = GameLength.quickplay,
    this.difficulty = Difficulty.beginner,
  }) : names = List.unmodifiable(names),
       _result = buildPlayers(mode, names);

  /// The defaults: 2 blank names, Quickplay, Beginner (A4).
  factory SetupState.initial() => SetupState(names: const ['', '']);

  /// Only [GameMode.turnBased] is playable in v1; the limits come from it.
  final GameMode mode;

  /// The names as typed, one per seat, not yet trimmed. Read-only.
  final List<String> names;

  final GameLength length;
  final Difficulty difficulty;

  final PlayerSetupResult _result;

  int get playerCount => names.length;

  bool get canAddPlayer => playerCount < mode.maxPlayers;
  bool get canRemovePlayer => playerCount > mode.minPlayers;

  /// Every name problem, sorted by seat; empty when all names are valid.
  List<NameError> get nameErrors => switch (_result) {
    InvalidNames(:final errors) => errors,
    PlayersReady() => const [],
  };

  /// The problems with the name at [seat].
  List<NameError> errorsFor(int seat) => [
    for (final error in nameErrors)
      if (error.seat == seat) error,
  ];

  /// The players to start a game with, or `null` while a name is invalid.
  List<Player>? get players => switch (_result) {
    PlayersReady(:final players) => players,
    InvalidNames() => null,
  };

  /// Start game is only possible when every name is valid (A4).
  bool get canStart => players != null;

  /// The engine settings for this setup (G1).
  GameConfig get config => GameConfig.forSetup(difficulty, length);

  SetupState _copyWith({
    List<String>? names,
    GameLength? length,
    Difficulty? difficulty,
  }) => SetupState(
    mode: mode,
    names: names ?? this.names,
    length: length ?? this.length,
    difficulty: difficulty ?? this.difficulty,
  );

  @override
  String toString() =>
      'SetupState(${mode.name}, $names, ${length.name}, ${difficulty.name})';
}

/// Holds the setup while the players fill it in.
///
/// A Cubit keeps one current `state`. Its methods build a new state and pass
/// it to `emit`, which replaces `state` and tells every listener (e.g. a
/// BlocBuilder) to rebuild. When nothing would change, the methods return
/// without emitting, so nothing rebuilds for no reason.
class SetupCubit extends Cubit<SetupState> {
  /// Starts from [initial] (step 10: a saved setup), or the defaults.
  SetupCubit([SetupState? initial]) : super(initial ?? SetupState.initial());

  /// Adds a blank seat at the end; existing names are kept. Ignored at the
  /// mode's maximum.
  void addPlayer() {
    if (!state.canAddPlayer) return;
    emit(state._copyWith(names: [...state.names, '']));
  }

  /// Drops the last seat. Ignored at the mode's minimum.
  void removePlayer() {
    if (!state.canRemovePlayer) return;
    emit(
      state._copyWith(names: state.names.sublist(0, state.playerCount - 1)),
    );
  }

  /// Sets the raw name at [seat], as typed.
  void setName(int seat, String raw) {
    if (state.names[seat] == raw) return;
    emit(state._copyWith(names: [...state.names]..[seat] = raw));
  }

  void setLength(GameLength length) {
    if (length == state.length) return;
    emit(state._copyWith(length: length));
  }

  void setDifficulty(Difficulty difficulty) {
    if (difficulty == state.difficulty) return;
    emit(state._copyWith(difficulty: difficulty));
  }
}
