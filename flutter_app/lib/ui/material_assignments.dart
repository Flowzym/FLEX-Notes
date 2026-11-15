part of 'material_library.dart';

/// One material: edit its complete assignment. Several materials (or a pupil
/// entry point): add assignments without replacing any existing pupil's dates.
Future<bool> showMaterialAssignments(
  BuildContext context,
  NotebookController c,
  List<ClassroomDocument> materials, {
  Pupil? pupil,
}) async {
  if (materials.isEmpty) return false;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _MaterialAssignments(
          controller: c,
          materials: materials,
          pupil: pupil,
        ),
      ) ??
      false;
}

class _MaterialAssignments extends StatefulWidget {
  const _MaterialAssignments({
    required this.controller,
    required this.materials,
    this.pupil,
  });
  final NotebookController controller;
  final List<ClassroomDocument> materials;
  final Pupil? pupil;

  @override
  State<_MaterialAssignments> createState() => _MaterialAssignmentsState();
}

class _MaterialAssignmentsState extends State<_MaterialAssignments> {
  NotebookController get c => widget.controller;
  bool get adding => widget.pupil != null || widget.materials.length > 1;
  late final ids = <String>{
    if (widget.pupil != null) widget.pupil!.id,
    if (!adding) ...widget.materials.single.strings('pupilIds'),
  };
  late final dates = <String, List<String>>{
    if (!adding)
      for (final id in ids) id: pupilMaterialDates(widget.materials.single, id),
  };
  late final pupils = <Pupil>[
    if (widget.pupil != null)
      widget.pupil!
    else ...[
      for (final p in c.pupils)
        if ((!p.archived && !p.deleted) || ids.contains(p.id)) p,
      for (final id in ids)
        if (!c.pupils.any((p) => p.id == id))
          Pupil(id: id, name: 'Nicht verfügbarer Schüler', archived: true),
    ],
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  String query = '';
  bool busy = false;
  String? error;

  Future<void> plan(String id, {String? previous}) async {
    final result = await pickFlexDate(
      context,
      date: previous ?? dateOnly(DateTime.now()),
      allowTime: false,
      allowDateClear: previous != null,
      title: 'Im Unterricht geplant',
    );
    if (result == null || !mounted) return;
    setState(() {
      final values = dates.putIfAbsent(id, () => []);
      values.remove(previous);
      if (result.$1.isNotEmpty && !values.contains(result.$1)) {
        values.add(result.$1);
      }
      values.sort();
    });
  }

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // Keep captured revisions. A concurrent edit must not be overwritten.
      await c.repository.saveClassroomDocuments([
        for (final material in widget.materials)
          assignMaterialPupils(material, ids, dates, add: adding),
      ]);
      await c.reload();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = pupils.where(
      (p) => p.name.toLowerCase().contains(query.trim().toLowerCase()),
    );
    return PopScope(
      canPop: !busy,
      child: FlexModal(
        title: Text(
          widget.pupil == null ? 'Schüler zuordnen' : 'Material zuordnen',
        ),
        onClose: busy ? null : () => Navigator.pop(context),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.materials.length == 1
                  ? widget.materials.single.title
                  : '${widget.materials.length} Materialien',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              adding
                  ? 'Einsatzdatum optional. Bestehende Zuordnungen bleiben erhalten.'
                  : 'Ein Material, individuelle Einsatzdaten pro Schüler.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (pupils.length > 6) ...[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('material-assignment-search'),
                enabled: !busy,
                decoration: const InputDecoration(
                  hintText: 'Schüler suchen',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
            ],
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  pupils.isEmpty
                      ? 'Zuerst unter Live → Notizen einen Schüler hinzufügen.'
                      : 'Keine passenden Schüler.',
                ),
              ),
            for (final p in visible)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.pupil != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(p.name),
                    )
                  else
                    CheckboxListTile(
                      key: ValueKey('material-assignment-${p.id}'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(p.name),
                      subtitle: p.archived ? const Text('Archiviert') : null,
                      value: ids.contains(p.id),
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              if (value == true) {
                                ids.add(p.id);
                              } else {
                                ids.remove(p.id);
                              }
                            }),
                    ),
                  if (ids.contains(p.id))
                    Wrap(
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final date in dates[p.id] ?? <String>[])
                          OutlinedButton.icon(
                            key: ValueKey('assignment-date-${p.id}-$date'),
                            onPressed: busy
                                ? null
                                : () => plan(p.id, previous: date),
                            icon: const Icon(Icons.event_outlined, size: 18),
                            label: Text(displayDate(date)),
                          ),
                        TextButton.icon(
                          key: ValueKey('assignment-plan-${p.id}'),
                          onPressed: busy ? null : () => plan(p.id),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(
                            (dates[p.id] ?? []).isEmpty
                                ? 'Einsatzdatum · optional'
                                : 'Weiteres Datum',
                          ),
                        ),
                      ],
                    ),
                  const Divider(height: 12),
                ],
              ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: const ValueKey('material-assignment-save'),
            onPressed: busy || (adding && ids.isEmpty) ? null : save,
            child: Text(busy ? 'Speichert …' : 'Übernehmen'),
          ),
        ],
      ),
    );
  }
}
