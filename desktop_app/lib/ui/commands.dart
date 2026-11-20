part of 'workspace.dart';

typedef _Command = ({
  String title,
  String detail,
  IconData icon,
  Object target,
});

class _DesktopCommands extends StatefulWidget {
  const _DesktopCommands(this.workspace);
  final WorkspaceController workspace;
  @override
  State<_DesktopCommands> createState() => _DesktopCommandsState();
}

class _DesktopCommandsState extends State<_DesktopCommands> {
  final scroll = ScrollController();
  late final focus = FocusNode(onKeyEvent: _key);
  String query = '';
  int active = 0;
  List<_Command> matches = [];
  WorkspaceController get c => widget.workspace;

  Iterable<_Command> candidates() sync* {
    final words = query.toLowerCase().trim().split(RegExp(r'\s+'));
    bool match(String s) => words.every(s.toLowerCase().contains);
    for (final s in WorkspaceSection.values) {
      if (match(s.label)) {
        yield (
          title: s.label,
          detail: 'Bereich öffnen',
          icon: sectionIcons[s.index],
          target: s,
        );
      }
    }
    for (final kind in EntryKind.values) {
      final title = '${kind.label} anlegen';
      if (match(title)) {
        yield (
          title: title,
          detail: 'Neuer Eintrag',
          icon: entryIcons[kind.index],
          target: kind,
        );
      }
    }
    if (query.trim().isEmpty) return;
    for (final p in c.pupils) {
      if (match(p.name)) {
        yield (
          title: p.name,
          detail: 'Schülerjournal',
          icon: Icons.person_outline,
          target: p,
        );
      }
    }
    for (final r in deskOrganization(
      c.notebook,
      type: 'Alle Arten',
      status: 'Alle',
      query: query,
      today: dateOnly(DateTime.now()),
    )) {
      yield (
        title: r.title,
        detail: [
          r.kind.label,
          if (r.date.isNotEmpty) shortDate(r.date),
        ].join(' · '),
        icon: switch (r.kind) {
          DeskEntryKind.returns => Icons.assignment_turned_in_outlined,
          DeskEntryKind.appointment => Icons.event_outlined,
          DeskEntryKind.note => Icons.notes,
          DeskEntryKind.task => Icons.checklist,
        },
        target: r.target,
      );
    }
    final pupils = c.pupils;
    for (final m in c.materials) {
      if (materialMatches(m, query, pupils: pupils)) {
        yield (
          title: m.title,
          detail: [
            'Material',
            m.text('subject'),
          ].where((s) => s.isNotEmpty).join(' · '),
          icon: Icons.description_outlined,
          target: m,
        );
      }
    }
    for (final r in c.notebook.records.where((r) => !r.deleted)) {
      final detail = '${r.kind.label} · ${c.name(r.pupilId)}';
      if (match('$detail ${r.searchText}')) {
        yield (
          title: r.title.isNotEmpty
              ? r.title
              : r.body.isNotEmpty
              ? r.body
              : r.kind.label,
          detail: detail,
          icon: entryIcons[EntryKind.values.byName(r.kind.name).index],
          target: r,
        );
      }
    }
    for (final doc in c.notebook.classroom.where(
      (d) =>
          !d.deleted &&
          (d.kind == ClassroomKind.plan || d.kind == ClassroomKind.lesson),
    )) {
      final label = doc.kind == ClassroomKind.plan
          ? 'Unterrichtsplanung'
          : 'Unterricht';
      if (match(
        [
          label,
          doc.title,
          doc.text('subject'),
          doc.text('topic'),
          doc.text('note'),
          doc.text('room'),
          doc.text('date'),
          ...doc.strings('pupilIds').map(c.name),
        ].join(' '),
      )) {
        yield (
          title: doc.title,
          detail: label,
          icon: Icons.view_week_outlined,
          target: doc,
        );
      }
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || matches.isEmpty) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      Navigator.pop(context, matches[active].target);
      return KeyEventResult.handled;
    }
    if (key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    setState(
      () => active = (active + (key == LogicalKeyboardKey.arrowDown ? 1 : -1))
          .clamp(0, matches.length - 1),
    );
    if (scroll.hasClients) {
      final top = active * 58.0;
      final last = top + 58.0 - scroll.position.viewportDimension;
      if (top < scroll.offset) {
        scroll.jumpTo(top);
      } else if (last > scroll.offset) {
        scroll.jumpTo(last.clamp(0.0, scroll.position.maxScrollExtent));
      }
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    matches = candidates().take(80).toList();
    return Dialog(
      child: SizedBox(
        width: 650,
        height: 510,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: TextField(
                autofocus: true,
                focusNode: focus,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Suchen und öffnen',
                  hintText: 'Schüler, Material, Eintrag oder Aktion',
                ),
                onChanged: (v) {
                  setState(() {
                    query = v;
                    active = 0;
                  });
                  if (scroll.hasClients) scroll.jumpTo(0);
                },
              ),
            ),
            const Divider(),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('Keine Treffer'))
                  : ListView.builder(
                      controller: scroll,
                      itemExtent: 58,
                      itemCount: matches.length,
                      itemBuilder: (ctx, i) {
                        final r = matches[i];
                        return ListTile(
                          selected: i == active,
                          selectedTileColor: wash,
                          leading: Icon(r.icon),
                          title: Text(
                            r.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            r.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.pop(ctx, r.target),
                        );
                      },
                    ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                '↑ ↓  auswählen     Eingabe  öffnen     Esc  schließen',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
