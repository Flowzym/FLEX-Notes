import 'dart:convert';
import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/document_scanner.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import 'common.dart';
import 'detail_flow.dart';
import 'flex_modal.dart';
import 'material_library.dart';
import 'scan_editor.dart';

Set<String> legacyHomeworkGroup(String recordId, Iterable<Json> groups) {
  for (final row in groups.where((g) => g['undone_at_utc'] == null)) {
    final request = jsonDecode(row['request'] as String) as Map;
    final ids = homeworkGroupRecordIds(request);
    if (ids.contains(recordId)) return ids;
  }
  return {recordId};
}

Future<void> collectHomework(
  BuildContext context,
  NotebookController c,
  SchoolRecord entry,
) async {
  final ids = entry.homeworkGroup.isEmpty
      ? legacyHomeworkGroup(entry.id, await c.repository.schoolGroups())
      : <String>{};
  if (!context.mounted) return;
  await showFlexDetail<void>(
    context: context,
    builder: (_) => SubmissionCollection(
      controller: c,
      title: entry.title.isNotEmpty
          ? entry.title
          : entry.tasks.where((t) => t.parentId == null).firstOrNull?.text ??
                'Hausübung',
      homeworkIds: ids,
      homeworkGroup: entry.homeworkGroup,
    ),
  );
}

Future<void> collectReturn(
  BuildContext context,
  NotebookController c,
  ClassroomDocument entry,
) => showFlexDetail<void>(
  context: context,
  builder: (_) => SubmissionCollection(
    controller: c,
    title: entry.title,
    returnId: entry.id,
  ),
);

class SubmissionCollection extends StatefulWidget {
  const SubmissionCollection({
    super.key,
    required this.controller,
    required this.title,
    this.homeworkIds = const {},
    this.homeworkGroup = '',
    this.returnId,
  });
  final NotebookController controller;
  final String title, homeworkGroup;
  final Set<String> homeworkIds;
  final String? returnId;
  @override
  State<SubmissionCollection> createState() => _SubmissionCollectionState();
}

typedef _Recipient = ({
  Pupil pupil,
  ScanContext scope,
  String status,
  bool editable,
});

class _SubmissionCollectionState extends State<SubmissionCollection> {
  NotebookController get c => widget.controller;
  bool busy = false;
  ClassroomDocument? get returnList => c.classroom
      .where(
        (d) =>
            d.id == widget.returnId &&
            d.kind == ClassroomKind.returnList &&
            !d.deleted,
      )
      .firstOrNull;
  List<_Recipient> recipients() {
    final pupils = {for (final p in c.pupils) p.id: p};
    final list = returnList;
    final result = <_Recipient>[];
    if (widget.returnId != null) {
      if (list == null) return [];
      for (final row in list.rows('participants')) {
        final pupil = pupils[row['pupilId']];
        if (pupil == null) continue;
        result.add((
          pupil: pupil,
          scope: ScanContext(
            pupilIds: [pupil.id],
            links: [DocumentLink('classroom', list.id)],
            collection: true,
            category: 'form',
            title: '${pupil.name} · ${list.title}',
          ),
          status: row['status'] as String,
          editable:
              !pupil.archived &&
              !list.flag('closed') &&
              row['status'] != 'exempt',
        ));
      }
    } else {
      for (final r in c.records.where(
        (r) =>
            !r.deleted &&
            r.kind == SchoolKind.homework &&
            (widget.homeworkGroup.isEmpty
                ? widget.homeworkIds.contains(r.id)
                : r.homeworkGroup == widget.homeworkGroup),
      )) {
        final p = pupils[r.pupilId];
        if (p == null) continue;
        result.add((
          pupil: p,
          scope: ScanContext(
            pupilIds: [p.id],
            links: [DocumentLink('school', r.id)],
            collection: true,
            includeTasks: false,
            category: 'pupilWork',
            subject: r.subject,
            title: '${p.name} · ${widget.title}',
          ),
          status: '',
          editable: !p.archived,
        ));
      }
    }
    return result..sort((a, b) => a.pupil.name.compareTo(b.pupil.name));
  }

  List<ClassroomDocument> files(_Recipient row) => c.classroom
      .where(
        (d) =>
            d.flag('collected') &&
            row.scope.matchesMaterial(d) &&
            d.strings('pupilIds').length == 1 &&
            DocumentLink.fromJson(d.rows('links').first).identity ==
                row.scope.links.single.identity,
      )
      .toList();
  DialogDraft? draft(_Recipient row) => c.dialogDrafts
      .where((d) => d.data['collection'] == true && row.scope.matchesDraft(d))
      .firstOrNull;

  Future<void> scan(_Recipient row) async {
    if (busy || !row.editable) return;
    setState(() => busy = true);
    try {
      await showDocumentScanner(
        context,
        c,
        scope: row.scope,
        draft: draft(row),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> receive(_Recipient row) async {
    final list = returnList;
    if (busy ||
        list == null ||
        list.flag('closed') ||
        !row.editable ||
        row.status != 'open' ||
        !{'form', 'material'}.contains(list.text('type'))) {
      return;
    }
    setState(() => busy = true);
    await guarded(
      context,
      () => c.saveClassroom(
        list.patch({
          'participants': [
            for (final p in list.rows('participants'))
              if (p['pupilId'] == row.pupil.id)
                {...p, 'status': 'received', 'updatedAtUtc': utcNow()}
              else
                p,
          ],
        }),
      ),
    );
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (ctx, _) {
      final rows = recipients();
      final submissions = {
        for (final row in rows)
          row.scope.links.single.identity + row.pupil.id: files(row),
      };
      List<ClassroomDocument> submitted(_Recipient row) =>
          submissions[row.scope.links.single.identity + row.pupil.id]!;
      final expected = rows.where(
        (row) =>
            row.status != 'exempt' &&
            (!row.pupil.archived || submitted(row).isNotEmpty),
      );
      final next = expected
          .where((r) => r.editable && submitted(r).isEmpty)
          .firstOrNull;
      final list = returnList;
      return FlexModal(
        title: const Text('Einsammeln'),
        onClose: busy ? null : () => Navigator.pop(ctx),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(ctx).textTheme.titleMedium),
            Text(
              '${expected.where((r) => submitted(r).isNotEmpty).length} von ${expected.length} eingesammelt',
            ),
            if (rows.isEmpty)
              const Text('Keine zugeordneten Schüler verfügbar.'),
            for (final row in rows)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      submitted(row).isEmpty
                          ? Icons.person_outline
                          : Icons.task_alt,
                    ),
                    title: Text(row.pupil.name),
                    subtitle: Text(
                      [
                        if (submitted(row).isNotEmpty)
                          '${submitted(row).length} PDF'
                        else if (draft(row) != null)
                          'Scanentwurf'
                        else
                          'Keine Abgabe erfasst',
                        if (list != null)
                          returnStatuses[list.text('type')]![row.status]!,
                      ].join(' · '),
                    ),
                    trailing: row.editable
                        ? IconButton(
                            tooltip: 'Für ${row.pupil.name} scannen',
                            icon: const Icon(Icons.document_scanner_outlined),
                            onPressed: busy ? null : () => scan(row),
                          )
                        : null,
                    onTap: busy || !row.editable ? null : () => scan(row),
                  ),
                  for (final d in submitted(row))
                    MaterialRow(
                      material: d,
                      onOpen: () => guarded(ctx, () => openMaterial(ctx, c, d)),
                    ),
                  if (submitted(row).isNotEmpty &&
                      row.editable &&
                      row.status == 'open' &&
                      list != null &&
                      {'form', 'material'}.contains(list.text('type')))
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: busy ? null : () => receive(row),
                        child: Text(
                          'Als ${returnStatuses[list.text('type')]!['received']} markieren',
                        ),
                      ),
                    ),
                  const Divider(height: 1),
                ],
              ),
          ],
        ),
        actions: [
          if (next != null)
            FilledButton.icon(
              onPressed: busy ? null : () => scan(next),
              icon: const Icon(Icons.document_scanner_outlined),
              label: Text(
                'Nächster Schüler · ${next.pupil.name}',
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Fertig'),
            ),
        ],
      );
    },
  );
}
