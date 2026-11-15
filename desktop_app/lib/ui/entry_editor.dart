part of 'workspace.dart';

class EntryEditor extends StatefulWidget {
  const EntryEditor({
    super.key,
    required this.session,
    required this.workspace,
    required this.onSave,
    required this.onPark,
    required this.onDiscard,
    required this.onTrash,
  });
  final EditorSession session;
  final WorkspaceController workspace;
  final VoidCallback onSave, onPark, onDiscard, onTrash;
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  EditorSession get s => widget.session;
  WorkspaceController get c => widget.workspace;
  Json get d => s.data;
  String tone = 'neutral';
  final catalogs = <String, List<String>>{};
  @override
  void initState() {
    super.initState();
    if (s.kind == EntryKind.social || s.kind == EntryKind.work) {
      for (final key in observationTones.keys) {
        unawaited(
          c.repository
              .observationCatalog('${s.kind.name}-$key')
              .then((catalog) {
                if (mounted) setState(() => catalogs[key] = catalog.options);
              })
              .catchError((Object _) {}),
        );
      }
    }
  }

  final newTask = TextEditingController();
  @override
  void dispose() {
    newTask.dispose();
    super.dispose();
  }

  String text(String key) => d[key] as String? ?? '';
  List<Json> rows(String key) =>
      (d[key] as List? ?? []).map((e) => Json.from(e as Map)).toList();
  List<String> ids(String key) => List<String>.from(d[key] as List? ?? []);
  Widget field(String key, String label, {int lines = 1, int? max}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: ValueKey('${s.draftId}:$key'),
      initialValue: text(key),
      maxLines: lines,
      maxLength: max,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: lines > 1,
      ),
      onChanged: (v) => s.patch({key: v}),
    ),
  );
  Widget section(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Text(
      title,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
  Widget dateField(String key, String label, {bool clear = true}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final initial = DateTime.tryParse(text(key)) ?? c.date;
              final selected = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (selected != null) s.patch({key: dateOnly(selected)});
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(
              '$label · ${text(key).isEmpty ? 'Ohne Datum' : shortDate(text(key))}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
        if (clear && text(key).isNotEmpty)
          IconButton(
            tooltip: 'Datum entfernen',
            onPressed: () =>
                s.patch({key: s.kind.school || s.kind.orga ? null : ''}),
            icon: const Icon(Icons.close, size: 16),
          ),
      ],
    ),
  );
  Widget timeField(String key, String label) => OutlinedButton(
    onPressed: () async {
      final n = clockMinutes(text(key));
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: n ~/ 60, minute: n % 60),
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      if (t != null) s.patch({key: minutesClock(t.hour * 60 + t.minute)});
    },
    child: Text('$label ${text(key)}', style: const TextStyle(fontSize: 11)),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: s,
    builder: (ctx, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (d['revision'] as int? ?? 0) > 0
                          ? 'EINTRAG BEARBEITEN'
                          : 'NEUER EINTRAG',
                      style: const TextStyle(
                        fontSize: 9,
                        color: muted,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      s.kind.label,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Schließen und Entwurf behalten',
                onPressed: s.saving ? null : widget.onPark,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (s.kind.school || s.kind.orga) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('${s.draftId}:owner'),
                  initialValue: text('pupilId').isEmpty ? '' : text('pupilId'),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Zuordnung'),
                  items: [
                    if (!s.kind.school)
                      const DropdownMenuItem(
                        value: '',
                        child: Text('FLEX-Klasse'),
                      ),
                    for (final p in c.notebook.pupils.where(
                      (p) =>
                          (!p.archived && !p.deleted) ||
                          p.id == text('pupilId'),
                    ))
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: s.saving
                      ? null
                      : (v) =>
                            s.patch({'pupilId': v?.isEmpty == true ? null : v}),
                ),
                const SizedBox(height: 16),
              ],
              if (s.kind == EntryKind.social || s.kind == EntryKind.work) ...[
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'positive', label: Text('Positiv')),
                    ButtonSegment(value: 'neutral', label: Text('Neutral')),
                    ButtonSegment(value: 'negative', label: Text('Negativ')),
                  ],
                  selected: {tone},
                  onSelectionChanged: (v) => setState(() => tone = v.first),
                  style: ButtonStyle(
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final label in suggestions())
                      FilterChip(
                        label: Text(
                          label,
                          style: const TextStyle(fontSize: 10),
                        ),
                        selected: ids(tone).contains(label),
                        onSelected: (selected) => s.patch({
                          tone: selected
                              ? [...ids(tone), label]
                              : ids(tone).where((e) => e != label).toList(),
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: addObservation,
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text(
                    'Eigene Beobachtung',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                if ([
                  'positive',
                  'neutral',
                  'negative',
                ].any((v) => ids(v).isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final value in ['positive', 'neutral', 'negative'])
                          for (final tag in ids(value))
                            InputChip(
                              backgroundColor: toneColor(
                                value,
                              ).withValues(alpha: .12),
                              label: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: toneColor(value),
                                ),
                              ),
                              onDeleted: () => s.patch({
                                value: ids(
                                  value,
                                ).where((t) => t != tag).toList(),
                              }),
                            ),
                      ],
                    ),
                  ),
                field('body', 'Beobachtung', lines: 6, max: 12000),
                dateField('observedOn', 'Beobachtet am', clear: false),
                field(
                  'subject',
                  s.kind == EntryKind.work ? 'Auftrag / Fach' : 'Situation',
                ),
              ] else ...[
                field(
                  'title',
                  s.kind == EntryKind.returnList ? 'Bezeichnung' : 'Titel',
                  max: s.kind.school ? 3000 : 160,
                ),
                if (s.kind == EntryKind.homework) ...[
                  field('subject', 'Fach'),
                  dateField('dueDate', 'Fällig'),
                  section('Aufgaben'),
                  taskList(school: true),
                  field('body', 'Notiz zur Hausübung', lines: 3),
                ] else if (s.kind == EntryKind.goal) ...[
                  field('body', 'Zielbeschreibung', lines: 4),
                  field(
                    'criterion',
                    'Woran erkennen wir den Fortschritt?',
                    lines: 2,
                  ),
                  field('support', 'Unterstützung', lines: 2),
                  dateField('nextReviewDate', 'Überprüfung'),
                  DropdownButtonFormField<String>(
                    initialValue: text('goalStatus'),
                    decoration: const InputDecoration(labelText: 'Stand'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Aktiv')),
                      DropdownMenuItem(
                        value: 'achieved',
                        child: Text('Erreicht'),
                      ),
                      DropdownMenuItem(value: 'ended', child: Text('Beendet')),
                    ],
                    onChanged: (v) => s.patch({'goalStatus': v}),
                  ),
                ] else if (s.kind == EntryKind.returnList)
                  ...returnFields()
                else if (s.kind == EntryKind.plan || s.kind == EntryKind.lesson)
                  ...planningFields()
                else ...[
                  field(
                    'body',
                    s.kind == EntryKind.note ? 'Notiz' : 'Beschreibung',
                    lines: 5,
                  ),
                  if (s.kind == EntryKind.task) ...[
                    dateField('dueDate', 'Fällig'),
                    section('Unteraufgaben'),
                    taskList(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Aufgabe erledigt',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: d['done'] == true,
                      onChanged: (v) => s.patch({'done': v}),
                    ),
                  ],
                  if (s.kind == EntryKind.appointment) ...[
                    dateField('appointmentDate', 'Termin', clear: false),
                    Row(
                      children: [
                        Expanded(child: timeField('appointmentTime', 'Von')),
                        const SizedBox(width: 8),
                        Expanded(child: timeField('appointmentEndTime', 'Bis')),
                      ],
                    ),
                    const SizedBox(height: 14),
                    tagsField(),
                  ],
                ],
              ],
              if (s.kind.orga) field('otherParticipants', 'Weitere Personen'),
              if (s.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    '${s.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    s.error == null
                        ? Icons.cloud_done_outlined
                        : Icons.error_outline,
                    size: 13,
                    color: s.error == null ? muted : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.status,
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                  ),
                  if ((d['revision'] as int? ?? 0) > 0)
                    IconButton(
                      tooltip: 'Eintrag in den Papierkorb',
                      onPressed: s.saving ? null : widget.onTrash,
                      icon: const Icon(Icons.delete_outline, size: 17),
                    ),
                  TextButton(
                    onPressed: s.saving ? null : widget.onDiscard,
                    child: const Text(
                      'Verwerfen',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              FilledButton.icon(
                onPressed: s.saving ? null : widget.onSave,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Speichern       Strg ↵'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  List<String> suggestions() =>
      catalogs[tone] ?? observationDefaults['${s.kind.name}-$tone'] ?? [];
  Color toneColor(String value) => switch (value) {
    'positive' => const Color(0xff52735c),
    'negative' => const Color(0xff97695e),
    _ => const Color(0xff647b8c),
  };
  Future<void> addObservation() async {
    final input = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${observationTones[tone]} · eigene Beobachtung'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 1000,
          decoration: const InputDecoration(labelText: 'Beobachtung'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (input.text.trim().isNotEmpty) {
                Navigator.pop(ctx, input.text.trim());
              }
            },
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
    if (value != null && mounted) {
      s.patch({
        tone: {...ids(tone), value}.toList(),
      });
    }
  }

  Widget tagsField() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      initialValue: ids('tags').join(', '),
      decoration: const InputDecoration(
        labelText: 'Tags · durch Komma trennen',
      ),
      onChanged: (v) => s.patch({
        'tags': v
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList(),
      }),
    ),
  );
  Widget taskList({bool school = false}) {
    final key = school ? 'tasks' : 'items',
        tasks = rows(school ? 'tasks' : 'items');
    return Column(
      children: [
        for (final task in tasks)
          Row(
            children: [
              if (!school)
                Checkbox(
                  value: task['checked'] == true,
                  onChanged: (v) => s.patch({
                    key: [
                      for (final row in tasks)
                        if (row['id'] == task['id'])
                          {...row, 'checked': v}
                        else
                          row,
                    ],
                  }),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TextFormField(
                    key: ValueKey(task['id']),
                    initialValue: task['text'] as String,
                    decoration: const InputDecoration(isDense: true),
                    onChanged: (v) => s.patch({
                      key: [
                        for (final row in tasks)
                          if (row['id'] == task['id'])
                            {...row, 'text': v}
                          else
                            row,
                      ],
                    }),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Teilaufgabe entfernen',
                onPressed: () => s.patch({
                  key: tasks
                      .where(
                        (t) =>
                            t['id'] != task['id'] &&
                            t['parentId'] != task['id'],
                      )
                      .toList(),
                }),
                icon: const Icon(Icons.close, size: 15),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: newTask,
            decoration: InputDecoration(
              hintText: 'Teilaufgabe hinzufügen',
              suffixIcon: IconButton(
                tooltip: 'Teilaufgabe hinzufügen',
                onPressed: () => appendTask(school),
                icon: const Icon(Icons.add),
              ),
            ),
            onSubmitted: (_) => appendTask(school),
          ),
        ),
      ],
    );
  }

  void appendTask(bool school) {
    if (newTask.text.trim().isEmpty) return;
    final key = school ? 'tasks' : 'items';
    s.patch({
      key: [
        ...rows(key),
        if (school)
          HomeworkTask(id: newId(), text: newTask.text.trim()).toJson()
        else
          CheckItem(id: newId(), text: newTask.text.trim()).toJson(),
      ],
    });
    newTask.clear();
  }

  void toggleParticipant(Pupil pupil, bool selected) => s.patch({
    'participants': selected
        ? [
            ...rows('participants'),
            {
              'pupilId': pupil.id,
              'name': pupil.name,
              'status': 'open',
              'note': '',
              'paid': 0,
            },
          ]
        : rows('participants').where((r) => r['pupilId'] != pupil.id).toList(),
  });
  List<Widget> returnFields() => [
    DropdownButtonFormField<String>(
      initialValue: text('type'),
      decoration: const InputDecoration(labelText: 'Art des Rücklaufs'),
      items: [
        for (final t in returnTypes.entries)
          DropdownMenuItem(value: t.key, child: Text(t.value)),
      ],
      onChanged: (v) {
        if (v == null) return;
        s.patch({
          'type': v,
          'participants': [
            for (final p in rows('participants'))
              {
                ...p,
                'status': returnStatuses[v]!.containsKey(p['status'])
                    ? p['status']
                    : 'open',
              },
          ],
        });
      },
    ),
    const SizedBox(height: 14),
    dateField('dueDate', 'Frist'),
    if (text('type') == 'payment')
      TextFormField(
        initialValue: ((d['amountDue'] as int? ?? 0) / 100).toStringAsFixed(2),
        decoration: const InputDecoration(labelText: 'Betrag pro Person (€)'),
        keyboardType: TextInputType.number,
        onChanged: (v) {
          final amount = double.tryParse(v.replaceAll(',', '.'));
          if (amount != null) s.patch({'amountDue': (amount * 100).round()});
        },
      ),
    section('Schüler & Rückmeldungen'),
    for (final p in c.pupils)
      Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(p.name, style: const TextStyle(fontSize: 11)),
                value: rows('participants').any((r) => r['pupilId'] == p.id),
                onChanged: (value) => toggleParticipant(p, value == true),
              ),
            ),
            if (rows('participants').any((r) => r['pupilId'] == p.id))
              DropdownButton<String>(
                value:
                    rows(
                          'participants',
                        ).firstWhere((r) => r['pupilId'] == p.id)['status']
                        as String,
                underline: const SizedBox(),
                style: const TextStyle(
                  fontFamily: 'FlexSans',
                  fontSize: 10,
                  color: ink,
                ),
                items: [
                  for (final status in returnStatuses[text('type')]!.entries)
                    DropdownMenuItem(
                      value: status.key,
                      child: Text(status.value),
                    ),
                ],
                onChanged: (v) => s.patch({
                  'participants': [
                    for (final row in rows('participants'))
                      if (row['pupilId'] == p.id)
                        {...row, 'status': v}
                      else
                        row,
                  ],
                }),
              ),
          ],
        ),
      ),
    const SizedBox(height: 14),
    field('note', 'Hinweis', lines: 3),
    materialChoices(),
  ];
  List<Widget> planningFields() => [
    dateField('date', 'Unterrichtstag', clear: false),
    if (s.kind == EntryKind.lesson) ...[
      Row(
        children: [
          Expanded(child: timeField('start', 'Von')),
          const SizedBox(width: 8),
          Expanded(child: timeField('end', 'Bis')),
        ],
      ),
      const SizedBox(height: 14),
      field('room', 'Raum'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Wöchentlich wiederholen',
          style: TextStyle(fontSize: 12),
        ),
        value: (d['repeat'] as Map?)?['frequency'] == 'weekly',
        onChanged: (v) => s.patch({
          'repeat': RepeatRule(frequency: v ? 'weekly' : 'none').toJson(),
        }),
      ),
    ],
    field('subject', 'Fach / Thema'),
    field(
      'note',
      s.kind == EntryKind.plan ? 'Ablauf · Ziele · Zeitbedarf' : 'Notiz',
      lines: 7,
    ),
    if (s.kind == EntryKind.plan) ...[
      DropdownButtonFormField<String>(
        initialValue: text('status'),
        decoration: const InputDecoration(labelText: 'Stand'),
        items: [
          for (final e in planStatuses.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => s.patch({'status': v}),
      ),
      const SizedBox(height: 14),
      field('followUp', 'Nachbereitung', lines: 3),
    ],
    section('Schülerzuordnung'),
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final p in c.pupils)
          FilterChip(
            label: Text(p.name, style: const TextStyle(fontSize: 10)),
            selected: ids('pupilIds').contains(p.id),
            onSelected: (v) => s.patch({
              'pupilIds': v
                  ? [...ids('pupilIds'), p.id]
                  : ids('pupilIds').where((id) => id != p.id).toList(),
            }),
          ),
      ],
    ),
    const SizedBox(height: 14),
    materialChoices(),
  ];
  Widget materialChoices() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      section('Zugeordnete Materialien'),
      if (c.materials.isEmpty)
        const Text(
          'Dateien zuerst im Materialbereich hinzufügen.',
          style: TextStyle(fontSize: 11, color: muted),
        ),
      for (final m in c.materials)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          secondary: MaterialThumbnail(
            material: m,
            files: c.files,
            width: 26,
            height: 35,
          ),
          title: Text(m.title, style: const TextStyle(fontSize: 11)),
          value: ids('materialIds').contains(m.id),
          onChanged: (v) => s.patch({
            'materialIds': v == true
                ? [...ids('materialIds'), m.id]
                : ids('materialIds').where((id) => id != m.id).toList(),
          }),
        ),
    ],
  );
}
