import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/material_workspace.dart';
import 'common.dart';

class MaterialGroupingButton extends StatelessWidget {
  const MaterialGroupingButton(this.controller, {super.key, this.onChanged});
  final NotebookController controller;
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (ctx, _) {
      final grouped = controller.appearance.groupMaterialsByPupil;
      return FilterChip(
        label: const Text('Nach Schüler'),
        tooltip: 'Materialien nach Schüler gruppieren',
        selected: grouped,
        avatar: grouped ? null : const Icon(Icons.group_outlined, size: 17),
        onSelected: (value) async {
          final saved = controller.saveAppearance(
            controller.appearance.patch({'groupMaterialsByPupil': value}),
          );
          onChanged?.call();
          await guarded(ctx, () => saved);
          if (ctx.mounted) onChanged?.call();
        },
      );
    },
  );
}

class MaterialGroupHeading extends StatelessWidget {
  const MaterialGroupHeading(this.label, this.count, {super.key});
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Text(
        '$label · $count',
        style: Theme.of(context).textTheme.titleSmall,
      ),
    ),
  );
}

List<Widget> groupedMaterialRows(
  NotebookController c,
  Iterable<ClassroomDocument> files,
  List<Widget> Function(List<ClassroomDocument>) rows, {
  String? day,
  bool enabled = true,
  String scope = "files",
}) {
  if (!enabled) return rows(files.toList());
  return groupedFileRows(
    c,
    files,
    (m) => materialOwnerIds(m, day: day),
    rows,
    scope: scope,
  );
}

List<Widget> groupedFileRows<T>(
  NotebookController c,
  Iterable<T> files,
  Iterable<String> Function(T) owners,
  List<Widget> Function(List<T>) rows, {
  String scope = "files",
}) {
  if (!c.appearance.groupMaterialsByPupil) return rows(files.toList());
  return [
    for (final g in pupilFileGroups(files, c.pupils, owners)) ...[
      MaterialGroupHeading(
        g.name,
        g.files.length,
        key: ValueKey((scope, 'heading', g.id)),
      ),
      for (final (i, row) in rows(g.files).indexed)
        KeyedSubtree(key: ValueKey((scope, g.id, row.key ?? i)), child: row),
    ],
  ];
}
