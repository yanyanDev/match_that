/// Players and setup validation (spec §6: P1, P2, P3, P3a, P3b, P5).
/// Pure Dart — no Flutter imports.
library;

/// Game mode and its player limits (P1).
///
/// The spec calls the turn-based mode "Default", but `default` is a reserved
/// word in Dart, so it is [turnBased] here.
enum GameMode {
  turnBased(minPlayers: 2, maxPlayers: 8),
  rush(minPlayers: 2, maxPlayers: 4);

  const GameMode({required this.minPlayers, required this.maxPlayers});

  final int minPlayers;
  final int maxPlayers;

  /// Whether this mode can be played with [playerCount] players.
  bool allows(int playerCount) =>
      playerCount >= minPlayers && playerCount <= maxPlayers;
}

/// Fixed palette of 8 player colors, assigned by seat (P3b).
///
/// The engine only knows these values; the UI maps each one to a real color.
enum PlayerColor {
  color1,
  color2,
  color3,
  color4,
  color5,
  color6,
  color7,
  color8;

  /// The color for 0-based [seat]. Throws [ArgumentError] outside 0..7.
  static PlayerColor forSeat(int seat) {
    if (seat < 0 || seat >= values.length) {
      throw ArgumentError.value(
        seat,
        'seat',
        'Must be 0..${values.length - 1}',
      );
    }
    return values[seat];
  }
}

/// Longest allowed name, counted in Unicode code points (P3a).
const maxNameLength = 12;

/// The default name for 0-based [seat]: seat 0 is "Player 1" (P3).
String defaultPlayerName(int seat) => 'Player ${seat + 1}';

/// One player in the game. Immutable.
class Player {
  const Player({
    required this.id,
    required this.seat,
    required this.name,
    required this.color,
  });

  /// Internal id, e.g. `p1`. Never derived from [name] (P5).
  final String id;

  /// 0-based position in setup order; turn order follows it (P4, P5).
  final int seat;

  /// Trimmed display name; never blank (P3a).
  final String name;

  final PlayerColor color;

  @override
  String toString() => 'Player($id, seat $seat, "$name", ${color.name})';
}

/// Outcome of [buildPlayers]: either every player is valid, or nothing is.
sealed class PlayerSetupResult {
  const PlayerSetupResult();
}

/// All names are valid; [players] is in seat order.
final class PlayersReady extends PlayerSetupResult {
  PlayersReady(List<Player> players) : players = List.unmodifiable(players);

  final List<Player> players;
}

/// At least one name is invalid. [errors] is sorted by seat.
final class InvalidNames extends PlayerSetupResult {
  InvalidNames(List<NameError> errors) : errors = List.unmodifiable(errors);

  final List<NameError> errors;
}

/// A problem with the name at [seat] (P3a).
sealed class NameError {
  const NameError(this.seat);

  final int seat;
}

/// The trimmed name is longer than [maxNameLength] code points.
final class NameTooLong extends NameError {
  const NameTooLong(super.seat, this.length);

  /// The name's length in code points.
  final int length;

  @override
  String toString() => 'NameTooLong(seat $seat, $length)';
}

/// The name matches other seats' names (trimmed, case-insensitive).
final class DuplicateName extends NameError {
  DuplicateName(super.seat, List<int> otherSeats)
    : otherSeats = List.unmodifiable(otherSeats);

  /// The other seats with the same name, ascending.
  final List<int> otherSeats;

  @override
  String toString() => 'DuplicateName(seat $seat, also $otherSeats)';
}

/// Builds the players from the names typed on the Names screen, one per seat.
///
/// Each name is trimmed; a blank one becomes [defaultPlayerName]. Then every
/// name is checked for length and duplicates, and all problems are returned
/// together as [InvalidNames] (P3a).
///
/// Throws [ArgumentError] if the number of names is outside [mode]'s limits.
/// Setup makes that impossible (P2), so it means a bug, not bad user input.
PlayerSetupResult buildPlayers(GameMode mode, List<String> rawNames) {
  final count = rawNames.length;
  if (!mode.allows(count)) {
    throw ArgumentError.value(
      count,
      'rawNames.length',
      '${mode.name} needs ${mode.minPlayers}–${mode.maxPlayers} players',
    );
  }

  final names = [
    for (var seat = 0; seat < count; seat++) _resolveName(rawNames[seat], seat),
  ];
  final keys = [for (final name in names) name.toLowerCase()];

  final errors = <NameError>[];
  for (var seat = 0; seat < count; seat++) {
    final length = names[seat].runes.length;
    if (length > maxNameLength) errors.add(NameTooLong(seat, length));

    final others = [
      for (var other = 0; other < count; other++)
        if (other != seat && keys[other] == keys[seat]) other,
    ];
    if (others.isNotEmpty) errors.add(DuplicateName(seat, others));
  }
  if (errors.isNotEmpty) return InvalidNames(errors);

  return PlayersReady([
    for (var seat = 0; seat < count; seat++)
      Player(
        id: 'p${seat + 1}',
        seat: seat,
        name: names[seat],
        color: PlayerColor.forSeat(seat),
      ),
  ]);
}

String _resolveName(String raw, int seat) {
  final trimmed = raw.trim();
  return trimmed.isEmpty ? defaultPlayerName(seat) : trimmed;
}
