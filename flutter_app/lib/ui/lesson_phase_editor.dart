part of 'lesson_flow_page.dart';

class _LessonPhaseEditor extends StatefulWidget {
  const _LessonPhaseEditor({
    required this.controller,
    required this.phase,
    required this.onSave,
    this.individual = false,
  });
  final NotebookController controller;
  final LessonPhase phase;
  final bool individual;
  final Future<void> Function(LessonPhase) onSave;
  @override
  State<_LessonPhaseEditor> createState() => _LessonPhaseEditorState();
}

class _LessonPhaseEditorState extends State<_LessonPhaseEditor> {
  late final title = TextEditingController(text: widget.phase.title);
  late final body = TextEditingController(text: widget.phase.body);
  late final minutes = TextEditingController(
    text: widget.phase.minutes == 0 ? '' : '${widget.phase.minutes}',
  );
  late var materials = [...widget.phase.materialIds],
      pupils = [...widget.phase.pupilIds];
  late String kind = widget.phase.kind;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    minutes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final duration = minutes.text.trim().isEmpty
          ? 0
          : int.tryParse(minutes.text.trim());
      if (duration == null) {
        throw const DomainError('Bitte die Dauer in ganzen Minuten eingeben.');
      }
      await widget.onSave(
        widget.phase.patch({
          'title': title.text.trim(),
          'body': body.text.trim(),
          'minutes': duration,
          'materialIds': materials,
          'pupilIds': widget.individual ? <String>[] : pupils,
          'kind': kind,
        }),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = friendlyError(e);
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: FlexModal(
      title: const Text('Unterrichtsphase'),
      onClose: busy ? null : () => Navigator.pop(context),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          TextField(
            controller: title,
            enabled: !busy,
            maxLength: 160,
            decoration: const InputDecoration(
              labelText: 'Titel',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: body,
            enabled: !busy,
            minLines: 2,
            maxLines: 6,
            maxLength: 12000,
            decoration: const InputDecoration(
              labelText: 'Arbeitsauftrag · optional',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: minutes,
            enabled: !busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Dauer · optional',
              suffixText: 'Min.',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              for (final entry in {
                'work': 'Unterricht',
                'homework': 'HÜ-Kontrolle',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: kind == entry.key,
                  onSelected: busy
                      ? null
                      : (_) => setState(() => kind = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final ids = await chooseMaterials(
                      context,
                      widget.controller,
                      materials,
                    );
                    if (ids != null && mounted) setState(() => materials = ids);
                  },
            icon: const Icon(Icons.folder_outlined),
            label: Text('Materialien · ${materials.length}'),
          ),
          for (final m in resolveMaterials(
            widget.controller.classroom,
            materials,
          ))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: MaterialThumbnail(material: m, width: 32, height: 42),
              title: Text(
                m.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Material entfernen: ${m.title}',
                onPressed: busy
                    ? null
                    : () => setState(() => materials.remove(m.id)),
                icon: const Icon(Icons.close, size: 18),
              ),
            ),
          if (!widget.individual)
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final ids = await chooseMaterialPupils(
                        context,
                        widget.controller,
                        pupils,
                      );
                      if (ids != null && mounted) setState(() => pupils = ids);
                    },
              icon: const Icon(Icons.people_outline),
              label: Text(
                pupils.isEmpty
                    ? 'Ganze FLEX-Klasse'
                    : 'Schüler · ${pupils.length}',
              ),
            ),
          if (pupils.isNotEmpty)
            Text(
              widget.controller.pupils
                  .where((p) => pupils.contains(p.id))
                  .map((p) => p.name)
                  .join(' · '),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Speichert …' : 'Speichern'),
        ),
      ],
    ),
  );
}

class _FlowTitleEditor extends StatefulWidget {
  const _FlowTitleEditor({
    required this.initial,
    required this.title,
    required this.onSave,
  });
  final String initial, title;
  final Future<void> Function(String) onSave;
  @override
  State<_FlowTitleEditor> createState() => _FlowTitleEditorState();
}

class _FlowTitleEditorState extends State<_FlowTitleEditor> {
  late final name = TextEditingController(text: widget.initial);
  String? error;
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSave(name.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: FlexModal(
      title: Text(widget.title),
      onClose: busy ? null : () => Navigator.pop(context),
      content: TextField(
        controller: name,
        enabled: !busy,
        maxLength: 160,
        decoration: InputDecoration(labelText: 'Name', errorText: error),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: const Text('Speichern'),
        ),
      ],
    ),
  );
}
