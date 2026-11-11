part of 'sqlite_notebook.dart';

extension DraftDocumentStore on SqliteNotebook {
  // Called inside the owner's transaction. Files are never deleted here.
  // Updating scan-source revisions keeps resumed image edits consistent.
  Future<void> _rewriteAttachmentLinks(
    bool Function(DocumentLink) matches,
    List<DocumentLink> Function(DocumentLink) replace, {
    Set<String> addedPupils = const {},
  }) async {
    List<Json> rewrite(List<Json> rows) => {
      for (final row in rows)
        for (final link in [DocumentLink.fromJson(row)])
          for (final next in matches(link) ? replace(link) : [link])
            next.identity: next.toJson(),
    }.values.toList();
    bool affected(List<Json> rows) =>
        rows.any((row) => matches(DocumentLink.fromJson(row)));
    final revisions = <String, (int, int)>{};
    for (final d in await classroomDocuments()) {
      if (!affected(d.rows('links'))) continue;
      final saved = await _writeClassroom(
        d.patch({
          'links': rewrite(d.rows('links')),
          'pupilIds': {...d.strings('pupilIds'), ...addedPupils}.toList(),
        }),
      );
      revisions[d.id] = (d.revision, saved.revision);
    }
    for (final d in (await dialogDrafts()).where((d) => d.type == 'scan')) {
      final links = (d.data['links'] as List)
          .map((l) => Json.from(l as Map))
          .toList();
      final source = revisions[d.data['sourceId']];
      final updateSource =
          source != null && d.data['sourceRevision'] == source.$1;
      final changed = affected(links);
      if (!changed && !updateSource) continue;
      await saveDialogDraft(
        DialogDraft.fromJson({
          ...d.toJson(),
          'data': {
            ...d.data,
            'links': rewrite(links),
            if (changed)
              'pupilIds': {
                ...List<String>.from(d.data['pupilIds'] as List),
                ...addedPupils,
              }.toList(),
            if (updateSource) 'sourceRevision': source.$2,
          },
        }),
      );
    }
  }

  Future<void> _publishSchoolAttachments(
    String draftId,
    SchoolRecord template,
    List<SchoolRecord> records,
  ) => _rewriteAttachmentLinks(
    (link) => link.kind == 'schoolDraft' && link.id == draftId,
    (link) {
      final index = template.tasks.indexWhere((t) => t.id == link.taskId);
      return [
        for (final r in records)
          DocumentLink(
            'school',
            r.id,
            taskId: index >= 0 && index < r.tasks.length
                ? r.tasks[index].id
                : '',
          ),
      ];
    },
    addedPupils: records.map((r) => r.pupilId).toSet(),
  );

  Future<void> _recoverGroupAttachments(
    String draftKind,
    String draftId,
    List<SchoolRecord> records,
    List<OrgaEntry> entries,
    List<HomeworkTask> tasks,
  ) => _rewriteAttachmentLinks(
    (l) =>
        l.kind == 'school' && records.any((r) => r.id == l.id) ||
        l.kind == 'orga' && entries.any((e) => e.id == l.id),
    (l) {
      final record = records.where((r) => r.id == l.id).firstOrNull;
      final index = record?.tasks.indexWhere((t) => t.id == l.taskId) ?? -1;
      // Preserve the link to the trashed publication as well as its recovered
      // draft. Files stay accessible through history and the resumable draft.
      return [
        l,
        DocumentLink(
          draftKind,
          draftId,
          taskId: index >= 0 && index < tasks.length ? tasks[index].id : '',
        ),
      ];
    },
  );

  Future<void> _detachDraftAttachments(String kind, String id) =>
      _rewriteAttachmentLinks((l) => l.kind == kind && l.id == id, (_) => []);
}
