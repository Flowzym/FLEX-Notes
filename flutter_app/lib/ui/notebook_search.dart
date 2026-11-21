import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/school.dart';
import 'quick_add.dart';

class NotebookHit {
  NotebookHit(
    this.value,
    this.title,
    this.detail,
    this.icon, [
    String more = '',
  ]) : terms = '$title $detail $more'.toLowerCase();
  final Object value;
  final String title, detail, terms;
  final IconData icon;
}

const _areas = {
  0: 'Kalender',
  1: 'Live',
  2: 'Organisation',
  3: 'Material',
  4: 'Weitere Bereiche',
  5: 'Scanner',
};

List<NotebookHit> notebookSearchIndex(NotebookController c) {
  final pupils = {
    for (final p in c.pupils)
      if (!p.archived && !p.deleted) p.id: p.name,
  };
  final active = c.currentSnapshot.active();
  final hits = <NotebookHit>[
    for (final p in c.pupils)
      if (pupils.containsKey(p.id))
        NotebookHit(p, p.name, 'Schüler', Icons.person_outline),
    for (final r in active.records)
      if (!r.deleted && pupils.containsKey(r.pupilId))
        NotebookHit(
          r,
          r.title.trim().isEmpty ? r.kind.label : r.title,
          '${r.kind.label} · ${pupils[r.pupilId]}',
          Icons.edit_note,
          '${r.searchText} ${r.observedOn}',
        ),
    for (final e in active.entries)
      if (!e.deleted && (e.pupilId == null || pupils.containsKey(e.pupilId)))
        NotebookHit(
          e,
          e.title,
          '${e.isAppointment
              ? 'Termin'
              : e.isTask
              ? 'Aufgabe'
              : 'Orga-Notiz'} · ${c.owner(e)}',
          Icons.event_note,
          [
            e.body,
            ...e.tags,
            for (final item in e.items) item.text,
            e.otherParticipants,
            e.appointmentDate,
            e.dueDate,
          ].nonNulls.join(' '),
        ),
  ];
  for (final d in active.classroom.where((d) => !d.deleted)) {
    final type = switch (d.kind) {
      ClassroomKind.material => ('Material', Icons.insert_drive_file_outlined),
      ClassroomKind.materialSet => (
        'Materialpaket',
        Icons.folder_copy_outlined,
      ),
      ClassroomKind.plan => (
        'Unterrichtsplanung',
        Icons.view_timeline_outlined,
      ),
      ClassroomKind.lesson => ('Unterricht', Icons.table_chart_outlined),
      ClassroomKind.returnList => ('Rücklauf', Icons.fact_check_outlined),
      _ => null,
    };
    if (type == null) continue;
    hits.add(
      NotebookHit(
        d,
        d.title,
        type.$1,
        type.$2,
        [
          d.text('subject'),
          d.text('note'),
          d.text('date'),
          d.text('dueDate'),
          d.text('folderPath'),
          d.text('otherParticipants'),
          ...d.strings('tags'),
          for (final id in d.strings('pupilIds')) pupils[id] ?? '',
          for (final row in d.rows('participants'))
            row['name']?.toString() ?? '',
        ].join(' '),
      ),
    );
  }
  return hits;
}

Future<Object?> showNotebookSearch(
  BuildContext context,
  NotebookController c,
) => Navigator.push<Object>(
  context,
  MaterialPageRoute(builder: (_) => _NotebookSearch(c)),
);

class _NotebookSearch extends StatefulWidget {
  const _NotebookSearch(this.controller);
  final NotebookController controller;
  @override
  State<_NotebookSearch> createState() => _NotebookSearchState();
}

class _NotebookSearchState extends State<_NotebookSearch> {
  final input = TextEditingController();
  late var index = notebookSearchIndex(widget.controller);
  late final commands = <NotebookHit>[
    for (final area in _areas.entries)
      NotebookHit(area.key, area.value, 'Bereich öffnen', Icons.arrow_forward),
    NotebookHit(
      'week',
      'Wochenmappe',
      'Bereich öffnen',
      Icons.calendar_view_week,
    ),
    NotebookHit(
      'board',
      'Unterrichtsplanung',
      'Planungstafel öffnen',
      Icons.view_kanban_outlined,
    ),
    for (final group in quickAddGroups())
      for (final action in group.$2)
        NotebookHit(
          action.$1,
          '${action.$2} hinzufügen',
          group.$1,
          action.$3,
          'neu anlegen erstellen',
        ),
  ];
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(refresh);
  }

  void refresh() {
    setState(() => index = notebookSearchIndex(widget.controller));
  }

  @override
  void dispose() {
    widget.controller.removeListener(refresh);
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = input.text.toLowerCase().trim().split(RegExp(r'\s+'));
    final hits = words.first.isEmpty
        ? commands
        : [
            ...index.where((h) => words.every(h.terms.contains)),
            ...commands.where((h) => words.every(h.terms.contains)),
          ];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        titleSpacing: 0,
        title: TextField(
          controller: input,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'FLEX durchsuchen',
            border: InputBorder.none,
          ),
          onSubmitted: (_) {
            if (hits.isNotEmpty) Navigator.pop(context, hits.first.value);
          },
        ),
        actions: [
          if (input.text.isNotEmpty)
            IconButton(
              tooltip: 'Suche leeren',
              onPressed: () => setState(input.clear),
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
      body: SafeArea(
        child: hits.isEmpty
            ? const ListTile(title: Text('Keine Treffer.'))
            : ListView.builder(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: hits.length,
                itemBuilder: (ctx, i) {
                  final h = hits[i];
                  return ListTile(
                    leading: Icon(h.icon),
                    title: Text(h.title),
                    subtitle: Text(h.detail),
                    onTap: () => Navigator.pop(ctx, h.value),
                  );
                },
              ),
      ),
    );
  }
}
