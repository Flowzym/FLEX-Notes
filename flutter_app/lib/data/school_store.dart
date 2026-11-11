part of 'sqlite_notebook.dart';

mixin SchoolStore {
  NotebookDatabase get db;
  Future<List<Json>> _rows(String sql, [List<String> values = const []]);
  Future<void> _audit(
    String kind,
    String entityId,
    int base,
    Json? before,
    Json after,
  );

  SchoolRecord _record(Json row) {
    final r = SchoolRecord.fromJson(
      Json.from(jsonDecode(row['payload'] as String) as Map),
    );
    if (r.id != row['id'] ||
        r.pupilId != row['pupil_id'] ||
        r.revision != row['revision'] ||
        r.situationId != row['situation_id']) {
      throw const DomainError('Widersprüchliche Eintragsdaten.');
    }
    return r;
  }

  Future<List<SchoolRecord>> schoolRecords() async => (await _rows(
    'SELECT * FROM school_records ORDER BY id',
  )).map(_record).toList();

  Future<SchoolRecord> saveSchoolRecord(
    SchoolRecord record, {
    String? draftId,
    int? draftRevision,
  }) => db.transaction(() async {
    if (draftId != null && draftRevision != null) {
      await _checkDraftRevision(draftId, draftRevision);
    }
    record.validate();
    final previous = await _rows('SELECT * FROM school_records WHERE id=?', [
      record.id,
    ]);
    final old = previous.isEmpty ? null : _record(previous.single);
    if ((old?.revision ?? 0) != record.revision) throw const StaleRevision();
    if (old != null &&
        ((old.pupilId != record.pupilId || old.kind != record.kind) &&
                !([SchoolKind.social, SchoolKind.work].contains(old.kind) &&
                    [
                      SchoolKind.social,
                      SchoolKind.work,
                    ].contains(record.kind)) ||
            old.createdAtUtc != record.createdAtUtc)) {
      throw const DomainError(
        'Die Zuordnung eines bestehenden Eintrags darf nicht geändert werden.',
      );
    }
    final owners = await _rows('SELECT * FROM pupils WHERE id=?', [
      record.pupilId,
    ]);
    if (owners.isEmpty || old == null && owners.single['archived'] == 1) {
      throw const DomainError('Bitte einen aktiven Schüler auswählen.');
    }
    if (record.goalId != null) {
      final goals = await _rows('SELECT * FROM school_records WHERE id=?', [
        record.goalId!,
      ]);
      if (goals.isEmpty ||
          _record(goals.single).kind != SchoolKind.goal ||
          _record(goals.single).pupilId != record.pupilId) {
        throw const DomainError('Das Ziel muss zum selben Schüler gehören.');
      }
    }
    for (final id in record.participantIds) {
      if ((await _rows('SELECT id FROM pupils WHERE id=?', [id])).isEmpty) {
        throw const DomainError('Eine beteiligte Person ist nicht vorhanden.');
      }
    }
    var saved = record.patch({'revision': record.revision + 1});
    if (saved.situationId == null &&
        (saved.context.isNotEmpty ||
            saved.participantIds.isNotEmpty ||
            saved.otherParticipants.isNotEmpty)) {
      final contextId = newId();
      final payload = {
        'text': saved.context,
        'participantIds': {...saved.participantIds, saved.pupilId}.toList(),
        'otherParticipants': saved.otherParticipants,
      };
      await db.customStatement(
        'INSERT INTO situations(id,revision,payload) VALUES (?,1,?)',
        [contextId, jsonEncode(payload)],
      );
      for (final id in {...saved.participantIds, saved.pupilId}) {
        await db.customStatement(
          'INSERT INTO situation_pupils(situation_id,pupil_id) VALUES (?,?)',
          [contextId, id],
        );
      }
      await _audit('situation', contextId, 0, null, payload);
      saved = saved.patch({'situationId': contextId});
    }
    await db.customStatement(
      'INSERT INTO school_records(id,pupil_id,situation_id,revision,payload) VALUES (?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET pupil_id=excluded.pupil_id,situation_id=excluded.situation_id,revision=excluded.revision,payload=excluded.payload',
      [
        saved.id,
        saved.pupilId,
        saved.situationId,
        saved.revision,
        jsonEncode(saved.toJson()),
      ],
    );
    await _audit(
      'school',
      saved.id,
      record.revision,
      old?.toJson(),
      saved.toJson(),
    );
    if (old != null && old.kind == SchoolKind.homework) {
      final removed = old.tasks.map((t) => t.id).toSet()
        ..removeAll(saved.tasks.map((t) => t.id));
      if (removed.isNotEmpty) {
        await (this as SqliteNotebook)._retainRemovedTaskDocuments(
          saved.id,
          removed,
        );
      }
    }
    if (draftId != null) {
      await (this as SqliteNotebook)._publishSchoolAttachments(
        draftId,
        record,
        [saved],
      );
      await db.customStatement('DELETE FROM school_drafts WHERE id=?', [
        draftId,
      ]);
    }
    return saved;
  });

  Future<List<SchoolRecord>> saveSchoolGroup(
    SchoolRecord record,
    List<String> recipients,
    String requestId, {
    int? draftRevision,
  }) => db.transaction(() async {
    final existing = await _rows('SELECT * FROM group_saves WHERE id=?', [
      requestId,
    ]);
    if (existing.isNotEmpty) {
      if (existing.single['undone_at_utc'] != null) {
        throw const DomainError(
          'Diese Gruppenerfassung wurde bereits zurückgenommen.',
        );
      }
      final request = Json.from(
        jsonDecode(existing.single['request'] as String) as Map,
      );
      final result = <SchoolRecord>[];
      for (final id in List<String>.from(request['ids'] as List)) {
        result.add(
          _record(
            (await _rows('SELECT * FROM school_records WHERE id=?', [
              id,
            ])).single,
          ),
        );
      }
      return result;
    }
    if (draftRevision != null) {
      await _checkDraftRevision(requestId, draftRevision);
    }
    if (record.revision != 0 ||
        recipients.isEmpty ||
        recipients.toSet().length != recipients.length) {
      throw const DomainError('Bitte eindeutige Empfänger auswählen.');
    }
    final result = <SchoolRecord>[];
    for (final pupil in recipients) {
      final taskIds = {for (final task in record.tasks) task.id: newId()};
      final next = record.patch({
        'id': newId(),
        'pupilId': pupil,
        'situationId': null,
        'tasks': record.tasks
            .map(
              (t) => {
                ...t.toJson(),
                'id': taskIds[t.id],
                'parentId': taskIds[t.parentId],
              },
            )
            .toList(),
      });
      result.add(await saveSchoolRecord(next));
    }
    await db.customStatement(
      'INSERT INTO group_saves(id,request,saved_at_utc) VALUES (?,?,?)',
      [
        requestId,
        jsonEncode({
          'rebuildFormat': 1,
          'ids': result.map((r) => r.id).toList(),
          'records': result.map((r) => r.toJson()).toList(),
          'template': record.toJson(),
          'recipients': recipients,
        }),
        utcNow(),
      ],
    );
    await (this as SqliteNotebook)._publishSchoolAttachments(
      requestId,
      record,
      result,
    );
    await db.customStatement('DELETE FROM school_drafts WHERE id=?', [
      requestId,
    ]);
    return result;
  });
  Future<List<Json>> schoolGroups() =>
      _rows('SELECT * FROM group_saves ORDER BY saved_at_utc DESC');
  Future<void> undoSchoolGroup(String id) => db.transaction(() async {
    final row = (await _rows('SELECT * FROM group_saves WHERE id=?', [
      id,
    ])).single;
    if (row['undone_at_utc'] != null) return;
    final request = Json.from(jsonDecode(row['request'] as String) as Map);
    if (request['type'] == 'dialog-bulk') {
      for (final item in request['school'] as List) {
        final original = SchoolRecord.fromJson(Json.from(item as Map));
        final current = _record(
          (await _rows('SELECT * FROM school_records WHERE id=?', [
            original.id,
          ])).single,
        );
        if (current.revision != original.revision ||
            (await _rows('SELECT id FROM school_drafts WHERE entity_id=?', [
              original.id,
            ])).isNotEmpty) {
          throw const StaleRevision();
        }
        await saveSchoolRecord(current.patch({'deleted': true}));
      }
      for (final item in request['orga'] as List) {
        final original = OrgaEntry.fromJson(Json.from(item as Map));
        final current = (await (this as SqliteNotebook).entries()).firstWhere(
          (e) => e.id == original.id,
        );
        if (current.revision != original.revision ||
            (await _rows('SELECT id FROM drafts WHERE entity_id=?', [
              original.id,
            ])).isNotEmpty) {
          throw const StaleRevision();
        }
        await (this as SqliteNotebook).saveEntry(
          current.copyWith(
            deleted: true,
            reminderState: current.reminderState == ReminderState.planned
                ? ReminderState.cancelled
                : current.reminderState,
          ),
        );
      }
      final originalDraft = DialogDraft.fromJson(
        Json.from(request['draft'] as Map),
      );
      final recovered = await (this as SqliteNotebook).saveDialogDraft(
        DialogDraft(
          id: newId(),
          type: 'bulk',
          ownerId: 'group',
          data: originalDraft.data,
          updatedAtUtc: utcNow(),
        ),
      );
      await (this as SqliteNotebook)._recoverGroupAttachments(
        'bulkDraft',
        recovered.id,
        (request['school'] as List)
            .map((j) => SchoolRecord.fromJson(Json.from(j as Map)))
            .toList(),
        (request['orga'] as List)
            .map((j) => OrgaEntry.fromJson(Json.from(j as Map)))
            .toList(),
        (originalDraft.data['tasks'] as List? ?? [])
            .map((j) => HomeworkTask.fromJson(Json.from(j as Map)))
            .toList(),
      );
      await db.customStatement(
        'UPDATE group_saves SET undone_at_utc=?,recovery_draft_id=? WHERE id=?',
        [utcNow(), recovered.id, id],
      );
      return;
    }
    final originals = (request['records'] as List)
        .map((v) => SchoolRecord.fromJson(Json.from(v as Map)))
        .toList();
    for (final r in originals) {
      final actual = _record(
        (await _rows('SELECT * FROM school_records WHERE id=?', [r.id])).single,
      );
      if (jsonEncode(actual.toJson()) != jsonEncode(r.toJson()) ||
          (await _rows('SELECT id FROM school_drafts WHERE entity_id=?', [
            r.id,
          ])).isNotEmpty) {
        throw const DomainError(
          'Eine Beobachtung wurde inzwischen geändert oder wird bearbeitet. Die Gruppe bleibt erhalten.',
        );
      }
    }
    for (final r in originals) {
      await saveSchoolRecord(r.patch({'deleted': true}));
    }
    final draftId = newId();
    await saveSchoolDraft(
      SchoolDraft(
        id: draftId,
        record: SchoolRecord.fromJson(
          Json.from(request['template'] as Map),
        ).patch({'id': newId()}),
        recipients: List<String>.from(request['recipients'] as List),
        updatedAtUtc: utcNow(),
      ),
    );
    await (this as SqliteNotebook)._recoverGroupAttachments(
      'schoolDraft',
      draftId,
      originals,
      [],
      SchoolRecord.fromJson(Json.from(request['template'] as Map)).tasks,
    );
    await db.customStatement(
      'UPDATE group_saves SET undone_at_utc=?,recovery_draft_id=? WHERE id=?',
      [utcNow(), draftId, id],
    );
  });

  Future<List<SchoolDraft>> schoolDrafts() async =>
      (await _rows(
        'SELECT * FROM school_drafts ORDER BY updated_at_utc DESC',
      )).map((row) {
        final j = Json.from(jsonDecode(row['payload'] as String) as Map);
        final r = SchoolRecord.fromJson(Json.from(j['record'] as Map));
        r.validate(draft: true);
        if (r.id != row['entity_id']) {
          throw const DomainError('Widersprüchlicher Entwurf.');
        }
        return SchoolDraft(
          id: row['id'] as String,
          record: r,
          recipients: List<String>.from(j['recipients'] as List),
          editRevision: j['editRevision'] as int,
          updatedAtUtc: row['updated_at_utc'] as String,
          mode: j['mode'] as String? ?? 'entry',
          taskId: j['taskId'] as String?,
          feedbackId: j['feedbackId'] as String?,
          baseline: j['baseline'] as String?,
        );
      }).toList();
  Future<SchoolDraft> saveSchoolDraft(
    SchoolDraft draft,
  ) => db.transaction(() async {
    draft.record.validate(draft: true);
    final existing = await _rows(
      'SELECT payload FROM school_drafts WHERE id=?',
      [draft.id],
    );
    final removedTasks = <String>{};
    if (existing.isNotEmpty) {
      final j = Json.from(
        jsonDecode(existing.single['payload'] as String) as Map,
      );
      if (j['editRevision'] != draft.editRevision) {
        throw const StaleRevision();
      }
      removedTasks.addAll(
        SchoolRecord.fromJson(Json.from(j['record'] as Map)).tasks
            .map((t) => t.id)
            .where((id) => !draft.record.tasks.any((t) => t.id == id)),
      );
    } else if (draft.editRevision != 0) {
      throw const StaleRevision();
    }
    final saved = SchoolDraft(
      id: draft.id,
      record: draft.record,
      updatedAtUtc: draft.updatedAtUtc,
      recipients: draft.recipients,
      editRevision: draft.editRevision + 1,
      mode: draft.mode,
      taskId: draft.taskId,
      feedbackId: draft.feedbackId,
      baseline: draft.baseline,
    );
    await db.customStatement(
      'INSERT INTO school_drafts(id,entity_id,payload,updated_at_utc) VALUES (?,?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,updated_at_utc=excluded.updated_at_utc',
      [
        saved.id,
        saved.record.id,
        jsonEncode(saved.toJson()),
        saved.updatedAtUtc,
      ],
    );
    if (removedTasks.isNotEmpty) {
      await (this as SqliteNotebook)._rewriteAttachmentLinks(
        (link) =>
            link.kind == 'schoolDraft' &&
            link.id == saved.id &&
            removedTasks.contains(link.taskId),
        (_) => [DocumentLink('schoolDraft', saved.id)],
      );
    }
    return saved;
  });
  Future<void> discardSchoolDraft(String id, {int? expectedRevision}) =>
      db.transaction(() async {
        if (expectedRevision != null) {
          await _checkDraftRevision(id, expectedRevision);
        }
        await (this as SqliteNotebook)._detachDraftAttachments(
          'schoolDraft',
          id,
        );
        await db.customStatement('DELETE FROM school_drafts WHERE id=?', [id]);
      });

  Future<void> _checkDraftRevision(String id, int expected) async {
    final existing = await _rows(
      'SELECT payload FROM school_drafts WHERE id=?',
      [id],
    );
    final actual = existing.isEmpty
        ? 0
        : (jsonDecode(existing.single['payload'] as String)
              as Map)['editRevision'];
    if (actual != expected) throw const StaleRevision();
  }
}
