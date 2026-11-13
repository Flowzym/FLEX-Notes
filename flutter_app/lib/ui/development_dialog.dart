import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/development.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import 'common.dart';
import 'flex_modal.dart';
import 'school_workspace.dart';

Future<void> showDevelopment(
  BuildContext context,
  NotebookController c,
  Pupil pupil,
) => showDialog<void>(
  context: context,
  builder: (_) => DevelopmentDialog(controller: c, pupil: pupil),
);

class DevelopmentDialog extends StatefulWidget {
  const DevelopmentDialog({
    super.key,
    required this.controller,
    required this.pupil,
  });
  final NotebookController controller;
  final Pupil pupil;
  @override
  State<DevelopmentDialog> createState() => _DevelopmentDialogState();
}

class _DevelopmentDialogState extends State<DevelopmentDialog> {
  String from = dateOnly(DateTime.now().subtract(const Duration(days: 27))),
      to = dateOnly(DateTime.now()),
      area = 'all',
      query = '';
  final selected = <String>{};
  Future<void> choose(bool start) async {
    final result = await pickFlexDate(
      context,
      date: start ? from : to,
      allowTime: false,
    );
    if (result == null || result.$1.isEmpty || !mounted) return;
    final a = start ? result.$1 : from, b = start ? to : result.$1;
    if (a.compareTo(b) > 0 ||
        schoolDay(b).difference(schoolDay(a)).inDays > 1096) {
      await guarded(
        context,
        () async => throw const DomainError(
          'Bitte einen gültigen Zeitraum bis zu drei Jahren wählen.',
        ),
      );
      return;
    }
    setState(() {
      from = a;
      to = b;
      selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (ctx, _) {
      final c = widget.controller;
      final weeks = developmentWeeks(
        c.records,
        pupilId: widget.pupil.id,
        from: from,
        to: to,
        area: area,
        query: query,
      );
      final rows = weeks.expand((w) => w.records).toList();
      final visible = rows.map((r) => r.id).toSet();
      final peak = weeks.fold(
        1,
        (n, w) => n > w.records.length ? n : w.records.length,
      );
      return FlexModal(
        maxWidth: 900,
        title: Text('Entwicklung · ${widget.pupil.name}'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in const [
                  (28, '4 Wochen'),
                  (84, '12 Wochen'),
                  (182, '6 Monate'),
                ])
                  OutlinedButton(
                    onPressed: () => setState(() {
                      to = dateOnly(DateTime.now());
                      from = dateOnly(
                        DateTime.now().subtract(Duration(days: d.$1 - 1)),
                      );
                      selected.clear();
                    }),
                    child: Text(d.$2),
                  ),
                TextButton(
                  onPressed: () => choose(true),
                  child: Text('Von: ${displayDate(from)}'),
                ),
                TextButton(
                  onPressed: () => choose(false),
                  child: Text('Bis: ${displayDate(to)}'),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final a in const {
                  'all': 'Sozial & Arbeit',
                  'social': 'Sozial',
                  'work': 'Arbeit',
                }.entries)
                  ChoiceChip(
                    label: Text(a.value),
                    selected: area == a.key,
                    onSelected: (_) => setState(() {
                      area = a.key;
                      selected.clear();
                    }),
                  ),
              ],
            ),
            TextField(
              key: const ValueKey('development-search'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Thema / Tag / Freitext',
              ),
              onChanged: (v) => setState(() {
                query = v;
                selected.clear();
              }),
            ),
            const SizedBox(height: 12),
            Text(
              '${rows.length} dokumentierte Einträge',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final tone in const [
                  ('positive', 'Positiv', Color(0xff526a50)),
                  ('neutral', 'Neutral', Color(0xff526c7d)),
                  ('negative', 'Negativ', Color(0xff955a52)),
                  ('free', 'Freitext ohne Tag', Color(0xff555555)),
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, color: tone.$3),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${tone.$2}: ${weeks.fold(0, (n, w) => n + w.count(tone.$1))}',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Gezählt werden dokumentierte Einträge, keine Bewertungen. Ein Eintrag kann mehrere Tonarten enthalten.',
            ),
            const SizedBox(height: 12),
            for (final week in weeks)
              ExpansionTile(
                key: ValueKey('development-week-${week.date}'),
                title: Text('Woche ab ${displayDate(week.date)}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      week.records.isEmpty
                          ? 'Keine Beobachtungen dokumentiert'
                          : '${week.records.length} Einträge',
                    ),
                    if (week.records.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: LinearProgressIndicator(
                          value: week.records.length / peak,
                          minHeight: 5,
                          semanticsLabel:
                              '${week.records.length} dokumentierte Einträge',
                        ),
                      ),
                  ],
                ),
                children: [
                  for (final record in week.records)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CheckboxListTile(
                          title: Text(
                            'Für Gespräch auswählen · ${displayDate(record.observedOn)}',
                          ),
                          value: selected.contains(record.id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              selected.add(record.id);
                            } else {
                              selected.remove(record.id);
                            }
                          }),
                        ),
                        SchoolRecordCard(controller: c, record: record),
                      ],
                    ),
                ],
              ),
            ExpansionTile(
              title: const Text('Ziele und Überprüfungen'),
              children: [
                for (final goal in c.records.where(
                  (r) =>
                      !r.deleted &&
                      r.pupilId == widget.pupil.id &&
                      r.kind == SchoolKind.goal,
                ))
                  SchoolRecordCard(controller: c, record: goal),
                if (!c.records.any(
                  (r) =>
                      !r.deleted &&
                      r.pupilId == widget.pupil.id &&
                      r.kind == SchoolKind.goal,
                ))
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Noch keine Ziele dokumentiert.'),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() => selected.addAll(visible)),
            child: const Text('Alle passenden auswählen'),
          ),
          FilledButton.icon(
            onPressed: selected.intersection(visible).isEmpty
                ? null
                : () => showBrief(
                    ctx,
                    c,
                    widget.pupil,
                    initialFrom: from,
                    initialTo: to,
                    initialSelection: selected.intersection(visible),
                  ),
            icon: const Icon(Icons.description_outlined),
            label: Text(
              'Gespräch vorbereiten · ${selected.intersection(visible).length}',
            ),
          ),
        ],
      );
    },
  );
}
