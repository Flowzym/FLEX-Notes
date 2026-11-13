import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import '../domain/homework_control.dart';
import 'common.dart';
import 'detail_flow.dart';
import 'flex_modal.dart';
import 'homework_record_view.dart';
import 'school_workspace.dart';

Future<void> showHomeworkControl(
  BuildContext context,
  NotebookController c,
  String date,
) => showFlexDetail<void>(
  context: context,
  builder: (_) => HomeworkControl(controller: c, date: date),
);

class HomeworkControl extends StatefulWidget {
  const HomeworkControl({
    super.key,
    required this.controller,
    required this.date,
  });
  final NotebookController controller;
  final String date;
  @override
  State<HomeworkControl> createState() => _HomeworkControlState();
}

class _HomeworkControlState extends State<HomeworkControl> {
  NotebookController get c => widget.controller;
  final reviewed = <String>{}, busy = <String>{};
  String query = '';
  bool all = false;
  Future<void> review(
    SchoolRecord record,
    HomeworkTask task,
    TaskState state,
  ) async {
    if (busy.contains(record.id)) return;
    setState(() => busy.add(record.id));
    final success = await guarded(context, () async {
      final latest = c.records.where((r) => r.id == record.id).firstOrNull;
      if (latest == null) {
        throw const DomainError('Die Hausübung ist nicht mehr verfügbar.');
      }
      final next = reviewHomeworkTask(latest, task.id, state, DateTime.now());
      if (!identical(next, latest)) await c.saveRecord(next);
    });
    if (mounted) {
      setState(() {
        busy.remove(record.id);
        if (success) reviewed.add(record.id);
      });
    }
  }

  Future<void> details(String id) => showFlexDetail<void>(
    context: context,
    builder: (ctx) => AnimatedBuilder(
      animation: c,
      builder: (ctx, _) {
        final r = c.records.where((v) => v.id == id && !v.deleted).firstOrNull;
        return FlexModal(
          title: const Text('Hausübung'),
          onClose: () => Navigator.pop(ctx),
          content: r == null
              ? const Text('Die Hausübung wurde entfernt.')
              : SchoolRecordCard(controller: c, record: r, standalone: true),
        );
      },
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) {
      final pupils = {
        for (final p in c.pupils.where((p) => !p.archived)) p.id: p,
      };
      final values =
          c.records
              .where(
                (r) =>
                    !r.deleted &&
                    r.kind == SchoolKind.homework &&
                    pupils.containsKey(r.pupilId) &&
                    (all ||
                        (r.pending || reviewed.contains(r.id)) &&
                            r.observedOn.compareTo(widget.date) <= 0 &&
                            (r.dueDate == null ||
                                r.dueDate!.compareTo(widget.date) <= 0)) &&
                    '${pupils[r.pupilId]!.name} ${r.searchText}'
                        .toLowerCase()
                        .contains(query.toLowerCase()),
              )
              .toList()
            ..sort((a, b) {
              final name = pupils[a.pupilId]!.name.compareTo(
                pupils[b.pupilId]!.name,
              );
              return name != 0
                  ? name
                  : (a.dueDate ?? a.observedOn).compareTo(
                      b.dueDate ?? b.observedOn,
                    );
            });
      return FlexModal(
        title: const Text('HÜ-Kontrolle'),
        onClose: () => Navigator.pop(context),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              all ? 'Alle Termine' : 'Fällig bis ${displayDate(widget.date)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Schüler oder Aufgabe suchen',
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Offen / gerade geprüft'),
                  selected: !all,
                  onSelected: (_) => setState(() => all = false),
                ),
                ChoiceChip(
                  label: const Text('Alle Hausübungen'),
                  selected: all,
                  onSelected: (_) => setState(() => all = true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List<Widget>.generate(values.isEmpty ? 1 : values.length, (i) {
              final ctx = context;
              if (values.isEmpty) {
                return const EmptyState(
                  'Keine passenden Hausübungen.',
                  icon: Icons.fact_check_outlined,
                );
              }
              final r = values[i], pupil = pupils[r.pupilId]!;
              final heading = r.title.isNotEmpty
                  ? r.title
                  : r.subject.isNotEmpty
                  ? r.subject
                  : 'Hausübung';
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (i == 0 || values[i - 1].pupilId != r.pupilId)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 6),
                        child: Text(
                          pupil.name,
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$heading · ${displayDate(r.dueDate ?? r.observedOn)}',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Aufgabendetails: $heading',
                          onPressed: busy.contains(r.id)
                              ? null
                              : () => details(r.id),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    for (final task in r.tasks)
                      Padding(
                        padding: EdgeInsets.only(
                          left: task.parentId == null ? 0 : 14,
                        ),
                        child: LayoutBuilder(
                          builder: (ctx, constraints) {
                            final name = Text(task.text);
                            final status = HomeworkStatusSelector(
                              task: task,
                              value: r.taskState(task),
                              onChanged: busy.contains(r.id)
                                  ? null
                                  : (s) => review(r, task, s),
                            );
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child:
                                  constraints.maxWidth >= 440 &&
                                      MediaQuery.textScalerOf(ctx).scale(14) <
                                          20
                                  ? Row(
                                      children: [
                                        Expanded(child: name),
                                        status,
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [name, status],
                                    ),
                            );
                          },
                        ),
                      ),
                    const Divider(height: 12),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}
