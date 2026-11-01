import 'dart:async';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../domain/models.dart';
import '../domain/repository.dart';
import 'common.dart';
import 'flex_modal.dart';

Future<bool> saveTextFile(
  String name,
  String text, {
  String mime = 'text/plain',
}) async {
  final file = XFile.fromData(
    Uint8List.fromList(utf8.encode(text)),
    name: name,
    mimeType: mime,
  );
  if (kIsWeb) {
    await file.saveTo(name);
    return true;
  }
  final location = await getSaveLocation(suggestedName: name);
  if (location == null) return false;
  await file.saveTo(location.path);
  return true;
}

/// Serializes draft writes and checks the draft's own revision independently
/// of its record. Closing awaits the last queued write.
class DraftBuffer {
  DraftBuffer(
    this.repository, {
    required String type,
    required String ownerId,
    required Json data,
    DialogDraft? initial,
  }) : draft =
           initial ??
           DialogDraft(
             id: newId(),
             type: type,
             ownerId: ownerId,
             data: data,
             updatedAtUtc: utcNow(),
           );
  final NotebookRepository repository;
  DialogDraft draft;
  Timer? timer;
  bool dirty = false;
  Object? error;
  Future<void> pending = Future.value();
  void change(Json data) {
    dirty = true;
    draft = DialogDraft(
      id: draft.id,
      type: draft.type,
      ownerId: draft.ownerId,
      data: Json.from(jsonDecode(jsonEncode(data)) as Map),
      updatedAtUtc: utcNow(),
      revision: draft.revision,
    );
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 400), () async {
      try {
        await flush();
      } catch (e) {
        error = e;
      }
    });
  }

  Future<void> flush() async {
    timer?.cancel();
    if (!dirty) {
      await pending;
      return;
    }
    final snapshot = draft;
    pending = pending.catchError((Object _) {}).then((_) async {
      final saved = await repository.saveDialogDraft(
        DialogDraft(
          id: snapshot.id,
          type: snapshot.type,
          ownerId: snapshot.ownerId,
          data: snapshot.data,
          updatedAtUtc: snapshot.updatedAtUtc,
          revision: draft.revision,
        ),
      );
      draft = DialogDraft(
        id: draft.id,
        type: draft.type,
        ownerId: draft.ownerId,
        data: draft.data,
        updatedAtUtc: draft.updatedAtUtc,
        revision: saved.revision,
      );
      error = null;
    });
    await pending;
  }

  void dispose() => timer?.cancel();
}

Future<bool> unsavedDraft(
  BuildContext context,
  NotebookRepository repository,
  Json input,
) async {
  String? error;
  var busy = false;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => FlexModal(
            maxWidth: 430,
            title: const Text('Entwurf nicht gesichert'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Die Eingabe ist nur in dieser Sitzung vorhanden.'),
                if (error != null) Text(error!),
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx, false),
                child: const Text('Weiterbearbeiten'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        update(() => busy = true);
                        try {
                          // Includes the unsaved input even when the repository cannot write.
                          Object? backup;
                          String? backupError;
                          try {
                            backup = jsonDecode(
                              await repository.exportBackup(),
                            );
                          } catch (e) {
                            backupError = friendlyError(e);
                          }
                          await saveTextFile(
                            'FLEX-Entwurfsrettung-${dateOnly(DateTime.now())}.json',
                            jsonEncode({
                              'format': 'FLEX-Unsaved-Recovery',
                              'backup': backup,
                              'backupError': ?backupError,
                              'unsavedInput': input,
                            }),
                            mime: 'application/json',
                          );
                        } catch (e) {
                          if (ctx.mounted) {
                            update(() => error = friendlyError(e));
                          }
                        }
                        if (ctx.mounted) update(() => busy = false);
                      },
                child: const Text('Sicherung exportieren'),
              ),
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx, true),
                child: const Text('Verwerfen'),
              ),
            ],
          ),
        ),
      ) ??
      false;
}
