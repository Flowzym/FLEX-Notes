import '../domain/entry_template.dart';
import '../domain/reminder_action.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;

import 'package:cryptography/cryptography.dart';

import '../domain/backup_merge.dart';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/school_year.dart';
import '../domain/repository.dart';
import '../domain/school.dart';
import '../domain/observation_catalog.dart';
import '../domain/classroom.dart';
import '../domain/drive_rules.dart';
import '../domain/planning_import.dart';
import '../domain/document_scanner.dart';
import '../domain/material_tags.dart';
import '../domain/material_versions.dart';
import 'database.dart';
part 'school_store.dart';
part 'privacy_store.dart';
part 'template_store.dart';
part 'backup_merge_store.dart';
part 'classroom_store.dart';
part 'draft_document_store.dart';

class SqliteNotebook
    with
        SchoolStore,
        ClassroomStore,
        BackupMergeStore,
        PrivacyStore,
        TemplateStore
    implements NotebookRepository, BackupMergeRepository {
  @override
  Future<NotebookSnapshot> snapshot() => db.transaction(() async {
    await materializeRepeats(DateTime.now());
    final years = await schoolYears();
    return NotebookSnapshot(
      schoolYears: years,
      pupils: await pupils(),
      entries: await entries(),
      drafts: await drafts(),
      records: await schoolRecords(),
      schoolDrafts: await schoolDrafts(),
      dialogDrafts: await dialogDrafts(),
      appearance: await appearance(),
      legacyCount: await legacyCount(),
      classroom: await classroomDocuments(),
    );
  });
  SqliteNotebook(this.db);

  @override
  Future<bool> applyReminderAction(
    ReminderAction action,
    DateTime now,
  ) => db.transaction(() async {
    action.validate();
    final token = (await Sha256().hash(
      utf8.encode('${action.target}|${action.revision}|${action.scheduledAt}'),
    )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final key = 'notification-action:$token';
    if ((await db
            .customSelect(
              'SELECT 1 FROM preferences WHERE key=?',
              variables: [Variable(key)],
            )
            .get())
        .isNotEmpty) {
      return false;
    }
    final data = (await snapshot()).active();
    final override = data.classroom
        .where(
          (d) =>
              !d.deleted &&
              d.kind == ClassroomKind.reminder &&
              d.text('target') == action.target,
        )
        .firstOrNull;
    if (override != null &&
        (override.flag('dismissed') ||
            DateTime.tryParse(override.text('at')) !=
                DateTime.parse(action.scheduledAt))) {
      throw const DomainError(
        'Diese Erinnerung wurde inzwischen geändert. Bitte in FLEX prüfen.',
      );
    }
    final parts = action.target.split(':');
    final id = parts[1];
    final pupilIds = data.pupils
        .where((p) => !p.archived && !p.deleted)
        .map((p) => p.id)
        .toSet();
    final entry = data.entries
        .where(
          (e) =>
              e.id == id &&
              !e.deleted &&
              (e.pupilId == null || pupilIds.contains(e.pupilId)),
        )
        .firstOrNull;
    final record = data.records
        .where((r) => r.id == id && !r.deleted && pupilIds.contains(r.pupilId))
        .firstOrNull;
    final document = data.classroom
        .where((d) => d.id == id && !d.deleted)
        .firstOrNull;
    final revision = switch (parts.first) {
      'orga' => entry?.revision,
      'school' => record?.revision,
      'return' =>
        document?.kind == ClassroomKind.returnList ? document?.revision : null,
      'lesson' =>
        document?.kind == ClassroomKind.lesson ? document?.revision : null,
      _ => null,
    };
    if (revision == null || revision != action.revision) {
      throw const DomainError(
        'Der Eintrag wurde inzwischen geändert oder entfernt. Bitte in FLEX prüfen.',
      );
    }
    if (action.action == 'done') {
      if (parts.first != 'orga' || entry == null || !entry.isTask) {
        throw const DomainError(
          'Dieser Eintrag lässt sich nicht als Aufgabe abschließen.',
        );
      }
      if (!entry.done) {
        await saveEntry(
          entry.copyWith(
            done: true,
            reminderState: entry.reminderAtUtc == null
                ? ReminderState.none
                : ReminderState.acknowledged,
          ),
        );
      }
    } else {
      if (entry?.done == true ||
          record != null && !record.pending ||
          document?.kind == ClassroomKind.returnList &&
              document!.flag('closed')) {
        throw const DomainError('Der Eintrag ist bereits abgeschlossen.');
      }
      if (parts.first == 'lesson') {
        if (parts.length != 3 ||
            !validDate(parts.last) ||
            !lessonOccurrences(
              data.classroom,
              parts.last,
              parts.last,
            ).any((l) => l.target == action.target)) {
          throw const DomainError(
            'Diese Unterrichtsstunde findet nicht mehr statt.',
          );
        }
      }
      final snoozeId = const Uuid().v5(
        Namespace.url.value,
        'flex-snooze:${action.target}',
      );
      final previous = data.classroom
          .where((d) => d.id == snoozeId)
          .firstOrNull;
      final fields = <String, dynamic>{
        'target': action.target,
        'at': now.add(const Duration(hours: 1)).toUtc().toIso8601String(),
        'dismissed': false,
        'deleted': false,
      };
      await saveClassroomDocument(
        previous == null
            ? ClassroomDocument.create(
                ClassroomKind.reminder,
                'Erinnerung',
                fields,
                id: snoozeId,
              )
            : previous.patch(fields),
      );
    }
    await db.customStatement(
      'INSERT INTO preferences(key,payload) VALUES (?,?)',
      [
        key,
        jsonEncode({'at': now.toUtc().toIso8601String()}),
      ],
    );
    await db.customStatement(
      "DELETE FROM preferences WHERE key LIKE 'notification-action:%' AND json_extract(payload,'\$.at') < ?",
      [now.subtract(const Duration(days: 30)).toUtc().toIso8601String()],
    );
    return true;
  });

  @override
  Future<void> renameMaterialTag(String oldTag, String? newTag) =>
      db.transaction(() async {
        final key = materialTagKey(oldTag);
        final replacement = newTag == null ? null : checkedMaterialTag(newTag);
        List<String> rewrite(Iterable<String> tags) => normalizeMaterialTags([
          for (final tag in tags)
            if (materialTagKey(tag) != key) tag else ?replacement,
        ]);
        bool affected(Iterable<String> tags) =>
            tags.any((t) => materialTagKey(t) == key);
        final revisions = <String, (int, int)>{};
        for (final d in await classroomDocuments()) {
          if (d.kind != ClassroomKind.material ||
              !affected(d.strings('tags'))) {
            continue;
          }
          final saved = await _writeClassroom(
            d.patch({'tags': rewrite(d.strings('tags'))}),
          );
          revisions[d.id] = (d.revision, saved.revision);
        }
        for (final draft in await dialogDrafts()) {
          if (!{'scan', 'classroom'}.contains(draft.type)) continue;
          final tags = List<String>.from(draft.data['tags'] as List? ?? []);
          final isScan = draft.type == 'scan';
          final source = revisions[draft.data[isScan ? 'sourceId' : 'id']];
          final revisionKey = isScan ? 'sourceRevision' : 'revision';
          final updateSource =
              source != null && draft.data[revisionKey] == source.$1;
          if (!affected(tags) && !updateSource) continue;
          await saveDialogDraft(
            DialogDraft.fromJson({
              ...draft.toJson(),
              'data': {
                ...draft.data,
                if (affected(tags)) 'tags': rewrite(tags),
                if (updateSource) revisionKey: source.$2,
              },
            }),
          );
        }
      });
  @override
  final NotebookDatabase db;

  // Removing a task never removes its files. Move its references to the HÜ
  // entry atomically, including drafts, and invalidate any stale open editor.
  Future<void> _retainRemovedTaskDocuments(
    String recordId,
    Set<String> removed,
  ) async {
    bool affected(Json l) =>
        l['kind'] == 'school' &&
        l['id'] == recordId &&
        removed.contains(l['taskId']);
    List<Json> retain(List<Json> links) => {
      for (final row in links)
        if (affected(row))
          DocumentLink('school', recordId).identity: DocumentLink(
            'school',
            recordId,
          ).toJson()
        else
          DocumentLink.fromJson(row).identity: row,
    }.values.toList();
    final revisions = <String, (int, int)>{};
    for (final d in await classroomDocuments()) {
      final links = d.rows('links');
      if (links.any(affected)) {
        final saved = await _writeClassroom(d.patch({'links': retain(links)}));
        revisions[d.id] = (d.revision, saved.revision);
      }
    }
    for (final d in (await dialogDrafts()).where((d) => d.type == 'scan')) {
      final links = (d.data['links'] as List)
          .map((l) => Json.from(l as Map))
          .toList();
      final source = revisions[d.data['sourceId']];
      final updateSource =
          source != null && d.data['sourceRevision'] == source.$1;
      if (links.any(affected) || updateSource) {
        await saveDialogDraft(
          DialogDraft.fromJson({
            ...d.toJson(),
            'data': {
              ...d.data,
              'links': retain(links),
              if (updateSource) 'sourceRevision': source.$2,
            },
          }),
        );
      }
    }
  }

  @override
  Future<void> resolveSchoolConflict(
    SchoolDraft draft, {
    required bool useOther,
  }) => db.transaction(() async {
    await _checkDraftRevision(draft.id, draft.editRevision);
    final current = _record(
      (await _rows('SELECT * FROM school_records WHERE id=?', [
        draft.record.id,
      ])).single,
    );
    var candidate = draft.record.patch({'revision': current.revision});
    if (draft.mode == 'comment') {
      final edited = draft.record.feedback.firstWhere(
        (f) => f.id == draft.feedbackId,
      );
      if (edited.taskId != null &&
          !current.tasks.any((t) => t.id == edited.taskId)) {
        throw const DomainError(
          'Diese Aufgabe ist in der aktuellen Version nicht mehr vorhanden.',
        );
      }
      final previous = current.feedback
          .where((f) => f.id == edited.id)
          .firstOrNull;
      final feedback = previous == null
          ? edited
          : previous.copyWith(note: edited.note, delivery: edited.delivery);
      candidate = current.patch({
        'feedback': [
          ...current.feedback
              .where((f) => f.id != edited.id)
              .map((f) => f.toJson()),
          feedback.toJson(),
        ],
      });
    }
    await db.customStatement(
      'INSERT INTO preferences(key,payload) VALUES (?,?)',
      [
        'resolved-conflict-${newId()}',
        jsonEncode({
          'current': current.toJson(),
          'other': draft.record.toJson(),
          'useOther': useOther,
          'at': utcNow(),
        }),
      ],
    );
    if (useOther) {
      await saveSchoolRecord(
        candidate,
        draftId: draft.id,
        draftRevision: draft.editRevision,
      );
    } else {
      await discardSchoolDraft(draft.id);
    }
  });
  @override
  Future<void> resolveOrgaConflict(EditDraft draft, {required bool useOther}) =>
      db.transaction(() async {
        await _checkOrgaDraft(draft.id, draft.editRevision);
        final current = await _entry(
          (await _rows('SELECT * FROM orga WHERE id=?', [
            draft.entry.id,
          ])).single,
        );
        await db.customStatement(
          'INSERT INTO preferences(key,payload) VALUES (?,?)',
          [
            'resolved-conflict-${newId()}',
            jsonEncode({
              'current': current.toJson(),
              'other': draft.entry.toJson(),
              'useOther': useOther,
              'at': utcNow(),
            }),
          ],
        );
        if (useOther) {
          await saveEntry(
            draft.entry.copyWith(revision: current.revision),
            draftId: draft.id,
            draftRevision: draft.editRevision,
          );
        } else {
          await discardDraft(draft.id);
        }
      });
  @override
  Future<void> maintainStorage(
    String capturedBackup, {
    required bool emptyTrash,
  }) => db.transaction(() async {
    final captured = Json.from(jsonDecode(capturedBackup) as Map);
    final current = Json.from(jsonDecode(await exportBackup()) as Map);
    if (jsonEncode(captured['tables']) != jsonEncode(current['tables'])) {
      throw const DomainError(
        'Die gespeicherten Daten wurden inzwischen geändert. Bitte eine neue vollständige Sicherung erstellen.',
      );
    }
    final check = await _rows('PRAGMA quick_check');
    if (check.length != 1 || check.single.values.single != 'ok') {
      throw const DomainError(
        'Die Speicherprüfung meldet einen Fehler. Es wurde nichts gelöscht.',
      );
    }
    if (!emptyTrash) {
      await db.customStatement('PRAGMA optimize');
      return;
    }
    final records = await schoolRecords(), orga = await entries();
    // Retain series sources and occurrence tombstones so maintenance cannot
    // break references or regenerate a deliberately deleted occurrence.
    final series = (await classroomDocuments())
        .where((d) => d.kind == ClassroomKind.repeat)
        .toList();
    final seriesIds = {
      for (final d in series) d.text('entryId'),
      for (final d in series)
        for (final date in d.map('generated').keys)
          const Uuid().v5(Namespace.url.value, '${d.id}:$date'),
    };
    final deleted = {
      ...records.where((r) => r.deleted).map((r) => r.id),
      ...orga
          .where((e) => e.deleted && !seriesIds.contains(e.id))
          .map((e) => e.id),
    };
    await _purgeEntries(deleted);
    await _purgeDeletedPupils(
      (await pupils()).where((p) => p.deleted).map((p) => p.id).toSet(),
    );
    await validateClassroomReferences();
  });

  @override
  Future<void> _purgeEntries(Set<String> deleted) async {
    if (deleted.isEmpty) return;
    final records = await schoolRecords();
    final affectedContexts = records
        .where((r) => deleted.contains(r.id))
        .map((r) => r.situationId)
        .whereType<String>()
        .toSet();
    final scanDrafts = (await dialogDrafts()).where((d) => d.type == 'scan');
    if (scanDrafts.any(
      (d) => (d.data['links'] as List).any((l) => deleted.contains(l['id'])),
    )) {
      throw const DomainError(
        'Zu gelöschten Einträgen sind noch Scanentwürfe vorhanden. Bitte diese zuerst bearbeiten oder verwerfen.',
      );
    }
    if ((await schoolDrafts()).any((d) => deleted.contains(d.record.id)) ||
        (await drafts()).any((d) => deleted.contains(d.entry.id))) {
      throw const DomainError(
        'Zu gelöschten Einträgen sind noch Entwürfe vorhanden. Bitte diese zuerst bearbeiten oder verwerfen.',
      );
    }
    for (final record in records.where(
      (r) => !r.deleted && deleted.contains(r.goalId),
    )) {
      await saveSchoolRecord(
        record.patch({'goalId': null, 'goalSnapshot': ''}),
      );
    }
    // Keep the PDF and student assignment when its source entry is permanently
    // removed; detach only those now-invalid entry links in the same transaction.
    for (final document in await classroomDocuments()) {
      final links = document.rows('links');
      if (links.any((l) => deleted.contains(l['id']))) {
        await _writeClassroom(
          document.patch({
            'links': links.where((l) => !deleted.contains(l['id'])).toList(),
          }),
        );
      }
    }
    for (final id in deleted) {
      await db.customStatement(
        'DELETE FROM outbox WHERE operation_id IN (SELECT id FROM operations WHERE revision_id IN (SELECT id FROM revisions WHERE entity_id=?))',
        [id],
      );
      await db.customStatement(
        'DELETE FROM operations WHERE revision_id IN (SELECT id FROM revisions WHERE entity_id=?)',
        [id],
      );
      await db.customStatement('DELETE FROM revisions WHERE entity_id=?', [id]);
      await db.customStatement('DELETE FROM orga_items WHERE orga_id=?', [id]);
      await db.customStatement('DELETE FROM preferences WHERE key=?', [
        'orga-time-$id',
      ]);
      await db.customStatement('DELETE FROM orga WHERE id=? AND deleted=1', [
        id,
      ]);
      await db.customStatement('DELETE FROM school_records WHERE id=?', [id]);
    }
    // Group snapshots contain copies of the removed records. Remove only
    // affected undo records after the complete snapshot has been exported.
    for (final group in await schoolGroups()) {
      final request = jsonEncode(jsonDecode(group['request'] as String));
      if (deleted.any((id) => request.contains(jsonEncode(id)))) {
        await db.customStatement('DELETE FROM group_saves WHERE id=?', [
          group['id'],
        ]);
      }
    }
    for (final row in await _rows(
      'SELECT id FROM situations WHERE id NOT IN (SELECT situation_id FROM school_records WHERE situation_id IS NOT NULL)',
    )) {
      final id = row['id'] as String;
      if (!affectedContexts.contains(id)) continue;
      if ((await _rows('SELECT id FROM context_drafts WHERE entity_id=?', [
        id,
      ])).isNotEmpty) {
        throw const DomainError(
          'Zu einem gemeinsamen Kontext ist noch ein Entwurf vorhanden. Es wurde nichts gelöscht.',
        );
      }
      await db.customStatement(
        'DELETE FROM outbox WHERE operation_id IN (SELECT id FROM operations WHERE revision_id IN (SELECT id FROM revisions WHERE entity_kind=? AND entity_id=?))',
        ['situation', id],
      );
      await db.customStatement(
        'DELETE FROM operations WHERE revision_id IN (SELECT id FROM revisions WHERE entity_kind=? AND entity_id=?)',
        ['situation', id],
      );
      await db.customStatement(
        'DELETE FROM revisions WHERE entity_kind=? AND entity_id=?',
        ['situation', id],
      );
      await db.customStatement(
        'DELETE FROM situation_pupils WHERE situation_id=?',
        [id],
      );
      await db.customStatement('DELETE FROM situations WHERE id=?', [id]);
    }
    for (final row in await _rows(
      "SELECT key,payload FROM preferences WHERE key LIKE 'resolved-conflict-%'",
    )) {
      if (deleted.any(
        (id) => (row['payload'] as String).contains(jsonEncode(id)),
      )) {
        await db.customStatement('DELETE FROM preferences WHERE key=?', [
          row['key'],
        ]);
      }
    }
    await _forgetArchivedIds(deleted);
  }

  @override
  Future<Json?> situation(String id) async {
    final rows = await _rows('SELECT * FROM situations WHERE id=?', [id]);
    if (rows.isEmpty) return null;
    return {
      ...Json.from(jsonDecode(rows.single['payload'] as String) as Map),
      'id': id,
      'revision': rows.single['revision'],
    };
  }

  @override
  Future<void> saveSituation(
    String id,
    int revision,
    String text,
    DialogDraft? draft,
  ) => db.transaction(() async {
    if (text.length > 12000) {
      throw const DomainError('Der gemeinsame Ablauf ist zu lang.');
    }
    final old = await situation(id);
    if (old == null || old['revision'] != revision) throw const StaleRevision();
    if (draft != null) await discardDialogDraft(draft.id, draft.revision);
    final payload = {...old, 'text': text, 'revision': revision + 1};
    await db.customStatement(
      'UPDATE situations SET revision=?,payload=? WHERE id=?',
      [revision + 1, jsonEncode(payload), id],
    );
    for (final row in await _rows(
      'SELECT * FROM school_records WHERE situation_id=?',
      [id],
    )) {
      await saveSchoolRecord(_record(row).patch({'context': text}));
    }
    await _audit('situation', id, revision, old, payload);
  });
  @override
  Future<void> saveBulkDialog(DialogDraft draft) => db.transaction(() async {
    if ((await _rows('SELECT id FROM group_saves WHERE id=?', [
      draft.id,
    ])).isNotEmpty) {
      return;
    }
    final data = draft.data;
    final recipients = List<String>.from(data['recipients'] as List);
    if (recipients.length < 2 ||
        recipients.toSet().length != recipients.length) {
      throw const DomainError('Bitte mindestens zwei Schüler auswählen.');
    }
    final pupilsById = {for (final p in await pupils()) p.id: p};
    if (recipients.any(
      (id) => pupilsById[id] == null || pupilsById[id]!.archived,
    )) {
      throw const DomainError(
        'Die Auswahl enthält einen nicht mehr aktiven Schüler. Bitte die Schülerauswahl neu treffen.',
      );
    }
    final kind = data['kind'] as String;
    String? contextId;
    if (kind == 'social' || kind == 'work') {
      contextId = newId();
      final context = {
        'text': data['context'] ?? '',
        'participantIds': recipients,
        'otherParticipants': data['otherParticipants'] ?? '',
      };
      await db.customStatement(
        'INSERT INTO situations(id,revision,payload) VALUES (?,1,?)',
        [contextId, jsonEncode(context)],
      );
      for (final id in recipients) {
        await db.customStatement(
          'INSERT INTO situation_pupils(situation_id,pupil_id) VALUES (?,?)',
          [contextId, id],
        );
      }
      await _audit('situation', contextId, 0, null, context);
    }
    final school = <Json>[], orga = <Json>[];
    for (final id in recipients) {
      if (kind == 'orga') {
        final text = data['body'] as String? ?? '';
        if (text.trim().isEmpty) {
          throw const DomainError('Bitte eine Notiz eingeben.');
        }
        final first = text.trim().split('\n').first;
        final reminderDate = data['reminderDate'] as String? ?? '';
        final reminderTime = data['reminderTime'] as String? ?? '';
        if (data['reminderOpen'] == true && !validDate(reminderDate)) {
          throw const DomainError('Bitte ein Datum für die Erinnerung wählen.');
        }
        if (!validTime(reminderTime)) {
          throw const DomainError('Bitte eine gültige Uhrzeit wählen.');
        }
        final reminderAt = reminderDate.isEmpty
            ? null
            : DateTime.parse(
                '${reminderDate}T${reminderTime.isEmpty ? '00:00' : reminderTime}:00',
              );
        final entry = OrgaEntry.empty(pupilId: id).copyWith(
          title: first.substring(0, first.length.clamp(0, 160)),
          body: text,
          otherParticipants: data['otherParticipants'] as String? ?? '',
          observedOn: data['observedOn'] as String,
          observedTime: data['observedTime'] as String? ?? '',
          isTask: data['isTask'] == true,
          dueDate: data['isTask'] == true ? data['dueDate'] : null,
          reminderAtUtc: reminderAt?.toUtc().toIso8601String(),
          reminderHasTime: reminderTime.isNotEmpty,
          reminderZone: reminderAt?.timeZoneName ?? 'UTC',
          reminderState: reminderAt == null
              ? ReminderState.none
              : ReminderState.planned,
          reminderText: data['reminderText'] as String? ?? '',
          needsCompletion: data['needsCompletion'] == true,
        );
        orga.add((await saveEntry(entry)).toJson());
      } else {
        final individual = Json.from(
          (data['individual'] as Map? ?? {})[id] as Map? ?? {},
        );
        final taskIds = <String, String>{};
        for (final t in data['tasks'] as List? ?? []) {
          taskIds[t['id'] as String] = newId();
        }
        final r = SchoolRecord.empty(SchoolKind.values.byName(kind), id).patch({
          if (kind == 'homework') 'homeworkGroup': draft.id,
          'observedOn': data['observedOn'],
          'observedTime': data['observedTime'] ?? '',
          'subject': data['subject'] ?? '',
          'taskTags': data['taskTags'] ?? [],
          'taskFree': data['taskFree'],
          'situation': kind == 'social' ? data['situation'] ?? '' : '',
          'otherParticipants': data['otherParticipants'] ?? '',
          'context': data['context'] ?? '',
          'body': individual['body'] ?? '',
          'positive': individual['positive'] ?? [],
          'neutral': individual['neutral'] ?? [],
          'negative': individual['negative'] ?? [],
          'participantIds': recipients.where((p) => p != id).toList(),
          'situationId': contextId,
          'dueDate': data['dueDate'],
          'needsCompletion': data['needsCompletion'] == true,
          'tasks': [
            for (final t in data['tasks'] as List? ?? [])
              if ((t['text'] as String).trim().isNotEmpty)
                {
                  ...Json.from(t as Map),
                  'id': taskIds[t['id']],
                  'parentId': taskIds[t['parentId']],
                },
          ],
        });
        school.add((await saveSchoolRecord(r)).toJson());
      }
    }
    final templateTasks = (data['tasks'] as List? ?? [])
        .where((t) => (t['text'] as String).trim().isNotEmpty)
        .toList();
    await _rewriteAttachmentLinks(
      (link) => link.kind == 'bulkDraft' && link.id == draft.id,
      (link) {
        final index = templateTasks.indexWhere((t) => t['id'] == link.taskId);
        return [
          for (final r in school)
            DocumentLink(
              'school',
              r['id'] as String,
              taskId: index >= 0 && index < (r['tasks'] as List).length
                  ? r['tasks'][index]['id'] as String
                  : '',
            ),
          for (final e in orga) DocumentLink('orga', e['id'] as String),
        ];
      },
      addedPupils: recipients.toSet(),
    );
    await discardDialogDraft(draft.id, draft.revision);
    await db.customStatement(
      'INSERT INTO group_saves(id,request,saved_at_utc) VALUES (?,?,?)',
      [
        draft.id,
        jsonEncode({
          'type': 'dialog-bulk',
          'school': school,
          'orga': orga,
          'draft': draft.toJson(),
        }),
        utcNow(),
      ],
    );
  });
  @override
  Future<List<DialogDraft>> dialogDrafts() async =>
      (await _rows('SELECT * FROM context_drafts ORDER BY updated_at_utc DESC'))
          .map(
            (row) => DialogDraft.fromJson(
              Json.from(jsonDecode(row['payload'] as String) as Map),
            ),
          )
          .toList();
  @override
  Future<DialogDraft> saveDialogDraft(
    DialogDraft draft,
  ) => db.transaction(() async {
    DialogDraft.fromJson(draft.toJson());
    final rows = await _rows('SELECT payload FROM context_drafts WHERE id=?', [
      draft.id,
    ]);
    final previous = rows.isEmpty
        ? null
        : DialogDraft.fromJson(
            Json.from(jsonDecode(rows.single['payload'] as String) as Map),
          );
    if ((previous?.revision ?? 0) != draft.revision) {
      throw const StaleRevision();
    }
    final saved = DialogDraft.fromJson({
      ...draft.toJson(),
      'revision': draft.revision + 1,
    });
    await db.customStatement(
      'INSERT INTO context_drafts(id,entity_id,payload,updated_at_utc) VALUES (?,?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,updated_at_utc=excluded.updated_at_utc',
      [saved.id, saved.ownerId, jsonEncode(saved.toJson()), saved.updatedAtUtc],
    );
    if (saved.type == 'bulk' && previous != null) {
      final removedTasks = (previous.data['tasks'] as List? ?? [])
          .map((t) => t['id'])
          .where(
            (id) =>
                !(saved.data['tasks'] as List? ?? []).any((t) => t['id'] == id),
          )
          .toSet();
      if (removedTasks.isNotEmpty) {
        await _rewriteAttachmentLinks(
          (l) =>
              l.kind == 'bulkDraft' &&
              l.id == saved.id &&
              removedTasks.contains(l.taskId),
          (_) => [DocumentLink('bulkDraft', saved.id)],
        );
      }
    }
    return saved;
  });
  @override
  Future<void> discardDialogDraft(String id, int revision) =>
      db.transaction(() async {
        final rows = await _rows(
          'SELECT payload FROM context_drafts WHERE id=?',
          [id],
        );
        final actual = rows.isEmpty
            ? 0
            : DialogDraft.fromJson(
                Json.from(jsonDecode(rows.single['payload'] as String) as Map),
              ).revision;
        if (actual != revision) throw const StaleRevision();
        if (rows.isNotEmpty) {
          final type =
              (jsonDecode(rows.single['payload'] as String) as Map)['type'];
          if (type == 'bulk' || type == 'classroom') {
            await _detachDraftAttachments('${type}Draft', id);
          }
        }
        await db.customStatement('DELETE FROM context_drafts WHERE id=?', [id]);
      });
  @override
  Future<Pupil> savePupilDialog(
    Pupil pupil,
    DialogDraft? draft, {
    ClassroomDocument? materialProfile,
    List<ClassroomDocument> materialUpdates = const [],
  }) => db.transaction(() async {
    if (draft != null) await discardDialogDraft(draft.id, draft.revision);
    final saved = await savePupil(pupil);
    if (materialProfile != null || materialUpdates.isNotEmpty) {
      if (materialProfile != null &&
              (materialProfile.kind != ClassroomKind.materialProfile ||
                  materialProfile.strings('pupilIds').singleOrNull !=
                      pupil.id) ||
          materialUpdates.any((d) => d.kind != ClassroomKind.material)) {
        throw const DomainError('Bitte die Materialzuordnung prüfen.');
      }
      await saveClassroomDocuments([?materialProfile, ...materialUpdates]);
    }
    return saved;
  });

  @override
  Future<void> savePlanningSync(
    List<ClassroomDocument> changes,
    Map<String, int> rosterRevisions,
  ) => db.transaction(() async {
    final current = planningRosterRevisions(
      await classroomDocuments(),
      await pupils(),
      includeFolders: changes.any((d) => d.kind == ClassroomKind.folder),
    );
    if (current.length != rosterRevisions.length ||
        current.entries.any((e) => rosterRevisions[e.key] != e.value)) {
      throw const StaleRevision();
    }
    await saveClassroomDocuments(changes);
  });
  @override
  Future<void> saveCatalogs(
    Map<String, List<String>> options,
    DialogDraft? draft,
  ) => db.transaction(() async {
    if (draft != null) await discardDialogDraft(draft.id, draft.revision);
    for (final entry in options.entries) {
      await saveObservationOptions(entry.key, entry.value);
    }
  });
  late String _deviceId;
  static const legacyTables = [
    'devices',
    'pupils',
    'orga',
    'orga_items',
    'drafts',
    'revisions',
    'operations',
    'outbox',
    'preferences',
    'legacy_backups',
  ];
  static const backupTables = [
    ...legacyTables,
    'situations',
    'situation_pupils',
    'context_drafts',
    'group_drafts',
    'group_saves',
    'school_records',
    'school_drafts',
    'pupil_drafts',
  ];
  @override
  Future<List<Json>> _rows(
    String sql, [
    List<String> values = const [],
  ]) async =>
      (await db
              .customSelect(
                sql,
                variables: values.map((v) => Variable<String>(v)).toList(),
              )
              .get())
          .map((r) => r.data)
          .toList();
  @override
  Future<void> initialize() async {
    await db.transaction(() async {
      final rows = await _rows(
        "SELECT value FROM metadata WHERE key='local_device_id'",
      );
      if (rows.isEmpty) {
        _deviceId = newId();
        await db.customStatement('INSERT INTO devices(id) VALUES (?)', [
          _deviceId,
        ]);
        await db.customStatement(
          "INSERT INTO metadata(key,value) VALUES ('local_device_id',?)",
          [_deviceId],
        );
      } else {
        _deviceId = rows.single['value'] as String;
      }
      await db.customStatement(
        "UPDATE devices SET name=CASE WHEN name='' THEN 'Dieses Gerät' ELSE name END,platform=?,created_at_utc=COALESCE(created_at_utc,?),last_seen_at_utc=? WHERE id=?",
        [
          kIsWeb ? 'web' : defaultTargetPlatform.name,
          utcNow(),
          utcNow(),
          _deviceId,
        ],
      );
    });
  }

  Pupil _pupil(Json row) => Pupil(
    id: row['id'] as String,
    name: row['name'] as String,
    color: row['color'] as int,
    archived: row['archived'] == 1,
    deleted: row['deleted'] == 1,
    createdAtUtc: row['created_at_utc'] as String?,
    updatedAtUtc: row['updated_at_utc'] as String?,
    deletedAtUtc: row['deleted_at_utc'] as String?,
    revision: row['revision'] as int,
  );
  @override
  Future<List<Pupil>> pupils() async => (await _rows(
    'SELECT * FROM pupils ORDER BY name COLLATE NOCASE,id',
  )).map(_pupil).toList();
  @override
  Future<Set<String>> searchEntryKeys(String query, {String? pupilId}) async {
    if (query.trim().isEmpty) return {};
    if (query.length > 300) {
      throw const DomainError('Bitte einen kürzeren Suchtext eingeben.');
    }
    final expression = query
        .trim()
        .split(RegExp(r'\s+'))
        .take(12)
        .map((word) => '"${word.replaceAll('"', '""')}"*')
        .join(' AND ');
    final result = await _rows(
      '''SELECT kind,entity_id FROM entry_search
      WHERE entry_search MATCH ? AND (?='' OR pupil_id=?)
      AND (pupil_id IS NULL OR pupil_id='' OR EXISTS
        (SELECT 1 FROM pupils p WHERE p.id=entry_search.pupil_id AND p.deleted=0 AND (p.archived=0 OR p.id=?)))
      AND ((kind='orga' AND EXISTS(SELECT 1 FROM orga o WHERE o.id=entity_id AND o.deleted=0))
        OR (kind='school' AND EXISTS(SELECT 1 FROM school_records r WHERE r.id=entity_id AND json_extract(r.payload,'\$.deleted')=0))
        OR (kind='classroom' AND EXISTS(SELECT 1 FROM preferences p WHERE p.key='classroom:'||entity_id AND json_extract(p.payload,'\$.deleted')=0)))
      ORDER BY rank''',
      [expression, pupilId ?? '', pupilId ?? '', pupilId ?? ''],
    );
    // Tags live with appointment metadata; include them without rewriting the
    // user's title or body to feed the text index.
    final tagged = await _rows(
      '''SELECT o.id,tag.value AS tag FROM orga o
      JOIN preferences m ON m.key='orga-time-'||o.id
      JOIN json_each(m.payload,'\$.tags') tag
      WHERE o.deleted=0 AND (?='' OR o.pupil_id=?)
      AND (o.pupil_id IS NULL OR EXISTS
        (SELECT 1 FROM pupils p WHERE p.id=o.pupil_id AND p.deleted=0 AND (p.archived=0 OR p.id=?)))''',
      [pupilId ?? '', pupilId ?? '', pupilId ?? ''],
    );
    return {
      ...result.map((row) => '${row['kind']}:${row['entity_id']}'),
      ...tagged
          .where(
            (row) => (row['tag'] as String).toLowerCase().contains(
              query.trim().toLowerCase(),
            ),
          )
          .map((row) => 'orga:${row['id']}'),
    };
  }

  @override
  Future<Pupil> savePupil(Pupil pupil) async {
    pupil.validate();
    return db.transaction(() async {
      if (pupil.revision == 0 &&
          (await pupils()).any(
            (p) =>
                p.id != pupil.id &&
                p.name.trim().toLowerCase() == pupil.name.trim().toLowerCase(),
          )) {
        throw const DomainError('Dieser Schüler ist bereits vorhanden.');
      }
      final old = await _rows('SELECT * FROM pupils WHERE id=?', [pupil.id]);
      if ((old.isEmpty ? 0 : old.single['revision']) != pupil.revision) {
        throw const StaleRevision();
      }
      final saved = pupil.copyWith(
        name: pupil.name.trim(),
        revision: pupil.revision + 1,
        createdAtUtc: old.isEmpty
            ? pupil.createdAtUtc ?? utcNow()
            : old.single['created_at_utc'] as String?,
        updatedAtUtc: utcNow(),
        deletedAtUtc: pupil.deleted ? pupil.deletedAtUtc ?? utcNow() : null,
      );
      await db.customStatement(
        'INSERT INTO pupils(id,name,color,archived,revision,created_at_utc,updated_at_utc,deleted,deleted_at_utc) VALUES (?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,color=excluded.color,archived=excluded.archived,revision=excluded.revision,updated_at_utc=excluded.updated_at_utc,deleted=excluded.deleted,deleted_at_utc=excluded.deleted_at_utc',
        [
          saved.id,
          saved.name,
          saved.color,
          saved.archived ? 1 : 0,
          saved.revision,
          saved.createdAtUtc,
          saved.updatedAtUtc,
          saved.deleted ? 1 : 0,
          saved.deletedAtUtc,
        ],
      );
      await _audit(
        'pupil',
        saved.id,
        pupil.revision,
        old.isEmpty ? null : _pupil(old.single).toJson(),
        saved.toJson(),
      );
      return saved;
    });
  }

  Future<OrgaEntry> _entry(Json row) async {
    final items = await _rows(
      'SELECT * FROM orga_items WHERE orga_id=? ORDER BY position',
      [row['id'] as String],
    );
    final metadata = await _rows(
      'SELECT payload FROM preferences WHERE key=?',
      ['orga-time-${row['id']}'],
    );
    final timeMetadata = metadata.isEmpty
        ? <String, dynamic>{}
        : Json.from(jsonDecode(metadata.single['payload'] as String) as Map);
    if (timeMetadata.isNotEmpty && timeMetadata['hasTime'] is! bool) {
      throw const DomainError('Ungültige Erinnerungszeit.');
    }
    return OrgaEntry(
      id: row['id'] as String,
      pupilId: row['pupil_id'] as String?,
      title: row['title'] as String,
      body: row['body'] as String,
      otherParticipants: timeMetadata['otherParticipants'] as String? ?? '',
      tags: List<String>.from(timeMetadata['tags'] as List? ?? const []),
      isTask: row['is_task'] == 1,
      done: row['done'] == 1,
      deleted: row['deleted'] == 1,
      observedOn: row['observed_on'] as String,
      observedTime: row['observed_time'] as String,
      reminderText: row['reminder_text'] as String,
      reminderHasTime: timeMetadata['hasTime'] as bool? ?? true,
      appointmentDate: timeMetadata['appointmentDate'] as String?,
      appointmentTime: timeMetadata['appointmentTime'] as String? ?? '',
      appointmentEndTime: timeMetadata['appointmentEndTime'] as String? ?? '',
      dueDate: row['due_date'] as String?,
      reminderAtUtc: row['reminder_at_utc'] as String?,
      reminderZone: row['reminder_zone'] as String,
      reminderState: ReminderState.values.byName(
        row['reminder_state'] as String,
      ),
      needsCompletion: row['needs_completion'] == 1,
      revision: row['revision'] as int,
      createdAtUtc: row['created_at_utc'] as String,
      updatedAtUtc: row['updated_at_utc'] as String,
      items: items
          .map(
            (i) => CheckItem(
              id: i['id'] as String,
              text: i['text'] as String,
              checked: i['checked'] == 1,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<List<OrgaEntry>> entries() => db.transaction(() async {
    final rows = await _rows(
      'SELECT * FROM orga ORDER BY updated_at_utc DESC,id',
    );
    return Future.wait(rows.map(_entry));
  });
  @override
  Future<OrgaEntry> saveEntry(
    OrgaEntry entry, {
    String? draftId,
    int? draftRevision,
  }) async {
    entry.validate();
    return db.transaction(() async {
      if (draftId != null && draftRevision != null) {
        await _checkOrgaDraft(draftId, draftRevision);
      }
      final rows = await _rows('SELECT * FROM orga WHERE id=?', [entry.id]);
      final old = rows.isEmpty ? null : await _entry(rows.single);
      if ((old?.revision ?? 0) != entry.revision) throw const StaleRevision();
      if (old != null &&
          (old.pupilId != entry.pupilId ||
              old.createdAtUtc != entry.createdAtUtc)) {
        throw const DomainError(
          'Die Zuordnung eines bestehenden Eintrags darf nicht still geändert werden.',
        );
      }
      final saved = entry.copyWith(
        title: entry.title.trim(),
        revision: entry.revision + 1,
        updatedAtUtc: utcNow(),
      );
      await db.customStatement(
        '''INSERT INTO orga(id,pupil_id,title,body,is_task,done,due_date,reminder_at_utc,reminder_zone,reminder_state,needs_completion,revision,created_at_utc,updated_at_utc)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET title=excluded.title,body=excluded.body,is_task=excluded.is_task,done=excluded.done,due_date=excluded.due_date,reminder_at_utc=excluded.reminder_at_utc,reminder_zone=excluded.reminder_zone,reminder_state=excluded.reminder_state,needs_completion=excluded.needs_completion,revision=excluded.revision,updated_at_utc=excluded.updated_at_utc''',
        [
          saved.id,
          saved.pupilId,
          saved.title,
          saved.body,
          saved.isTask ? 1 : 0,
          saved.done ? 1 : 0,
          saved.dueDate,
          saved.reminderAtUtc,
          saved.reminderZone,
          saved.reminderState.name,
          saved.needsCompletion ? 1 : 0,
          saved.revision,
          saved.createdAtUtc,
          saved.updatedAtUtc,
        ],
      );
      await db.customStatement('DELETE FROM orga_items WHERE orga_id=?', [
        saved.id,
      ]);
      for (var i = 0; i < saved.items.length; i++) {
        final item = saved.items[i];
        await db.customStatement(
          'INSERT INTO orga_items(id,orga_id,position,text,checked) VALUES (?,?,?,?,?)',
          [item.id, saved.id, i, item.text, item.checked ? 1 : 0],
        );
      }
      await db.customStatement(
        'UPDATE orga SET deleted=?,observed_on=?,observed_time=?,reminder_text=? WHERE id=?',
        [
          saved.deleted ? 1 : 0,
          saved.observedOn,
          saved.observedTime,
          saved.reminderText,
          saved.id,
        ],
      );
      await db.customStatement(
        'INSERT INTO preferences(key,payload) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload',
        [
          'orga-time-${saved.id}',
          jsonEncode({
            'hasTime': saved.reminderHasTime,
            'appointmentDate': saved.appointmentDate,
            'appointmentTime': saved.appointmentTime,
            'appointmentEndTime': saved.appointmentEndTime,
            'otherParticipants': saved.otherParticipants,
            'tags': saved.tags,
          }),
        ],
      );
      await _audit(
        'orga',
        saved.id,
        entry.revision,
        old?.toJson(),
        saved.toJson(),
      );
      if (draftId != null) {
        await _rewriteAttachmentLinks(
          (link) => link.kind == 'orgaDraft' && link.id == draftId,
          (_) => [DocumentLink('orga', saved.id)],
          addedPupils: {if (saved.pupilId != null) saved.pupilId!},
        );
        await db.customStatement('DELETE FROM drafts WHERE id=?', [draftId]);
      }
      return saved;
    });
  }

  @override
  Future<void> _audit(
    String kind,
    String entityId,
    int base,
    Json? before,
    Json after,
  ) async {
    final revisionId = newId(), operationId = newId();
    final next =
        (await _rows(
              'SELECT COALESCE(MAX(sequence),0)+1 AS seq FROM operations WHERE device_id=?',
              [_deviceId],
            )).single['seq']
            as int;
    await db.customStatement(
      'INSERT INTO revisions(id,entity_kind,entity_id,base_revision,revision,before_payload,after_payload,captured_at_utc,device_id) VALUES (?,?,?,?,?,?,?,?,?)',
      [
        revisionId,
        kind,
        entityId,
        base,
        base + 1,
        before == null ? null : jsonEncode(before),
        jsonEncode(after),
        utcNow(),
        _deviceId,
      ],
    );
    final payload = {
      'kind': kind,
      'entityId': entityId,
      'baseRevision': base,
      'before': before,
      'after': after,
    };
    await db.customStatement(
      'INSERT INTO operations(id,device_id,sequence,protocol_version,revision_id,payload) VALUES (?,?,?,1,?,?)',
      [operationId, _deviceId, next, revisionId, jsonEncode(payload)],
    );
    await db.customStatement('INSERT INTO outbox(operation_id) VALUES (?)', [
      operationId,
    ]);
  }

  @override
  Future<EditDraft> saveDraft(EditDraft draft) => db.transaction(() async {
    await _checkOrgaDraft(draft.id, draft.editRevision);
    final next = EditDraft(
      id: draft.id,
      entry: draft.entry,
      updatedAtUtc: draft.updatedAtUtc,
      editRevision: draft.editRevision + 1,
      baseline: draft.baseline,
      typeDraft: draft.typeDraft,
    );
    await db.customStatement(
      'INSERT INTO drafts(id,entity_id,base_revision,payload,updated_at_utc) VALUES (?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,updated_at_utc=excluded.updated_at_utc',
      [
        next.id,
        next.entry.id,
        next.entry.revision,
        jsonEncode({
          ...next.entry.toJson(),
          'editRevision': next.editRevision,
          'draftBaseline': ?next.baseline,
          'orgaTypeDraft': next.typeDraft.toJson(),
        }),
        next.updatedAtUtc,
      ],
    );
    return next;
  });
  Future<void> _checkOrgaDraft(String id, int revision) async {
    final rows = await _rows('SELECT payload FROM drafts WHERE id=?', [id]);
    final actual = rows.isEmpty
        ? 0
        : (jsonDecode(rows.single['payload'] as String) as Map)['editRevision']
                  as int? ??
              0;
    if (actual != revision) throw const StaleRevision();
  }

  @override
  Future<List<EditDraft>> drafts() async =>
      (await _rows('SELECT * FROM drafts ORDER BY updated_at_utc DESC')).map((
        r,
      ) {
        final payload = jsonDecode(r['payload'] as String) as Json;
        final entry = OrgaEntry.fromJson(payload);
        if (entry.id != r['entity_id'] ||
            entry.revision != r['base_revision']) {
          throw const DomainError(
            'Ein Entwurf enthält widersprüchliche Versionsdaten. Der gespeicherte Entwurf bleibt erhalten.',
          );
        }
        return EditDraft(
          id: r['id'] as String,
          entry: entry,
          editRevision: payload['editRevision'] as int? ?? 0,
          updatedAtUtc: r['updated_at_utc'] as String,
          baseline: payload['draftBaseline'] as String?,
          typeDraft: OrgaTypeDraft.fromJson(
            Json.from(payload['orgaTypeDraft'] as Map? ?? const {}),
          ),
        );
      }).toList();
  @override
  Future<void> discardDraft(String id, {int? expectedRevision}) =>
      db.transaction(() async {
        if (expectedRevision != null) {
          await _checkOrgaDraft(id, expectedRevision);
        }
        await _detachDraftAttachments('orgaDraft', id);
        await db.customStatement('DELETE FROM drafts WHERE id=?', [id]);
      });
  @override
  Future<List<Json>> history(String entityId) => _rows(
    'SELECT * FROM revisions WHERE entity_id=? ORDER BY revision DESC',
    [entityId],
  );
  @override
  Future<Appearance> appearance() async {
    final rows = await _rows(
      "SELECT payload FROM preferences WHERE key='appearance'",
    );
    return rows.isEmpty
        ? const Appearance()
        : Appearance.fromJson(
            jsonDecode(rows.single['payload'] as String) as Json,
          );
  }

  @override
  Future<void> saveAppearance(Appearance appearance) async {
    Appearance.fromJson(appearance.toJson());
    await db.customStatement(
      "INSERT INTO preferences(key,payload) VALUES ('appearance',?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload",
      [jsonEncode(appearance.toJson())],
    );
  }

  @override
  Future<ObservationCatalog> observationCatalog(String key) async {
    final defaults = ObservationCatalog.defaults(key);
    final rows = await _rows('SELECT payload FROM preferences WHERE key=?', [
      'observation-$key',
    ]);
    return rows.isEmpty
        ? defaults
        : ObservationCatalog.fromJson(
            jsonDecode(rows.single['payload'] as String) as Json,
          );
  }

  @override
  Future<ObservationCatalog> _saveCatalog(
    String key,
    ObservationCatalog value,
  ) async {
    ObservationCatalog.fromJson(value.toJson());
    await db.customStatement(
      'INSERT INTO preferences(key,payload) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload',
      ['observation-$key', jsonEncode(value.toJson())],
    );
    return value;
  }

  @override
  Future<ObservationCatalog> saveObservationOptions(
    String key,
    List<String> options,
  ) => db.transaction(() async {
    final previous = await observationCatalog(key);
    final clean = options.map((v) => v.trim()).toList();
    if (clean.any((v) => v.isEmpty)) {
      throw const DomainError('Bitte leere Einträge ausfüllen oder entfernen.');
    }
    if (clean.any((v) => v.length > 150)) {
      throw const DomainError('Bitte höchstens 150 Zeichen verwenden.');
    }
    if (clean.length > 200) {
      throw const DomainError(
        'Bitte höchstens 200 Einträge pro Liste verwenden.',
      );
    }
    if (clean.map((v) => v.toLowerCase()).toSet().length != clean.length) {
      throw const DomainError(
        'Jeder Text darf nur einmal in derselben Liste vorkommen.',
      );
    }
    return _saveCatalog(
      key,
      ObservationCatalog(
        options: clean,
        favorites: previous.favorites.where(clean.contains).toList(),
      ),
    );
  });

  @override
  Future<ObservationCatalog> toggleObservationFavorite(
    String key,
    String text,
  ) => db.transaction(() async {
    final previous = await observationCatalog(key);
    if (!previous.options.contains(text)) {
      throw const DomainError('Diese Auswahl wurde inzwischen entfernt.');
    }
    final favorites = [...previous.favorites];
    if (!favorites.remove(text)) favorites.add(text);
    return _saveCatalog(
      key,
      ObservationCatalog(options: previous.options, favorites: favorites),
    );
  });

  @override
  Future<String> exportBackup() => db.transaction(() async {
    final tables = <String, dynamic>{};
    for (final table in backupTables) {
      tables[table] = await _rows('SELECT * FROM $table');
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'FLEX-Flutter-Rebuild-Backup',
      'version': 1,
      'schemaVersion': 8,
      'createdAtUtc': utcNow(),
      'tables': tables,
    });
  });
  Json _decode(String text) {
    if (text.length > 20000000) {
      throw const DomainError('Die Datei überschreitet 20 MB.');
    }
    final value = jsonDecode(text);
    if (value is! Map<String, dynamic>) {
      throw const DomainError('Kein gültiges JSON-Objekt.');
    }
    return value;
  }

  @override
  Future<void> restoreBackup(String text) async {
    final backup = _decode(text);
    final legacy =
        backup['format'] == 'FLEX-Flutter-Backup' && backup['version'] == 1;
    if ((!legacy &&
            (backup['format'] != 'FLEX-Flutter-Rebuild-Backup' ||
                !{7, 8}.contains(backup['schemaVersion']))) ||
        backup['version'] != 1 ||
        backup['tables'] is! Map) {
      throw const DomainError(
        'Diese Sicherung wird noch nicht unterstützt. Bitte eine vollständige FLEX-Sicherung verwenden. Vorhandene Daten bleiben erhalten.',
      );
    }
    final tables = Map<String, dynamic>.from(backup['tables'] as Map);
    final expected = legacy ? legacyTables : backupTables;
    if (tables.keys.toSet().difference(expected.toSet()).isNotEmpty ||
        tables.length != expected.length) {
      throw const DomainError(
        'Die Sicherung hat unbekannte oder fehlende Tabellen.',
      );
    }
    if (legacy) {
      for (final table in backupTables.where(
        (t) => !legacyTables.contains(t),
      )) {
        tables[table] = <Json>[];
      }
      tables['orga'] = (tables['orga'] as List)
          .map(
            (r) => <String, dynamic>{
              'deleted': 0,
              'reminder_text': '',
              'observed_on': '',
              'observed_time': '',
              ...Json.from(r as Map),
            },
          )
          .toList();
    }
    if (legacy || backup['schemaVersion'] == 7) {
      tables['pupils'] = (tables['pupils'] as List)
          .map(
            (r) => <String, dynamic>{
              'created_at_utc': null,
              'updated_at_utc': null,
              'deleted': 0,
              'deleted_at_utc': null,
              ...Json.from(r as Map),
            },
          )
          .toList();
      tables['devices'] = (tables['devices'] as List)
          .map(
            (r) => <String, dynamic>{
              'name': '',
              'platform': '',
              'created_at_utc': null,
              'last_seen_at_utc': null,
              'public_key_metadata': null,
              ...Json.from(r as Map),
            },
          )
          .toList();
    }
    // Storage accepts future envelopes; the application explicitly supports v1.
    if ((tables['operations'] as List).any(
      (r) => (r as Map)['protocol_version'] != 1,
    )) {
      throw const DomainError(
        'Diese Sicherung enthält ein neueres Änderungsformat. Bitte FLEX zuerst aktualisieren.',
      );
    }
    await db.transaction(() async {
      for (final table in backupTables.where(
        (t) => t != 'devices' && t != 'preferences',
      )) {
        if ((await _rows('SELECT COUNT(*) AS n FROM $table')).single['n'] !=
            0) {
          throw const DomainError(
            'Wiederherstellung ist nur in einem leeren Arbeitsbereich möglich. Die vorhandenen Daten bleiben erhalten.',
          );
        }
      }
      await db.customStatement('DELETE FROM preferences');
      for (final table in backupTables) {
        final columns = (await _rows(
          'PRAGMA table_info($table)',
        )).map((r) => r['name'] as String).toSet();
        final rows = tables[table];
        if (rows is! List || rows.length > 100000) {
          throw const DomainError('Ungültige Tabellendaten.');
        }
        // One worker round-trip per table, rather than one per history row.
        // The surrounding transaction still rolls back every table on failure.
        await db.batch((batch) {
          for (final value in rows) {
            final row = Map<String, dynamic>.from(value as Map);
            if (row.length != columns.length ||
                row.keys.toSet().difference(columns).isNotEmpty) {
              throw const DomainError('Unbekannte oder fehlende Datenfelder.');
            }
            final names = row.keys.toList();
            batch.customStatement(
              'INSERT INTO $table(${names.join(',')}) VALUES (${List.filled(names.length, '?').join(',')})${table == 'devices' ? ' ON CONFLICT(id) DO NOTHING' : ''}',
              names.map((n) => row[n]).toList(),
            );
          }
        });
      }
      for (final p in await pupils()) {
        p.validate();
      }
      for (final row in await _rows('SELECT * FROM orga')) {
        (await _entry(row)).validate();
      }
      await drafts();
      await dialogDrafts();
      await appearance();
      for (final key in observationDefaults.keys) {
        await observationCatalog(key);
      }
      for (final r in await schoolRecords()) {
        r.validate();
      }
      await schoolDrafts();
      await validateClassroomReferences();
      await schoolYears();
      await retentionPolicy();
      if ((await _rows('PRAGMA foreign_key_check')).isNotEmpty) {
        throw const DomainError('Die Sicherung enthält beschädigte Verweise.');
      }
    });
  }

  @override
  Future<LegacyReport> inspectLegacy(String text) async {
    final value = _decode(text);
    if (value['format'] == 'FLEX-Encrypted') {
      throw const DomainError(
        'Diese ältere Sicherung bitte zuerst in der ursprünglichen FLEX-Version öffnen und dort unverschlüsselt als JSON exportieren. Diese Exportdatei enthält persönliche Daten und sollte nach dem Import sicher entfernt werden.',
      );
    }
    if (value['version'] != 3 ||
        value['schemaVersion'] != 5 ||
        ![
          'students',
          'entries',
          'homework',
          'reminders',
        ].every((key) => value[key] is List)) {
      throw const DomainError(
        'Erwartet wird eine aktuelle HTML-Vollsicherung (Version 3, Schema 5).',
      );
    }
    // Inspection, never activation: unsupported domains/history remain verbatim.
    return LegacyReport(
      pupils: (value['students'] as List).length,
      entries: (value['entries'] as List).length,
      classTasks: (value['classTasks'] as List? ?? []).length,
      drafts:
          (value['savedDrafts'] as List? ?? []).length +
          (value['editorDrafts'] as List? ?? []).length,
    );
  }

  @override
  Future<void> stageLegacy(String text) async {
    await inspectLegacy(text);
    final id = const Uuid().v5(Namespace.url.value, text);
    await db.customStatement(
      'INSERT INTO legacy_backups(id,original_json,captured_at_utc) VALUES (?,?,?) ON CONFLICT(id) DO NOTHING',
      [id, text, utcNow()],
    );
  }

  @override
  Future<int> legacyCount() async =>
      (await _rows('SELECT COUNT(*) AS n FROM legacy_backups')).single['n']
          as int;
  @override
  Future<void> close() => db.close();
}
