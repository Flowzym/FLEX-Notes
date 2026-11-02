import 'package:flutter/material.dart';
import 'common.dart';
import 'flex_modal.dart';

/// Used by every draft list. The repository checks the draft revision; a
/// failed delete leaves the draft available and lets the user retry.
class DraftDeleteButton extends StatefulWidget {
  const DraftDeleteButton({super.key, required this.onDelete});
  final Future<void> Function() onDelete;
  @override
  State<DraftDeleteButton> createState() => _DraftDeleteButtonState();
}

class _DraftDeleteButtonState extends State<DraftDeleteButton> {
  bool busy = false;
  String? error;
  Future<void> remove() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (await confirmFlex(
            context,
            'Entwurf löschen?',
            'Nur dieser Entwurf wird gelöscht. Bereits gespeicherte Einträge bleiben erhalten.',
            accept: 'Löschen',
          ) &&
          mounted) {
        await widget.onDelete();
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Entwurf löschen',
        onPressed: busy ? null : remove,
        icon: const Icon(Icons.delete_outline),
      ),
      if (error != null)
        SizedBox(
          width: 180,
          child: Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ),
    ],
  );
}
