import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/lesson_flow_data.dart';
import '../domain/material_workspace.dart';
import '../domain/models.dart';
import '../domain/planning_import.dart';
import '../domain/teaching_sheet.dart';
import '../services/onedrive.dart';
import '../services/teaching_exchange.dart';
import 'common.dart';
import 'material_library.dart';
part 'teaching_row_editor.dart';

Future<void> openTeachingReview(
  BuildContext context,
  NotebookController c,
  ClassroomDocument source, {
  Future<void> Function(ClassroomDocument)? original,
  String? initialRow,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => TeachingReview(
      controller: c,
      sourceId: source.id,
      original: original,
      initialRow: initialRow,
    ),
  ),
);

class TeachingReview extends StatefulWidget {
  const TeachingReview({
    super.key,
    required this.controller,
    required this.sourceId,
    this.original,
    this.initialRow,
  });
  final NotebookController controller;
  final String sourceId;
  final String? initialRow;
  final Future<void> Function(ClassroomDocument)? original;
  @override
  State<TeachingReview> createState() => _TeachingReviewState();
}

class _TeachingReviewState extends State<TeachingReview> {
  NotebookController get c => widget.controller;
  late String? selection = widget.initialRow;
  bool all = false, busy = false;
  Future<void> run(Future<void> Function() fn) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await guarded(context, fn);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> exchange(ClassroomDocument m, bool publish) async {
    final drive = OneDriveClient(appFolderAccess: true);
    try {
      final folder = c.classroom
          .where((d) => d.id == m.text('cloudRule'))
          .firstOrNull;
      if (folder == null) {
        throw const DomainError(
          'Bitte den Klassenordner mit OneDrive verbinden.',
        );
      }
      await drive.load();
      if (!drive.connected && mounted) await connectOneDrive(context, drive);
      if (!drive.connected || !mounted) return;
      final service = await TeachingExchange.open(drive, m.text('driveId'));
      if (publish) {
        await service.publish(c.repository, m, folder);
      } else {
        final next = await service.preview(m, folder, replaceLocal: true);
        if (!mounted) return;
        if (identical(next, m)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kein freigegebener Planstand vorhanden.'),
            ),
          );
          return;
        }
        final local = teachingRows(m), shared = teachingRows(next);
        String summary(Json r) => [
          for (final e in sheetFields.entries)
            if (sheetText(r, e.key).isNotEmpty) '${e.value} · ${r[e.key]}',
        ].join('\n');
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Planstände vergleichen'),
            content: SizedBox(
              width: 580,
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Text(
                    'Übernehmen ersetzt die lokalen Planungskorrekturen für diese Datei.',
                  ),
                  for (var i = 0; i < shared.length; i++)
                    if (shared[i].toString() != local[i].toString())
                      ListTile(
                        title: Text(sheetText(shared[i], 'line')),
                        subtitle: Text(
                          'Hier · ${summary(local[i])}\nOneDrive · ${summary(shared[i])}',
                        ),
                      ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Zurück'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Planstand übernehmen'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await c.repository.saveClassroomDocument(next);
      }
      await c.reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              publish
                  ? 'Planstand im FLEX-App-Ordner freigegeben.'
                  : 'Planstand übernommen.',
            ),
          ),
        );
      }
    } finally {
      drive.dispose();
    }
  }

  Future<void> edit(ClassroomDocument m, Json row) async {
    final original = sheetList(
      m.map('planSheet'),
      'rows',
    ).firstWhere((r) => r['id'] == row['id']);
    final changes = await showDialog<Json>(
      context: context,
      builder: (_) => _RowEditor(m, row, c),
    );
    if (changes == null) return;
    final edits = m.map('planEdits'),
        delta = <String, dynamic>{
          for (final e in changes.entries)
            if (e.value != original[e.key] &&
                (e.value != '' ||
                    original.containsKey(e.key) ||
                    e.key == 'files'))
              e.key: e.value,
        };
    await c.saveClassroom(
      m.patch({
        'planEdits': {
          ...edits,
          'dirty': true,
          'changes': [
            for (final r in sheetList(edits, 'changes'))
              if (r['id'] != row['id']) r,
            if (delta.isNotEmpty) {'id': row['id'], ...delta},
          ],
        },
      }),
    );
  }

  Future<void> move(
    ClassroomDocument m,
    List<Json> rows,
    Json row,
    int delta,
  ) async {
    final siblings = rows.where((r) => r['type'] == row['type']).toList();
    final i = siblings.indexWhere((r) => r['id'] == row['id']), j = i + delta;
    if (i < 0 || j < 0 || j >= siblings.length) return;
    final order = rows.map((r) => r['id'] as String).toList();
    final a = order.indexOf(row['id']),
        b = order.indexOf(siblings[j]['id'] as String);
    order[a] = siblings[j]['id'];
    order[b] = row['id'];
    final edits = m.map('planEdits');
    await c.saveClassroom(
      m.patch({
        'planEdits': {
          ...edits,
          'dirty': true,
          'changes': edits['changes'] ?? <Json>[],
          'order': order,
        },
      }),
    );
  }

  Widget details(ClassroomDocument m, List<Json> rows, Json r) {
    final kind = sheetText(r, 'type'),
        siblings = rows.where((v) => v['type'] == kind).toList(),
        pos = siblings.indexWhere((v) => v['id'] == r['id']);
    final mapped = kind == 'phase'
        ? buildTeachingFlow(
            m,
            c.classroom,
            c.pupils,
          ).phases.where((p) => p.sourceRow == r['id'])
        : <LessonPhase>[];
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          sheetText(r, 'line'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 5),
        Text(
          sheetText(r, 'raw'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Divider(height: 30),
        Text(
          sheetTypes[kind] ?? kind,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final field in sheetFields.entries.where(
          (e) =>
              e.key != 'type' &&
              e.key != 'files' &&
              sheetText(r, e.key).isNotEmpty,
        ))
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SelectableText('${field.value}\n${r[field.key]}'),
          ),
        const SizedBox(height: 14),
        for (final p in mapped) ...[
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text('${p.title} · ${p.minutes} Min.'),
            subtitle: Text(
              [
                if (p.pupilIds.isNotEmpty)
                  c.pupils
                      .where((s) => p.pupilIds.contains(s.id))
                      .map((s) => s.name)
                      .join(' · '),
                ...resolveMaterials(
                  c.classroom,
                  p.materialIds,
                ).map((m) => m.title),
              ].join('\n'),
            ),
          ),
          for (final g in p.guidance)
            ListTile(
              dense: true,
              leading: const Icon(Icons.person_outline),
              title: Text(
                c.pupils
                    .where((s) => (g['pupilIds'] as List).contains(s.id))
                    .map((s) => s.name)
                    .join(' · '),
              ),
              subtitle: Text(
                [
                  g['body'],
                  if (g['minutes'] > 0) "${g['minutes']} Min.",
                  ...resolveMaterials(
                    c.classroom,
                    List<String>.from(g['materialIds']),
                  ).map((m) => m.title),
                ].join('\n'),
              ),
            ),
        ],
        Wrap(
          spacing: 4,
          children: [
            FilledButton.tonalIcon(
              onPressed: busy ? null : () => run(() => edit(m, r)),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Zeile bearbeiten'),
            ),
            IconButton(
              tooltip: 'Früher einordnen',
              onPressed: busy || pos <= 0
                  ? null
                  : () => run(() => move(m, rows, r, -1)),
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: 'Später einordnen',
              onPressed: busy || pos + 1 >= siblings.length
                  ? null
                  : () => run(() => move(m, rows, r, 1)),
              icon: const Icon(Icons.arrow_downward),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) {
      final m = c.classroom
          .where((d) => d.id == widget.sourceId && !d.deleted)
          .firstOrNull;
      if (m == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Planprüfung')),
          body: const Center(
            child: Text('Die Planung ist nicht mehr verfügbar.'),
          ),
        );
      }
      final rows = teachingRows(m),
          visible = rows.where((r) => all || r['type'] != 'note').toList();
      final selected = visible.where((r) => r['id'] == selection).firstOrNull;
      final edits = m.map('planEdits'),
          orphan = sheetList(
            edits,
            'changes',
          ).where((c) => rows.every((r) => r['id'] != c['id'])).toList();
      final issues = buildTeachingFlow(m, c.classroom, c.pupils).issues;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Planprüfung'),
          actions: [
            IconButton(
              tooltip: 'Original öffnen',
              onPressed: busy
                  ? null
                  : () => run(
                      () =>
                          widget.original?.call(m) ??
                          openMaterial(context, c, m),
                    ),
              icon: const Icon(Icons.description_outlined),
            ),
            PopupMenuButton<String>(
              enabled: !busy,
              onSelected: (v) => run(() => exchange(m, v == 'publish')),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'publish',
                  child: Text('Planstand für andere Geräte freigeben'),
                ),
                PopupMenuItem(
                  value: 'pull',
                  child: Text('Freigegebenen Planstand vergleichen'),
                ),
              ],
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (ctx, box) {
            final wide = box.maxWidth >= 760,
                active = selected ?? (wide ? visible.firstOrNull : null);
            final list = ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(m.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  '${rows.where((r) => r['type'] == 'phase').length} Phasen · ${rows.where((r) => r['type'] == 'aid').length} Schülerhilfen',
                ),
                if (sheetText(m.map('planSheet'), 'issue').isNotEmpty)
                  Text(sheetText(m.map('planSheet'), 'issue')),
                if (!sheetUsable(m))
                  ListTile(
                    title: const Text('Datei einlesen'),
                    subtitle: const Text('OneDrive-Abgleich starten'),
                    onTap: busy ? null : () => run(c.syncMaterials),
                  ),
                if (issues.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('${issues.length} Zuordnungen prüfen'),
                    children: [
                      for (final s in issues)
                        ListTile(dense: true, title: Text(s)),
                    ],
                  ),
                if (orphan.isNotEmpty)
                  ExpansionTile(
                    initiallyExpanded: true,
                    title: const Text('Korrekturen aus früherer Dateiversion'),
                    children: [
                      for (final r in orphan)
                        ListTile(
                          title: Text(
                            [
                              for (final e in sheetFields.keys)
                                if (sheetText(r, e).isNotEmpty) r[e],
                            ].join(' · '),
                          ),
                          subtitle: const Text(
                            'Die Quellzeile wurde geändert. Die Korrektur kann auf eine aktuelle Zeile übertragen werden.',
                          ),
                          onTap: busy
                              ? null
                              : () => run(() async {
                                  final id = await showDialog<String>(
                                    context: context,
                                    builder: (ctx) => SimpleDialog(
                                      title: const Text(
                                        'Aktuelle Zeile wählen',
                                      ),
                                      children: [
                                        for (final v in rows)
                                          SimpleDialogOption(
                                            onPressed: () =>
                                                Navigator.pop(ctx, v['id']),
                                            child: Text(
                                              '${v['line']} · ${v['raw']}',
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                  if (id == null) return;
                                  final changes = sheetList(edits, 'changes');
                                  final other = changes
                                      .where((v) => v['id'] == id)
                                      .firstOrNull;
                                  await c.saveClassroom(
                                    m.patch({
                                      'planEdits': {
                                        ...edits,
                                        'dirty': true,
                                        'changes': [
                                          for (final v in changes)
                                            if (v['id'] != r['id'] &&
                                                v['id'] != id)
                                              v,
                                          {...r, ...?other, 'id': id},
                                        ],
                                      },
                                    }),
                                  );
                                }),
                        ),
                    ],
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Begleittext anzeigen'),
                  value: all,
                  onChanged: (v) => setState(() => all = v),
                ),
                for (final r in visible)
                  ListTile(
                    selected: active?['id'] == r['id'],
                    leading: Icon(switch (r['type']) {
                      'phase' => Icons.play_circle_outline,
                      'aid' => Icons.person_outline,
                      'review' => Icons.help_outline,
                      _ => Icons.notes,
                    }),
                    title: Text(
                      [
                            sheetText(r, 'time'),
                            sheetText(r, 'phase'),
                            sheetText(r, 'day'),
                            sheetText(r, 'who'),
                          ].where((s) => s.isNotEmpty).join(' · ').isEmpty
                          ? (sheetTypes[r['type']] ?? 'Hinweis')
                          : [
                              sheetText(r, 'time'),
                              sheetText(r, 'phase'),
                              sheetText(r, 'day'),
                              sheetText(r, 'who'),
                            ].where((s) => s.isNotEmpty).join(' · '),
                    ),
                    subtitle: Text(
                      sheetText(r, 'task').isEmpty
                          ? sheetText(r, 'raw')
                          : sheetText(r, 'task'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => setState(() => selection = r['id']),
                  ),
              ],
            );
            if (wide) {
              return Row(
                children: [
                  Expanded(child: list),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: active == null
                        ? const Center(
                            child: Text(
                              'Original öffnen, um die Planung zu lesen.',
                            ),
                          )
                        : details(m, rows, active),
                  ),
                ],
              );
            }
            if (active == null) return list;
            return Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => selection = null),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Alle Zeilen'),
                  ),
                ),
                Expanded(child: details(m, rows, active)),
              ],
            );
          },
        ),
      );
    },
  );
}
