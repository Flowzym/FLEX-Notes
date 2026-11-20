import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import 'common.dart';
import 'flex_modal.dart';

Future<void> editLessonQuestion(
  BuildContext context,
  NotebookController c,
  SchoolRecord goal,
) async {
  final original = goal.lessonQuestion;
  var date = original?.date ?? dateOnly(DateTime.now());
  var start = original?.start ?? '', end = original?.end ?? '';
  var question = original?.text ?? '';
  final change = await showDialog<({LessonQuestion? value})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, refresh) {
        final choices = <(String, String), String>{
          for (final l in lessonOccurrences(
            c.classroom,
            date,
            date,
          ).where((l) => l.document.isTeachingLesson))
            (l.start, l.end): l.title,
        };
        if (start.isNotEmpty) {
          choices.putIfAbsent((start, end), () => 'Vorgemerkte Stunde');
        }
        return FlexModal(
          title: const Text('Beobachtungsfrage'),
          onClose: () => Navigator.pop(ctx),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(goal.title, style: Theme.of(ctx).textTheme.titleMedium),
              TextFormField(
                initialValue: question,
                maxLength: 300,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Was möchtest du beobachten?',
                  hintText: 'Beginnt der Schüler selbst mit der Aufgabe?',
                ),
                onChanged: (v) => refresh(() => question = v),
              ),
              TextButton.icon(
                onPressed: () async {
                  final choice = await pickFlexDate(
                    ctx,
                    date: date,
                    allowTime: false,
                    allowDateClear: false,
                  );
                  if (choice != null && ctx.mounted && choice.$1 != date) {
                    refresh(() {
                      date = choice.$1;
                      start = '';
                      end = '';
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(displayDate(date)),
              ),
              if (choices.isNotEmpty)
                DropdownButton<(String, String)>(
                  value: (start, end),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: ('', ''),
                      child: Text('Ganzer Unterrichtstag'),
                    ),
                    for (final e in choices.entries)
                      DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          '${e.key.$1}–${e.key.$2} · ${e.value}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      refresh(() {
                        start = v.$1;
                        end = v.$2;
                      });
                    }
                  },
                ),
            ],
          ),
          actions: [
            if (original != null)
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, (value: null as LessonQuestion?)),
                child: const Text('Entfernen'),
              ),
            FilledButton(
              onPressed: question.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, (
                      value: LessonQuestion(
                        question.trim(),
                        date,
                        start: start,
                        end: end,
                      ),
                    )),
              child: const Text('Vormerken'),
            ),
          ],
        );
      },
    ),
  );
  if (change != null && context.mounted) {
    await guarded(
      context,
      () =>
          c.saveRecord(goal.patch({'lessonQuestion': change.value?.toJson()})),
    );
  }
}

class LessonQuestionPrompt extends StatelessWidget {
  const LessonQuestionPrompt({
    super.key,
    required this.controller,
    required this.record,
    required this.onChanged,
  });
  final NotebookController controller;
  final SchoolRecord record;
  final ValueChanged<Json> onChanged;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = record.observedOn;
    final time = record.observedTime.isNotEmpty
        ? record.observedTime
        : day == dateOnly(now)
        ? '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'
        : '';
    final saved = record.lessonQuestion;
    final answered = {
      for (final r in controller.records)
        if (!r.deleted &&
            r.id != record.id &&
            r.kind == SchoolKind.work &&
            r.pupilId == record.pupilId &&
            r.observedOn == day)
          if (r.lessonQuestion case final q?)
            (r.goalId, q.text, q.start, q.end),
    };
    final prompts = <({String goalId, String goal, LessonQuestion q})>[
      if (saved != null && record.goalId != null)
        (goalId: record.goalId!, goal: record.goalSnapshot, q: saved)
      else
        for (final goal in controller.records)
          if (goal.kind == SchoolKind.goal &&
              !goal.deleted &&
              goal.goalStatus == 'active' &&
              goal.pupilId == record.pupilId &&
              (record.goalId == null || record.goalId == goal.id) &&
              goal.lessonQuestion != null &&
              goal.lessonQuestion!.applies(day, time) &&
              !answered.contains((
                goal.id,
                goal.lessonQuestion!.text,
                goal.lessonQuestion!.start,
                goal.lessonQuestion!.end,
              )))
            (goalId: goal.id, goal: goal.title, q: goal.lessonQuestion!),
    ];
    if (prompts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in prompts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Beobachtungsfrage · ${p.goal}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(p.q.text, style: Theme.of(context).textTheme.titleMedium),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final answer in focusAnswers)
                      ChoiceChip(
                        label: Text(answer),
                        selected: saved?.answer == answer,
                        onSelected: (v) => onChanged({
                          'goalId': p.goalId,
                          'goalSnapshot': p.goal,
                          'lessonQuestion': v
                              ? {...p.q.toJson(), 'answer': answer}
                              : null,
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
