import 'material_grouping.dart';
import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/calendar.dart';
import '../domain/calendar_layout.dart';
import '../domain/classroom.dart';
import '../domain/material_workspace.dart';
import '../domain/models.dart';
import '../domain/week_folder.dart';
import '../services/week_pdf.dart';
import 'calendar_page.dart';
import 'classroom_editor.dart';
import 'common.dart';
import 'draft_buffer.dart';
import 'lesson_flow_page.dart';
import 'material_library.dart';
import 'teaching_review.dart';

Future<void> openWeekFolder(
  BuildContext context,
  NotebookController c, {
  String? date,
}) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    builder: (_) => WeekFolderPage(controller: c, date: date),
  ),
);

class WeekFolderPage extends StatefulWidget {
  const WeekFolderPage({super.key, required this.controller, this.date});
  final NotebookController controller;
  final String? date;
  @override
  State<WeekFolderPage> createState() => _WeekFolderPageState();
}

class _WeekFolderPageState extends State<WeekFolderPage> {
  late DateTime selected = widget.date == null
      ? DateTime.now()
      : schoolDay(widget.date!);
  bool exporting = false;
  NotebookController get c => widget.controller;
  String name(String? id) =>
      c.pupils.where((p) => p.id == id).firstOrNull?.name ?? '';
  Future<void> export(List<WeekDayFolder> days) async {
    if (exporting) return;
    setState(() => exporting = true);
    await guarded(context, () async {
      final bytes = await weekFolderPdf(
        days,
        name,
        pupils: c.pupils,
        grouped: c.appearance.groupMaterialsByPupil,
      );
      await saveBytesFile(
        'FLEX-Wochenmappe-${dateOnly(days.first.day)}.pdf',
        bytes,
        mime: 'application/pdf',
      );
    });
    if (mounted) setState(() => exporting = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (ctx, _) {
      final weekends = c.appearance.weekFolderWeekends;
      final days = buildWeekFolder(
        c.currentSnapshot,
        selected,
        weekends: weekends,
      );
      final day = days[(selected.weekday - 1).clamp(0, days.length - 1)];
      final date = dateOnly(day.day);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Wochenmappe'),
          toolbarHeight: 48,
          actions: [
            IconButton(
              tooltip: 'Woche als PDF speichern',
              onPressed: exporting ? null : () => export(days),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
            PopupMenuButton<bool>(
              tooltip: 'Wochenansicht einstellen',
              icon: const Icon(Icons.tune),
              onSelected: (value) {
                setState(
                  () => selected = !value && selected.weekday > 5
                      ? offsetDay(selected, 5 - selected.weekday)
                      : selected,
                );
                guarded(
                  ctx,
                  () => c.saveAppearance(
                    c.appearance.patch({'weekFolderWeekends': value}),
                  ),
                );
              },
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: !weekends,
                  checked: weekends,
                  child: const Text('Samstag und Sonntag'),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Vorherige Woche',
                    onPressed: () =>
                        setState(() => selected = offsetDay(day.day, -7)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      calendarRangeLabel(days.first.day, days.last.day),
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => selected = DateTime.now()),
                    child: const Text('Heute'),
                  ),
                  IconButton(
                    tooltip: 'Nächste Woche',
                    onPressed: () =>
                        setState(() => selected = offsetDay(day.day, 7)),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              Wrap(
                spacing: 4,
                children: [
                  for (final item in days)
                    ChoiceChip(
                      selected: item == day,
                      showCheckmark: false,
                      label: Text(
                        '${calendarWeekday(item.day, short: true)} ${item.day.day}.',
                      ),
                      onSelected: (_) => setState(() => selected = item.day),
                    ),
                ],
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${calendarWeekday(day.day)}, ${displayDate(date)}',
                ),
                trailing: IconButton(
                  tooltip: 'Tagesablauf öffnen',
                  icon: const Icon(Icons.view_timeline_outlined),
                  onPressed: () => Navigator.push<void>(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Tagesablauf')),
                        body: SafeArea(
                          child: LessonFlowPage(
                            controller: c,
                            initialDate: date,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              for (final item in day.agenda)
                ListTile(
                  dense: true,
                  title: Text(item.title),
                  subtitle: Text(
                    [
                      calendarCategories[item.category] ?? item.category,
                      if (item.time.isNotEmpty)
                        [
                          item.time,
                          if (item.end.isNotEmpty) item.end,
                        ].join('–'),
                      if (item.detail.isNotEmpty) item.detail,
                      if (item.done) 'Erledigt',
                    ].join(' · '),
                  ),
                  onTap: () => showCalendarItem(ctx, c, item),
                ),
              if (day.agenda.isEmpty)
                const Text(
                  'Für diesen Tag sind keine Termine oder Fristen eingetragen.',
                ),
              for (final focus in day.focus)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Wochenschwerpunkt'),
                  subtitle: Text(focus.source.title),
                  children: [
                    for (final line in focus.lines)
                      ListTile(dense: true, title: Text(line)),
                    TextButton(
                      onPressed: () => openTeachingReview(ctx, c, focus.source),
                      child: const Text('Wochenplanung öffnen'),
                    ),
                  ],
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Unterlagen (${day.materials.length})'),
                trailing: IconButton(
                  tooltip: 'Unterlagen bereitlegen',
                  icon: const Icon(Icons.playlist_add),
                  onPressed: () async {
                    final ids = await chooseMaterials(ctx, c, []);
                    if (ids != null && ids.isNotEmpty && ctx.mounted) {
                      await guarded(
                        ctx,
                        () => c.saveClassroom(
                          prepareMaterials(c.classroom, date, ids),
                        ),
                      );
                    }
                  },
                ),
              ),
              if (day.materials.isEmpty)
                const Text('Noch keine Unterlagen bereitgelegt.'),
              if (day.materials.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: MaterialGroupingButton(c),
                ),
              ...groupedMaterialRows(
                c,
                day.materials,
                (files) => [
                  for (final m in files)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(m.title),
                      subtitle: Text(materialDayOwners(m, date, name)),
                      onTap: () => showMaterialDetails(ctx, c, m),
                    ),
                ],
                day: date,
              ),
            ],
          ),
        ),
      );
    },
  );
}
