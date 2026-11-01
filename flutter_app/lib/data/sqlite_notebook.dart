import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../domain/models.dart';
import '../domain/repository.dart';
import '../domain/school.dart';
import 'database.dart';
part 'school_store.dart';

class SqliteNotebook with SchoolStore implements NotebookRepository {
  SqliteNotebook(this.db);
  @override
  final NotebookDatabase db;
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
    });
  }

  Pupil _pupil(Json row) => Pupil(
    id: row['id'] as String,
    name: row['name'] as String,
    color: row['color'] as int,
    archived: row['archived'] == 1,
    revision: row['revision'] as int,
  );
  @override
  Future<List<Pupil>> pupils() async => (await _rows(
    'SELECT * FROM pupils ORDER BY name COLLATE NOCASE,id',
  )).map(_pupil).toList();
  @override
  Future<Pupil> savePupil(Pupil pupil) async {
    pupil.validate();
    return db.transaction(() async {
      final old = await _rows('SELECT * FROM pupils WHERE id=?', [pupil.id]);
      if ((old.isEmpty ? 0 : old.single['revision']) != pupil.revision) {
        throw const StaleRevision();
      }
      final saved = pupil.copyWith(
        name: pupil.name.trim(),
        revision: pupil.revision + 1,
      );
      await db.customStatement(
        'INSERT INTO pupils(id,name,color,archived,revision) VALUES (?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,color=excluded.color,archived=excluded.archived,revision=excluded.revision',
        [
          saved.id,
          saved.name,
          saved.color,
          saved.archived ? 1 : 0,
          saved.revision,
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
    return OrgaEntry(
      id: row['id'] as String,
      pupilId: row['pupil_id'] as String?,
      title: row['title'] as String,
      body: row['body'] as String,
      isTask: row['is_task'] == 1,
      done: row['done'] == 1,
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
  Future<OrgaEntry> saveEntry(OrgaEntry entry, {String? draftId}) async {
    entry.validate();
    return db.transaction(() async {
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
      await _audit(
        'orga',
        saved.id,
        entry.revision,
        old?.toJson(),
        saved.toJson(),
      );
      if (draftId != null) {
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
  Future<void> saveDraft(EditDraft draft) async => db.customStatement(
    'INSERT INTO drafts(id,entity_id,base_revision,payload,updated_at_utc) VALUES (?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,updated_at_utc=excluded.updated_at_utc',
    [
      draft.id,
      draft.entry.id,
      draft.entry.revision,
      jsonEncode(draft.entry.toJson()),
      draft.updatedAtUtc,
    ],
  );
  @override
  Future<List<EditDraft>> drafts() async =>
      (await _rows('SELECT * FROM drafts ORDER BY updated_at_utc DESC')).map((
        r,
      ) {
        final entry = OrgaEntry.fromJson(
          jsonDecode(r['payload'] as String) as Json,
        );
        if (entry.id != r['entity_id'] ||
            entry.revision != r['base_revision']) {
          throw const DomainError(
            'Ein Entwurf enthält widersprüchliche Versionsdaten. Der gespeicherte Entwurf bleibt erhalten.',
          );
        }
        return EditDraft(
          id: r['id'] as String,
          entry: entry,
          updatedAtUtc: r['updated_at_utc'] as String,
        );
      }).toList();
  @override
  Future<void> discardDraft(String id) =>
      db.customStatement('DELETE FROM drafts WHERE id=?', [id]);
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
  Future<String> exportBackup() => db.transaction(() async {
    final tables = <String, dynamic>{};
    for (final table in backupTables) {
      tables[table] = await _rows('SELECT * FROM $table');
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'FLEX-Flutter-Rebuild-Backup',
      'version': 1,
      'schemaVersion': 7,
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
                backup['schemaVersion'] != 7)) ||
        backup['version'] != 1 ||
        backup['tables'] is! Map) {
      throw const DomainError(
        'Keine unterstützte Vollsicherung. Die Rekonstruktion importiert ihre eigenen Sicherungen sowie Flutter 0.1.0; für andere Stände ist eine gesonderte Migration erforderlich.',
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
    await db.transaction(() async {
      for (final table in backupTables.where(
        (t) => t != 'devices' && t != 'preferences',
      )) {
        if ((await _rows('SELECT COUNT(*) AS n FROM $table')).single['n'] !=
            0) {
          throw const DomainError(
            'Wiederherstellung ist nur in einem leeren Arbeitsbereich möglich. Der vorhandene Datenstand bleibt erhalten.',
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
        for (final value in rows) {
          final row = Map<String, dynamic>.from(value as Map);
          if (row.length != columns.length ||
              row.keys.toSet().difference(columns).isNotEmpty) {
            throw const DomainError('Unbekannte oder fehlende Datenfelder.');
          }
          final names = row.keys.toList();
          await db.customStatement(
            'INSERT INTO $table(${names.join(',')}) VALUES (${List.filled(names.length, '?').join(',')})${table == 'devices' ? ' ON CONFLICT(id) DO NOTHING' : ''}',
            names.map((n) => row[n]).toList(),
          );
        }
      }
      for (final p in await pupils()) {
        p.validate();
      }
      for (final row in await _rows('SELECT * FROM orga')) {
        (await _entry(row)).validate();
      }
      await drafts();
      await appearance();
      for (final r in await schoolRecords()) {
        r.validate();
      }
      await schoolDrafts();
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
        'Diese Sicherung ist verschlüsselt. Bitte im unveränderten HTML-Prototyp öffnen und für die Migration als JSON exportieren.',
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
