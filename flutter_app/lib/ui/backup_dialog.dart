import 'merge_dialog.dart';
import 'compact_switch.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../security/backup_codec.dart';
import 'common.dart';
import 'draft_buffer.dart';
import 'flex_modal.dart';

Future<String> _encrypt(Map<String, String> args) =>
    BackupCodec.encrypt(args['text']!, args['password']!);
Future<String> _decrypt(Map<String, String> args) =>
    BackupCodec.decrypt(args['text']!, args['password']!);

Future<String?> backupPassword(
  BuildContext context, {
  required bool opening,
}) async {
  final text = TextEditingController();
  String? error;
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => FlexModal(
        maxWidth: 430,
        title: Text(opening ? 'Sicherung öffnen' : 'Sicherung verschlüsseln'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: text,
              autofocus: true,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Passwort'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Das Passwort wird nicht gespeichert. Ohne Passwort kann eine verschlüsselte Sicherung nicht wiederhergestellt werden.',
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (text.text.isEmpty || !opening && text.text.length < 12) {
                update(
                  () => error = opening
                      ? 'Bitte ein Passwort eingeben.'
                      : 'Bitte mindestens zwölf Zeichen verwenden.',
                );
              } else {
                Navigator.pop(ctx, text.text);
              }
            },
            child: const Text('Fortfahren'),
          ),
        ],
      ),
    ),
  );
  // The field remains mounted during the route's exit transition.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  text.dispose();
  return result;
}

class BackupDialog extends StatefulWidget {
  const BackupDialog({super.key, required this.controller, this.export = true});
  final NotebookController controller;
  final bool export;
  @override
  State<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<BackupDialog> {
  bool encrypt = true, appearance = true, catalogs = true, busy = false;
  String? message;
  Future<void> action(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => message = friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> exportFile() async {
    final data = Json.from(
      jsonDecode(await widget.controller.repository.exportBackup()) as Map,
    );
    if (!appearance) {
      (data['tables']['preferences'] as List).removeWhere(
        (row) => row['key'] == 'appearance',
      );
    }
    var text = jsonEncode(data);
    if (encrypt) {
      if (!mounted) return;
      final password = await backupPassword(context, opening: false);
      if (password == null) return;
      text = await compute(_encrypt, {'text': text, 'password': password});
    }
    final saved = await saveTextFile(
      'FLEX-Sicherung-${dateOnly(DateTime.now())}.json',
      text,
      mime: 'application/json',
    );
    if (saved && mounted) {
      setState(() => message = 'Sicherungsdatei wurde ausgegeben.');
    }
  }

  Future<void> importFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'JSON',
          extensions: ['json'],
          mimeTypes: ['application/json'],
        ),
      ],
    );
    if (file == null) return;
    if (await file.length() > BackupCodec.maxEnvelopeBytes) {
      throw const DomainError('Die Datei überschreitet 28 MB.');
    }
    final bytes = BytesBuilder();
    await for (final part in file.openRead()) {
      if (bytes.length + part.length > BackupCodec.maxEnvelopeBytes) {
        throw const DomainError('Die Datei überschreitet 28 MB.');
      }
      bytes.add(part);
    }
    var text = utf8.decode(bytes.takeBytes());
    if (BackupCodec.isEncrypted(text)) {
      if (!mounted) return;
      final password = await backupPassword(context, opening: true);
      if (password == null) return;
      text = await compute(_decrypt, {'text': text, 'password': password});
    }
    if (!mounted) return;
    await showImportReview(
      context,
      widget.controller,
      text,
      catalogs: catalogs,
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: FlexModal(
      maxWidth: 430,
      title: Text(
        widget.export ? 'Sicherung exportieren' : 'Sicherung importieren',
      ),
      onClose: busy ? null : () => Navigator.pop(context),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.export) ...[
            CompactSwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sicherung mit Passwort verschlüsseln'),
              value: encrypt,
              onChanged: busy ? null : (v) => setState(() => encrypt = v),
            ),
            CompactSwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Anzeigeeinstellungen mitsichern'),
              value: appearance,
              onChanged: busy ? null : (v) => setState(() => appearance = v),
            ),
          ] else
            CompactSwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auswahllisten aus der Sicherung übernehmen'),
              value: catalogs,
              onChanged: busy ? null : (v) => setState(() => catalogs = v),
            ),
          if (widget.export)
            const Text(
              'Die Sicherung enthält Unterrichtsdaten und Entwürfe einschließlich Papierkorb und früherer Fassungen. Bewahre sie geschützt auf.',
            ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(message!),
            ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
      actions: [
        FilledButton.icon(
          onPressed: busy
              ? null
              : () => action(widget.export ? exportFile : importFile),
          icon: Icon(widget.export ? Icons.download : Icons.upload_file),
          label: Text(widget.export ? 'Exportieren' : 'Datei auswählen'),
        ),
      ],
    ),
  );
}

Future<void> showImportReview(
  BuildContext context,
  NotebookController c,
  String text, {
  bool catalogs = true,
}) async {
  Json value;
  try {
    value = Json.from(jsonDecode(text) as Map);
  } catch (_) {
    throw const DomainError('Keine gültige FLEX-Sicherung.');
  }
  final legacy =
      value['format'] != 'FLEX-Flutter-Rebuild-Backup' &&
      value['format'] != 'FLEX-Flutter-Backup';
  if (legacy) {
    final report = await c.repository.inspectLegacy(text);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => FlexModal(
        title: const Text('Sicherung prüfen'),
        onClose: () => Navigator.pop(ctx),
        content: Text(
          '${report.pupils} Schüler, ${report.entries} Einträge. Diese HTML-Sicherung kann unverändert zur Migration vorgemerkt werden. Sie wird noch nicht als aktiver Datenstand übernommen.',
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              if (await guarded(ctx, () => c.repository.stageLegacy(text)) &&
                  ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Unverändert vormerken'),
          ),
        ],
      ),
    );
    return;
  }
  final tables = value['tables'];
  if (tables is! Map || tables['pupils'] is! List) {
    throw const DomainError('Keine gültige FLEX-Sicherung.');
  }
  if (c.pupils.isNotEmpty ||
      c.entries.isNotEmpty ||
      c.trashedEntries.isNotEmpty ||
      c.records.isNotEmpty ||
      c.draftCount > 0 ||
      c.stagedLegacyCount > 0 ||
      c.classroom.isNotEmpty) {
    if (context.mounted) {
      await showMergeReview(context, c, text, catalogs: catalogs);
    }
    return;
  }
  bool includeAppearance = (tables['preferences'] as List? ?? []).any(
        (r) => r['key'] == 'appearance',
      ),
      confirmed = false,
      busy = false;
  String? error;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => PopScope(
        canPop: !busy,
        child: FlexModal(
          title: const Text('Sicherung prüfen'),
          onClose: busy ? null : () => Navigator.pop(ctx),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${(tables['pupils'] as List).length} Schüler · ${(tables['school_records'] as List? ?? []).length + (tables['orga'] as List? ?? []).length} Einträge',
              ),
              const Text(
                'Diese Fassung stellt geprüfte Sicherungen in einem leeren Arbeitsbereich wieder her. Ein vorhandener Datenstand wird nicht überschrieben.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Diese Sicherung als neuen Datenstand verwenden',
                ),
                value: confirmed,
                onChanged: busy
                    ? null
                    : (v) => update(() => confirmed = v == true),
              ),
              CompactSwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Darstellung übernehmen'),
                value: includeAppearance,
                onChanged: busy
                    ? null
                    : (v) => update(() => includeAppearance = v),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!confirmed) {
                        update(
                          () => error =
                              'Bitte die Wiederherstellung als neuen Datenstand bestätigen.',
                        );
                        return;
                      }
                      update(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        final copy = Json.from(jsonDecode(text) as Map);
                        final preferences =
                            copy['tables']['preferences'] as List;
                        preferences.removeWhere(
                          (r) =>
                              !includeAppearance && r['key'] == 'appearance' ||
                              !catalogs &&
                                  (r['key'] as String).startsWith(
                                    'observation-',
                                  ),
                        );
                        if (!includeAppearance) {
                          preferences.add({
                            'key': 'appearance',
                            'payload': jsonEncode(c.appearance.toJson()),
                          });
                        }
                        if (!catalogs) {
                          final local = Json.from(
                            jsonDecode(await c.repository.exportBackup())
                                as Map,
                          );
                          preferences.addAll(
                            (local['tables']['preferences'] as List).where(
                              (r) => (r['key'] as String).startsWith(
                                'observation-',
                              ),
                            ),
                          );
                        }
                        await c.repository.restoreBackup(jsonEncode(copy));
                        await c.reload();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) update(() => error = friendlyError(e));
                      }
                      if (ctx.mounted) update(() => busy = false);
                    },
              child: const Text('Sicherung wiederherstellen'),
            ),
          ],
        ),
      ),
    ),
  );
}
