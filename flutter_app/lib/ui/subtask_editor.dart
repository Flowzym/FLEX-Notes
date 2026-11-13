import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import 'common.dart';
import 'flex_modal.dart';

class SubtaskEditor extends StatefulWidget {
  const SubtaskEditor({
    super.key,
    required this.controller,
    required this.entry,
  });
  final NotebookController controller;
  final OrgaEntry entry;
  @override
  State<SubtaskEditor> createState() => _SubtaskEditorState();
}

class _SubtaskEditorState extends State<SubtaskEditor> {
  final text = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || text.text.trim().isEmpty) return;
    setState(() => busy = true);
    final ok = await guarded(
      context,
      () => widget.controller.saveEntry(
        widget.entry.withTaskItems([
          ...widget.entry.items,
          CheckItem(id: newId(), text: text.text.trim()),
        ]),
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: FlexModal(
      title: const Text('Unteraufgabe hinzufügen'),
      onClose: busy ? null : () => Navigator.pop(context),
      content: TextField(
        controller: text,
        autofocus: true,
        enabled: !busy,
        maxLength: 2000,
        decoration: const InputDecoration(labelText: 'Unteraufgabe'),
        onSubmitted: (_) => save(),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: const Text('Hinzufügen'),
        ),
      ],
    ),
  );
}
