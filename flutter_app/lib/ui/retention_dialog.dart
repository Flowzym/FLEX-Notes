import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/school_year.dart';
import '../platform/backup_transfer.dart';
import '../services/material_storage.dart';
import '../services/stream_backup.dart';
import 'backup_dialog.dart';
import 'common.dart';
import 'flex_modal.dart';

Future<void> showRetentionReview(BuildContext context, NotebookController c) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RetentionDialog(controller: c),
    );

class RetentionDialog extends StatefulWidget {
  const RetentionDialog({super.key, required this.controller});
  final NotebookController controller;
  @override
  State<RetentionDialog> createState() => _RetentionDialogState();
}

class _RetentionDialogState extends State<RetentionDialog> {
  RetentionPolicy policy = const RetentionPolicy();
  List<RetentionCandidate> candidates = [];
  final selected = <String>{};
  final word = TextEditingController();
  String? captured, error;
  bool busy = true, confirmed = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    word.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final nextPolicy = await widget.controller.repository.retentionPolicy();
      final next = await widget.controller.repository.retentionReview(
        DateTime.now(),
      );
      if (mounted) {
        setState(() {
          policy = nextPolicy;
          candidates = next;
          selected.retainAll(next.map((c) => c.key));
          busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = friendlyError(e);
          busy = false;
        });
      }
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget duration(String label, int value, ValueChanged<int> change) =>
      DropdownButtonFormField<int>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final days in [0, 30, 90, 180, 365])
            DropdownMenuItem(
              value: days,
              child: Text(
                days == 0 ? 'Keine Frist' : 'Nach $days Tagen prüfen',
              ),
            ),
        ],
        onChanged: busy
            ? null
            : (v) {
                if (v != null) change(v);
              },
      );
  Future<void> policyChange(RetentionPolicy next) => run(() async {
    await widget.controller.repository.saveRetentionPolicy(next);
    captured = null;
    confirmed = false;
    await load();
  });
  Future<void> backup() async {
    final password = await backupPassword(context, opening: false);
    if (password == null) return;
    final snapshot = await widget.controller.repository.exportBackup();
    final saved = await saveBackupStream(
      'FLEX-Vor-Loeschpruefung-${dateOnly(DateTime.now())}.flexbackup',
      StreamBackup.capture(
        widget.controller.repository,
        const LocalMaterialFiles(),
        password: password,
        capturedNotebook: snapshot,
      ),
    );
    if (saved && mounted) {
      setState(() {
        captured = snapshot;
        confirmed = false;
      });
    }
  }

  Future<void> purge() async {
    if (captured == null ||
        !confirmed ||
        word.text != 'LÖSCHEN' ||
        selected.isEmpty) {
      return;
    }
    await widget.controller.repository.purgeRetained(
      Set.of(selected),
      captured!,
    );
    await widget.controller.reload();
    captured = null;
    confirmed = false;
    selected.clear();
    word.clear();
    await load();
    try {
      await widget.controller.repository.removeUnreferencedFiles(
        const LocalMaterialFiles().remove,
      );
    } catch (_) {
      throw const DomainError(
        'Die ausgewählten Daten wurden entfernt. Einige Dateien konnten noch nicht gelöscht werden; FLEX versucht es beim nächsten Start erneut.',
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ausgewählte Daten endgültig entfernt.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: FlexModal(
      title: const Text('Aufbewahrung & Löschprüfung'),
      maxWidth: 680,
      onClose: busy ? null : () => Navigator.pop(context),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Fristen erzeugen eine Prüfliste. FLEX löscht erst nach deiner Auswahl, einer vollständigen Sicherung und Bestätigung.',
          ),
          const SizedBox(height: 16),
          duration(
            'Importkopien',
            policy.importDays,
            (v) => policyChange(
              RetentionPolicy(importDays: v, trashDays: policy.trashDays),
            ),
          ),
          const SizedBox(height: 12),
          duration(
            'Papierkorb',
            policy.trashDays,
            (v) => policyChange(
              RetentionPolicy(importDays: policy.importDays, trashDays: v),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${candidates.length} zur Prüfung · ${selected.length} ausgewählt',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (candidates.isEmpty && !busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Zurzeit ist keine Löschprüfung fällig.'),
            ),
          for (final item in candidates)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selected.contains(item.key),
              title: Text(item.label),
              subtitle: Text(
                '${displayDate(item.date)}${item.count > 0 ? ' · ${item.count} Einträge' : ''}',
              ),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      v == true
                          ? selected.add(item.key)
                          : selected.remove(item.key);
                      confirmed = false;
                    }),
            ),
          if (selected.isNotEmpty) ...[
            const Divider(),
            const Text(
              'Entfernt werden die ausgewählten Einträge mit früheren Versionen und ausschließlich zugehörigen Dateien. Bei Schülern auch deren Einträge und betroffene Importkopien. Gemeinsam genutzte Materialien und Namensnennungen in anderen Texten bleiben erhalten. Externe Sicherungsdateien werden nicht gelöscht.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.lock_outline),
              onPressed: busy ? null : () => run(backup),
              label: const Text('Verschlüsselte Sicherung erstellen'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: confirmed,
              onChanged: busy || captured == null
                  ? null
                  : (v) => setState(() => confirmed = v == true),
              title: const Text(
                'Sicherungsdatei gespeichert und Auswahl geprüft',
              ),
            ),
            TextField(
              controller: word,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Zum endgültigen Löschen LÖSCHEN eingeben',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Schließen'),
        ),
        FilledButton(
          onPressed:
              busy ||
                  selected.isEmpty ||
                  captured == null ||
                  !confirmed ||
                  word.text != 'LÖSCHEN'
              ? null
              : () => run(purge),
          child: const Text('Auswahl endgültig löschen'),
        ),
      ],
    ),
  );
}
