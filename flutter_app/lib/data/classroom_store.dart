part of 'sqlite_notebook.dart';

mixin ClassroomStore on SchoolStore {
  Future<List<Pupil>> pupils();
  Future<List<OrgaEntry>> entries();
  Future<OrgaEntry> saveEntry(
    OrgaEntry entry, {
    String? draftId,
    int? draftRevision,
  });

  Future<List<ClassroomDocument>> classroomDocuments() async =>
      (await _rows(
        "SELECT key,payload FROM preferences WHERE key LIKE 'classroom:%' ORDER BY key",
      )).map((row) {
        final doc = ClassroomDocument.fromJson(
          Json.from(jsonDecode(row['payload'] as String) as Map),
        );
        if (row['key'] != 'classroom:${doc.id}') {
          throw const DomainError('Beschädigte Klassen-Zuordnung.');
        }
        return doc;
      }).toList();

  Future<ClassroomDocument> _writeClassroom(ClassroomDocument value) async {
    value.validate();
    final rows = await _rows('SELECT payload FROM preferences WHERE key=?', [
      'classroom:${value.id}',
    ]);
    final old = rows.isEmpty
        ? null
        : ClassroomDocument.fromJson(
            Json.from(jsonDecode(rows.single['payload'] as String) as Map),
          );
    if ((old?.revision ?? 0) != value.revision) throw const StaleRevision();
    if (old != null &&
        (old.kind != value.kind ||
            old.text('createdAtUtc') != value.text('createdAtUtc'))) {
      throw const DomainError(
        'Die Art eines vorhandenen Klassen-Eintrags darf nicht geändert werden.',
      );
    }
    final saved = value.patch({
      'title': value.title.trim(),
      'revision': value.revision + 1,
      'updatedAtUtc': utcNow(),
    });
    await db.customStatement(
      'INSERT INTO preferences(key,payload) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload',
      ['classroom:${saved.id}', jsonEncode(saved.toJson())],
    );
    await _audit(
      'classroom',
      saved.id,
      value.revision,
      old?.toJson(),
      saved.toJson(),
    );
    return saved;
  }

  Future<void> discardDialogDraft(String id, int revision);
  Future<ClassroomDocument> saveClassroomDocument(
    ClassroomDocument value, {
    DialogDraft? draft,
  }) => db.transaction(() async {
    if (draft != null) {
      final scan =
          draft.type == 'scan' &&
          value.kind == ClassroomKind.material &&
          (draft.ownerId == value.id ||
              draft.data['sourceId'] == value.id &&
                  draft.data['sourceRevision'] == value.revision);
      if (!scan && (draft.type != 'classroom' || draft.ownerId != value.id)) {
        throw const DomainError('Ungültiger Klassenentwurf.');
      }
      await discardDialogDraft(draft.id, draft.revision);
    }
    final saved = await _writeClassroom(value);
    await validateClassroomReferences();
    return saved;
  });

  Future<void> saveClassroomDocuments(
    List<ClassroomDocument> values, {
    DialogDraft? draft,
  }) => db.transaction(() async {
    if (draft != null) {
      final scan =
          draft.type == 'scan' &&
          values.isNotEmpty &&
          values.first.id == draft.ownerId &&
          values.every(
            (d) => d.kind == ClassroomKind.material && d.revision == 0,
          );
      if (!scan &&
          (draft.type != 'classroom' ||
              !values.any((d) => d.id == draft.ownerId))) {
        throw const DomainError('Ungültiger Klassenentwurf.');
      }
      await discardDialogDraft(draft.id, draft.revision);
    }
    for (final value in values) {
      await _writeClassroom(value);
    }
    await validateClassroomReferences();
  });

  Future<void> validateClassroomReferences() async {
    final docs = await classroomDocuments();
    final materials = docs
        .where((d) => d.kind == ClassroomKind.material)
        .map((d) => d.id)
        .toSet();
    final people = (await pupils()).map((p) => p.id).toSet();
    final lessons = docs
        .where((d) => d.kind == ClassroomKind.lesson)
        .map((d) => d.id)
        .toSet();
    final orga = (await entries()).map((e) => e.id).toSet();
    final plans = docs
        .where((d) => d.kind == ClassroomKind.plan)
        .map((d) => d.id)
        .toSet();
    final school = {for (final r in await schoolRecords()) r.id: r};
    final schoolDrafts = {
      for (final d in await this.schoolDrafts()) d.id: d.record,
    };
    final orgaDrafts = (await (this as SqliteNotebook).drafts())
        .map((d) => d.id)
        .toSet();
    final pending = await (this as SqliteNotebook).dialogDrafts();
    final bulkDrafts = {
      for (final d in pending)
        if (d.type == 'bulk') d.id: d,
    };
    final documentIds = docs.map((d) => d.id).toSet();
    bool validLink(DocumentLink link) => switch (link.kind) {
      'orga' => orga.contains(link.id),
      'school' =>
        school.containsKey(link.id) &&
            (link.taskId.isEmpty ||
                school[link.id]!.kind == SchoolKind.homework &&
                    school[link.id]!.tasks.any((t) => t.id == link.taskId)),
      'orgaDraft' => orgaDrafts.contains(link.id),
      'schoolDraft' =>
        schoolDrafts.containsKey(link.id) &&
            (link.taskId.isEmpty ||
                schoolDrafts[link.id]!.tasks.any((t) => t.id == link.taskId)),
      'bulkDraft' =>
        bulkDrafts.containsKey(link.id) &&
            (link.taskId.isEmpty ||
                (bulkDrafts[link.id]!.data['tasks'] as List? ?? []).any(
                  (t) => t['id'] == link.taskId,
                )),
      'lesson' => lessons.contains(link.id),
      _ => documentIds.contains(link.id),
    };
    for (final scan in pending.where((d) => d.type == 'scan')) {
      for (final raw in scan.data['links'] as List) {
        final link = DocumentLink.fromJson(Json.from(raw as Map));
        if (link.kind.endsWith('Draft') && !validLink(link)) {
          throw const DomainError(
            'Ein Scan verweist auf einen fehlenden Entwurf.',
          );
        }
      }
    }
    for (final d in docs) {
      for (final value in d.rows('links')) {
        final link = DocumentLink.fromJson(value);
        final valid = validLink(link);
        if (!valid) {
          throw const DomainError(
            'Eine Dokumentzuordnung fehlt. Bitte zuerst die zugehörigen Einträge wiederherstellen oder die Zuordnung ändern.',
          );
        }
      }
      if (d.text('timetableId').isNotEmpty) {
        final timetable = docs
            .where(
              (t) =>
                  t.id == d.text('timetableId') &&
                  t.kind == ClassroomKind.timetable,
            )
            .firstOrNull;
        final slots =
            timetable?.rows('slots').map((s) => s['id']).toList() ?? [];
        final selected = d.strings('slotIds');
        final first = selected.isEmpty ? -1 : slots.indexOf(selected.first);
        if (timetable == null ||
            first < 0 ||
            first + selected.length > slots.length ||
            selected.indexed.any((e) => slots[first + e.$1] != e.$2)) {
          throw const DomainError(
            'Die Unterrichtszeit gehört zu keinem gültigen Stundenplan.',
          );
        }
      }
      if (!materials.containsAll(d.strings('materialIds')) ||
          (d.map('flow')['phases'] as List? ?? []).any(
            (p) =>
                !materials.containsAll(
                  List<String>.from(p['materialIds'] as List),
                ) ||
                !people.containsAll(List<String>.from(p['pupilIds'] as List)),
          ) ||
          d
              .rows('exceptions')
              .any(
                (e) =>
                    !materials.containsAll(
                      List<String>.from(e['materialIds'] as List? ?? []),
                    ) ||
                    !plans.containsAll(
                      List<String>.from(e['planIds'] as List? ?? []),
                    ),
              ) ||
          !people.containsAll(d.strings('pupilIds')) ||
          !lessons.containsAll(d.strings('lessonIds')) ||
          d.kind == ClassroomKind.returnList &&
              !d
                  .rows('participants')
                  .every((r) => people.contains(r['pupilId'])) ||
          d.kind == ClassroomKind.repeat && !orga.contains(d.text('entryId'))) {
        throw const DomainError(
          'Der Klassen-Eintrag enthält eine ungültige Zuordnung.',
        );
      }
    }
  }

  /// The source entry is the first occurrence. Generated entries use stable IDs
  /// and separate checklist IDs; completing one never completes another.
  Future<void> configureRepeat(
    OrgaEntry entry,
    RepeatRule rule, {
    String? effectiveFrom,
  }) => db.transaction(() async {
    rule.validate();
    final docs = await classroomDocuments();
    final id = const Uuid().v5(Namespace.url.value, 'flex-repeat:${entry.id}');
    final old = docs.where((d) => d.id == id).firstOrNull;
    final current = (await entries())
        .where((e) => e.id == entry.id)
        .firstOrNull;
    if (current == null ||
        current.revision != entry.revision ||
        old == null && (current.deleted || current.done)) {
      throw const StaleRevision();
    }
    final start = entry.appointmentDate ?? entry.dueDate;
    if (start == null || !entry.isAppointment && !entry.isTask) {
      throw const DomainError(
        'Bitte zuerst Termin oder Aufgabenfälligkeit festlegen.',
      );
    }
    final from = effectiveFrom ?? dateOnly(DateTime.now());
    if (!validDate(from)) throw const DomainError('Ungültiger Serienbeginn.');
    final fields = <String, dynamic>{
      'entryId': entry.id,
      'date': start,
      'repeat': rule.toJson(),
      'template': entry.toJson(),
      'stopped': !rule.repeats,
      'generated': old?.map('generated') ?? <String, dynamic>{},
    };
    final value = old == null
        ? ClassroomDocument.create(
            ClassroomKind.repeat,
            entry.title,
            fields,
            id: id,
          )
        : old.patch({...fields, 'title': entry.title});
    final savedSeries = await _writeClassroom(value);
    await _materializeSeries(
      savedSeries,
      docs,
      DateTime.now(),
      replacingFrom: from,
    );
    await validateClassroomReferences();
  });

  String _repeatEntryId(String series, String date) =>
      const Uuid().v5(Namespace.url.value, '$series:$date');

  Future<void> materializeRepeats(DateTime now) => db.transaction(() async {
    final docs = await classroomDocuments();
    for (final series in docs.where(
      (d) => d.kind == ClassroomKind.repeat && !d.deleted,
    )) {
      await _materializeSeries(series, docs, now);
    }
  });

  Future<void> _materializeSeries(
    ClassroomDocument series,
    List<ClassroomDocument> docs,
    DateTime now, {
    String? replacingFrom,
  }) async {
    if (series.deleted) return;
    final existing = {for (final e in await entries()) e.id: e};
    final source = existing[series.text('entryId')];
    if (source == null) return;
    if (source.pupilId != null &&
        !(await pupils()).any((p) => p.id == source.pupilId && !p.archived)) {
      return;
    }
    final generated = series.map('generated');
    var changed = false;
    final template = OrgaEntry.fromJson(series.map('template'));
    final anchor = schoolDay(series.text('date'));
    // A bounded rolling year covers closed-app reminders without creating an
    // infinite database. Missed historical entries are not invented on reopen.
    final today = schoolDay(dateOnly(now));
    final first = anchor.isAfter(today) ? anchor : today;
    final until = today.add(const Duration(days: 366));
    for (
      var day = first;
      !day.isAfter(until);
      day = day.add(const Duration(days: 1))
    ) {
      final date = dateOnly(day);
      if (date == series.text('date')) continue;
      final id = _repeatEntryId(series.id, date),
          old = existing[_repeatEntryId(series.id, date)];
      final managed = old != null && old.revision == generated[date];
      final allowed =
          !series.flag('stopped') &&
          series.rule.includes(series.text('date'), date, docs);
      if (!allowed) {
        if (managed && !old.deleted && !old.done) {
          final removed = await saveEntry(
            old.copyWith(
              deleted: true,
              reminderState: old.reminderState == ReminderState.planned
                  ? ReminderState.cancelled
                  : old.reminderState,
            ),
          );
          generated[date] = removed.revision;
          changed = true;
        }
        continue;
      }
      if (old != null &&
          (!managed ||
              old.done ||
              !old.deleted &&
                  (replacingFrom == null ||
                      date.compareTo(replacingFrom) < 0))) {
        continue;
      }
      final delta = day.difference(anchor);
      String? reminder;
      if (template.reminderAtUtc != null &&
          template.reminderState == ReminderState.planned) {
        // Keep local clock time across DST, rather than adding 24 UTC hours.
        final at = DateTime.parse(template.reminderAtUtc!).toLocal();
        reminder = DateTime(
          at.year,
          at.month,
          at.day + delta.inDays,
          at.hour,
          at.minute,
        ).toUtc().toIso8601String();
      }
      final data = template.toJson();
      final candidate = OrgaEntry.fromJson({
        ...data,
        'id': id,
        'revision': old?.revision ?? 0,
        'deleted': false,
        'done': false,
        'createdAtUtc': old?.createdAtUtc ?? utcNow(),
        'updatedAtUtc': utcNow(),
        'appointmentDate': template.isAppointment ? date : null,
        'dueDate': template.isTask ? date : null,
        'reminderAtUtc': reminder,
        'reminderState': reminder == null ? 'none' : 'planned',
        'items': [
          for (final item in template.items)
            {
              'id': const Uuid().v5(Namespace.url.value, '$id:${item.id}'),
              'text': item.text,
              'checked': false,
            },
        ],
      });
      final saved = await saveEntry(candidate);
      generated[date] = saved.revision;
      changed = true;
    }
    if (changed) await _writeClassroom(series.patch({'generated': generated}));
  }
}
