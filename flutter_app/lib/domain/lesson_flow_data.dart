import 'models.dart';

/// Day-specific progress. Templates contain only open, unstarted phases.
class LessonPhase {
  const LessonPhase({
    required this.id,
    required this.title,
    this.body = '',
    this.minutes = 0,
    this.kind = 'work',
    this.status = 'open',
    this.materialIds = const [],
    this.pupilIds = const [],
    this.elapsed = 0,
    this.startedAt = '',
    this.carriedTo = '',
    this.guidance = const [],
    this.resumeNote = '',
  });
  final String id, title, body, kind, status, startedAt, carriedTo, resumeNote;
  final List<Json> guidance;
  final int minutes, elapsed;
  final List<String> materialIds, pupilIds;
  bool get running => startedAt.isNotEmpty;
  bool get pending => status == 'open' || status == 'active';
  int elapsedAt(DateTime now) =>
      elapsed +
      (running
          ? now
                .toUtc()
                .difference(DateTime.parse(startedAt))
                .inSeconds
                .clamp(0, 31536000)
          : 0);
  Json toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'minutes': minutes,
    'kind': kind,
    'status': status,
    'materialIds': materialIds,
    'pupilIds': pupilIds,
    if (guidance.isNotEmpty) 'guidance': guidance,
    'elapsed': elapsed,
    'startedAt': startedAt,
    'carriedTo': carriedTo,
    if (resumeNote.isNotEmpty) 'resumeNote': resumeNote,
  };
  factory LessonPhase.fromJson(Json j) {
    const keys = {
      'id',
      'title',
      'body',
      'minutes',
      'kind',
      'status',
      'materialIds',
      'pupilIds',
      'elapsed',
      'startedAt',
      'carriedTo',
      'resumeNote',
      'guidance',
    };
    if ((j.containsKey('resumeNote') && j['resumeNote'] is! String) ||
        j.keys.any((k) => !keys.contains(k)) ||
        [
          'id',
          'title',
          'body',
          'kind',
          'status',
          'startedAt',
          'carriedTo',
        ].any((k) => j[k] is! String) ||
        j['minutes'] is! int ||
        j['elapsed'] is! int ||
        ['materialIds', 'pupilIds'].any(
          (k) =>
              j[k] is! List ||
              (j[k] as List).any(
                (v) => v is! String || v.isEmpty || v.length > 250,
              ) ||
              (j[k] as List).length > 5000 ||
              (j[k] as List).toSet().length != (j[k] as List).length,
        )) {
      throw const DomainError('Ungültige Unterrichtsphase.');
    }
    final aids = j['guidance'] ?? [];
    if (aids is! List ||
        aids.length > 500 ||
        aids.any(
          (r) =>
              r is! Map ||
              r.keys.any(
                (k) =>
                    !{'pupilIds', 'materialIds', 'body', 'minutes'}.contains(k),
              ) ||
              r['body'] is! String ||
              (r['body'] as String).length > 12000 ||
              r['minutes'] is! int ||
              (r['minutes'] as int) < 0 ||
              (r['minutes'] as int) > 600 ||
              ['materialIds', 'pupilIds'].any(
                (k) =>
                    r[k] is! List ||
                    (r[k] as List).length > 500 ||
                    (r[k] as List).any(
                      (i) => i is! String || i.isEmpty || i.length > 250,
                    ),
              ),
        )) {
      throw const DomainError('Ungültige individuelle Unterrichtshilfe.');
    }
    final p = LessonPhase(
      guidance: [for (final r in aids) Json.from(r as Map)],
      id: j['id'],
      title: j['title'],
      body: j['body'],
      minutes: j['minutes'],
      kind: j['kind'],
      status: j['status'],
      materialIds: List<String>.from(j['materialIds']),
      pupilIds: List<String>.from(j['pupilIds']),
      elapsed: j['elapsed'],
      startedAt: j['startedAt'],
      carriedTo: j['carriedTo'],
      resumeNote: j['resumeNote'] as String? ?? '',
    );
    if (p.id.isEmpty ||
        p.id.length > 250 ||
        p.title.trim().isEmpty ||
        p.title.length > 160 ||
        p.body.length > 12000 ||
        p.resumeNote.length > 300 ||
        p.minutes < 0 ||
        p.minutes > 600 ||
        p.elapsed < 0 ||
        p.elapsed > 31536000 ||
        !['work', 'homework'].contains(p.kind) ||
        !['open', 'active', 'done', 'skipped'].contains(p.status) ||
        p.running &&
            (p.status != 'active' ||
                !p.startedAt.endsWith('Z') ||
                DateTime.tryParse(p.startedAt) == null) ||
        p.carriedTo.isNotEmpty && !validDate(p.carriedTo)) {
      throw const DomainError('Bitte Titel, Dauer und Stand der Phase prüfen.');
    }
    return p;
  }
  LessonPhase patch(Json changes) =>
      LessonPhase.fromJson({...toJson(), ...changes});
  LessonPhase pause(DateTime now) =>
      patch({'elapsed': elapsedAt(now), 'startedAt': ''});
  LessonPhase fresh() => patch({
    'id': newId(),
    'status': 'open',
    'elapsed': 0,
    'startedAt': '',
    'carriedTo': '',
    'resumeNote': '',
  });
}

void validateLessonFlow(Json data) {
  if (data.keys.any(
        (k) => !{
          'template',
          'lessonTarget',
          'phases',
          'pupilId',
          'sourceId',
          'sourceVersion',
          'sourceBase',
        }.contains(k),
      ) ||
      (data.containsKey('pupilId') &&
          (data['pupilId'] is! String ||
              (data['pupilId'] as String).length > 250)) ||
      ['sourceId', 'sourceVersion'].any(
        (k) =>
            data.containsKey(k) &&
            (data[k] is! String || (data[k] as String).length > 250),
      ) ||
      data.containsKey('sourceBase') &&
          (data['sourceBase'] is! Map ||
              (data['sourceBase'] as Map).length > 80 ||
              (data['sourceBase'] as Map).entries.any(
                (e) =>
                    e.key is! String ||
                    (e.key as String).length > 250 ||
                    e.value is! String ||
                    (e.value as String).length > 80,
              )) ||
      data['template'] is! bool ||
      data['lessonTarget'] is! String ||
      (data['lessonTarget'] as String).length > 300 ||
      data['phases'] is! List ||
      (data['phases'] as List).length > 80 ||
      (data['phases'] as List).any((p) => p is! Map)) {
    throw const DomainError('Ungültiger Unterrichtsablauf.');
  }
  final phases = (data['phases'] as List)
      .map((p) => LessonPhase.fromJson(Json.from(p as Map)))
      .toList();
  if (phases.map((p) => p.id).toSet().length != phases.length ||
      phases.where((p) => p.status == 'active').length > 1 ||
      data['template'] == true &&
          (data['lessonTarget'] != '' ||
              (data['pupilId'] ?? '') != '' ||
              phases.any(
                (p) =>
                    p.status != 'open' ||
                    p.elapsed != 0 ||
                    p.running ||
                    p.carriedTo.isNotEmpty ||
                    p.resumeNote.isNotEmpty,
              ))) {
    throw const DomainError(
      'Ein Ablauf darf nur eine aktuelle Phase haben. Vorlagen enthalten keinen Fortschritt.',
    );
  }
}
