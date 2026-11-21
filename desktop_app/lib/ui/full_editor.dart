part of 'workspace.dart';

extension _DesktopEntryWorkflows on _DesktopWorkspaceState {
  Future<String?> chooseEntryPupil(EntryKind kind) async {
    if (c.pupils.isEmpty) {
      throw const DomainError(
        'Bitte zuerst einen Schüler zur Klasse hinzufügen.',
      );
    }
    if (c.pupils.length == 1) return c.pupils.single.id;
    var query = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text('${kind.label} für …'),
          content: SizedBox(
            width: 420,
            height: 352,
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Schüler suchen',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) =>
                      update(() => query = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      for (final p in c.pupils.where(
                        (p) => p.name.toLowerCase().contains(query),
                      ))
                        ListTile(
                          leading: CircleAvatar(
                            radius: 8,
                            backgroundColor: Color(p.color),
                          ),
                          title: Text(p.name),
                          onTap: () => Navigator.pop(ctx, p.id),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> newDesktopEntry(
    EntryKind kind, {
    String? pupil,
    DateTime? onDate,
    Json? fields,
  }) async {
    var owner =
        pupil ?? (c.section == WorkspaceSection.journal ? c.pupil?.id : null);
    if (kind.school && owner == null) {
      owner = await chooseEntryPupil(kind);
      if (!mounted || owner == null) return;
    }
    await c.parkEditor();
    if (!mounted) return;
    final day = onDate ?? c.date;
    if (kind.school) {
      await editSchool(
        context,
        c.notebook,
        SchoolRecord.empty(
          SchoolKind.values.byName(kind.name),
          owner!,
        ).patch({'observedOn': dateOnly(day)}),
      );
    } else if (kind.orga) {
      final entry = OrgaEntry.fromJson({
        ...newEntry(kind, pupilId: owner, date: day),
        ...?fields,
      });
      await desktopOrgaEditor(entry);
    } else {
      await showClassroomEditor(
        context,
        c.notebook,
        ClassroomKind.values.byName(kind.name),
        date: kind == EntryKind.returnList ? null : dateOnly(day),
        fields: {
          if (owner != null && kind == EntryKind.returnList)
            'participants': [
              {
                'pupilId': owner,
                'name': c.name(owner),
                'status': 'open',
                'note': '',
                'paid': 0,
              },
            ]
          else if (owner != null)
            'pupilIds': [owner],
          ...?fields,
        },
      );
    }
  }

  Future<void> desktopOrgaEditor(OrgaEntry e, {String? draftId}) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => OrgaEditor(
          controller: c.notebook,
          entry: e,
          draftId: draftId,
          defaultToClassTask: false,
        ),
      );

  Future<void> openDesktopValue(Object value) async {
    if (value is ClassroomDocument && value.kind == ClassroomKind.material) {
      await c.edit(value);
      return;
    }
    await c.parkEditor();
    if (!mounted) return;
    final n = c.notebook;
    switch (value) {
      case SchoolDraft():
        await editSchool(context, n, value.record, draft: value);
      case EditDraft():
        await desktopOrgaEditor(value.entry, draftId: value.id);
      case DialogDraft():
        switch (value.type) {
          case 'scan':
            await showDocumentScanner(context, n, draft: value);
          case 'pupil':
            await editPupil(draft: value);
          case 'catalog':
            await showCatalog(context, n, value.ownerId, draft: value);
          case 'context':
            await showSituation(context, n, value.ownerId, draft: value);
          case 'bulk':
            await showBulk(context, n, draft: value);
          case 'classroom':
            if (value.data['kind'] == 'timetable' ||
                value.data['_timetableEditor'] == true) {
              await resumeTimetableDraft(context, n, value);
            } else {
              await showClassroomEditor(
                context,
                n,
                ClassroomKind.values.byName(value.data['kind'] as String),
                draft: value,
              );
            }
          default:
            throw const DomainError(
              'Dieser Entwurfstyp wird von dieser FLEX-Version noch nicht unterstützt.',
            );
        }
      case SchoolRecord():
        if (value.kind == SchoolKind.homework) {
          await showHomeworkDetail(context, n, value.id);
        } else {
          await editSchool(context, n, value);
        }
      case OrgaEntry():
        await desktopOrgaEditor(value);
      case ClassroomDocument():
        if (value.kind == ClassroomKind.returnList) {
          await showReturnDetail(context, n, value.id);
        } else {
          await showClassroomEditor(context, n, value.kind, document: value);
        }
    }
  }

  Future<void> expandQuickEditor() async {
    final session = c.editor;
    if (session == null) return;
    final data = Json.from(session.data),
        kind = session.kind,
        id = session.draftId;
    await c.parkEditor();
    if (!mounted) return;
    final drafts = <Object>[
      ...c.notebook.drafts.where((d) => d.id == id),
      ...c.notebook.schoolDrafts.where((d) => d.id == id),
      ...c.notebook.dialogDrafts.where((d) => d.id == id),
    ];
    if (drafts.isNotEmpty) {
      await openDesktopValue(drafts.single);
      return;
    }
    if (kind.orga) {
      await desktopOrgaEditor(OrgaEntry.fromJson(data));
      return;
    }
    if (kind.school) {
      await editSchool(context, c.notebook, SchoolRecord.fromJson(data));
      return;
    }
    await showClassroomEditor(
      context,
      c.notebook,
      ClassroomKind.values.byName(kind.name),
      fields: data,
    );
  }

  Future<void> openDeskCalendarItem(CalendarItem i) async {
    if (i.lesson != null) {
      await showCalendarItem(context, c.notebook, i);
      return;
    }
    final item = i.entry ?? i.record ?? i.document;
    if (item != null) await openDesktopValue(item);
  }
}
