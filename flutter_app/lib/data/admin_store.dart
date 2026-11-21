part of 'sqlite_notebook.dart';

class _AdminRollback implements Exception {
  const _AdminRollback(this.preview);
  final AdminDeletionPreview preview;
}

mixin AdminStore on PrivacyStore, ClassroomStore {
  Future<Pupil> savePupil(Pupil value);
  Future<void> discardDraft(String id, {int? expectedRevision});
  Future<void> discardDialogDraft(String id, int revision);
  Future<Set<String>> erasedDriveSources() async => {
    for (final r in await _rows(
      "SELECT key FROM preferences WHERE key LIKE 'erased-drive:%'",
    ))
      (r['key'] as String).substring('erased-drive:'.length),
  };
  Future<String> _fingerprint() async {
    final all = (jsonDecode(await exportBackup()) as Map)['tables'];
    return base64UrlEncode(
      (await Sha256().hash(utf8.encode(canonical(all)))).bytes,
    );
  }

  Future<Map<String, Map<String, String>>> _inventory() async {
    final f = <String, String>{};
    void addKeys(Iterable<String> keys) {
      for (final key in keys) {
        f[key] = '';
      }
    }

    final documents = await classroomDocuments(),
        dialogs = await dialogDrafts();
    for (final m in documents) {
      addKeys(materialFileKeys(m.toJson()));
    }
    for (final d in dialogs) {
      if (d.type == 'scan') {
        addKeys(scanFileKeys(d.data));
      } else if (d.type == 'classroom') {
        addKeys(materialFileKeys(d.data));
      }
    }
    return {
      'Schüler': {for (final p in await pupils()) p.id: p.revision.toString()},
      'Organisationseinträge': {
        for (final e in await entries()) e.id: e.revision.toString(),
      },
      'Schülereinträge': {
        for (final r in await schoolRecords()) r.id: r.revision.toString(),
      },
      'Materialien': {
        for (final m in documents.where(
          (d) => d.kind == ClassroomKind.material,
        ))
          m.id: m.revision.toString(),
      },
      'Klassendokumente': {
        for (final m in documents.where(
          (d) => d.kind != ClassroomKind.material,
        ))
          m.id: m.revision.toString(),
      },
      'Entwürfe': {
        for (final row in await _rows(
          "SELECT 'orga:'||id AS id FROM drafts UNION ALL SELECT 'school:'||id FROM school_drafts UNION ALL SELECT 'dialog:'||id FROM context_drafts UNION ALL SELECT 'group:'||id FROM group_drafts UNION ALL SELECT 'pupil:'||id FROM pupil_drafts",
        ))
          row['id'] as String: '',
      },
      'Dateien auf diesem Gerät': f,
      'Schuljahresarchive': {for (final y in await schoolYears()) y.id: ''},
      'Importkopien': {
        for (final row in await _rows(
          "SELECT id FROM legacy_backups UNION ALL SELECT key AS id FROM preferences WHERE key LIKE 'import-archive-%'",
        ))
          row['id'] as String: '',
      },
    };
  }

  Future<AdminDeletionPreview> previewAdminDeletion(AdminTarget target) async {
    // Exercise the exact cascade and its FK checks, entirely inside a rollback.
    try {
      return await db.transaction<AdminDeletionPreview>(() async {
        final stamp = await _fingerprint(), before = await _inventory();
        final title = await _applyAdminDeletion(target);
        final after = await _inventory(), changes = <String, int>{};
        var unlinked = 0;
        for (final e in before.entries) {
          final remaining = after[e.key]!;
          final removed = e.value.keys
              .where((k) => !remaining.containsKey(k))
              .length;
          if (removed > 0) changes[e.key] = removed;
          unlinked += e.value.keys
              .where(
                (k) => remaining.containsKey(k) && remaining[k] != e.value[k],
              )
              .length;
        }
        throw _AdminRollback(
          AdminDeletionPreview(target, title, stamp, changes, unlinked),
        );
      });
    } on _AdminRollback catch (done) {
      return done.preview;
    }
  }

  Future<void> deleteAdminSelection(
    AdminDeletionPreview preview,
  ) => db.transaction(() async {
    if (await _fingerprint() != preview.fingerprint) {
      throw const DomainError(
        'Die Auswahl hat sich inzwischen geändert. Bitte die Löschvorschau erneut öffnen.',
      );
    }
    await _applyAdminDeletion(preview.target);
  });

  Future<void> _discardRelatedDrafts(Set<String> ids) async {
    bool refers(Object? value) =>
        ids.any((id) => jsonEncode(value).contains(jsonEncode(id)));
    for (final draft in await dialogDrafts()) {
      if (!refers(draft.toJson())) continue;
      final group = List<String>.from(draft.data['recipients'] as List? ?? []);
      if (group.any(ids.contains) && group.any((p) => !ids.contains(p))) {
        throw const DomainError(
          'Ein offener Gruppenentwurf betrifft weitere Schüler. Bitte ihn zuerst speichern oder die betroffene Person aus dem Entwurf entfernen.',
        );
      }
      if (draft.type == 'scan') {
        for (final key in scanFileKeys(draft.data)) {
          await _preference('pending-file-delete:$key', {'key': key});
        }
      } else if (draft.type == 'classroom') {
        for (final key in materialFileKeys(draft.data)) {
          await _preference('pending-file-delete:$key', {'key': key});
        }
      }
      await discardDialogDraft(draft.id, draft.revision);
    }
    for (final d in await drafts()) {
      if (refers([d.entry.toJson(), d.typeDraft.toJson()])) {
        await discardDraft(d.id, expectedRevision: d.editRevision);
      }
    }
    for (final d in await schoolDrafts()) {
      if (refers([d.record.toJson(), d.recipients])) {
        if (d.recipients.any(ids.contains) &&
            d.recipients.any((p) => !ids.contains(p))) {
          throw const DomainError(
            'Bitte den gemeinsamen Schülerentwurf zuerst speichern.',
          );
        }
        await discardSchoolDraft(d.id, expectedRevision: d.editRevision);
      }
    }
  }

  Future<String> _applyAdminDeletion(AdminTarget target) async {
    final id = target.id, docs = await classroomDocuments();
    if (target.kind == 'all') {
      final inventory = await _inventory();
      final keys = inventory['Dateien auf diesem Gerät']!.keys.toSet();
      for (final table in SqliteNotebook.backupTables.reversed) {
        if (table == 'devices') continue;
        if (table == 'preferences') {
          await db.customStatement(
            "DELETE FROM preferences WHERE key NOT LIKE 'pending-file-delete:%'",
          );
        } else {
          await db.customStatement('DELETE FROM $table');
        }
      }
      await db.customStatement(
        "DELETE FROM devices WHERE id<>(SELECT value FROM metadata WHERE key='local_device_id')",
      );
      await db.customStatement("UPDATE devices SET name='Dieses Gerät'");
      await db.customStatement('DELETE FROM entry_search');
      for (final key in keys) {
        await _preference('pending-file-delete:$key', {'key': key});
      }
      return 'Gesamtes lokales Notizbuch';
    }
    String title;
    final people = <String>{}, entities = <String>{}, documents = <String>{};
    final orga = await entries(), records = await schoolRecords();
    switch (target.kind) {
      case 'pupil':
        final p = (await pupils()).where((v) => v.id == id).firstOrNull;
        if (p == null) throw const StaleRevision();
        title = p.name;
        people.add(id);
        entities.addAll(orga.where((e) => e.pupilId == id).map((e) => e.id));
        entities.addAll(records.where((e) => e.pupilId == id).map((e) => e.id));
        await _discardRelatedDrafts({id, ...entities});
        if (!p.deleted) {
          await savePupil(p.copyWith(deleted: true, archived: true));
        }
      case 'orga':
        final e = orga.where((v) => v.id == id).firstOrNull;
        if (e == null) throw const StaleRevision();
        title = e.title;
        entities.add(id);
      case 'school':
        final r = records.where((v) => v.id == id).firstOrNull;
        if (r == null) throw const StaleRevision();
        title = r.title.isEmpty ? r.kind.label : r.title;
        entities.add(id);
      case 'document':
        final d = docs.where((v) => v.id == id).firstOrNull;
        if (d == null) throw const StaleRevision();
        title = d.title;
        documents.add(id);
      default:
        throw const DomainError('Unbekannte Löschoption.');
    }
    await _discardRelatedDrafts({...entities, ...documents});
    for (final d in docs) {
      if (d.kind == ClassroomKind.repeat &&
          entities.contains(d.text('entryId'))) {
        documents.add(d.id);
      }
      if (d.kind == ClassroomKind.repeat &&
          !documents.contains(d.id) &&
          entities.isNotEmpty) {
        final dates = d
            .map('generated')
            .keys
            .where((date) => entities.contains(_repeatEntryId(d.id, date)));
        if (dates.isNotEmpty) {
          await saveClassroomDocument(
            d.patch({
              'excludedDates': {
                ...d.strings('excludedDates'),
                ...dates,
              }.toList(),
            }),
          );
        }
      }
      if (d.kind == ClassroomKind.material && entities.isNotEmpty) {
        final links = d.rows('links');
        if (links.isNotEmpty &&
            links.every((l) => entities.contains(l['id'])) &&
            d.strings('pupilIds').every(people.contains) &&
            !docs.any(
              (other) =>
                  other.id != d.id &&
                  jsonEncode(other.toJson()).contains(jsonEncode(d.id)),
            )) {
          documents.add(d.id);
        }
      }
    }
    // Purging a pupil also detaches them from shared work and its history.
    if (people.isNotEmpty) {
      await _purgeDeletedPupils(people);
    } else if (entities.isNotEmpty) {
      await _markAndPurge(entities);
    }
    await _eraseDocuments(documents);
    await validateClassroomReferences();
    if ((await _rows('PRAGMA foreign_key_check')).isNotEmpty) {
      throw const DomainError('Die Auswahl enthält noch verknüpfte Daten.');
    }
    return title;
  }
}
