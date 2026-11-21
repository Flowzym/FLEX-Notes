import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'teaching_sheet.dart';
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
  Iterable<Pupil> pupils = const [],
  ClassroomDocument? chosenSource,
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
            lessonFlowFor(
              docs,
              date,
              lesson: lesson,
              lessonTarget: target,
              pupils: pupils,
            );
  final candidates = shared == null
      ? dayCandidates(docs, date, lesson)
      : const <ClassroomDocument>[];
  final simultaneous =
      lesson != null &&
      lessonOccurrences(docs, date, date).any(
        (l) =>
            l.document.isTeachingLesson &&
            l.target != lesson.target &&
            l.start.compareTo(lesson.end) < 0 &&
            l.end.compareTo(lesson.start) > 0,
      );
  final source =
      chosenSource ??
      (!simultaneous && candidates.length == 1 ? candidates.single : null);
  final imported = source == null
      ? null
      : buildTeachingFlow(
          source,
          docs,
          pupils,
          lesson: lesson,
          explicit: chosenSource != null,
        );
  final personal = shared == null
      ? null
      : [
          for (final phase in lessonPhases(shared))
            if (phase.pupilIds.isEmpty || phase.pupilIds.contains(pupilId))
              individualTeachingPhase(phase, pupilId),
        ];
  final parentSourceId = shared?.map('flow')['sourceId'];
  final parentSource = parentSourceId == null
      ? null
      : docs.where((d) => d.id == parentSourceId).firstOrNull;
  return ClassroomDocument.create(
    ClassroomKind.plan,
    shared?.title ?? lesson?.title ?? source?.title ?? 'FLEX-Klasse',
    {
      'date': date,
      'status': 'planned',
      'flow': {
        'template': false,
        'lessonTarget': target,
        if (pupilId.isNotEmpty) 'pupilId': pupilId,
        if (imported != null) ...teachingFlowOrigin(imported),
        if (parentSource != null && personal != null)
          ...teachingFlowOrigin(
            ImportedTeachingFlow(parentSource, personal, {}),
          ),
        'phases': personal != null
            ? personal.map((p) => p.toJson()).toList()
            : imported?.phases.map((p) => p.toJson()).toList() ??
                  (candidates.isNotEmpty
                      ? <Json>[]
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
                        ]),
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
        'phases': lessonPhases(
          source,
        ).map((p) => p.fresh().patch({'guidance': <Json>[]}).toJson()).toList(),
      },
    });

/// Atomic caller saves both documents. The source retains its history and destination.
List<ClassroomDocument> carryLessonPhases(
  ClassroomDocument source,
  ClassroomDocument target,
  DateTime now, {
  String? phaseId,
  String? resumeNote,
}) {
  if (source.id == target.id || source.text('date') == target.text('date')) {
    throw const DomainError('Bitte einen anderen Unterrichtstag wählen.');
  }
  if (lessonFlowPupil(source) != lessonFlowPupil(target)) {
    throw const DomainError(
      'Offene Phasen müssen beim selben Schüler bleiben.',
    );
  }
  if (phaseId != null &&
      (lessonFlowPupil(source).isEmpty ||
          target.text('date').compareTo(source.text('date')) <= 0)) {
    throw const DomainError(
      'Bitte einen späteren Unterrichtstag für diesen Schüler wählen.',
    );
  }
  bool selected(LessonPhase p) =>
      p.pending && (phaseId == null || p.id == phaseId);
  final pending = lessonPhases(source).where(selected).toList();
  if (pending.isEmpty) {
    throw const DomainError('Keine offenen Phasen vorhanden.');
  }
  return [
    withLessonPhases(source, [
      for (final p in lessonPhases(source))
        if (selected(p))
          p.pause(now).patch({
            'status': 'skipped',
            'carriedTo': target.text('date'),
            if (resumeNote != null) 'resumeNote': resumeNote.trim(),
          })
        else
          p,
    ]),
    withLessonPhases(target, [
      if (phaseId == null) ...lessonPhases(target),
      for (final p in pending)
        p.fresh().patch({'resumeNote': resumeNote?.trim() ?? p.resumeNote}),
      if (phaseId != null) ...lessonPhases(target),
    ]),
  ];
}

String _phaseSignature(LessonPhase p) => sheetHash(
  jsonEncode([
    p.title,
    p.body,
    p.minutes,
    p.kind,
    p.materialIds,
    p.pupilIds,
    p.guidance,
  ]),
);
String teachingFlowVersion(ImportedTeachingFlow f) => sheetHash(
  jsonEncode([
    teachingVersion(f.source),
    for (final p in f.phases) _phaseSignature(p),
  ]),
);
Json teachingFlowOrigin(ImportedTeachingFlow f) => {
  'sourceId': f.source.id,
  'sourceVersion': teachingFlowVersion(f),
  'sourceBase': {for (final p in f.phases) p.id: _phaseSignature(p)},
};

/// A running session is a snapshot. On explicit refresh only untouched, open
/// source phases follow the document. Local deletions, additions and timers survive.
ClassroomDocument reconcileTeachingFlow(
  ClassroomDocument current,
  ImportedTeachingFlow incoming,
) {
  final old = current.map('flow'), base = old['sourceBase'] as Map? ?? {};
  final fresh = {for (final p in incoming.phases) p.id: p},
      held = lessonPhases(current);
  bool untouched(LessonPhase p) =>
      p.status == 'open' &&
      !p.running &&
      p.elapsed == 0 &&
      base[p.id] == _phaseSignature(p);
  final next = <LessonPhase>[
    for (final p in held)
      if (!untouched(p)) p else if (fresh.containsKey(p.id)) fresh[p.id]!,
  ];
  // Follow new source ordering only if the teacher has kept the original order.
  final oldIds = held.map((p) => p.id).toSet();
  if (jsonEncode(
        held.where((p) => base.containsKey(p.id)).map((p) => p.id).toList(),
      ) ==
      jsonEncode(base.keys.where(oldIds.contains).toList())) {
    final movable = held.where(untouched).map((p) => p.id).toSet();
    final ordered = incoming.phases
        .where((p) => movable.contains(p.id))
        .iterator;
    for (var i = 0; i < next.length; i++) {
      if (movable.contains(next[i].id) && ordered.moveNext()) {
        next[i] = ordered.current;
      }
    }
  }
  for (final (index, p) in incoming.phases.indexed) {
    if (base.containsKey(p.id) || next.any((other) => other.id == p.id)) {
      continue;
    }
    final before = incoming.phases.take(index).map((p) => p.id).toSet();
    final previous = next.lastIndexWhere((p) => before.contains(p.id));
    next.insert(previous < 0 ? 0 : previous + 1, p);
  }
  if (next.length > 80) {
    throw const DomainError(
      'Bitte zuerst Phasen zusammenfassen. Ein Ablauf enthält höchstens 80 Phasen.',
    );
  }
  return withLessonPhases(
    current.patch({
      'flow': {...old, ...teachingFlowOrigin(incoming)},
    }),
    next,
  );
}
