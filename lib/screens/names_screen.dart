import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubits/setup_cubit.dart';
import '../engine/players.dart';
import '../ui/app_colors.dart';
import '../ui/app_text_styles.dart';
import '../ui/widgets/primary_button.dart';

/// Names (§7 screen 3, Figma 02, D13): one row per seat. Tapping a row opens
/// a dialog to change that name. Done goes back to Setup.
///
/// Reads the [SetupCubit] provided above MaterialApp (D14), so the names
/// typed here are still there on Setup and in the next game.
class NamesScreen extends StatelessWidget {
  const NamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PLAYER NAMES')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: BlocBuilder<SetupCubit, SetupState>(
            builder: (context, state) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('YOUR CREW.', style: AppTextStyles.headline),
                const SizedBox(height: 12),
                const Text(
                  'Tap a name to change it. Leave it blank to use Player N.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.separated(
                    itemCount: state.playerCount,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, seat) => _NameRow(
                      seat: seat,
                      raw: state.names[seat],
                      errors: state.errorsFor(seat),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'DONE',
                  showArrow: false,
                  // pop removes this page from the Navigator's stack: back
                  // to Setup, the page underneath.
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One seat: number, name (or its default, in grey), color, ↗, and any
/// name errors underneath (A4).
class _NameRow extends StatelessWidget {
  const _NameRow({required this.seat, required this.raw, required this.errors});

  final int seat;
  final String raw;
  final List<NameError> errors;

  @override
  Widget build(BuildContext context) {
    final typed = raw.trim();
    final isDefault = typed.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: AppColors.cream,
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: AppColors.ink),
          ),
          child: InkWell(
            onTap: () => _edit(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Text(_seatLabel(seat), style: AppTextStyles.label),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      isDefault ? defaultPlayerName(seat) : typed,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        color: isDefault ? AppColors.grey : AppColors.ink,
                      ),
                    ),
                  ),
                  // The seat's color (P3b), outlined like every colored
                  // surface (D1).
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: PlayerColor.forSeat(seat).color,
                      border: Border.all(color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.north_east, size: 18, color: AppColors.ink),
                ],
              ),
            ),
          ),
        ),
        for (final error in errors)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              _errorText(error),
              style: AppTextStyles.label.copyWith(fontSize: 11),
            ),
          ),
      ],
    );
  }

  /// Opens the edit dialog and saves what it returns.
  Future<void> _edit(BuildContext context) async {
    // Read the Cubit before the await: after it, this row may have been
    // rebuilt and its context shouldn't be used any more.
    final setup = context.read<SetupCubit>();

    // showDialog pushes the dialog as a route on top and returns a Future
    // that completes when the dialog pops: with the name on Save, `null` on
    // Cancel or a tap outside.
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameEditDialog(seat: seat, initial: raw),
    );
    if (name != null) setup.setName(seat, name);
  }
}

/// "01".."08".
String _seatLabel(int seat) => '${seat + 1}'.padLeft(2, '0');

String _errorText(NameError error) => switch (error) {
  DuplicateName(:final otherSeats) =>
    'Same name as ${otherSeats.map(_seatLabel).join(', ')}',
  NameTooLong(:final length) => 'Too long: $length / $maxNameLength',
};

/// The edit dialog: one text field, Cancel / Save (D13).
///
/// A StatefulWidget because it owns a [TextEditingController]: the object
/// that holds the field's text and cursor. It's made once in [State.initState]
/// (filled with the current name) and must be released in [State.dispose].
class _NameEditDialog extends StatefulWidget {
  const _NameEditDialog({required this.seat, required this.initial});

  final int seat;
  final String initial;

  @override
  State<_NameEditDialog> createState() => _NameEditDialogState();
}

class _NameEditDialogState extends State<_NameEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.ink),
      ),
      title: Text(
        'PLAYER ${_seatLabel(widget.seat)}',
        style: AppTextStyles.label.copyWith(fontSize: 14),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true, // keyboard opens right away
        // Blocks typing past 12 characters and shows a "4/12" counter (P3a).
        maxLength: maxNameLength,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(), // the keyboard's Done key
        style: AppTextStyles.body.copyWith(color: AppColors.ink),
        decoration: InputDecoration(hintText: defaultPlayerName(widget.seat)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // null: no change
          child: const Text('CANCEL', style: AppTextStyles.button),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('SAVE', style: AppTextStyles.button),
        ),
      ],
    );
  }
}
