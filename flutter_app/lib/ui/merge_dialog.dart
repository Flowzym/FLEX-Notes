import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/backup_merge.dart';
import '../domain/models.dart';
import 'common.dart';
import 'conflict_dialog.dart';
import 'flex_modal.dart';
import 'draft_buffer.dart';
import 'backup_dialog.dart';
import '../security/backup_codec.dart';

Future<void> showMergeReview(
  BuildContext context,
  NotebookController c,
  String text, {
  bool catalogs = true,
}) async {
  final repository = c.repository as BackupMergeRepository;
  var plan = await repository.prepareBackupMerge(text, catalogs: catalogs);
  final choices = <String, Set<String>>{};
  var busy = false;
  String? error;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => PopScope(
        canPop: !busy,
        child: FlexModal(
          maxWidth: 1000,
          title: const Text('Sicherungen zusammenführen'),
          onClose: busy ? null : () => Navigator.pop(ctx),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${plan.newCount} neu · ${plan.duplicates} identisch · ${plan.conflicts} mit Unterschieden · ${plan.draftCount} Entwürfe in der Sicherung',
              ),
              const SizedBox(height: 12),
              const Text(
                'Bei Unterschieden bleibt zunächst der lokale Wert ausgewählt. Listen werden als ganzes Feld übernommen. Abweichende Entwürfe bleiben zusätzlich erhalten. Die vollständige Originalfassung mit Verläufen und Gruppenaktionen ist anschließend im Importarchiv verfügbar.',
              ),
              for (final match in plan.sameNames.entries)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Gleichnamiger Schüler: ${match.value.first.name}',
                        ),
                        const Text(
                          'Gehören beide Fassungen zur selben Person?',
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final pupil in match.value)
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () async {
                                        update(() => busy = true);
                                        try {
                                          final next = await repository
                                              .prepareBackupMerge(
                                                text,
                                                catalogs: catalogs,
                                                pupilLinks: {
                                                  ...plan.pupilLinks,
                                                  match.key: pupil.id,
                                                },
                                              );
                                          if (ctx.mounted) {
                                            update(() {
                                              plan = next;
                                              choices.clear();
                                              error = null;
                                            });
                                          }
                                        } catch (e) {
                                          if (ctx.mounted) {
                                            update(
                                              () => error = friendlyError(e),
                                            );
                                          }
                                        }
                                        if (ctx.mounted) {
                                          update(() => busy = false);
                                        }
                                      },
                                child: Text(
                                  'Mit ${pupil.name}${pupil.archived ? ' (Archiv)' : ''} verbinden',
                                ),
                              ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      update(() => busy = true);
                                      try {
                                        final next = await repository
                                            .prepareBackupMerge(
                                              text,
                                              catalogs: catalogs,
                                              pupilLinks: {
                                                ...plan.pupilLinks,
                                                match.key: match.key,
                                              },
                                            );
                                        if (ctx.mounted) {
                                          update(() {
                                            plan = next;
                                            choices.clear();
                                            error = null;
                                          });
                                        }
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          update(
                                            () => error = friendlyError(e),
                                          );
                                        }
                                      }
                                      if (ctx.mounted) {
                                        update(() => busy = false);
                                      }
                                    },
                              child: const Text('Als eigene Person hinzufügen'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              for (final item in plan.items.where((i) => !i.identical))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${item.isNew ? 'Neu' : 'Unterschiede'} · ${item.label.isEmpty ? 'Ohne Titel' : item.label}',
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                        if (item.isNew)
                          Text(
                            item.kind == 'pupil'
                                ? 'Schüler wird ergänzt.'
                                : item.incoming['body'] as String? ??
                                      'Wird ergänzt.',
                          )
                        else ...[
                          for (final field in item.differences)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    conflictFieldLabels[field] ??
                                        const {
                                          'name': 'Name',
                                          'color': 'Farbe',
                                          'archived': 'Archiviert',
                                          'options': 'Optionen',
                                        }[field] ??
                                        field,
                                    style: Theme.of(ctx).textTheme.titleSmall,
                                  ),
                                  for (final incoming in [false, true])
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: OutlinedButton(
                                        onPressed: busy
                                            ? null
                                            : () => update(() {
                                                final selected = choices
                                                    .putIfAbsent(
                                                      item.key,
                                                      () => <String>{},
                                                    );
                                                if (incoming) {
                                                  selected.add(field);
                                                } else {
                                                  selected.remove(field);
                                                }
                                              }),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                (choices[item.key]?.contains(
                                                              field,
                                                            ) ??
                                                            false) ==
                                                        incoming
                                                    ? Icons.radio_button_checked
                                                    : Icons
                                                          .radio_button_unchecked,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  '${incoming ? 'Sicherung' : 'Lokal'}: ${conflictText(field, incoming ? item.incoming[field] : item.local![field], c)}',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
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
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: busy || plan.sameNames.isNotEmpty
                  ? null
                  : () async {
                      update(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await repository.applyBackupMerge(plan, choices);
                        await c.reload();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) update(() => error = friendlyError(e));
                      }
                      if (ctx.mounted) update(() => busy = false);
                    },
              child: Text(busy ? 'Führt zusammen …' : 'Auswahl zusammenführen'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showImportArchives(
  BuildContext context,
  NotebookController c,
) async {
  final repository = c.repository as BackupMergeRepository;
  final archives = await repository.importArchives();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => FlexModal(
      title: const Text('Importarchiv'),
      onClose: () => Navigator.pop(ctx),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (archives.isEmpty)
            const Text('Noch keine Sicherungen zusammengeführt.'),
          for (final archive in archives)
            ListTile(
              title: Text(
                'Import vom ${(archive['importedAt'] as String).replaceFirst('T', ' ').split('.').first} UTC',
              ),
              subtitle: const Text(
                'Vollständige Originalfassung verschlüsselt exportieren',
              ),
              trailing: const Icon(Icons.download),
              onTap: () => guarded(ctx, () async {
                final password = await backupPassword(ctx, opening: false);
                if (password == null) return;
                final original = await repository.importArchive(
                  archive['id'] as String,
                );
                await saveTextFile(
                  'FLEX-Importarchiv-${dateOnly(DateTime.now())}.json',
                  await BackupCodec.encrypt(original, password),
                  mime: 'application/json',
                );
              }),
            ),
        ],
      ),
    ),
  );
}
