import 'package:uuid/uuid.dart';
import 'classroom.dart';
import 'models.dart';
import 'document_scanner.dart';

List<String> pupilMaterialDates(ClassroomDocument material, String pupilId) =>
    (material
        .rows('pupilDates')
        .where((row) => row['pupilId'] == pupilId)
        .map((row) => row['date'] as String)
        .toList()
      ..sort());

/// Assign without duplicating the file or changing another pupil's schedule.
ClassroomDocument planPupilMaterial(
  ClassroomDocument material,
  String pupilId,
  String date, {
  String? replaceDate,
}) {
  final dates = [
    for (final row in material.rows('pupilDates'))
      if (!(row['pupilId'] == pupilId &&
          (row['date'] == replaceDate || row['date'] == date)))
        row,
    {'pupilId': pupilId, 'date': date},
  ];
  return material.patch({
    'pupilIds': {...material.strings('pupilIds'), pupilId}.toList(),
    'pupilDates': dates,
  });
}

List<ClassroomDocument> pupilMaterialsOnDay(
  Iterable<ClassroomDocument> docs,
  String date,
) => docs
    .where(
      (d) =>
          !d.deleted &&
          d.kind == ClassroomKind.material &&
          d.rows('pupilDates').any((row) => row['date'] == date),
    )
    .toList();

String preparationId(String date) =>
    const Uuid().v5(Namespace.url.value, 'flex-preparation:$date');

ClassroomDocument preparationFor(
  Iterable<ClassroomDocument> docs,
  String date,
) {
  schoolDay(date);
  return docs.where((d) => d.id == preparationId(date)).firstOrNull ??
      ClassroomDocument.create(ClassroomKind.preparation, 'Bereitgelegt', {
        'date': date,
        'materialIds': <String>[],
      }, id: preparationId(date));
}

/// Ordered references: preparing a package never copies or mutates its files.
ClassroomDocument prepareMaterials(
  Iterable<ClassroomDocument> docs,
  String date,
  Iterable<String> ids,
) {
  final current = preparationFor(docs, date);
  return current.patch({
    'deleted': false,
    'materialIds': {...current.strings('materialIds'), ...ids}.toList(),
  });
}

List<ClassroomDocument> resolveMaterials(
  Iterable<ClassroomDocument> docs,
  Iterable<String> ids,
) {
  final byId = {
    for (final d in docs)
      if (!d.deleted && d.kind == ClassroomKind.material) d.id: d,
  };
  return [
    for (final id in ids)
      if (byId[id] != null) byId[id]!,
  ];
}

bool planOnDay(ClassroomDocument plan, String date, {String? lessonId}) {
  if (plan.deleted || plan.kind != ClassroomKind.plan) return false;
  final dated = plan.text('date').isNotEmpty;
  final inPeriod =
      dated &&
      date.compareTo(plan.text('date')) >= 0 &&
      date.compareTo(
            plan.text('endDate').isEmpty
                ? plan.text('date')
                : plan.text('endDate'),
          ) <=
          0;
  if (lessonId != null) {
    return plan.strings('lessonIds').contains(lessonId) && (!dated || inPeriod);
  }
  return inPeriod;
}

List<ClassroomDocument> suggestedMaterials(
  Iterable<ClassroomDocument> docs,
  String date,
) {
  final lessons = lessonOccurrences(docs, date, date);
  final day = schoolDay(date);
  final monday = day.subtract(Duration(days: day.weekday - 1));
  final ids = <String>{
    ...pupilMaterialsOnDay(docs, date).map((m) => m.id),
    for (final l in lessons) ...l.materialIds,
    for (final l in lessons)
      ...linkedMaterials(docs, l.document.id, date: l.date).map((d) => d.id),
    for (final l in lessons)
      for (final p in lessonPlans(docs, l)) ...p.strings('materialIds'),
    for (final l in lessons)
      for (final p in lessonPlans(docs, l))
        ...linkedMaterials(docs, p.id).map((d) => d.id),
    for (final p in docs.where(
      (p) => p.strings('lessonIds').isEmpty && planOnDay(p, date),
    ))
      ...p.strings('materialIds'),
    for (final p in docs.where(
      (p) => p.strings('lessonIds').isEmpty && planOnDay(p, date),
    ))
      ...linkedMaterials(docs, p.id).map((d) => d.id),
    for (final m in docs.where(
      (m) =>
          m.kind == ClassroomKind.material &&
          !m.deleted &&
          m.text('week').isNotEmpty,
    ))
      if (schoolDay(
            m.text('week'),
          ).subtract(Duration(days: schoolDay(m.text('week')).weekday - 1)) ==
          monday)
        m.id,
  };
  final selected = preparationFor(docs, date).strings('materialIds').toSet();
  return resolveMaterials(docs, ids.where((id) => !selected.contains(id)));
}

List<ClassroomDocument> lessonPlans(
  Iterable<ClassroomDocument> docs,
  LessonOccurrence lesson,
) => [
  for (final p in docs)
    if (!p.deleted &&
        p.kind == ClassroomKind.plan &&
        (lesson.exception.containsKey('planIds')
            ? lesson.planIds.contains(p.id)
            : planOnDay(p, lesson.date, lessonId: lesson.document.id)))
      p,
];

bool materialMatches(
  ClassroomDocument d,
  String query, {
  Iterable<Pupil> pupils = const [],
}) {
  final words = query.toLowerCase().trim().split(RegExp(r'\s+'));
  final haystack = [
    d.title,
    d.text('name'),
    d.text('subject'),
    d.text('topic'),
    d.text('note'),
    d.text('sourcePath'),
    ...d.strings('tags'),
    materialTypes[d.text('documentType', 'other')] ?? '',
    materialAudiences[d.text('audience', 'all')] ?? '',
    for (final p in pupils)
      if (d.strings('pupilIds').contains(p.id)) p.name,
  ].join(' ').toLowerCase();
  return words.every(haystack.contains);
}

/// Only explicit, reviewable filename hints; no hardcoded class or pupil names.
Json suggestMaterialMetadata(String name) {
  final text = name.toLowerCase();
  final type = text.contains('lösung') || text.contains('loesung')
      ? 'solution'
      : text.contains('wochenplan')
      ? 'weekPlan'
      : text.contains('lernplan')
      ? 'learningPlan'
      : text.contains('planung')
      ? 'planning'
      : text.contains('protokoll')
      ? 'protocol'
      : text.contains('eltern')
      ? 'parentInfo'
      : text.contains('vorlage')
      ? 'template'
      : text.contains('arbeitsblatt')
      ? 'worksheet'
      : 'other';
  return {
    'documentType': type,
    'audience': type == 'solution'
        ? 'teacher'
        : type == 'parentInfo'
        ? 'parents'
        : 'all',
  };
}

List<ClassroomDocument> linkedMaterials(
  Iterable<ClassroomDocument> docs,
  String id, {
  String? date,
}) => [
  for (final d in docs)
    if (!d.deleted &&
        d.kind == ClassroomKind.material &&
        d
            .rows('links')
            .map(DocumentLink.fromJson)
            .any(
              (link) =>
                  link.id == id &&
                  (link.kind == 'classroom' ||
                      link.kind == 'lesson' && link.date == date),
            ))
      d,
];
