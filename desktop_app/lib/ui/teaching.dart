part of 'workspace.dart';

extension _TeachingDesk on _DesktopWorkspaceState {
  Future<void> deskFile(ClassroomDocument m) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 960,
          height: MediaQuery.sizeOf(ctx).height * .8,
          child: Column(
            children: [
              ListTile(
                title: Text(m.title),
                trailing: IconButton(
                  tooltip: 'Schließen',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: DocumentPreview(
                  key: ValueKey(m.text('localKey')),
                  material: m,
                  files: c.files,
                  loadOnline: loadDocxPreview,
                ),
              ),
              TextButton.icon(
                onPressed: () => run(() => openOriginal(m)),
                icon: const Icon(Icons.file_open_outlined),
                label: Text(
                  m.text('localKey').isEmpty
                      ? 'In OneDrive öffnen'
                      : 'Originaldatei speichern',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> deskLesson(String day, {CalendarItem? item}) async {
    final occurrence = item?.lesson;
    var selectedDay = day;
    final timelineKey = GlobalKey();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => Scaffold(
            appBar: AppBar(
              title: Text(
                selectedDay == day
                    ? occurrence?.title ?? 'Unterrichtsablauf'
                    : 'Unterrichtsablauf',
              ),
              actions: [
                if (item != null && selectedDay == day)
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await run(() => openDeskCalendarItem(item));
                    },
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Stunde bearbeiten'),
                  ),
              ],
            ),
            body: AnimatedBuilder(
              animation: c.notebook,
              builder: (ctx, _) {
                final sourceFiles = [
                  ...teachingSources(c.notebook.classroom, selectedDay),
                  ...teachingSources(
                    c.notebook.classroom,
                    selectedDay,
                    week: true,
                  ),
                ];
                final timeline = LessonFlowPage(
                  key: timelineKey,
                  controller: c.notebook,
                  initialDate: day,
                  initialTarget: occurrence?.target,
                  openFile: deskFile,
                  onDateChanged: (v) => update(() => selectedDay = v),
                );
                if (sourceFiles.isEmpty || MediaQuery.sizeOf(ctx).width < 860) {
                  return timeline;
                }
                return Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _DeskPlanSource(
                        key: ValueKey(sourceFiles.map((m) => m.id).join('|')),
                        sources: sourceFiles,
                        files: c.files,
                        loadOnline: loadDocxPreview,
                        onReview: (m) => openTeachingReview(
                          ctx,
                          c.notebook,
                          m,
                          original: deskFile,
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 6, child: timeline),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> chooseSource() async {
    final items = c.notebook.classroom.where(isTeachingSource).toList()
      ..sort(
        (a, b) => (teachingDay(b).isEmpty ? teachingWeek(b) : teachingDay(b))
            .compareTo(
              teachingDay(a).isEmpty ? teachingWeek(a) : teachingDay(a),
            ),
      );
    var query = '';
    final chosen = await showDialog<ClassroomDocument>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Unterrichtsplanungen aus OneDrive'),
          content: SizedBox(
            width: 600,
            height: 440,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Planung suchen',
                  ),
                  onChanged: (v) => update(() => query = sheetFold(v)),
                ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Verbinde den Planungsordner unter Materialien mit OneDrive.',
                    ),
                  ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final m in items.where(
                        (m) => sheetFold(m.title).contains(query),
                      ))
                        ListTile(
                          leading: Icon(
                            teachingUse(m) == 'weekPlan'
                                ? Icons.view_week_outlined
                                : Icons.view_day_outlined,
                          ),
                          title: Text(m.title),
                          subtitle: Text(m.text('sourcePath')),
                          onTap: () => Navigator.pop(ctx, m),
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
              child: const Text('Schließen'),
            ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      await openTeachingReview(context, c.notebook, chosen, original: deskFile);
    }
  }
}

class _DeskPlanSource extends StatefulWidget {
  const _DeskPlanSource({
    super.key,
    required this.sources,
    required this.files,
    required this.onReview,
    required this.loadOnline,
  });
  final List<ClassroomDocument> sources;
  final MaterialFiles files;
  final Future<Uint8List?> Function(ClassroomDocument) loadOnline;
  final Future<void> Function(ClassroomDocument) onReview;
  @override
  State<_DeskPlanSource> createState() => _DeskPlanSourceState();
}

class _DeskPlanSourceState extends State<_DeskPlanSource> {
  String? id;
  @override
  Widget build(BuildContext context) {
    final m =
        widget.sources.where((d) => d.id == id).firstOrNull ??
        widget.sources.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Planungsunterlagen',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          DropdownButton<String>(
            isExpanded: true,
            value: m.id,
            items: [
              for (final s in widget.sources)
                DropdownMenuItem(
                  value: s.id,
                  child: Text(s.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => id = v),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.rule),
              label: const Text('Zeilen prüfen und zuordnen'),
              onPressed: () => widget.onReview(m),
            ),
          ),
          Expanded(
            child: DocumentPreview(
              key: ValueKey('${m.id}/${m.text('localKey')}'),
              material: m,
              files: widget.files,
              loadOnline: widget.loadOnline,
            ),
          ),
        ],
      ),
    );
  }
}
