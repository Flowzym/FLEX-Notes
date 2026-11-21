import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/lesson_flow.dart';
import '../domain/models.dart';
import '../domain/planning_import.dart';
import '../domain/teaching_sheet.dart';
import 'classroom_editor.dart';
import 'common.dart';
import 'lesson_flow_page.dart';
import 'teaching_review.dart';

Future<void> openPlanningBoard(
  BuildContext context,
  NotebookController c, {
  bool documents = false,
}) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    builder: (_) => PlanningBoard(controller: c, documents: documents),
  ),
);

Future<void> openSavedPlan(
  BuildContext context,
  NotebookController c,
  ClassroomDocument plan,
) async {
  if (hasLessonFlow(plan) &&
      !isFlowTemplate(plan) &&
      validDate(plan.text('date'))) {
    final pupil = lessonFlowPupil(plan);
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(plan.title)),
          body: SafeArea(
            child: LessonFlowPage(
              controller: c,
              initialDate: plan.text('date'),
              initialTarget: plan.map('flow')['lessonTarget'] as String?,
              initialPupilId: pupil.isEmpty ? null : pupil,
            ),
          ),
        ),
      ),
    );
  } else {
    await showClassroomEditor(context, c, plan.kind, document: plan);
  }
}

class PlanningBoard extends StatefulWidget {
  const PlanningBoard({
    super.key,
    required this.controller,
    this.documents = false,
  });
  final bool documents;
  final NotebookController controller;
  @override
  State<PlanningBoard> createState() => _PlanningBoardState();
}

class _PlanningBoardState extends State<PlanningBoard> {
  String query = '', status = 'planned';
  late bool sources = widget.documents;
  final copying = <String>{};
  NotebookController get c => widget.controller;

  Future<void> duplicate(ClassroomDocument p) async {
    if (!copying.add(p.id)) return;
    try {
      String? date;
      var target = '';
      if (hasLessonFlow(p) && !isFlowTemplate(p)) {
        final start = DateTime.tryParse(p.text('date')) ?? DateTime.now();
        final chosen = await showDatePicker(
          context: context,
          initialDate: DateTime(start.year, start.month, start.day + 1),
          firstDate: DateTime(1900),
          lastDate: DateTime(2200),
          helpText: 'Unterrichtstag für die Kopie',
        );
        if (chosen == null || !mounted) return;
        date = dateOnly(chosen);
        final lessons = lessonOccurrences(
          c.classroom,
          date,
          date,
        ).where((l) => l.document.isTeachingLesson);
        if (lessons.isNotEmpty) {
          final choice = await showDialog<String>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: const Text('Ablauf zuordnen'),
              children: [
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: const Text('Ganzer Tag'),
                ),
                for (final l in lessons)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, l.target),
                    child: Text('${l.start} · ${l.title}'),
                  ),
              ],
            ),
          );
          if (choice == null || !mounted) return;
          target = choice;
        }
      }
      final ok = await guarded(
        context,
        () => c.saveClassroom(
          copyTeachingPlan(p, c.classroom, date: date, lessonTarget: target),
        ),
      );
      if (ok && mounted) {
        setState(() => status = 'planned');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kopie unter „Geplant“ gespeichert.')),
        );
      }
    } finally {
      copying.remove(p.id);
    }
  }

  Widget planTile(ClassroomDocument p) => Card(
    child: ListTile(
      title: Text(p.title),
      subtitle: Text(
        [
          if (isFlowTemplate(p)) 'Ablaufvorlage',
          p.text('subject'),
          displayDate(p.text('date')),
          p.text('note'),
        ].where((s) => s.isNotEmpty).join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => openSavedPlan(context, c, p),
      trailing: PopupMenuButton<String>(
        tooltip: 'Planung bearbeiten',
        onSelected: (value) {
          if (value == 'copy') {
            duplicate(p);
          } else {
            guarded(context, () => c.saveClassroom(p.patch({'status': value})));
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'copy',
            child: Text('Planung duplizieren'),
          ),
          for (final e in planStatuses.entries)
            CheckedPopupMenuItem(
              value: e.key,
              checked: p.text('status', 'planned') == e.key,
              child: Text(e.value),
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (ctx, _) {
      final words = query.toLowerCase().trim().split(RegExp(r'\s+'));
      final docs = c.classroom.where((d) {
        if (d.deleted ||
            (sources ? !isTeachingSource(d) : d.kind != ClassroomKind.plan)) {
          return false;
        }
        final body = [
          d.title,
          d.text('subject'),
          d.text('note'),
          d.text('date'),
          d.text('remotePath'),
          teachingDay(d),
          teachingWeek(d),
          if (sources)
            for (final row in teachingRows(d))
              ...row.values.whereType<String>(),
        ].join(' ').toLowerCase();
        return words.every(body.contains);
      }).toList()..sort((a, b) => a.title.compareTo(b.title));
      final groups = {
        for (final s in planStatuses.keys)
          s: docs.where((d) => d.text('status', 'planned') == s).toList(),
      };
      final statuses = [
        'planned',
        'started',
        'done',
        if (groups['moved']!.isNotEmpty || status == 'moved') 'moved',
      ];
      Widget list(String s) => ListView(
        padding: const EdgeInsets.only(bottom: 76),
        children: [
          if (groups[s]!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Keine Planungen.'),
            ),
          ...groups[s]!.map(planTile),
        ],
      );
      return Scaffold(
        appBar: AppBar(
          title: const Text('Unterrichtsplanung'),
          toolbarHeight: 48,
        ),
        floatingActionButton: sources
            ? null
            : FloatingActionButton(
                tooltip: 'Planung hinzufügen',
                onPressed: () =>
                    showClassroomEditor(ctx, c, ClassroomKind.plan),
                child: const Icon(Icons.add),
              ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in {
                      false: 'Planungstafel',
                      true: 'OneDrive-Dokumente',
                    }.entries)
                      ChoiceChip(
                        label: Text(option.value),
                        selected: sources == option.key,
                        onSelected: (_) => setState(() => sources = option.key),
                      ),
                  ],
                ),
                TextField(
                  onChanged: (s) => setState(() => query = s),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: sources
                        ? 'Planungsdokumente durchsuchen'
                        : 'Planungen durchsuchen',
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: sources
                      ? ListView(
                          children: [
                            if (docs.isEmpty)
                              const ListTile(
                                title: Text(
                                  'Keine passenden Planungsdokumente.',
                                ),
                              ),
                            for (final d in docs)
                              ListTile(
                                leading: const Icon(Icons.description_outlined),
                                title: Text(d.title),
                                subtitle: Text(
                                  teachingUse(d) == 'weekPlan'
                                      ? 'Wochenplanung · ${displayDate(teachingWeek(d))}'
                                      : 'Tagesplanung · ${displayDate(teachingDay(d))}',
                                ),
                                onTap: () => openTeachingReview(ctx, c, d),
                              ),
                          ],
                        )
                      : LayoutBuilder(
                          builder: (ctx, box) =>
                              box.maxWidth >=
                                  statuses.length *
                                      225 *
                                      MediaQuery.textScalerOf(ctx).scale(1)
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final s in statuses)
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Text(
                                              '${planStatuses[s]} (${groups[s]!.length})',
                                            ),
                                            Expanded(child: list(s)),
                                          ],
                                        ),
                                      ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 4,
                                      children: [
                                        for (final s in statuses)
                                          ChoiceChip(
                                            label: Text(
                                              '${planStatuses[s]} (${groups[s]!.length})',
                                            ),
                                            selected: status == s,
                                            onSelected: (_) =>
                                                setState(() => status = s),
                                          ),
                                      ],
                                    ),
                                    Expanded(child: list(status)),
                                  ],
                                ),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
