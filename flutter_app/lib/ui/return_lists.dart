import 'homework_record_view.dart';
import 'detail_flow.dart';
import 'document_attachments.dart';
import '../domain/document_scanner.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';
import '../services/brief_pdf.dart';
import 'classroom_editor.dart';
import 'common.dart';
import 'draft_buffer.dart';
import 'flex_modal.dart';
import 'material_library.dart';
import 'reminder_actions.dart';
import 'school_workspace.dart';
import 'surfaces.dart';
import 'collapsible_search.dart';

Future<void> showReturnLists(BuildContext context, NotebookController c) =>
    showDialog<void>(
      context: context,
      builder: (_) => FlexModal(
        maxWidth: 1000,
        title: const Text('Rückläufe · FLEX-Klasse'),
        onClose: () => Navigator.pop(context),
        scrollable: false,
        content: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ReturnLists(controller: c),
        ),
      ),
    );

class ReturnLists extends StatefulWidget {
  const ReturnLists({super.key, required this.controller});
  final NotebookController controller;
  @override
  State<ReturnLists> createState() => _ReturnListsState();
}

class _ReturnListsState extends State<ReturnLists> {
  String filter = 'open', query = '';
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (ctx, _) {
      final c = widget.controller;
      final docs =
          c.classroom
              .where(
                (d) =>
                    d.kind == ClassroomKind.returnList &&
                    d.title.toLowerCase().contains(query.toLowerCase()) &&
                    (filter == 'trash'
                        ? d.deleted
                        : !d.deleted &&
                              (filter == 'all' ||
                                  (filter == 'closed') == d.flag('closed'))),
              )
              .toList()
            ..sort(
              (a, b) => a
                  .text('dueDate', '9999')
                  .compareTo(b.text('dueDate', '9999')),
            );
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          CollapsibleSearch(
            controller: search,
            fieldKey: const ValueKey('return-search'),
            label: 'Rückläufe durchsuchen',
            iconOnly: true,
            leading: Text(
              'Rückläufe',
              style: Theme.of(ctx).textTheme.headlineSmall,
            ),
            onChanged: (v) => setState(() => query = v),
            actions: [
              IconButton(
                tooltip: 'Rücklauf anlegen',
                onPressed: () =>
                    showClassroomEditor(ctx, c, ClassroomKind.returnList),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final f in const {
                'open': 'Offen',
                'closed': 'Abgeschlossen',
                'all': 'Alle',
                'trash': 'Papierkorb',
              }.entries)
                ChoiceChip(
                  label: Text(f.value),
                  selected: filter == f.key,
                  onSelected: (_) => setState(() => filter = f.key),
                ),
            ],
          ),
          if (docs.isEmpty)
            const EmptyState(
              'Keine passenden Rückläufe.',
              icon: Icons.fact_check_outlined,
            ),
          for (final d in docs)
            FlexCard(
              child: ListTile(
                title: Text(d.title),
                subtitle: Text(
                  '${displayDate(d.text('dueDate').isEmpty ? null : d.text('dueDate'))} · ${d.rows('participants').where(returnPending).length} von ${d.rows('participants').length} offen',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showReturnDetail(ctx, c, d.id),
              ),
            ),
        ],
      );
    },
  );
}

Future<void> showReturnDetail(
  BuildContext context,
  NotebookController c,
  String id,
) => showFlexDetail<void>(
  context: context,
  builder: (_) => ReturnDetail(controller: c, id: id),
);

class ReturnDetail extends StatefulWidget {
  const ReturnDetail({super.key, required this.controller, required this.id});
  final NotebookController controller;
  final String id;
  @override
  State<ReturnDetail> createState() => _ReturnDetailState();
}

class _ReturnDetailState extends State<ReturnDetail> {
  bool openOnly = false, busy = false;
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  final selected = <String>{};
  String query = '';
  NotebookController get c => widget.controller;
  Future<void> change(ClassroomDocument d, List<Json> rows) async {
    if (busy) return;
    setState(() => busy = true);
    await guarded(
      context,
      () => c.saveClassroom(d.patch({'participants': rows})),
    );
    if (mounted) setState(() => busy = false);
  }

  Future<void> setStatus(
    ClassroomDocument d,
    Set<String> ids,
    String status,
  ) async {
    int? partial;
    if (d.text('type') == 'payment' && status == 'partial') {
      var amount = '';
      partial = await showDialog<int>(
        context: context,
        builder: (ctx) => FlexModal(
          title: const Text('Teilzahlung'),
          onClose: () => Navigator.pop(ctx),
          content: TextFormField(
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Betrag pro ausgewähltem Schüler · €',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => amount = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                final n = double.tryParse(amount.replaceAll(',', '.'));
                final cents = n == null || !n.isFinite ? -1 : (n * 100).round();
                if (cents <= 0 || cents >= d.number('amountDue')) {
                  await guarded(
                    ctx,
                    () async => throw const DomainError(
                      'Teilzahlung muss größer als null und kleiner als der Gesamtbetrag sein.',
                    ),
                  );
                } else {
                  Navigator.pop(ctx, cents);
                }
              },
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      );
      if (partial == null || !mounted) return;
    }
    await change(d, [
      for (final row in d.rows('participants'))
        if (ids.contains(row['pupilId']))
          {
            ...row,
            'status': status,
            'updatedAtUtc': utcNow(),
            if (d.text('type') == 'payment' && status != 'exempt')
              'paid': status == 'received'
                  ? d.number('amountDue')
                  : status == 'partial'
                  ? partial!
                  : 0,
          }
        else
          row,
    ]);
  }

  Future<void> editRow(ClassroomDocument d, Json row) async {
    var note = row['note'] as String, paid = row['paid'] as int;
    await showFlexDetail<void>(
      context: context,
      builder: (ctx) => FlexModal(
        title: Text(row['name'] as String),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(d.title, style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextFormField(
              readOnly: d.flag('closed') || d.deleted,
              initialValue: note,
              decoration: const InputDecoration(labelText: 'Notiz'),
              minLines: 2,
              maxLines: 6,
              onChanged: (v) => note = v,
            ),
            if (d.text('type') == 'payment')
              TextFormField(
                readOnly: d.flag('closed') || d.deleted,
                initialValue: (paid / 100).toStringAsFixed(2),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Eingegangener Betrag · €',
                ),
                onChanged: (v) {
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  paid = n == null || !n.isFinite ? -1 : (n * 100).round();
                },
              ),
            const SizedBox(height: 16),
            DocumentAttachmentSection(
              controller: c,
              scope: rowScope(d, row),
              readOnly: d.flag('closed') || d.deleted,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          if (!d.flag('closed') && !d.deleted)
            FilledButton(
              onPressed: () async {
                if (paid < 0) {
                  await guarded(
                    ctx,
                    () async => throw const DomainError(
                      'Bitte einen gültigen Betrag eingeben.',
                    ),
                  );
                  return;
                }
                final next = {
                  ...row,
                  'note': note,
                  'paid': paid,
                  'updatedAtUtc': utcNow(),
                };
                if (d.text('type') == 'payment' && row['status'] != 'exempt') {
                  next['status'] = paid == 0
                      ? 'open'
                      : paid >= d.number('amountDue')
                      ? 'received'
                      : 'partial';
                }
                final ok = await guarded(
                  ctx,
                  () => c.saveClassroom(
                    d.patch({
                      'participants': [
                        for (final r in d.rows('participants'))
                          if (r['pupilId'] == row['pupilId']) next else r,
                      ],
                    }),
                  ),
                );
                if (ok && ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Speichern'),
            ),
        ],
      ),
    );
  }

  Future<void> export(ClassroomDocument d) async {
    final text = [
      d.title,
      'FLEX-Klasse · ${returnTypes[d.text('type')]}',
      'Frist: ${displayDate(d.text('dueDate').isEmpty ? null : d.text('dueDate'))}',
      d.text('note'),
      '',
      for (final r in d.rows('participants'))
        '${r['name']} · ${returnStatuses[d.text('type')]![r['status']]}${d.text('type') == 'payment' ? ' · ${((r['paid'] as int) / 100).toStringAsFixed(2)} €' : ''}${(r['note'] as String).isEmpty ? '' : '\n${r['note']}'}',
    ].join('\n');
    final bytes = await briefPdf(
      text: text,
      regularFont: await rootBundle.load('assets/fonts/Selawik-Regular.ttf'),
      boldFont: await rootBundle.load('assets/fonts/Selawik-Bold.ttf'),
    );
    await saveBytesFile(
      'FLEX-Ruecklauf-${dateOnly(DateTime.now())}.pdf',
      bytes,
      mime: 'application/pdf',
    );
  }

  ScanContext generalScope(ClassroomDocument d) => ScanContext(
    links: [DocumentLink('classroom', d.id)],
    title: d.title,
    category: 'form',
    unassignedPupilsOnly: true,
  );
  ScanContext rowScope(ClassroomDocument d, Json row) => ScanContext(
    pupilIds: [row['pupilId'] as String],
    links: [DocumentLink('classroom', d.id)],
    title: '${row['name']} · ${d.title}',
    category: 'form',
  );

  Widget participantRow(BuildContext context, ClassroomDocument d, Json row) {
    final scheme = Theme.of(context).colorScheme;
    final scope = rowScope(d, row);
    final count = c.classroom.where(scope.matchesMaterial).length;
    final statusLabel = returnStatuses[d.text('type')]![row['status']]!;
    final title = InkWell(
      key: ValueKey('return-pupil-${row['pupilId']}'),
      onTap: () => editRow(d, row),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    [
                      statusLabel,
                      if (d.text('type') == 'payment')
                        '${((row['paid'] as int) / 100).toStringAsFixed(2)} €',
                      if ((row['note'] as String).isNotEmpty) 'Notiz',
                      if (count > 0) '$count Dateien',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
    final statuses = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final status in returnStatuses[d.text('type')]!.entries)
          Semantics(
            selected: row['status'] == status.key,
            child: IconButton(
              key: ValueKey('return-status-${row['pupilId']}-${status.key}'),
              tooltip: status.value,
              onPressed: busy || d.flag('closed') || d.deleted
                  ? null
                  : () => setStatus(d, {row['pupilId'] as String}, status.key),
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                backgroundColor: row['status'] == status.key
                    ? scheme.primary.withValues(alpha: .18)
                    : Colors.transparent,
                foregroundColor: row['status'] == status.key
                    ? scheme.primary
                    : scheme.onSurface,
              ),
              icon: Icon(switch (status.key) {
                'received' || 'yes' => Icons.check_circle_outline,
                'partial' => Icons.contrast,
                'no' => Icons.cancel_outlined,
                'exempt' => Icons.remove_circle_outline,
                _ => Icons.radio_button_unchecked,
              }),
            ),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (_, box) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                semanticLabel: '${row['name']} auswählen',
                value: selected.contains(row['pupilId']),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    selected.add(row['pupilId'] as String);
                  } else {
                    selected.remove(row['pupilId']);
                  }
                }),
              ),
              Expanded(
                child:
                    box.maxWidth >= 540 &&
                        MediaQuery.textScalerOf(context).scale(1) <= 1.4
                    ? Row(
                        children: [
                          Expanded(child: title),
                          statuses,
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title, statuses],
                      ),
              ),
            ],
          ),
        ),
        HomeworkThumbnails(
          controller: c,
          scope: scope,
          readOnly: d.deleted || d.flag('closed'),
        ),
        Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .4)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (ctx, _) {
      final d = c.classroom.where((d) => d.id == widget.id).firstOrNull;
      if (d == null) {
        return FlexModal(
          title: const Text('Rücklauf'),
          onClose: () => Navigator.pop(ctx),
          content: const Text('Dieser Vorgang ist nicht mehr verfügbar.'),
        );
      }
      final rows = d.rows('participants');
      final visible = rows
          .where(
            (r) =>
                (!openOnly || returnPending(r)) &&
                (r['name'] as String).toLowerCase().contains(
                  query.toLowerCase(),
                ),
          )
          .toList();
      return FlexModal(
        maxWidth: 950,
        title: Text(d.title),
        onClose: busy ? null : () => Navigator.pop(ctx),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${returnTypes[d.text('type')]} · Frist: ${displayDate(d.text('dueDate').isEmpty ? null : d.text('dueDate'))}',
            ),
            Text(
              '${rows.where(returnPending).length} offen · ${rows.where((r) => r['status'] == 'exempt').length} ausgenommen',
            ),
            if (d.text('note').isNotEmpty) Text(d.text('note')),
            if (d.text('type') == 'payment')
              Text(
                'Eingegangen: ${(rows.fold(0, (n, r) => n + (r['paid'] as int)) / 100).toStringAsFixed(2)} € · Soll: ${(rows.where((r) => r['status'] != 'exempt').length * d.number('amountDue') / 100).toStringAsFixed(2)} €',
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Zum gesamten Vorgang',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Unterlagen zum gesamten Vorgang',
                  onPressed: () =>
                      showContextDocuments(ctx, c, generalScope(d)),
                  icon: const Icon(Icons.folder_open_outlined),
                ),
                IconButton(
                  tooltip: 'Für den gesamten Vorgang scannen',
                  onPressed: d.deleted || d.flag('closed')
                      ? null
                      : () => scanAndShow(ctx, c, generalScope(d)),
                  icon: const Icon(Icons.document_scanner_outlined),
                ),
              ],
            ),
            HomeworkThumbnails(
              controller: c,
              scope: generalScope(d),
              readOnly: d.deleted || d.flag('closed'),
            ),
            for (final key in d.strings('materialIds'))
              if (c.classroom.any((m) => m.id == key && !m.deleted))
                MaterialRow(
                  material: c.classroom.firstWhere((m) => m.id == key),
                  onOpen: () => guarded(
                    ctx,
                    () => openMaterial(
                      ctx,
                      c,
                      c.classroom.firstWhere((m) => m.id == key),
                    ),
                  ),
                ),
            const Divider(),
            CollapsibleSearch(
              controller: search,
              fieldKey: const ValueKey('return-pupil-search'),
              label: 'Schüler suchen',
              iconOnly: true,
              onChanged: (v) => setState(() => query = v),
              leading: FilterChip(
                label: const Text('Nur offene'),
                selected: openOnly,
                onSelected: (v) => setState(() => openOnly = v),
              ),
              actions: [
                IconButton(
                  tooltip: selected.isEmpty
                      ? 'Sichtbare auswählen'
                      : 'Auswahl aufheben',
                  onPressed: () => setState(() {
                    if (selected.isEmpty) {
                      selected.addAll(
                        visible.map((r) => r['pupilId'] as String),
                      );
                    } else {
                      selected.clear();
                    }
                  }),
                  icon: Icon(
                    selected.isEmpty ? Icons.checklist : Icons.deselect,
                  ),
                ),
              ],
            ),
            if (selected.isNotEmpty) ...[
              Text(
                'Für ${selected.length} ausgewählte Schüler',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
              Wrap(
                spacing: 4,
                children: [
                  for (final status in returnStatuses[d.text('type')]!.entries)
                    TextButton(
                      onPressed: busy || d.flag('closed') || d.deleted
                          ? null
                          : () => setStatus(d, Set.of(selected), status.key),
                      child: Text(status.value),
                    ),
                  IconButton(
                    tooltip: 'Scan für ausgewählte Schüler',
                    onPressed: busy || d.flag('closed') || d.deleted
                        ? null
                        : () => scanAndShow(
                            ctx,
                            c,
                            ScanContext(
                              pupilIds: selected.toList(),
                              links: [DocumentLink('classroom', d.id)],
                              title: d.title,
                              category: 'form',
                            ),
                          ),
                    icon: const Icon(Icons.document_scanner_outlined),
                  ),
                ],
              ),
            ],
            if (busy) const LinearProgressIndicator(),
            if (visible.isEmpty) const EmptyState('Keine passenden Schüler.'),
            for (final row in visible) participantRow(ctx, d, row),
            const SizedBox(height: 12),
            const Divider(),
            Text(
              'Vorgang verwalten',
              style: Theme.of(ctx).textTheme.titleSmall,
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => showClassroomEditor(
                          ctx,
                          c,
                          ClassroomKind.returnList,
                          document: d,
                        ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Bearbeiten'),
                ),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => showReminderActions(
                          ctx,
                          c,
                          'return:${d.id}',
                          d.title,
                        ),
                  icon: const Icon(Icons.snooze),
                  label: const Text('Erinnern'),
                ),
                TextButton.icon(
                  onPressed: busy ? null : () => guarded(ctx, () => export(d)),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
                TextButton(
                  onPressed: () => showJournal(ctx, c, d.id),
                  child: const Text('Änderungen'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => guarded(
                          ctx,
                          () => c.saveClassroom(
                            d.patch({'closed': !d.flag('closed')}),
                          ),
                        ),
                  child: Text(
                    d.flag('closed') ? 'Wieder öffnen' : 'Abschließen',
                  ),
                ),
                IconButton(
                  tooltip: d.deleted ? 'Wiederherstellen' : 'In Papierkorb',
                  onPressed: busy
                      ? null
                      : () => guarded(
                          ctx,
                          () =>
                              c.saveClassroom(d.patch({'deleted': !d.deleted})),
                        ),
                  icon: Icon(d.deleted ? Icons.restore : Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
