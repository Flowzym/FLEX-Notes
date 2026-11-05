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
      if (draft.type != 'classroom' || draft.ownerId != value.id) {
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
      if (draft.type != 'classroom' ||
          !values.any((d) => d.id == draft.ownerId)) {
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
    final orga = (await entries()).map((e) => e.id).toSet();
    for (final d in docs) {
      if (!materials.containsAll(d.strings('materialIds')) ||
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
