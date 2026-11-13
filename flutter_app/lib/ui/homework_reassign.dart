import 'package:flutter/material.dart';

import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import 'common.dart';
import 'flex_modal.dart';

Future<void> suggestHomeworkReassignment(
  BuildContext context,
  NotebookController c,
  SchoolRecord record,
  String taskId,
) async {
  final task = record.tasks.firstWhere((t) => t.id == taskId);
  String? dueDate = dateOnly(DateTime.now().add(const Duration(days: 1)));
  String? error;
  var busy = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => PopScope(
        canPop: !busy,
        child: FlexModal(
          maxWidth: 430,
          title: const Text('Erneut aufgeben?'),
          onClose: busy ? null : () => Navigator.pop(ctx),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(task.text, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text(
                record.tasks.any((t) => t.parentId == taskId)
                    ? 'Diese Aufgabe mit ihren Unteraufgaben erneut aufgeben.'
                    : 'Diese Aufgabe als neue offene Hausübung aufgeben.',
              ),
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final value = await pickFlexDate(
                          ctx,
                          date: dueDate ?? '',
                          allowTime: false,
                        );
                        if (value != null && ctx.mounted) {
                          update(
                            () => dueDate = value.$1.isEmpty ? null : value.$1,
                          );
                        }
                      },
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  dueDate == null
                      ? 'Ohne Fälligkeit'
                      : 'Fällig: ${displayDate(dueDate)}',
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              if (busy) const LinearProgressIndicator(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('So belassen'),
            ),
            FilledButton(
              key: const ValueKey('reassign-homework'),
              onPressed: busy
                  ? null
                  : () async {
                      update(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await c.repository.reassignHomeworkTask(
                          record,
                          taskId,
                          dueDate: dueDate,
                        );
                        await c.reload();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          update(() {
                            busy = false;
                            error = friendlyError(e);
                          });
                        }
                      }
                    },
              child: const Text('Erneut aufgeben'),
            ),
          ],
        ),
      ),
    ),
  );
}
