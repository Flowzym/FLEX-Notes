import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/assignment_sources.dart';
import '../domain/classroom.dart';
import '../domain/material_workspace.dart';
import '../domain/models.dart';
import '../services/assignment_text.dart';
import '../services/material_files.dart';
import '../services/material_storage.dart';
import '../services/onedrive.dart';
import 'classroom_editor.dart';
import 'common.dart';
import 'detail_flow.dart';
import 'flex_modal.dart';
import 'material_library.dart';
import 'material_thumbnail.dart';
import 'option_bar.dart';

class WorkAssignmentSources extends StatelessWidget {
  const WorkAssignmentSources({
    super.key,
    required this.controller,
    required this.date,
    required this.values,
    this.onChanged,
    this.files = const LocalMaterialFiles(),
  });
  final NotebookController controller;
  final String date;
  final List<AssignmentSource> values;
  final ValueChanged<List<AssignmentSource>>? onChanged;
  final MaterialFiles files;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (onChanged != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('assignment-sources'),
            onPressed: () async {
              final result = await showFlexDetail<List<AssignmentSource>>(
                context: context,
                builder: (_) => _AssignmentPicker(
                  controller: controller,
                  date: date,
                  initial: values,
                  files: files,
                ),
              );
              if (result != null) onChanged!(result);
            },
            icon: const Icon(Icons.link),
            label: const Text('Planung / Material zuordnen'),
          ),
        ),
      for (final source in values)
        Builder(
          builder: (ctx) {
            final doc = controller.classroom
                .where((d) => d.id == source.documentId && !d.deleted)
                .firstOrNull;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: doc?.kind == ClassroomKind.material
                  ? MaterialThumbnail(
                      material: doc!,
                      width: 40,
                      height: 48,
                      files: files,
                    )
                  : const Icon(Icons.assignment_outlined),
              title: Text(
                source.text.isEmpty ? source.title : source.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                doc == null
                    ? '${source.title} · Quelle nicht verfügbar'
                    : source.text.isEmpty
                    ? doc.kind == ClassroomKind.plan
                          ? 'FLEX-Planung'
                          : doc.text('extension').isEmpty
                          ? 'Material'
                          : '${doc.text('extension').toUpperCase()} · Material'
                    : '${source.title}${source.page == null ? '' : ' · Seite ${source.page}'}',
              ),
              onTap: doc == null
                  ? null
                  : () => guarded(
                      ctx,
                      () => doc.kind == ClassroomKind.plan
                          ? showClassroomEditor(
                              ctx,
                              controller,
                              doc.kind,
                              document: doc,
                            )
                          : openMaterial(ctx, controller, doc, files: files),
                    ),
              trailing: onChanged == null
                  ? null
                  : IconButton(
                      tooltip: 'Zuordnung entfernen',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => onChanged!(
                        values
                            .where((v) => v.identity != source.identity)
                            .toList(),
                      ),
                    ),
            );
          },
        ),
    ],
  );
}

class _AssignmentPicker extends StatefulWidget {
  const _AssignmentPicker({
    required this.controller,
    required this.date,
    required this.initial,
    required this.files,
  });
  final NotebookController controller;
  final String date;
  final List<AssignmentSource> initial;
  final MaterialFiles files;
  @override
  State<_AssignmentPicker> createState() => _AssignmentPickerState();
}

class _AssignmentPickerState extends State<_AssignmentPicker> {
  late final selected = [...widget.initial];
  final drive = OneDriveClient();
  var view = 'day', query = '', busy = false;
  String? error;
  NotebookController get c => widget.controller;
  @override
  void dispose() {
    drive.dispose();
    super.dispose();
  }

  void toggle(AssignmentSource value) {
    setState(() {
      error = null;
      if (selected.any((v) => v.identity == value.identity)) {
        selected.removeWhere((v) => v.identity == value.identity);
      } else if (selected.length < 30) {
        selected.add(value);
      } else {
        error = 'Bis zu 30 Zuordnungen pro Eintrag.';
      }
    });
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> tasks(ClassroomDocument doc) => run(() async {
    if (doc.kind == ClassroomKind.material &&
        !await widget.files.exists(doc.text('localKey'))) {
      if (doc.text('itemId').isEmpty) {
        throw const DomainError(
          'Die lokale Datei fehlt. Bitte die vollständige Sicherung wiederherstellen.',
        );
      }
      await drive.load();
      if (!mounted) return;
      if (!drive.connected) await connectOneDrive(context, drive);
      if (!drive.connected) return;
      doc = await cacheMaterial(c, doc, drive, widget.files);
    }
    final values = await readAssignmentText(doc, widget.files);
    if (!mounted) return;
    setState(() => busy = false);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => FlexModal(
          title: Text(doc.title),
          maxWidth: 620,
          onClose: () => Navigator.pop(ctx),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (values.isEmpty)
                const Text(
                  'Kein auswählbarer Text gefunden. Du kannst das gesamte Dokument verknüpfen und einen eigenen Auftrag ergänzen.',
                ),
              if (values.length >= 300)
                const Text('Die ersten 300 Textabschnitte werden angezeigt.'),
              for (final value in values)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selected.any((v) => v.identity == value.identity),
                  title: Text(value.text),
                  subtitle: value.page == null
                      ? null
                      : Text('Seite ${value.page}'),
                  onChanged: (_) {
                    toggle(value);
                    update(() {});
                  },
                ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      ),
    );
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (ctx, _) {
      final date = widget.date;
      final today = {
        ...preparationFor(c.classroom, date).strings('materialIds'),
        ...suggestedMaterials(c.classroom, date).map((d) => d.id),
        for (final p in c.classroom.where((d) => planOnDay(d, date))) p.id,
        for (final lesson in lessonOccurrences(c.classroom, date, date))
          ...lessonPlans(c.classroom, lesson).map((p) => p.id),
      };
      final docs = c.classroom
          .where(
            (d) =>
                !d.deleted &&
                {ClassroomKind.plan, ClassroomKind.material}.contains(d.kind) &&
                (view == 'day'
                    ? today.contains(d.id)
                    : view == 'plans'
                    ? d.kind == ClassroomKind.plan ||
                          {
                            'planning',
                            'weekPlan',
                            'learningPlan',
                          }.contains(d.text('documentType'))
                    : d.kind == ClassroomKind.material) &&
                materialMatches(d, query, pupils: c.pupils),
          )
          .toList();
      return PopScope(
        canPop: !busy,
        child: FlexModal(
          title: const Text('Auftrag zuordnen'),
          maxWidth: 720,
          onClose: busy ? null : () => Navigator.pop(ctx),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OptionBar(
                value: view,
                options: const {
                  'day': 'Tag',
                  'plans': 'Planungen',
                  'all': 'Materialien',
                },
                onChanged: (v) => setState(() => view = v),
              ),
              if (view == 'day') Text(displayDate(date)),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Planung oder Material suchen',
                ),
                onChanged: (v) => setState(() => query = v),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          await drive.load();
                          if (!ctx.mounted) return;
                          if (!drive.connected) {
                            await connectOneDrive(ctx, drive);
                          }
                          if (drive.connected && ctx.mounted) {
                            await browseOneDrive(ctx, c, drive);
                          }
                        }),
                  icon: const Icon(Icons.cloud_outlined),
                  label: const Text('OneDrive'),
                ),
              ),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Keine passenden Planungen oder Materialien.'),
                ),
              for (final d in docs)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: d.kind == ClassroomKind.material
                              ? MaterialThumbnail(
                                  material: d,
                                  width: 44,
                                  height: 52,
                                  files: widget.files,
                                )
                              : const Icon(Icons.assignment_outlined),
                          title: Text(d.title),
                          subtitle: Text(
                            d.kind == ClassroomKind.plan
                                ? 'FLEX-Planung'
                                : d.text('extension').toUpperCase(),
                          ),
                          value: selected.any(
                            (v) => v.documentId == d.id && v.text.isEmpty,
                          ),
                          onChanged: busy
                              ? null
                              : (_) => toggle(
                                  AssignmentSource(
                                    documentId: d.id,
                                    title: d.title,
                                  ),
                                ),
                        ),
                        if (d.kind == ClassroomKind.plan ||
                            {'docx', 'pdf'}.contains(d.text('extension')))
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: busy ? null : () => tasks(d),
                              icon: const Icon(Icons.playlist_add),
                              label: const Text('Aufgaben auswählen'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              key: const ValueKey('apply-assignment-sources'),
              onPressed: busy ? null : () => Navigator.pop(ctx, selected),
              child: Text('Zuordnen · ${selected.length}'),
            ),
          ],
        ),
      );
    },
  );
}
