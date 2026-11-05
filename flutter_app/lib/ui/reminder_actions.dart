import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';
import 'common.dart';
import 'flex_modal.dart';

Future<void> showReminderActions(
  BuildContext context,
  NotebookController c,
  String target,
  String title,
) async {
  final id = const Uuid().v5(Namespace.url.value, 'flex-snooze:$target');
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      var busy = false;
      return StatefulBuilder(
        builder: (ctx, update) {
          Future<void> save(DateTime? at) async {
            if (busy) return;
            update(() => busy = true);
            final ok = await guarded(ctx, () async {
              final old = c.classroom.where((d) => d.id == id).firstOrNull;
              final fields = <String, dynamic>{
                'target': target,
                'at': (at ?? DateTime.now()).toUtc().toIso8601String(),
                'dismissed': at == null,
                'deleted': false,
              };
              final doc = old == null
                  ? ClassroomDocument.create(
                      ClassroomKind.reminder,
                      title,
                      fields,
                      id: id,
                    )
                  : old.patch(fields);
              await c.saveClassroom(doc);
            });
            if (!ctx.mounted) return;
            if (ok) {
              Navigator.pop(ctx);
            } else {
              update(() => busy = false);
            }
          }

          return FlexModal(
            maxWidth: 480,
            title: const Text('Erinnerung verschieben'),
            onClose: busy ? null : () => Navigator.pop(ctx),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title),
                const SizedBox(height: 12),
                const Text('Die Fälligkeit bleibt bestehen.'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () =>
                            save(DateTime.now().add(const Duration(hours: 1))),
                  icon: const Icon(Icons.snooze),
                  label: const Text('In einer Stunde'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          final now = DateTime.now();
                          save(DateTime(now.year, now.month, now.day + 1, 9));
                        },
                  child: const Text('Morgen um 09:00'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final picked = await pickFlexDate(
                            ctx,
                            date: dateOnly(DateTime.now()),
                            time: '09:00',
                            allowTime: true,
                          );
                          if (picked == null ||
                              picked.$1.isEmpty ||
                              !ctx.mounted) {
                            return;
                          }
                          final at = DateTime.parse(
                            '${picked.$1}T${picked.$2.isEmpty ? '09:00' : picked.$2}:00',
                          );
                          if (!at.isAfter(DateTime.now())) {
                            await guarded(
                              ctx,
                              () async => throw const DomainError(
                                'Bitte einen Zeitpunkt in der Zukunft wählen.',
                              ),
                            );
                            return;
                          }
                          await save(at);
                        },
                  child: const Text('Zeitpunkt wählen'),
                ),
                TextButton(
                  onPressed: busy ? null : () => save(null),
                  child: const Text('Keine weitere Erinnerung'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
