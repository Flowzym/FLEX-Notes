import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/assignment_sources.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';
import 'classroom_editor.dart';
import 'work_assignment_sources.dart';

class HomeworkMaterials extends StatefulWidget {
  const HomeworkMaterials({
    super.key,
    required this.controller,
    required this.pupils,
    required this.sources,
    required this.onChanged,
    this.published = false,
  });
  final NotebookController controller;
  final List<Pupil> pupils;
  final List<AssignmentSource> sources;
  final ValueChanged<List<AssignmentSource>> onChanged;
  final bool published;
  @override
  State<HomeworkMaterials> createState() => _HomeworkMaterialsState();
}

class _HomeworkMaterialsState extends State<HomeworkMaterials> {
  String? selectedPupil;
  @override
  Widget build(BuildContext context) {
    final people = widget.pupils;
    final pupil = people.length == 1
        ? people.single
        : people.where((p) => p.id == selectedPupil).firstOrNull;
    final scope = widget.published ? null : pupil?.id;
    final visible = widget.sources.where((s) => s.pupilId == scope).toList();
    final controller = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Unterrichtsmaterial',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (people.length > 1)
          DropdownButton<String>(
            value: pupil?.id ?? '',
            isExpanded: true,
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Für alle ausgewählten Schüler'),
              ),
              for (final p in people)
                DropdownMenuItem(value: p.id, child: Text('Nur für ${p.name}')),
            ],
            onChanged: (v) => setState(() => selectedPupil = v),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Material verknüpfen'),
          onPressed: people.isEmpty
              ? null
              : () async {
                  final ids = await chooseMaterials(context, controller, [
                    for (final s in visible) s.documentId,
                  ], pupil: pupil);
                  if (ids == null || !mounted) return;
                  widget.onChanged([
                    for (final s in widget.sources)
                      if (s.pupilId != scope || ids.contains(s.documentId)) s,
                    for (final d in controller.classroom)
                      if (!d.deleted &&
                          d.kind == ClassroomKind.material &&
                          ids.contains(d.id) &&
                          !visible.any((s) => s.documentId == d.id))
                        AssignmentSource(
                          documentId: d.id,
                          title: d.title,
                          pupilId: scope,
                        ),
                  ]);
                },
        ),
        for (final group in <String?>{
          for (final s in widget.sources) s.pupilId,
        })
          if (group == null || people.any((p) => p.id == group)) ...[
            if (people.length > 1)
              Text(
                group == null
                    ? 'Gemeinsam'
                    : people.firstWhere((p) => p.id == group).name,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            WorkAssignmentSources(
              controller: controller,
              date: '',
              showPicker: false,
              onChanged: (remaining) => widget.onChanged([
                for (final s in widget.sources)
                  if (s.pupilId != group || remaining.contains(s)) s,
              ]),
              values: widget.sources.where((s) => s.pupilId == group).toList(),
            ),
          ],
      ],
    );
  }
}
