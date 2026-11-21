part of 'teaching_review.dart';

class _RowEditor extends StatefulWidget {
  const _RowEditor(this.source, this.row, this.c);
  final ClassroomDocument source;
  final Json row;
  final NotebookController c;
  @override
  State<_RowEditor> createState() => _RowEditorState();
}

class _RowEditorState extends State<_RowEditor> {
  late String type;
  late final Map<String, TextEditingController> fields;
  late final TeachingLinks links;
  late Set<String> chosen;
  bool explicit = false;
  String? error;
  @override
  void initState() {
    super.initState();
    type = sheetText(widget.row, 'type');
    fields = {
      for (final k in sheetFields.keys.where(
        (k) => k != 'type' && k != 'files',
      ))
        k: TextEditingController(text: sheetText(widget.row, k)),
    };
    links = TeachingLinks(widget.source, widget.c.classroom, widget.c.pupils);
    explicit = widget.row.containsKey('files');
    chosen = explicit
        ? sheetText(
            widget.row,
            'files',
          ).split('\n').where((s) => s.isNotEmpty).toSet()
        : links
              .rowMaterials(widget.row)
              .map(
                (id) => links.items.values
                    .firstWhere((m) => m.id == id)
                    .text('itemId'),
              )
              .toSet();
  }

  @override
  void dispose() {
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> pickFiles() async {
    final selected = {...chosen};
    var query = '';
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Unterlagen dieser Planung'),
          content: SizedBox(
            width: 520,
            height: 390,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Datei suchen'),
                  onChanged: (v) => update(() => query = sheetFold(v)),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final m in links.items.values.where(
                        (m) => sheetFold(m.title).contains(query),
                      ))
                        CheckboxListTile(
                          value: selected.contains(m.text('itemId')),
                          title: Text(m.title),
                          subtitle: Text(
                            m.text('sourcePath'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onChanged: (on) => update(
                            () => on == true
                                ? selected.add(m.text('itemId'))
                                : selected.remove(m.text('itemId')),
                          ),
                        ),
                    ],
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
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Zuordnen'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        chosen = result;
        explicit = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = switch (type) {
      'phase' => [
        'phase',
        'time',
        'task',
        'goal',
        'subject',
        'duration',
        'owner',
        'refs',
      ],
      'aid' => ['phase', 'who', 'task', 'duration', 'refs'],
      'week' => ['day', 'task', 'prep'],
      'goal' => ['subject', 'goal', 'time'],
      _ => ['task'],
    };
    return AlertDialog(
      title: const Text('Planzeile bearbeiten'),
      content: SizedBox(
        width: 520,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              sheetText(widget.row, 'raw'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Zeilenart'),
              items: [
                for (final e in sheetTypes.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => type = v!),
            ),
            for (final k in visible) ...[
              const SizedBox(height: 10),
              TextField(
                controller: fields[k],
                decoration: InputDecoration(
                  labelText: sheetFields[k],
                  helperText: k == 'time' && type == 'phase'
                      ? 'z. B. 08:00–08:30'
                      : null,
                ),
                keyboardType: k == 'duration'
                    ? TextInputType.number
                    : TextInputType.multiline,
                maxLines: k == 'task' || k == 'goal' ? 4 : 1,
              ),
              if (k == 'who')
                Wrap(
                  spacing: 5,
                  children: [
                    for (final p in widget.c.pupils.where(
                      (p) => !p.deleted && !p.archived,
                    ))
                      ActionChip(
                        label: Text(p.name),
                        onPressed: () {
                          final code =
                              pupilProfile(
                                widget.c.classroom,
                                p.id,
                                teachingPlan(widget.source)['year']
                                        as String? ??
                                    '',
                              )?.text('code') ??
                              '';
                          final value = code.isEmpty ? p.name : code;
                          final people = fields['who']!.text
                              .split(RegExp(r'[/,;]'))
                              .map((v) => v.trim())
                              .where(
                                (v) => v.isNotEmpty && sheetFold(v) != 'alle',
                              )
                              .toSet();
                          if (!people.remove(value)) people.add(value);
                          setState(
                            () => fields['who']!.text = people.join(' / '),
                          );
                        },
                      ),
                  ],
                ),
              if (k == 'refs')
                OutlinedButton.icon(
                  onPressed: pickFiles,
                  icon: const Icon(Icons.folder_open),
                  label: Text('Dateien zuordnen · ${chosen.length}'),
                ),
            ],
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            String v(String k) => fields[k]!.text.trim();
            if ((type == 'phase' || type == 'aid') &&
                    (v('phase').isEmpty || v('phase').length > 160) ||
                type == 'phase' &&
                    v('time').isNotEmpty &&
                    sheetTime(v('time')) == null ||
                type == 'aid' && v('who').isEmpty ||
                type == 'week' && sheetWeekdays(v('day')).isEmpty ||
                visible.contains('duration') &&
                    v('duration').isNotEmpty &&
                    ((int.tryParse(v('duration')) ?? 0) < 1 ||
                        (int.tryParse(v('duration')) ?? 601) > 600)) {
              setState(
                () => error = 'Bitte Phase, Zeit, Dauer und Zuordnung prüfen.',
              );
              return;
            }
            Navigator.pop(context, <String, dynamic>{
              'type': type,
              for (final e in fields.entries) e.key: e.value.text.trim(),
              if (explicit) 'files': chosen.join('\n'),
            });
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
