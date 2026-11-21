import 'merge_dialog.dart';
import '../services/secret_store.dart';
import '../services/automatic_backup.dart';
import '../platform/backup_transfer.dart';
import '../services/stream_backup.dart';
import 'compact_switch.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../security/backup_codec.dart';
import '../services/complete_backup.dart';
import '../services/material_files.dart';
import '../services/material_storage.dart';
import 'common.dart';
import 'flex_modal.dart';

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
  const BackupDialog({
    super.key,
    required this.controller,
    this.export = true,
    this.files = const LocalMaterialFiles(),
  });
  final NotebookController controller;
  final bool export;
  final MaterialFiles files;
  @override
  State<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<BackupDialog> {
  bool encrypt = true, appearance = true, catalogs = true, busy = false;
  String? message;
  static const _manualKey = 'flex.lastManualBackup';
  late final inventory = CompleteBackup.inventory(
    widget.controller.repository,
    widget.files,
  );
  DateTime? lastSuccess;
  @override
  void initState() {
    super.initState();
    if (widget.export) loadLastSuccess();
  }

  Future<void> loadLastSuccess() async {
    try {
      const store = DeviceSecretStore();
      final manual = await store.read(_manualKey);
      final raw = await store.read(AutomaticBackup.key);
      final automatic = raw == null
          ? null
          : (jsonDecode(raw) as Map)['lastSuccess'] as String?;
      final dates =
          [manual, automatic]
              .whereType<String>()
              .map(DateTime.tryParse)
              .whereType<DateTime>()
              .toList()
            ..sort();
      if (mounted &&
          dates.isNotEmpty &&
          (lastSuccess == null || dates.last.isAfter(lastSuccess!))) {
        setState(() => lastSuccess = dates.last.toLocal());
      }
    } catch (_) {
      /* The archive can still be exported if status storage is unavailable. */
    }
  }

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
    final password = encrypt
        ? await backupPassword(context, opening: false)
        : null;
    if (encrypt && password == null) return;
    final saved = await saveBackupStream(
      'FLEX-Sicherung-${dateOnly(DateTime.now())}.flexbackup',
      StreamBackup.capture(
        widget.controller.repository,
        widget.files,
        password: password,
        appearance: appearance,
        progress: (count, bytes) {
          if (mounted) {
            setState(
              () => message =
                  '$count Dateien · ${(bytes / 1000000).toStringAsFixed(1)} MB verarbeitet',
            );
          }
        },
      ),
    );
    if (saved) {
      lastSuccess = DateTime.now();
      try {
        await const DeviceSecretStore().write(
          _manualKey,
          lastSuccess!.toUtc().toIso8601String(),
        );
      } catch (_) {}
    }
    if (mounted) {
      setState(
        () => message = saved
            ? 'Sicherungsdatei wurde ausgegeben.'
            : 'Speichern abgebrochen.',
      );
    }
  }

  Future<void> importFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'FLEX-Sicherung',
          extensions: ['flexbackup', 'json'],
          mimeTypes: ['application/octet-stream', 'application/json'],
        ),
      ],
    );
    if (file == null) return;
    final length = await file.length();
    if (length > StreamBackup.maxArchiveBytes) {
      throw const DomainError(
        'Die Datei überschreitet die maximale Archivgröße.',
      );
    }
    Stream<List<int>> source() async* {
      // Web XFile.openRead() otherwise materializes the entire Blob at once.
      for (var offset = 0; offset < length; offset += 262144) {
        yield* file.openRead(offset, (offset + 262144).clamp(0, length));
      }
    }

    if (!mounted) return;
    await showBackupSourceReview(
      context,
      widget.controller,
      source,
      catalogs: catalogs,
      files: widget.files,
      progress: (count, bytes) {
        if (mounted) setState(() => message = '$count Dateien geprüft');
      },
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: FlexModal(
      maxWidth: 430,
      title: Text(
        widget.export ? 'Vollständige Sicherung' : 'Sicherung wiederherstellen',
      ),
      onClose: busy ? null : () => Navigator.pop(context),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.export) ...[
            FutureBuilder(
              future: inventory,
              builder: (context, snapshot) {
                final v = snapshot.data;
                return Text(
                  v == null
                      ? snapshot.hasError
                            ? 'Größe konnte nicht ermittelt werden.'
                            : 'Dateigröße wird ermittelt …'
                      : '${v.count} lokale Dateien · ca. ${(v.bytes / 1000000).toStringAsFixed(1)} MB${v.unknown == 0 ? '' : ' · ${v.unknown} ohne Größenangabe'}',
                );
              },
            ),
            Text(
              lastSuccess == null
                  ? 'Letzte Sicherung: kein Zeitpunkt gespeichert'
                  : 'Letzte Sicherung: ${displayDate(dateOnly(lastSuccess!))} · ${TimeOfDay.fromDateTime(lastSuccess!).format(context)}',
            ),
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
              'Eine Datei für Einträge, Entwürfe, lokale Materialien, Scans und Dokumentversionen. OneDrive-Links bleiben verknüpft; nur heruntergeladene Dateien sind offline enthalten.',
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

Future<void> showBackupSourceReview(
  BuildContext context,
  NotebookController controller,
  BackupSource source, {
  String? password,
  bool catalogs = true,
  MaterialFiles files = const LocalMaterialFiles(),
  BackupProgress? progress,
}) async {
  if (await StreamBackup.recognizes(source)) {
    if (password == null && await StreamBackup.requiresPassword(source)) {
      if (!context.mounted) return;
      password = await backupPassword(context, opening: true);
      if (password == null) return;
    }
    final restore = await StreamBackup.prepare(
      source,
      files,
      password: password,
      progress: progress,
    );
    if (context.mounted) {
      await showImportReview(
        context,
        controller,
        restore.notebook,
        catalogs: catalogs,
        files: files,
        complete: restore,
      );
    }
    return;
  }
  // Historical JSON containers remain supported. Only their legacy decoder
  // requires a full in-memory buffer; new exports use the streaming path.
  final bytes = BytesBuilder();
  await for (final part in source()) {
    if (bytes.length + part.length > BackupCodec.maxCompleteEnvelopeBytes) {
      throw const DomainError('Die Datei überschreitet 220 MB.');
    }
    bytes.add(part);
  }
  var text = utf8.decode(bytes.takeBytes());
  if (BackupCodec.isEncrypted(text)) {
    if (password == null) {
      if (!context.mounted) return;
      password = await backupPassword(context, opening: true);
      if (password == null) return;
    }
    text = await compute(_decrypt, {'text': text, 'password': password});
  }
  if (context.mounted) {
    await showImportReview(
      context,
      controller,
      text,
      catalogs: catalogs,
      files: files,
    );
  }
}

Future<void> showImportReview(
  BuildContext context,
  NotebookController c,
  String text, {
  bool catalogs = true,
  MaterialFiles files = const LocalMaterialFiles(),
  CompleteRestore? complete,
}) async {
  Json value;
  try {
    value = Json.from(jsonDecode(text) as Map);
  } catch (_) {
    throw const DomainError('Keine gültige FLEX-Sicherung.');
  }
  if (value['format'] == CompleteBackup.format) {
    final bundle = await CompleteBackup.decode(value);
    final restore = await bundle.prepare(files);
    if (context.mounted) {
      await showImportReview(
        context,
        c,
        restore.notebook,
        catalogs: catalogs,
        files: files,
        complete: restore,
      );
    }
    return;
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
          '${report.pupils} Schüler, ${report.entries} Einträge. Diese HTML-Sicherung kann unverändert zur Migration vorgemerkt werden. Ihre Einträge werden noch nicht in FLEX übernommen.',
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
      await showMergeReview(
        context,
        c,
        text,
        catalogs: catalogs,
        complete: complete,
      );
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
              if (complete != null)
                Text(
                  '${complete.fileCount} Dateien geprüft · werden gemeinsam wiederhergestellt',
                ),
              Text(
                '${(tables['pupils'] as List).length} Schüler · ${(tables['school_records'] as List? ?? []).length + (tables['orga'] as List? ?? []).length} Einträge',
              ),
              const Text(
                'Geprüfte Sicherungen können in einem leeren Arbeitsbereich wiederhergestellt werden. Vorhandene Daten bleiben erhalten.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Die Daten aus dieser Sicherung wiederherstellen',
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
                              'Bitte die Wiederherstellung dieser Sicherung bestätigen.',
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
                                  !(r['key'] as String).contains('@') &&
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
                              (r) =>
                                  !(r['key'] as String).contains('@') &&
                                  (r['key'] as String).startsWith(
                                    'observation-',
                                  ),
                            ),
                          );
                        }
                        Future<void> apply() =>
                            c.repository.restoreBackup(jsonEncode(copy));
                        if (complete == null) {
                          await apply();
                        } else {
                          await complete.commit(apply);
                        }
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
