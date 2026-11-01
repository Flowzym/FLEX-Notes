import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import 'common.dart';
import 'draft_buffer.dart';
import 'flex_modal.dart';

class MaintenanceDialog extends StatefulWidget {
  const MaintenanceDialog({
    super.key,
    required this.controller,
    this.emptyTrash = false,
  });
  final NotebookController controller;
  final bool emptyTrash;
  @override
  State<MaintenanceDialog> createState() => _MaintenanceDialogState();
}

class _MaintenanceDialogState extends State<MaintenanceDialog> {
  bool confirmed = false, busy = false;
  String? backup, error;
  final word = TextEditingController();
  @override
  void dispose() {
    word.dispose();
    super.dispose();
  }

  Future<void> action(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: FlexModal(
      maxWidth: 640,
      title: Text(
        widget.emptyTrash ? 'Papierkorb endgültig leeren' : 'Speicher pflegen',
      ),
      onClose: busy ? null : () => Navigator.pop(context),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.emptyTrash
                ? 'Gelöschte Einträge und ihre früheren Fassungen werden endgültig entfernt. Erstelle zuerst eine vollständige Sicherung.'
                : 'Der lokale Speicher wird geprüft und optimiert. Einträge, frühere Fassungen und Entwürfe bleiben erhalten.',
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => action(() async {
                    final captured = await widget.controller.repository
                        .exportBackup();
                    if (await saveTextFile(
                      'FLEX-Vollstaendige-Sicherung-${dateOnly(DateTime.now())}.json',
                      captured,
                      mime: 'application/json',
                    )) {
                      if (mounted) {
                        setState(() {
                          backup = captured;
                          confirmed = false;
                        });
                      }
                    }
                  }),
            child: const Text('Vollständige Sicherung herunterladen'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Ich habe die Sicherung gespeichert und andere App-Tabs geschlossen.',
            ),
            value: confirmed,
            onChanged: busy
                ? null
                : (v) => setState(() => confirmed = v == true),
          ),
          if (widget.emptyTrash)
            TextField(
              controller: word,
              decoration: const InputDecoration(
                labelText: 'Zum endgültigen Löschen LÖSCHEN eingeben',
              ),
            ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: busy
              ? null
              : () => action(() async {
                  if (backup == null ||
                      !confirmed ||
                      widget.emptyTrash && word.text != 'LÖSCHEN') {
                    throw const DomainError(
                      'Bitte zuerst die Sicherung bestätigen und die erforderliche Eingabe ausfüllen.',
                    );
                  }
                  await widget.controller.repository.maintainStorage(
                    backup!,
                    emptyTrash: widget.emptyTrash,
                  );
                  await widget.controller.reload();
                  if (context.mounted) Navigator.pop(context);
                }),
          child: const Text('Ausführen'),
        ),
      ],
    ),
  );
}
