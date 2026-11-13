part of 'sqlite_notebook.dart';

class _ImportedSnapshot implements Exception {
  const _ImportedSnapshot(this.data, this.tables);
  final NotebookSnapshot data;
  final Map<String, dynamic> tables;
}

/// Uses a rolled-back savepoint to run the *same* strict restore validation as
/// an empty installation. No imported row is visible to other connections and
/// no successful preview commits a change to the working database.
mixin BackupMergeStore on SchoolStore {
  Future<String> exportBackup();
  Future<void> restoreBackup(String text);
  Future<NotebookSnapshot> snapshot();
  Future<List<Pupil>> pupils();
  Future<Pupil> savePupil(Pupil value);
  Future<OrgaEntry> saveEntry(
    OrgaEntry value, {
    String? draftId,
    int? draftRevision,
  });
  Future<List<EditDraft>> drafts();
  Future<List<DialogDraft>> dialogDrafts();
  Future<Appearance> appearance();
  Future<ObservationCatalog> observationCatalog(String key);
  Future<List<ClassroomDocument>> classroomDocuments();
  Future<ClassroomDocument> saveClassroomDocument(
    ClassroomDocument value, {
    DialogDraft? draft,
  });
  Future<void> validateClassroomReferences();

  Future<_ImportedSnapshot> _inspectIncoming(String text) async {
    try {
      await db.transaction(() async {
        // Dependency order, not backup serialization order.
        for (final table in [
          'outbox',
          'operations',
          'revisions',
          'school_drafts',
          'pupil_drafts',
          'context_drafts',
          'group_drafts',
          'group_saves',
          'school_records',
          'situation_pupils',
          'situations',
          'drafts',
          'orga_items',
          'orga',
          'pupils',
          'legacy_backups',
          'preferences',
        ]) {
          await db.customStatement('DELETE FROM $table');
        }
        await restoreBackup(text);
        final data = await snapshot();
        final tables =
            (jsonDecode(await exportBackup()) as Map)['tables']
                as Map<String, dynamic>;
        // Roll back the nested transaction even on a valid incoming backup.
        throw _ImportedSnapshot(data, tables);
      });
    } on _ImportedSnapshot catch (result) {
      return result;
    }
  }

  String _tablesStamp(Map tables) => canonical({
    for (final table in tables.entries)
      table.key: (table.value as List).map(canonical).toList()..sort(),
  });
  Json _references(Json value, Map<String, String> links) {
    dynamic visit(dynamic item, [String? key]) {
      if (item is Map) {
        return {
          for (final entry in item.entries)
            entry.key: visit(entry.value, entry.key as String),
        };
      }
      if (item is List) {
        final values = item.map((v) => visit(v, key)).toList();
        return key == 'pupilIds' ? values.toSet().toList() : values;
      }
      if (item is String &&
          const {
            'pupilId',
            'pupilIds',
            'pupil_id',
            'participantIds',
            'recipients',
          }.contains(key)) {
        return links[item] ?? item;
      }
      return item;
    }

    return Json.from(visit(value) as Map);
  }

  Future<BackupMergePlan> prepareBackupMerge(
    String text, {
    Map<String, String> pupilLinks = const {},
    bool catalogs = true,
  }) => db.transaction(() async {
    final local = await snapshot();
    final localTables =
        (jsonDecode(await exportBackup()) as Map)['tables'] as Map;
    final source = await _inspectIncoming(text);
    final sameNames = <String, List<Pupil>>{};
    final localIds = local.pupils.map((p) => p.id).toSet();
    for (final pupil in source.data.pupils.where(
      (p) => !localIds.contains(p.id),
    )) {
      final matches = local.pupils
          .where(
            (p) =>
                p.name.trim().toLowerCase() == pupil.name.trim().toLowerCase(),
          )
          .toList();
      if (matches.isNotEmpty && !pupilLinks.containsKey(pupil.id)) {
        sameNames[pupil.id] = matches;
      }
    }
    for (final link in pupilLinks.entries) {
      if (!source.data.pupils.any((p) => p.id == link.key) ||
          (link.value != link.key && !localIds.contains(link.value)) ||
          (localIds.contains(link.key) && link.key != link.value)) {
        throw const DomainError('Ungültige Schülerzuordnung.');
      }
    }
    final items = <MergeItem>[];
    final seen = <String>{};
    for (final pupil in source.data.pupils) {
      final id = pupilLinks[pupil.id] ?? pupil.id;
      if (!seen.add(id)) {
        throw const DomainError(
          'Mehrere Schüler der Sicherung dürfen nicht derselben Person zugeordnet werden.',
        );
      }
      items.add(
        MergeItem(
          kind: 'pupil',
          id: id,
          label: pupil.name,
          incoming: {...pupil.toJson(), 'id': id},
          local: local.pupils.where((p) => p.id == id).firstOrNull?.toJson(),
        ),
      );
    }
    for (final entry in source.data.entries) {
      final incoming = _references(entry.toJson(), pupilLinks);
      final old = local.entries
          .where((e) => e.id == entry.id)
          .firstOrNull
          ?.toJson();
      if (old != null && old['pupilId'] != incoming['pupilId']) {
        throw const DomainError(
          'Dieselbe Eintrags-ID ist unterschiedlichen Schülern zugeordnet. Der Import wurde gestoppt.',
        );
      }
      items.add(
        MergeItem(
          kind: 'orga',
          id: entry.id,
          label: entry.title,
          incoming: incoming,
          local: old,
        ),
      );
    }
    for (final record in source.data.records) {
      final incoming = _references(record.toJson(), pupilLinks);
      final old = local.records
          .where((r) => r.id == record.id)
          .firstOrNull
          ?.toJson();
      if (old != null && old['pupilId'] != incoming['pupilId']) {
        throw const DomainError(
          'Dieselbe Eintrags-ID ist unterschiedlichen Schülern zugeordnet. Der Import wurde gestoppt.',
        );
      }
      items.add(
        MergeItem(
          kind: 'school',
          id: record.id,
          label: '${record.kind.label} · ${record.title}',
          incoming: incoming,
          local: old,
        ),
      );
    }
    for (final doc in source.data.classroom) {
      final incoming = _references(doc.toJson(), pupilLinks);
      final old = local.classroom.where((d) => d.id == doc.id).firstOrNull;
      if (old != null && old.kind != doc.kind) {
        throw const DomainError(
          'Dieselbe Klassen-ID hat unterschiedliche Eintragsarten.',
        );
      }
      items.add(
        MergeItem(
          kind: 'classroom',
          id: doc.id,
          label: '${doc.label} · ${doc.title}',
          incoming: incoming,
          local: old?.toJson(),
        ),
      );
    }
    for (final row in (source.tables['preferences'] as List).cast<Map>()) {
      final key = row['key'] as String;
      // Device state and entity-specific metadata are not global options.
      if (key != 'appearance' &&
          (!catalogs || !key.startsWith('observation-'))) {
        continue;
      }
      final old = (localTables['preferences'] as List)
          .where((p) => p['key'] == key)
          .firstOrNull;
      final incoming = jsonDecode(row['payload'] as String);
      final current = old == null ? null : jsonDecode(old['payload'] as String);
      items.add(
        MergeItem(
          kind: 'preference',
          id: key,
          label: key == 'appearance'
              ? 'Darstellung'
              : 'Beobachtungsoptionen · $key',
          incoming: incoming is Map
              ? Json.from(incoming)
              : {'options': incoming},
          local: current == null
              ? null
              : current is Map
              ? Json.from(current)
              : {'options': current},
        ),
      );
    }
    return BackupMergePlan(
      original: text,
      catalogs: catalogs,
      localStamp: _tablesStamp(localTables),
      items: items,
      pupilLinks: Map.of(pupilLinks),
      sameNames: sameNames,
      draftCount:
          source.data.drafts.length +
          source.data.schoolDrafts.length +
          source.data.dialogDrafts.length,
    );
  });
  Future<void> _insertRow(String table, Json row) async {
    final keys = row.keys.toList();
    await db.customStatement(
      'INSERT INTO $table(${keys.join(',')}) VALUES (${List.filled(keys.length, '?').join(',')})',
      keys.map((k) => row[k]).toList(),
    );
  }

  Future<void> applyBackupMerge(
    BackupMergePlan plan,
    Map<String, Set<String>> incomingFields,
  ) => db.transaction(() async {
    final currentTables =
        (jsonDecode(await exportBackup()) as Map)['tables'] as Map;
    if (_tablesStamp(currentTables) != plan.localStamp) {
      throw const DomainError(
        'Der Datenstand hat sich seit der Vorschau geändert. Bitte den Import erneut öffnen.',
      );
    }
    // Re-validate instead of trusting caller-editable model maps.
    final checked = await prepareBackupMerge(
      plan.original,
      pupilLinks: plan.pupilLinks,
      catalogs: plan.catalogs,
    );
    if (checked.sameNames.isNotEmpty) {
      throw const DomainError('Bitte gleichnamige Schüler zuerst zuordnen.');
    }
    final source = await _inspectIncoming(plan.original);
    final tables = source.tables;
    final now = utcNow();
    final newIds = checked.items
        .where((i) => i.isNew)
        .map((i) => '${i.kind}:${i.id}')
        .toSet();
    for (final row in (tables['devices'] as List).cast<Map>()) {
      await db.customStatement(
        'INSERT INTO devices(id) VALUES (?) ON CONFLICT(id) DO NOTHING',
        [row['id']],
      );
    }
    for (final item in checked.items.where((i) => i.kind == 'pupil')) {
      final resolved = item.resolve(incomingFields[item.key] ?? {});
      final pupil = Pupil.fromJson(resolved);
      pupil.validate();
      if (item.isNew) {
        await _insertRow('pupils', {
          'id': pupil.id,
          'name': pupil.name,
          'color': pupil.color,
          'archived': pupil.archived ? 1 : 0,
          'revision': pupil.revision,
        });
      } else if (canonical(resolved) != canonical(item.local)) {
        await savePupil(pupil);
      }
    }
    // Preserve imported context groups. A diverged context gets its own ID.
    final contextLinks = <String, String>{};
    for (final value in (tables['situations'] as List).cast<Map>()) {
      final row = Json.from(value), id = value['id'] as String;
      final payload = _references(
        Json.from(jsonDecode(row['payload'] as String) as Map),
        checked.pupilLinks,
      );
      final old = await _rows('SELECT * FROM situations WHERE id=?', [id]);
      if (old.isNotEmpty &&
          canonical(jsonDecode(old.single['payload'] as String)) ==
              canonical(payload)) {
        contextLinks[id] = id;
        continue;
      }
      final target = old.isEmpty
          ? id
          : const Uuid().v5(Namespace.url.value, '$id:${canonical(payload)}');
      contextLinks[id] = target;
      if ((await _rows('SELECT id FROM situations WHERE id=?', [
        target,
      ])).isNotEmpty) {
        continue;
      }
      await _insertRow('situations', {
        ...row,
        'id': target,
        'payload': jsonEncode(payload),
      });
      for (final participant in (tables['situation_pupils'] as List).where(
        (r) => r['situation_id'] == id,
      )) {
        final pupil =
            checked.pupilLinks[participant['pupil_id']] ??
            participant['pupil_id'];
        await db.customStatement(
          'INSERT OR IGNORE INTO situation_pupils(situation_id,pupil_id) VALUES (?,?)',
          [target, pupil],
        );
      }
    }
    final checklistLinks = <String, String>{};
    // Orga records include their checklist and appointment metadata.
    for (final item in checked.items.where((i) => i.kind == 'orga')) {
      final resolved = item.resolve(incomingFields[item.key] ?? {});
      final entry = OrgaEntry.fromJson(resolved);
      entry.validate();
      if (item.isNew) {
        final row = Json.from(
          (tables['orga'] as List).singleWhere((r) => r['id'] == item.id)
              as Map,
        );
        await _insertRow('orga', {...row, 'pupil_id': entry.pupilId});
        for (final raw in (tables['orga_items'] as List).where(
          (r) => r['orga_id'] == item.id,
        )) {
          final check = Json.from(raw as Map);
          if ((await _rows('SELECT id FROM orga_items WHERE id=?', [
            check['id'] as String,
          ])).isNotEmpty) {
            final previousId = check['id'] as String;
            check['id'] = const Uuid().v5(
              Namespace.url.value,
              '${item.id}:$previousId',
            );
            checklistLinks[previousId] = check['id'] as String;
          }
          await _insertRow('orga_items', check);
        }
        final metadata = (tables['preferences'] as List)
            .where((r) => r['key'] == 'orga-time-${item.id}')
            .firstOrNull;
        if (metadata != null) {
          await db.customStatement(
            'INSERT OR REPLACE INTO preferences(key,payload) VALUES (?,?)',
            [metadata['key'], metadata['payload']],
          );
        }
      } else if (canonical(resolved) != canonical(item.local)) {
        await saveEntry(entry);
      }
    }
    final school = checked.items.where((i) => i.kind == 'school').toList()
      ..sort(
        (a, b) => (a.incoming['kind'] == 'goal' ? 0 : 1).compareTo(
          b.incoming['kind'] == 'goal' ? 0 : 1,
        ),
      );
    for (final item in school) {
      var resolved = item.resolve(incomingFields[item.key] ?? {});
      if (item.isNew) {
        resolved = {
          ...resolved,
          'situationId':
              contextLinks[resolved['situationId']] ?? resolved['situationId'],
        };
        final record = SchoolRecord.fromJson(resolved);
        record.validate();
        await _insertRow('school_records', {
          'id': record.id,
          'pupil_id': record.pupilId,
          'situation_id': record.situationId,
          'revision': record.revision,
          'payload': jsonEncode(record.toJson()),
        });
      } else if (canonical(resolved) != canonical(item.local)) {
        // Mixing a context field must not mutate other records in the group.
        if ([
          'context',
          'participantIds',
          'otherParticipants',
        ].any((k) => canonical(resolved[k]) != canonical(item.local![k]))) {
          resolved['situationId'] = null;
        }
        await saveSchoolRecord(SchoolRecord.fromJson(resolved));
      }
    }
    final draftLinks = <String, String>{};
    final importedScans = <String>[];
    // Draft IDs are deduplicated; a divergent draft is kept as a second draft.
    for (final table in [
      'drafts',
      'school_drafts',
      'pupil_drafts',
      'context_drafts',
      'group_drafts',
    ]) {
      final importedRows = (tables[table] as List).cast<Map>().toList();
      if (table == 'context_drafts') {
        // Resolve owners before comparing linked scan drafts for duplicates.
        int rank(Map row) =>
            {
              'bulk',
              'classroom',
            }.contains((jsonDecode(row['payload'] as String) as Map)['type'])
            ? 0
            : 1;
        importedRows.sort((a, b) => rank(a).compareTo(rank(b)));
      }
      for (final raw in importedRows) {
        final row = Json.from(raw), id = raw['id'] as String;
        final old = await _rows('SELECT * FROM $table WHERE id=?', [id]);
        String draftSignature(Json row) {
          final payload = Json.from(
            jsonDecode(row['payload'] as String) as Map,
          );
          if (payload['format'] == 'flex-dialog-draft-1') payload.remove('id');
          return canonical({...row, 'id': '', 'payload': payload});
        }

        final payload = _references(
          Json.from(jsonDecode(row['payload'] as String) as Map),
          checked.pupilLinks,
        );
        if (table == 'drafts') {
          for (final item in (payload['items'] as List? ?? [])) {
            item['id'] = checklistLinks[item['id']] ?? item['id'];
          }
        }
        if (table == 'school_drafts') {
          final record = payload['record'] as Map;
          record['situationId'] =
              contextLinks[record['situationId']] ?? record['situationId'];
        }
        if (payload['format'] == 'flex-dialog-draft-1') {
          if (payload['type'] == 'pupil') {
            final target =
                checked.pupilLinks[payload['ownerId']] ?? payload['ownerId'];
            payload['ownerId'] = target;
            (payload['data'] as Map)['id'] = target;
            row['entity_id'] = target;
          } else if (payload['type'] == 'context') {
            final target =
                contextLinks[payload['ownerId']] ?? payload['ownerId'];
            payload['ownerId'] = target;
            row['entity_id'] = target;
          } else if (payload['type'] == 'bulk') {
            final data = payload['data'] as Map;
            final individual = data['individual'] as Map;
            data['individual'] = {
              for (final entry in individual.entries)
                checked.pupilLinks[entry.key] ?? entry.key: entry.value,
            };
          }
        }
        if (payload['format'] == 'flex-dialog-draft-1' &&
            payload['type'] == 'scan') {
          final data = payload['data'] as Map;
          data['links'] = [
            for (final rawLink in data['links'] as List)
              {
                ...Json.from(rawLink as Map),
                'id':
                    draftLinks['${rawLink['kind']}:${rawLink['id']}'] ??
                    rawLink['id'],
              },
          ];
        }
        row['payload'] = jsonEncode(payload);
        final duplicate = (await _rows('SELECT * FROM $table'))
            .where(
              (existing) => draftSignature(existing) == draftSignature(row),
            )
            .firstOrNull;
        final linkKind = switch (table) {
          'drafts' => 'orgaDraft',
          'school_drafts' => 'schoolDraft',
          _ => payload['type'] == 'classroom' ? 'classroomDraft' : 'bulkDraft',
        };
        if (duplicate != null) {
          draftLinks['$linkKind:$id'] = duplicate['id'] as String;
          continue;
        }
        if (old.isNotEmpty) {
          row['id'] = newId();
          if (payload['format'] == 'flex-dialog-draft-1') {
            payload['id'] = row['id'];
          }
        }
        row['payload'] = jsonEncode(payload);
        draftLinks['$linkKind:$id'] = row['id'] as String;
        if (table == 'context_drafts' && payload['type'] == 'scan') {
          importedScans.add(row['id'] as String);
        }
        await _insertRow(table, row);
      }
    }
    List<Json> remapDraftLinks(Object? rows) => [
      for (final raw in rows as List? ?? [])
        {
          ...Json.from(raw as Map),
          'id': draftLinks['${raw['kind']}:${raw['id']}'] ?? raw['id'],
        },
    ];
    // A scan may appear before its owner in the imported table. Resolve links
    // only after every imported draft has a final (possibly deduplicated) ID.
    for (final id in importedScans) {
      final row = (await _rows(
        'SELECT payload FROM context_drafts WHERE id=?',
        [id],
      )).single;
      final payload = Json.from(jsonDecode(row['payload'] as String) as Map);
      final data = Json.from(payload['data'] as Map);
      payload['data'] = {...data, 'links': remapDraftLinks(data['links'])};
      await db.customStatement(
        'UPDATE context_drafts SET payload=? WHERE id=?',
        [jsonEncode(payload), id],
      );
    }
    // Import all classroom documents before checking their cross-links; lessons
    // can refer to material appearing later in the same backup.
    for (final item in checked.items.where((i) => i.kind == 'classroom')) {
      final resolved = item.resolve(incomingFields[item.key] ?? {});
      if (resolved.containsKey('links') &&
          (item.isNew || (incomingFields[item.key] ?? {}).contains('links'))) {
        resolved['links'] = remapDraftLinks(resolved['links']);
      } else if (resolved.containsKey('links') &&
          canonical(item.incoming['links']) ==
              canonical(item.local?['links'])) {
        // An unchanged shared file can belong to both diverged owner drafts.
        final incomingLinks = remapDraftLinks(item.incoming['links']);
        if (canonical(incomingLinks) != canonical(resolved['links'] ?? [])) {
          resolved['links'] = {
            for (final row in [
              ...(resolved['links'] as List? ?? []),
              ...incomingLinks,
            ])
              DocumentLink.fromJson(Json.from(row as Map)).identity: row,
          }.values.toList();
        }
      }
      final doc = ClassroomDocument.fromJson(resolved);
      if (item.isNew) {
        await db.customStatement(
          'INSERT INTO preferences(key,payload) VALUES (?,?)',
          ['classroom:${doc.id}', jsonEncode(doc.toJson())],
        );
      } else if (canonical(resolved) != canonical(item.local)) {
        // Use the normal revision/audit writer after all rows have been staged.
        final saved = doc.patch({
          'revision': doc.revision + 1,
          'updatedAtUtc': utcNow(),
        });
        await db.customStatement(
          'UPDATE preferences SET payload=? WHERE key=?',
          [jsonEncode(saved.toJson()), 'classroom:${doc.id}'],
        );
        await _audit(
          'classroom',
          doc.id,
          doc.revision,
          item.local,
          saved.toJson(),
        );
      }
    }
    for (final item in checked.items.where((i) => i.kind == 'preference')) {
      final resolved = item.resolve(incomingFields[item.key] ?? {});
      await db.customStatement(
        'INSERT INTO preferences(key,payload) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload',
        [item.id, jsonEncode(resolved)],
      );
    }
    // Retain original history for newly added entities. Conflicting historical
    // branches and device sequences remain in the complete import archive.
    for (final raw in (tables['revisions'] as List).cast<Map>()) {
      final kind = raw['entity_kind'] == 'school'
          ? 'school'
          : raw['entity_kind'];
      if (!newIds.contains('$kind:${raw['entity_id']}')) continue;
      final row = Json.from(raw);
      if ((await _rows('SELECT id FROM revisions WHERE id=?', [
        row['id'] as String,
      ])).isNotEmpty) {
        row['id'] = newId();
      }
      await _insertRow('revisions', row);
    }
    for (final value in (tables['legacy_backups'] as List).cast<Map>()) {
      if ((await _rows('SELECT id FROM legacy_backups WHERE id=?', [
        value['id'] as String,
      ])).isEmpty) {
        await _insertRow('legacy_backups', Json.from(value));
      }
    }
    // Validate cross-entity links, which SQLite cannot express inside JSON.
    final allRecords = await schoolRecords();
    final allPupils = (await pupils()).map((p) => p.id).toSet();
    for (final record in allRecords) {
      record.validate();
      if (!allPupils.contains(record.pupilId) ||
          !allPupils.containsAll(record.participantIds) ||
          record.goalId != null &&
              !allRecords.any(
                (r) =>
                    r.id == record.goalId &&
                    r.pupilId == record.pupilId &&
                    r.kind == SchoolKind.goal,
              )) {
        throw const DomainError(
          'Die gewählte Zusammenführung enthält ungültige Verknüpfungen. Bitte die Feldentscheidungen prüfen.',
        );
      }
    }
    await drafts();
    await schoolDrafts();
    await dialogDrafts();
    await validateClassroomReferences();
    await appearance();
    for (final key in observationDefaults.keys) {
      await observationCatalog(key);
    }
    if ((await _rows('PRAGMA foreign_key_check')).isNotEmpty) {
      throw const DomainError(
        'Die Zusammenführung enthält ungültige Verweise.',
      );
    }
    final digest = (await Sha256().hash(
      utf8.encode(canonical(jsonDecode(plan.original))),
    )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await db.customStatement(
      'INSERT INTO preferences(key,payload) VALUES (?,?) ON CONFLICT(key) DO NOTHING',
      [
        'import-archive-$digest',
        jsonEncode({
          'importedAt': now,
          'encoding': 'json',
          'original': plan.original,
        }),
      ],
    );
    // Keep the result exportable by the same documented backup format.
    if (utf8.encode(await exportBackup()).length > 20000000) {
      throw const DomainError(
        'Die Zusammenführung wäre größer als das Sicherungslimit von 20 MB. Es wurde nichts geändert.',
      );
    }
  });
  Future<List<Json>> importArchives() async =>
      (await _rows(
            "SELECT key,payload FROM preferences WHERE key LIKE 'import-archive-%' ORDER BY key",
          ))
          .map(
            (row) => <String, dynamic>{
              'id': row['key'],
              'importedAt':
                  (jsonDecode(row['payload'] as String) as Map)['importedAt'],
            },
          )
          .toList();
  Future<String> importArchive(String id) async {
    if (!id.startsWith('import-archive-')) {
      throw const DomainError('Unbekanntes Importarchiv.');
    }
    final rows = await _rows('SELECT payload FROM preferences WHERE key=?', [
      id,
    ]);
    if (rows.isEmpty) throw const DomainError('Importarchiv nicht vorhanden.');
    final data = jsonDecode(rows.single['payload'] as String) as Map;
    return data['original'] as String;
  }
}
