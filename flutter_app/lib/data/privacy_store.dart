part of 'sqlite_notebook.dart';

mixin PrivacyStore on SchoolStore {
  Future<List<Pupil>> pupils();
  Future<List<OrgaEntry>> entries();
  Future<List<EditDraft>> drafts();
  Future<List<DialogDraft>> dialogDrafts();
  Future<List<ClassroomDocument>> classroomDocuments();
  Future<void> validateClassroomReferences();
  Future<ClassroomDocument> _writeClassroom(ClassroomDocument value);
  Future<String> exportBackup();
  Future<NotebookSnapshot> snapshot();
  Future<void> _purgeEntries(Set<String> ids);
  Future<OrgaEntry> saveEntry(
    OrgaEntry value, {
    String? draftId,
    int? draftRevision,
  });

  Future<void> removeUnreferencedFiles(
    Future<void> Function(String key) remove,
  ) => db.transaction(() async {
    final references = <String>{};
    for (final d in await classroomDocuments()) {
      references.addAll(materialFileKeys(d.toJson()));
    }
    for (final d in await dialogDrafts()) {
      if (d.type == 'scan') references.addAll(scanFileKeys(d.data));
      if (d.type == 'classroom') references.addAll(materialFileKeys(d.data));
    }
    for (final row in await _rows(
      "SELECT key,payload FROM preferences WHERE key LIKE 'pending-file-delete:%'",
    )) {
      final key =
          (jsonDecode(row['payload'] as String) as Map)['key'] as String;
      if (!RegExp(r'^[a-zA-Z0-9_-]{1,120}$').hasMatch(key)) {
        throw const DomainError('Ungültige Dateizuordnung.');
      }
      if (!references.contains(key)) await remove(key);
      await db.customStatement('DELETE FROM preferences WHERE key=?', [
        row['key'],
      ]);
    }
  });

  Future<void> _forgetArchivedIds(Set<String> ids) async {
    for (final year in await schoolYears()) {
      if (!{
        ...year.orgaIds,
        ...year.recordIds,
        ...year.documentIds,
      }.any(ids.contains)) {
        continue;
      }
      await _preference('school-year:${year.id}', {
        ...year.toJson(),
        'orgaIds': year.orgaIds.difference(ids).toList(),
        'recordIds': year.recordIds.difference(ids).toList(),
        'documentIds': year.documentIds.difference(ids).toList(),
      });
    }
  }

  Future<void> _preference(String key, Json data) => db.customStatement(
    'INSERT INTO preferences(key,payload) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload',
    [key, jsonEncode(data)],
  );

  Future<List<SchoolYearArchive>> schoolYears() async =>
      (await _rows(
        "SELECT key,payload FROM preferences WHERE key LIKE 'school-year:%' ORDER BY key",
      )).map((row) {
        final year = SchoolYearArchive.fromJson(
          Json.from(jsonDecode(row['payload'] as String) as Map),
        );
        if (row['key'] != 'school-year:${year.id}') {
          throw const DomainError(
            'Das Schuljahresarchiv konnte nicht zugeordnet werden.',
          );
        }
        return year;
      }).toList();

  Future<void> validateYearReferences() async {
    final years = await schoolYears();
    final orga = (await entries()).map((e) => e.id).toSet();
    final records = (await schoolRecords()).map((e) => e.id).toSet();
    final documents = (await classroomDocuments()).map((e) => e.id).toSet();
    final used = <String>{};
    for (final year in years) {
      if (year.orgaIds.difference(orga).isNotEmpty ||
          year.recordIds.difference(records).isNotEmpty ||
          year.documentIds.difference(documents).isNotEmpty) {
        throw const DomainError(
          'Im Schuljahresarchiv fehlen Einträge. Bitte beim Zusammenführen alle zugehörigen Einträge übernehmen.',
        );
      }
      for (final id in [
        ...year.orgaIds,
        ...year.recordIds,
        ...year.documentIds,
      ]) {
        if (!used.add(id)) {
          throw const DomainError(
            'Ein Eintrag ist mehreren Schuljahresarchiven zugeordnet. Bitte den Import prüfen.',
          );
        }
      }
    }
  }

  Future<void> _assertCaptured(String text) async {
    final captured = jsonDecode(text) as Map;
    final current = jsonDecode(await exportBackup()) as Map;
    if (canonical(captured['tables']) != canonical(current['tables'])) {
      throw const DomainError(
        'Die Daten wurden seit der Sicherung geändert. Bitte zuerst eine neue Sicherung erstellen.',
      );
    }
  }

  Future<void> archiveSchoolYear(
    SchoolYearArchive archive,
    String capturedBackup,
  ) => db.transaction(() async {
    SchoolYearArchive.fromJson(archive.toJson());
    await _assertCaptured(capturedBackup);
    final previous = await schoolYears();
    if (previous.any(
      (y) =>
          archive.from.compareTo(y.to) <= 0 &&
          archive.to.compareTo(y.from) >= 0,
    )) {
      throw const DomainError(
        'Dieser Zeitraum ist bereits archiviert. Bitte das betreffende Schuljahr zuerst wieder öffnen.',
      );
    }
    final allowed = SchoolYearArchive.preview(
      await snapshot(),
      title: archive.title,
      from: archive.from,
      to: archive.to,
      keepOpen: false,
    );
    if (archive.orgaIds.difference(allowed.orgaIds).isNotEmpty ||
        archive.recordIds.difference(allowed.recordIds).isNotEmpty ||
        archive.documentIds.difference(allowed.documentIds).isNotEmpty) {
      throw const DomainError(
        'Die Auswahl hat sich geändert. Bitte den Schuljahresabschluss neu öffnen.',
      );
    }
    if (archive.count == 0) {
      throw const DomainError(
        'In diesem Zeitraum sind keine passenden Einträge vorhanden.',
      );
    }
    final draftData = [
      ...(await drafts()).map((d) => jsonEncode(d.entry.toJson())),
      ...(await schoolDrafts()).map((d) => jsonEncode(d.record.toJson())),
      ...(await dialogDrafts()).map((d) => jsonEncode(d.toJson())),
    ];
    final ids = {
      ...archive.orgaIds,
      ...archive.recordIds,
      ...archive.documentIds,
    };
    if (draftData.any((s) => ids.any((id) => s.contains(jsonEncode(id))))) {
      throw const DomainError(
        'Zu diesen Einträgen sind noch Entwürfe offen. Bitte diese vor dem Archivieren speichern oder verwerfen.',
      );
    }
    await _preference('school-year:${archive.id}', archive.toJson());
  });

  Future<void> reopenSchoolYear(String id) async {
    if (!(await schoolYears()).any((y) => y.id == id)) {
      throw const DomainError('Das Schuljahresarchiv wurde bereits entfernt.');
    }
    await db.customStatement('DELETE FROM preferences WHERE key=?', [
      'school-year:$id',
    ]);
  }

  Future<RetentionPolicy> retentionPolicy() async {
    final rows = await _rows(
      "SELECT payload FROM preferences WHERE key='retention-policy'",
    );
    return rows.isEmpty
        ? const RetentionPolicy()
        : RetentionPolicy.fromJson(
            Json.from(jsonDecode(rows.single['payload'] as String) as Map),
          );
  }

  Future<void> saveRetentionPolicy(RetentionPolicy policy) => _preference(
    'retention-policy',
    RetentionPolicy.fromJson(policy.toJson()).toJson(),
  );

  Future<List<RetentionCandidate>> retentionReview(DateTime now) async {
    final policy = await retentionPolicy(), result = <RetentionCandidate>[];
    bool expired(String? stamp, int days) =>
        days > 0 &&
        stamp != null &&
        DateTime.tryParse(stamp) != null &&
        !DateTime.parse(
          stamp,
        ).toUtc().add(Duration(days: days)).isAfter(now.toUtc());
    for (final y in await schoolYears()) {
      if (y.reviewOn != null && y.reviewOn!.compareTo(dateOnly(now)) <= 0) {
        result.add(
          RetentionCandidate(
            'year',
            y.id,
            y.title,
            y.reviewOn!,
            count: y.count,
          ),
        );
      }
    }
    for (final row in await _rows(
      'SELECT id,captured_at_utc FROM legacy_backups',
    )) {
      final stamp = row['captured_at_utc'] as String;
      if (expired(stamp, policy.importDays)) {
        result.add(
          RetentionCandidate(
            'legacy',
            row['id'] as String,
            'Ältere HTML-Importkopie',
            stamp,
          ),
        );
      }
    }
    for (final row in await _rows(
      "SELECT key,payload FROM preferences WHERE key LIKE 'import-archive-%'",
    )) {
      final stamp =
          (jsonDecode(row['payload'] as String) as Map)['importedAt']
              as String?;
      if (expired(stamp, policy.importDays)) {
        result.add(
          RetentionCandidate(
            'import',
            row['key'] as String,
            'Importkopie einer Sicherung',
            stamp!,
          ),
        );
      }
    }
    for (final p in await pupils()) {
      if (p.deleted && expired(p.deletedAtUtc, policy.trashDays)) {
        result.add(RetentionCandidate('pupil', p.id, p.name, p.deletedAtUtc!));
      }
    }
    for (final e in await entries()) {
      if (e.deleted && expired(e.updatedAtUtc, policy.trashDays)) {
        result.add(RetentionCandidate('orga', e.id, e.title, e.updatedAtUtc));
      }
    }
    // School records do not invent modification timestamps: the audit is the source.
    for (final r in (await schoolRecords()).where((r) => r.deleted)) {
      final rows = await _rows(
        "SELECT MAX(captured_at_utc) AS stamp FROM revisions WHERE entity_kind='school' AND entity_id=?",
        [r.id],
      );
      final stamp = rows.single['stamp'] as String?;
      if (expired(stamp, policy.trashDays)) {
        result.add(
          RetentionCandidate(
            'school',
            r.id,
            r.title.isEmpty ? r.kind.label : r.title,
            stamp!,
          ),
        );
      }
    }
    return result;
  }

  Future<void> _eraseHistory(Set<String> ids) async {
    if (ids.isEmpty) return;
    final revisions = await _rows(
      'SELECT id,entity_id,before_payload,after_payload FROM revisions',
    );
    for (final row in revisions) {
      if (!ids.contains(row['entity_id']) &&
          !ids.any(
            (id) =>
                (row['before_payload'] as String? ?? '').contains(
                  jsonEncode(id),
                ) ||
                (row['after_payload'] as String).contains(jsonEncode(id)),
          )) {
        continue;
      }
      await db.customStatement(
        'DELETE FROM outbox WHERE operation_id IN (SELECT id FROM operations WHERE revision_id=?)',
        [row['id']],
      );
      await db.customStatement('DELETE FROM operations WHERE revision_id=?', [
        row['id'],
      ]);
      await db.customStatement('DELETE FROM revisions WHERE id=?', [row['id']]);
    }
  }

  Json _cleanDocumentReferences(
    Json data, {
    Set<String> documents = const {},
    Set<String> people = const {},
  }) {
    Object? clean(Object? value, [String key = '']) {
      if (value is Map) {
        return {
          for (final e in value.entries) e.key: clean(e.value, e.key as String),
        };
      }
      if (value is List) {
        if ({'materialIds', 'planIds', 'lessonIds'}.contains(key)) {
          return value.where((v) => !documents.contains(v)).toList();
        }
        if ({
          'pupilIds',
          'planningDecisions',
          'planningDeferred',
          'planningAutoDates',
        }.contains(key)) {
          return value.where((v) => !people.contains(v)).toList();
        }
        if (key == 'links') {
          return value
              .where((v) => !documents.contains((v as Map)['id']))
              .map((v) => clean(v))
              .toList();
        }
        if (key == 'pupilDates' || key == 'participants') {
          return value
              .where((v) => !people.contains((v as Map)['pupilId']))
              .map((v) => clean(v))
              .toList();
        }
        return value.map((v) => clean(v)).toList();
      }
      if (key == 'lessonTarget' &&
          value is String &&
          documents.any((id) => value.startsWith('lesson:$id:'))) {
        return '';
      }
      return value;
    }

    return Json.from(clean(data) as Map);
  }

  Future<void> _eraseDocuments(Set<String> ids) async {
    if (ids.isEmpty) return;
    for (final d in await classroomDocuments()) {
      if (ids.contains(d.id)) {
        if (d.kind == ClassroomKind.material) {
          for (final key in materialFileKeys(d.toJson())) {
            await _preference('pending-file-delete:$key', {
              'key': key,
              'queuedAtUtc': utcNow(),
            });
          }
        }
        await db.customStatement('DELETE FROM preferences WHERE key=?', [
          'classroom:${d.id}',
        ]);
      } else {
        final cleaned = _cleanDocumentReferences(d.toJson(), documents: ids);
        if (canonical(cleaned) != canonical(d.toJson())) {
          await _writeClassroom(ClassroomDocument.fromJson(cleaned));
        }
      }
    }
    await _eraseHistory(ids);
    await _forgetArchivedIds(ids);
  }

  Future<void> _markAndPurge(Set<String> ids) async {
    for (final e in await entries()) {
      if (ids.contains(e.id) && !e.deleted) {
        await saveEntry(
          e.copyWith(
            deleted: true,
            reminderState: e.reminderState == ReminderState.planned
                ? ReminderState.cancelled
                : e.reminderState,
          ),
        );
      }
    }
    for (final r in await schoolRecords()) {
      if (ids.contains(r.id) && !r.deleted) {
        await saveSchoolRecord(r.patch({'deleted': true}));
      }
    }
    await _purgeEntries(ids);
    await _eraseHistory(ids);
  }

  Future<void> _purgeDeletedPupils(Set<String> ids) async {
    if (ids.isEmpty) return;
    final all = await pupils();
    if (ids.any((id) => !all.any((p) => p.id == id && p.deleted))) {
      throw const DomainError('Die Schülerauswahl hat sich geändert.');
    }
    final draftData = [
      ...(await drafts()).map((d) => jsonEncode(d.entry.toJson())),
      ...(await schoolDrafts()).map((d) => jsonEncode(d.record.toJson())),
      ...(await dialogDrafts()).map((d) => jsonEncode(d.toJson())),
    ];
    if (draftData.any((s) => ids.any((id) => s.contains(jsonEncode(id))))) {
      throw const DomainError(
        'Zu gelöschten Schülern sind noch Entwürfe vorhanden. Bitte diese zuerst speichern oder verwerfen.',
      );
    }
    final owned = {
      ...(await entries())
          .where((e) => ids.contains(e.pupilId))
          .map((e) => e.id),
      ...(await schoolRecords())
          .where((r) => ids.contains(r.pupilId))
          .map((r) => r.id),
    };
    final documents = await classroomDocuments(), removeDocuments = <String>{};
    for (final d in documents) {
      if (d.kind == ClassroomKind.repeat && owned.contains(d.text('entryId'))) {
        removeDocuments.add(d.id);
        continue;
      }
      if (ids.contains(d.map('flow')['pupilId'])) {
        removeDocuments.add(d.id);
        continue;
      }
      final assigned = d.strings('pupilIds');
      final onlyThese = assigned.isNotEmpty && assigned.every(ids.contains);
      final shared = documents.any(
        (other) =>
            other.id != d.id &&
            jsonEncode(other.toJson()).contains(jsonEncode(d.id)),
      );
      if (d.kind == ClassroomKind.material &&
          onlyThese &&
          !shared &&
          d.rows('links').every((l) => owned.contains(l['id']))) {
        removeDocuments.add(d.id);
        continue;
      }
      final fields = <String, dynamic>{};
      if (d.kind == ClassroomKind.materialProfile && onlyThese) {
        fields.addAll({'code': '', 'aliases': <String>[]});
      }
      if (d.kind == ClassroomKind.material) {
        for (final key in [
          'planningDecisions',
          'planningAutoDates',
          'planningDeferred',
        ]) {
          if (d.strings(key).any(ids.contains)) {
            fields[key] = d
                .strings(key)
                .where((id) => !ids.contains(id))
                .toList();
          }
        }
      }
      if (assigned.any(ids.contains)) {
        fields['pupilIds'] = assigned.where((id) => !ids.contains(id)).toList();
      }
      if (d.kind == ClassroomKind.returnList &&
          d.rows('participants').any((p) => ids.contains(p['pupilId']))) {
        final remaining = d
            .rows('participants')
            .where((p) => !ids.contains(p['pupilId']))
            .toList();
        if (remaining.isEmpty) {
          removeDocuments.add(d.id);
          continue;
        }
        fields['participants'] = remaining;
      }
      final cleaned = _cleanDocumentReferences(
        d.patch(fields).toJson(),
        people: ids,
      );
      if (canonical(cleaned) != canonical(d.toJson())) {
        await _writeClassroom(ClassroomDocument.fromJson(cleaned));
      }
    }
    for (final r in await schoolRecords()) {
      if (!owned.contains(r.id) && r.participantIds.any(ids.contains)) {
        await saveSchoolRecord(
          r.patch({
            'participantIds': r.participantIds
                .where((id) => !ids.contains(id))
                .toList(),
          }),
        );
      }
    }
    await _markAndPurge(owned);
    await _eraseDocuments(removeDocuments);
    await _eraseHistory(ids);
    // Old imported snapshots can contain the same personal data. Active records
    // from those imports are retained; only the redundant source copy is erased.
    final tokens = {
      ...ids,
      ...all.where((p) => ids.contains(p.id)).map((p) => p.name),
    };
    bool containsPerson(dynamic value, [int depth = 0]) {
      if (depth > 40) return false;
      if (value is Map) {
        return value.values.any((v) => containsPerson(v, depth + 1));
      }
      if (value is List) return value.any((v) => containsPerson(v, depth + 1));
      if (value is! String) return false;
      if (tokens.contains(value)) return true;
      if (value.startsWith('{') || value.startsWith('[')) {
        try {
          return containsPerson(jsonDecode(value), depth + 1);
        } on FormatException {
          return false;
        }
      }
      return false;
    }

    for (final row in await _rows(
      'SELECT id,original_json FROM legacy_backups',
    )) {
      if (containsPerson(row['original_json'])) {
        await db.customStatement('DELETE FROM legacy_backups WHERE id=?', [
          row['id'],
        ]);
      }
    }
    for (final row in await _rows(
      "SELECT key,payload FROM preferences WHERE key LIKE 'import-archive-%'",
    )) {
      if (containsPerson(row['payload'])) {
        await db.customStatement('DELETE FROM preferences WHERE key=?', [
          row['key'],
        ]);
      }
    }
    for (final year in await schoolYears()) {
      await _preference('school-year:${year.id}', {
        ...year.toJson(),
        'orgaIds': year.orgaIds.difference(owned).toList(),
        'recordIds': year.recordIds.difference(owned).toList(),
        'documentIds': year.documentIds.difference(removeDocuments).toList(),
      });
    }
    for (final id in ids) {
      await db.customStatement(
        'DELETE FROM situation_pupils WHERE pupil_id=?',
        [id],
      );
      await db.customStatement('DELETE FROM pupils WHERE id=?', [id]);
    }
  }

  Future<void> purgeRetained(
    Set<String> keys,
    String capturedBackup, {
    DateTime? now,
  }) => db.transaction(() async {
    await _assertCaptured(capturedBackup);
    final candidates = {
      for (final c in await retentionReview(now ?? DateTime.now())) c.key: c,
    };
    if (keys.isEmpty || keys.any((key) => !candidates.containsKey(key))) {
      throw const DomainError(
        'Die Auswahl zur Löschprüfung hat sich geändert.',
      );
    }
    final entityIds = <String>{}, pupilIds = <String>{}, documents = <String>{};
    for (final key in keys) {
      final c = candidates[key]!;
      switch (c.kind) {
        case 'legacy':
          await db.customStatement('DELETE FROM legacy_backups WHERE id=?', [
            c.id,
          ]);
        case 'import':
          await db.customStatement('DELETE FROM preferences WHERE key=?', [
            c.id,
          ]);
        case 'year':
          final year = (await schoolYears()).firstWhere((y) => y.id == c.id);
          entityIds.addAll({...year.orgaIds, ...year.recordIds});
          documents.addAll(year.documentIds);
          await db.customStatement('DELETE FROM preferences WHERE key=?', [
            'school-year:${c.id}',
          ]);
        case 'pupil':
          pupilIds.add(c.id);
        case 'orga':
        case 'school':
          entityIds.add(c.id);
      }
    }
    final series = (await classroomDocuments()).where(
      (d) => d.kind == ClassroomKind.repeat,
    );
    final entriesById = {for (final e in await entries()) e.id: e};
    for (final d in series) {
      final source = d.text('entryId');
      final referenced = {
        source,
        for (final date in d.map('generated').keys)
          if (date.compareTo(dateOnly(now ?? DateTime.now())) >= 0)
            const Uuid().v5(Namespace.url.value, '${d.id}:$date'),
      };
      if (!referenced.any(entityIds.contains) ||
          pupilIds.contains(entriesById[source]?.pupilId)) {
        continue;
      }
      if (!d.deleted && !d.flag('stopped')) {
        throw const DomainError(
          'Eine ausgewählte Aufgabe gehört noch zu einer Wiederholung. Bitte diese Wiederholung zuerst beenden.',
        );
      }
      if (entityIds.contains(source)) documents.add(d.id);
    }
    final allDocuments = await classroomDocuments();
    for (final d in allDocuments.where(
      (d) => d.kind == ClassroomKind.material,
    )) {
      final links = d.rows('links');
      if (links.isNotEmpty &&
          links.every((l) => entityIds.contains(l['id'])) &&
          !allDocuments.any(
            (other) =>
                other.id != d.id &&
                !documents.contains(other.id) &&
                jsonEncode(other.toJson()).contains(jsonEncode(d.id)),
          )) {
        documents.add(d.id);
      }
    }
    await _markAndPurge(entityIds);
    await _eraseDocuments(documents);
    await _purgeDeletedPupils(pupilIds);
    await validateClassroomReferences();
    if ((await _rows('PRAGMA foreign_key_check')).isNotEmpty) {
      throw const DomainError(
        'Die Löschung würde ungültige Verweise hinterlassen. Es wurde nichts entfernt.',
      );
    }
  });
}
