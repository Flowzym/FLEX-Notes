import 'dart:async';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/models.dart';
import '../domain/drafts.dart';
import '../domain/repository.dart';
import 'common.dart';
import 'flex_modal.dart';

Future<bool> saveTextFile(
  String name,
  String text, {
  String mime = 'text/plain',
}) => saveBytesFile(name, Uint8List.fromList(utf8.encode(text)), mime: mime);

Future<bool> saveBytesFile(
  String name,
  Uint8List bytes, {
  required String mime,
}) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return await const MethodChannel(
          'at.flowzym.flex_notizbuch/files',
        ).invokeMethod<bool>('saveFile', {
          'name': name,
          'mime': mime,
          'bytes': bytes,
        }) ??
        false;
  }
  final file = XFile.fromData(bytes, name: name, mimeType: mime);
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
    String? baseline,
    this.onPersisted,
    this.onStatusChanged,
    this.retainEmpty,
  }) : baseline =
           initial?.baseline ?? baseline ?? dialogDraftSignature(type, data),
       draft =
           initial ??
           DialogDraft(
             id: newId(),
             type: type,
             ownerId: ownerId,
             data: data,
             updatedAtUtc: utcNow(),
           ) {
    dirty = initial != null && !hasContent;
  }
  final NotebookRepository repository;
  final String baseline;
  final bool Function(DialogDraft)? retainEmpty;
  final Future<void> Function()? onPersisted;
  final VoidCallback? onStatusChanged;
  DialogDraft draft;
  Timer? timer;
  bool dirty = false;
  int generation = 0;
  Object? error;
  Future<void> pending = Future.value();
  bool get hasContent =>
      dialogDraftSignature(draft.type, draft.data) != baseline ||
      (retainEmpty?.call(draft) ?? false);
  void change(Json data) {
    dirty = true;
    generation++;
    draft = DialogDraft(
      id: draft.id,
      type: draft.type,
      ownerId: draft.ownerId,
      data: Json.from(jsonDecode(jsonEncode(data)) as Map),
      updatedAtUtc: utcNow(),
      revision: draft.revision,
      baseline: baseline,
    );
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 400), () async {
      try {
        await flush();
      } catch (e) {
        error = e;
        onStatusChanged?.call();
      }
    });
  }

  Future<void> flush({bool force = false}) async {
    timer?.cancel();
    if (!dirty && !force) {
      await pending;
      return;
    }
    final snapshot = draft, revisionGeneration = generation;
    pending = pending.catchError((Object _) {}).then((_) async {
      var revision = 0;
      if (force ||
          dialogDraftSignature(snapshot.type, snapshot.data) != baseline ||
          (retainEmpty?.call(snapshot) ?? false)) {
        final saved = await repository.saveDialogDraft(
          DialogDraft(
            id: snapshot.id,
            type: snapshot.type,
            ownerId: snapshot.ownerId,
            data: snapshot.data,
            updatedAtUtc: snapshot.updatedAtUtc,
            revision: draft.revision,
            baseline: baseline,
          ),
        );
        revision = saved.revision;
      } else if (draft.revision > 0) {
        await repository.discardDialogDraft(draft.id, draft.revision);
      }
      draft = DialogDraft(
        id: draft.id,
        type: draft.type,
        ownerId: draft.ownerId,
        data: draft.data,
        updatedAtUtc: draft.updatedAtUtc,
        revision: revision,
        baseline: baseline,
      );
      if (generation == revisionGeneration) dirty = false;
      error = null;
      await onPersisted?.call();
      onStatusChanged?.call();
    });
    await pending;
  }

  Future<void> discard() async {
    timer?.cancel();
    // An already queued write must finish before its revision can be deleted.
    await pending.catchError((Object _) {});
    if (draft.revision > 0) {
      await repository.discardDialogDraft(draft.id, draft.revision);
    }
    dirty = false;
    pending = Future.value();
    generation++;
    error = null;
    draft = DialogDraft(
      id: draft.id,
      type: draft.type,
      ownerId: draft.ownerId,
      data: draft.data,
      updatedAtUtc: draft.updatedAtUtc,
      revision: 0,
      baseline: baseline,
    );
  }

  void dispose() => timer?.cancel();
}

class DraftStatus extends StatelessWidget {
  const DraftStatus({super.key, required this.buffer});
  final DraftBuffer buffer;
  @override
  Widget build(BuildContext context) {
    final status = buffer.error != null
        ? 'Entwurf nicht gesichert: ${friendlyError(buffer.error!)}'
        : buffer.dirty
        ? 'Entwurf wird gesichert …'
        : buffer.draft.revision > 0
        ? 'Entwurf gesichert'
        : '';
    if (status.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 11,
            color: buffer.error == null
                ? null
                : Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
  }
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
