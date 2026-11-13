import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/document_scanner.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import 'classroom_editor.dart';
import 'common.dart';
import 'detail_flow.dart';
import 'document_attachments.dart';
import 'flex_modal.dart';
import 'material_library.dart';
import 'orga_editor.dart';
import 'pupil_editor.dart';
import 'school_workspace.dart';
import 'dialog_workflows.dart';

class QuickAddButton extends StatelessWidget {
  const QuickAddButton({
    super.key,
    required this.controller,
    this.pupil,
    this.date,
  });
  final NotebookController controller;
  final Pupil? pupil;
  final String? date;
  @override
  Widget build(BuildContext context) => FloatingActionButton(
    key: const ValueKey('quick-add'),
    heroTag: null,
    tooltip: 'Hinzufügen',
    elevation: 3,
    shape: const CircleBorder(),
    onPressed: () =>
        showQuickAdd(context, controller, pupil: pupil, date: date),
    child: const Icon(Icons.add, size: 28),
  );
}

Future<Pupil?> _choosePupil(BuildContext context, NotebookController c) async {
  var query = '';
  return showDialog<Pupil>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => FlexModal(
        title: const Text('Für welchen Schüler?'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: false,
              decoration: const InputDecoration(
                hintText: 'Schüler suchen',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => update(() => query = v),
            ),
            for (final p in c.pupils.where(
              (p) =>
                  !p.archived &&
                  p.name.toLowerCase().contains(query.toLowerCase()),
            ))
              ListTile(
                title: Text(p.name),
                leading: const Icon(Icons.person_outline),
                onTap: () => Navigator.pop(ctx, p),
              ),
            if (!c.pupils.any((p) => !p.archived))
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Bitte zuerst einen Schüler hinzufügen.'),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showQuickAdd(
  BuildContext context,
  NotebookController c, {
  Pupil? pupil,
  String? date,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 600),
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * .8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hinzufügen',
                    style: Theme.of(ctx).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Schließen',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (pupil != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  pupil.name,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
            for (final group in <(String, List<(String, String, IconData)>)>[
              (
                'Aufzeichnen',
                [
                  ('social', 'Sozial', Icons.people_outline),
                  ('work', 'Arbeit', Icons.description_outlined),
                  ('goal', 'Ziel', Icons.track_changes),
                  ('homework', 'Hausübung', Icons.school_outlined),
                ],
              ),
              (
                'Organisieren',
                [
                  ('note', 'Notiz', Icons.edit_note),
                  ('task', 'Aufgabe', Icons.task_alt),
                  ('appointment', 'Termin', Icons.event_outlined),
                  ('returnList', 'Rücklauf', Icons.fact_check_outlined),
                ],
              ),
              (
                'Material',
                [
                  ('scan', 'Scan / Bild', Icons.document_scanner_outlined),
                  ('file', 'Datei', Icons.upload_file_outlined),
                  ('material', 'Link', Icons.link),
                  ('materialSet', 'Paket', Icons.folder_copy_outlined),
                ],
              ),
              (
                'Unterricht',
                [
                  ('plan', 'Planung', Icons.event_note_outlined),
                  ('lesson', 'Unterricht', Icons.table_chart_outlined),
                  ('holiday', 'Ferien / Ausfall', Icons.beach_access_outlined),
                  if (pupil == null)
                    ('pupil', 'Schüler', Icons.person_add_alt_1_outlined),
                  if (pupil == null)
                    ('bulk', 'Gruppeneintrag', Icons.group_add_outlined),
                ],
              ),
            ]) ...[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 4),
                child: Text(
                  group.$1,
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
              ),
              LayoutBuilder(
                builder: (ctx, box) {
                  final columns =
                      MediaQuery.textScalerOf(ctx).scale(1) > 1.4 &&
                          box.maxWidth < 400
                      ? 1
                      : 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final a in group.$2)
                        SizedBox(
                          width: (box.maxWidth - (columns - 1) * 8) / columns,
                          child: TextButton(
                            key: ValueKey('quick-add-${a.$1}'),
                            style: TextButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                            onPressed: () => Navigator.pop(ctx, a.$1),
                            child: Row(
                              children: [
                                Icon(a.$3, size: 23),
                                const SizedBox(width: 10),
                                Flexible(child: Text(a.$2)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  if (['goal', 'social', 'work', 'homework'].contains(action)) {
    final selected = pupil ?? await _choosePupil(context, c);
    if (selected == null || !context.mounted) return;
    await editSchool(
      context,
      c,
      SchoolRecord.empty(SchoolKind.values.byName(action), selected.id),
    );
  } else if (['note', 'task', 'appointment'].contains(action)) {
    final entry = OrgaEntry.empty(pupilId: pupil?.id).copyWith(
      isTask: action == 'task',
      appointmentDate: action == 'appointment'
          ? date ?? dateOnly(DateTime.now())
          : null,
      dueDate: action == 'task' ? date : null,
    );
    await showFlexDetail<void>(
      context: context,
      builder: (_) =>
          OrgaEditor(controller: c, entry: entry, defaultToClassTask: false),
    );
  } else if (action == 'scan') {
    await scanAndShow(
      context,
      c,
      ScanContext(
        pupilIds: [if (pupil != null) pupil.id],
        title: pupil?.name ?? '',
      ),
    );
  } else if (action == 'file') {
    await guarded(
      context,
      () => importMaterialFile(context, c, pupilId: pupil?.id),
    );
  } else if (action == 'pupil') {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PupilEditor(controller: c),
    );
  } else if (action == 'bulk') {
    await showBulk(context, c);
  } else {
    await showClassroomEditor(
      context,
      c,
      ClassroomKind.values.byName(action),
      date: date,
      fields:
          pupil != null && ['material', 'materialSet', 'plan'].contains(action)
          ? {
              'pupilIds': [pupil.id],
            }
          : null,
    );
  }
}
