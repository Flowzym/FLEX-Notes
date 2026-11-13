import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/material_versions.dart';
import '../services/material_files.dart';
import '../services/material_storage.dart';
import '../services/material_versions.dart';
import 'common.dart';
import 'flex_modal.dart';
import 'material_library.dart';

Future<void> showMaterialVersions(
  BuildContext context,
  NotebookController c,
  ClassroomDocument original, {
  MaterialFiles files = const LocalMaterialFiles(),
}) async {
  var busy = false;
  String? error;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AnimatedBuilder(
        animation: c,
        builder: (ctx, _) {
          final current =
              c.classroom.where((d) => d.id == original.id).firstOrNull ??
              original;
          final versions = materialVersions(current.toJson());
          Future<void> apply(String id, {bool remove = false}) async {
            if (remove &&
                !await confirmFlex(
                  ctx,
                  'Version endgültig löschen?',
                  'Die aktuelle Datei bleibt erhalten.',
                  accept: 'Version löschen',
                )) {
              return;
            }
            if (!ctx.mounted) return;
            update(() {
              busy = true;
              error = null;
            });
            try {
              await changeMaterialVersion(
                c.repository,
                files,
                current,
                id,
                remove: remove,
              );
              await c.reload();
            } catch (e) {
              if (ctx.mounted) update(() => error = friendlyError(e));
            }
            if (ctx.mounted) update(() => busy = false);
          }

          return PopScope(
            canPop: !busy,
            child: FlexModal(
              title: const Text('Dokumentversionen'),
              maxWidth: 620,
              onClose: busy ? null : () => Navigator.pop(ctx),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Die letzten fünf Fassungen bleiben auf diesem Gerät gespeichert. Frühere Fassungen können Inhalte vor einer Schwärzung enthalten.',
                  ),
                  const SizedBox(height: 12),
                  if (versions.isEmpty)
                    const Text('Noch keine frühere Fassung.'),
                  for (final v in versions)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayDate(v['createdAtUtc'] as String)),
                          Text(
                            '${v['name']} · ${((v['size'] as int) / 1000).round()} KB',
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => guarded(
                                        ctx,
                                        () => openMaterial(
                                          ctx,
                                          c,
                                          current.patch({
                                            for (final k in versionFileFields)
                                              if (v[k] != null) k: v[k],
                                            'versions': [],
                                            'driveId': '',
                                            'itemId': '',
                                            'url': '',
                                          }),
                                          files: files,
                                        ),
                                      ),
                                child: const Text('Ansehen'),
                              ),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => apply(v['id'] as String),
                                child: const Text('Wiederherstellen'),
                              ),
                              IconButton(
                                tooltip: 'Version löschen',
                                onPressed: busy
                                    ? null
                                    : () => apply(
                                        v['id'] as String,
                                        remove: true,
                                      ),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (error != null) Text(error!),
                  if (busy) const LinearProgressIndicator(),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
