import 'package:uuid/uuid.dart';
import 'classroom.dart';
import 'lesson_flow_data.dart';
import 'models.dart';
export 'lesson_flow_data.dart';

bool hasLessonFlow(ClassroomDocument d) =>
    d.kind == ClassroomKind.plan && d.map('flow').isNotEmpty;
bool isFlowTemplate(ClassroomDocument d) =>
    hasLessonFlow(d) && d.map('flow')['template'] == true;
String lessonFlowPupil(ClassroomDocument d) =>
    d.map('flow')['pupilId'] as String? ?? '';
List<LessonPhase> lessonPhases(ClassroomDocument d) =>
    (d.map('flow')['phases'] as List? ?? [])
        .map((p) => LessonPhase.fromJson(Json.from(p as Map)))
        .toList();

ClassroomDocument withLessonPhases(
  ClassroomDocument d,
  List<LessonPhase> phases,
) => d.patch({
  if (!isFlowTemplate(d))
    'status': phases.isNotEmpty && phases.every((p) => !p.pending)
        ? phases.every((p) => p.carriedTo.isNotEmpty)
              ? 'moved'
              : 'done'
        : phases.any((p) => p.status != 'open' || p.elapsed > 0)
        ? 'started'
        : 'planned',
  'flow': {...d.map('flow'), 'phases': phases.map((p) => p.toJson()).toList()},
});

ClassroomDocument lessonFlowFor(
  Iterable<ClassroomDocument> docs,
  String date, {
  LessonOccurrence? lesson,
  String? lessonTarget,
  String pupilId = '',
  ClassroomDocument? sharedFlow,
}) {
  final target = lessonTarget ?? lesson?.target ?? '';
  final existing = docs
      .where(
        (d) =>
            !d.deleted &&
            hasLessonFlow(d) &&
            !isFlowTemplate(d) &&
            d.text('date') == date &&
            lessonFlowPupil(d) == pupilId &&
            d.map('flow')['lessonTarget'] == target,
      )
      .firstOrNull;
  if (existing != null) return existing;
  final stableId = const Uuid().v5(
    Namespace.url.value,
    'flex-flow:$date:$target${pupilId.isEmpty ? '' : ':pupil:$pupilId'}',
  );
  final shared = pupilId.isEmpty
      ? null
      : sharedFlow ??
            lessonFlowFor(docs, date, lesson: lesson, lessonTarget: target);
  return ClassroomDocument.create(
    ClassroomKind.plan,
    shared?.title ?? lesson?.title ?? 'FLEX-Klasse',
    {
      'date': date,
      'status': 'planned',
      'flow': {
        'template': false,
        'lessonTarget': target,
        if (pupilId.isNotEmpty) 'pupilId': pupilId,
        'phases': shared != null
            ? [
                for (final p in lessonPhases(shared))
                  if (p.pupilIds.isEmpty || p.pupilIds.contains(pupilId))
                    p.fresh().patch({'pupilIds': <String>[]}).toJson(),
              ]
            : [
                for (final p in [
                  ('Ankommen', 10, 'work'),
                  ('HÜ-Kontrolle', 10, 'homework'),
                  ('Arbeitsphase', 30, 'work'),
                  ('Austausch', 10, 'work'),
                  ('Abschluss', 5, 'work'),
                ])
                  LessonPhase(
                    id: newId(),
                    title: p.$1,
                    minutes: p.$2,
                    kind: p.$3,
                  ).toJson(),
              ],
      },
    },
    id: docs.any((d) => d.id == stableId) ? newId() : stableId,
  );
}

ClassroomDocument activateLessonPhase(
  ClassroomDocument d,
  String id,
  DateTime now,
) => withLessonPhases(d, [
  for (final p in lessonPhases(d))
    if (p.id == id)
      p.pause(now).patch({
        'status': 'active',
        'startedAt': now.toUtc().toIso8601String(),
        'carriedTo': '',
      })
    else if (p.status == 'active')
      p.pause(now).patch({'status': 'open'})
    else
      p,
]);

ClassroomDocument finishLessonPhase(
  ClassroomDocument d,
  String id,
  DateTime now, {
  bool skip = false,
}) {
  final phases = [
    for (final p in lessonPhases(d))
      if (p.id == id)
        p.pause(now).patch({'status': skip ? 'skipped' : 'done'})
      else
        p,
  ];
  final next = phases.where((p) => p.status == 'open').firstOrNull;
  final updated = withLessonPhases(d, phases);
  return next == null ? updated : activateLessonPhase(updated, next.id, now);
}

ClassroomDocument flowTemplate(ClassroomDocument source, String title) =>
    ClassroomDocument.create(ClassroomKind.plan, title, {
      'flow': {
        'template': true,
        'lessonTarget': '',
        'phases': lessonPhases(source).map((p) => p.fresh().toJson()).toList(),
      },
    });

/// Atomic caller saves both documents. The source retains its history and destination.
List<ClassroomDocument> carryLessonPhases(
  ClassroomDocument source,
  ClassroomDocument target,
  DateTime now,
) {
  if (source.id == target.id || source.text('date') == target.text('date')) {
    throw const DomainError('Bitte einen anderen Unterrichtstag wählen.');
  }
  if (lessonFlowPupil(source) != lessonFlowPupil(target)) {
    throw const DomainError(
      'Offene Phasen müssen beim selben Schüler bleiben.',
    );
  }
  final pending = lessonPhases(source).where((p) => p.pending).toList();
  if (pending.isEmpty) {
    throw const DomainError('Keine offenen Phasen vorhanden.');
  }
  return [
    withLessonPhases(source, [
      for (final p in lessonPhases(source))
        if (p.pending)
          p.pause(now).patch({
            'status': 'skipped',
            'carriedTo': target.text('date'),
          })
        else
          p,
    ]),
    withLessonPhases(target, [
      ...lessonPhases(target),
      ...pending.map((p) => p.fresh()),
    ]),
  ];
}
