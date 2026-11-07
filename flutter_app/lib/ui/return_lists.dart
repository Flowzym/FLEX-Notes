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
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () =>
                  showClassroomEditor(ctx, c, ClassroomKind.returnList),
              icon: const Icon(Icons.add),
              label: const Text('Rücklauf anlegen'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Rückläufe durchsuchen',
            ),
            onChanged: (v) => setState(() => query = v),
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
) => showDialog<void>(
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
    await showDialog<void>(
      context: context,
      builder: (ctx) => FlexModal(
        title: Text(row['name'] as String),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: note,
              decoration: const InputDecoration(labelText: 'Notiz'),
              minLines: 2,
              maxLines: 6,
              onChanged: (v) => note = v,
            ),
            if (d.text('type') == 'payment')
              TextFormField(
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
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
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                DocumentAttachmentsButton(
                  controller: c,
                  scope: ScanContext(
                    links: [DocumentLink('classroom', d.id)],
                    title: d.title,
                    category: 'form',
                  ),
                ),
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
            for (final key in d.strings('materialIds'))
              if (c.classroom.any((m) => m.id == key && !m.deleted))
                TextButton.icon(
                  onPressed: () => guarded(
                    ctx,
                    () => openMaterial(
                      ctx,
                      c,
                      c.classroom.firstWhere((m) => m.id == key),
                    ),
                  ),
                  icon: const Icon(Icons.attach_file),
                  label: Text(c.classroom.firstWhere((m) => m.id == key).title),
                ),
            const Divider(),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Schüler suchen',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Nur offene'),
                  selected: openOnly,
                  onSelected: (v) => setState(() => openOnly = v),
                ),
                TextButton(
                  onPressed: () => setState(
                    () => selected.addAll(
                      visible.map((r) => r['pupilId'] as String),
                    ),
                  ),
                  child: const Text('Sichtbare auswählen'),
                ),
                TextButton(
                  onPressed: () => setState(selected.clear),
                  child: const Text('Auswahl aufheben'),
                ),
              ],
            ),
            if (selected.isNotEmpty)
              Wrap(
                spacing: 6,
                children: [
                  for (final status in returnStatuses[d.text('type')]!.entries)
                    OutlinedButton(
                      onPressed: busy || d.flag('closed') || d.deleted
                          ? null
                          : () => setStatus(d, Set.of(selected), status.key),
                      child: Text('${status.value} · ${selected.length}'),
                    ),
                ],
              ),
            if (busy) const LinearProgressIndicator(),
            for (final row in visible)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DocumentAttachmentsButton(
                      controller: c,
                      scope: ScanContext(
                        pupilIds: [row['pupilId'] as String],
                        links: [DocumentLink('classroom', d.id)],
                        title: '${row['name']} · ${d.title}',
                        category: 'form',
                      ),
                    ),
                    Row(
                      children: [
                        Checkbox(
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
                          child: Text(
                            row['name'] as String,
                            style: Theme.of(ctx).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Notiz / Betrag',
                          onPressed: busy || d.flag('closed') || d.deleted
                              ? null
                              : () => editRow(d, row),
                          icon: const Icon(Icons.edit_note),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final status
                            in returnStatuses[d.text('type')]!.entries)
                          ChoiceChip(
                            label: Text(status.value),
                            selected: row['status'] == status.key,
                            onSelected: busy || d.flag('closed') || d.deleted
                                ? null
                                : (_) => setStatus(d, {
                                    row['pupilId'] as String,
                                  }, status.key),
                          ),
                      ],
                    ),
                    if ((row['note'] as String).isNotEmpty)
                      Text(row['note'] as String),
                    if (d.text('type') == 'payment')
                      Text(
                        '${((row['paid'] as int) / 100).toStringAsFixed(2)} €',
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
