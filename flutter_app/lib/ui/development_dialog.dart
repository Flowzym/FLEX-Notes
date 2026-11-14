import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/development.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import 'collapsible_search.dart';
import 'common.dart';
import 'detail_flow.dart';
import 'flex_modal.dart';
import 'observation_tone_colors.dart';
import 'option_bar.dart';
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
      query = '',
      tone = '',
      topic = '';
  final selected = <String>{};
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Iterable<String> tags(SchoolRecord r) => {
    ...r.positive,
    ...r.neutral,
    ...r.negative,
  };
  String recordLabel(SchoolRecord r) => [
    r.body,
    tags(r).join(' · '),
    r.assignmentFree,
    ...r.assignmentSources.map(
      (source) => source.title.trim().isEmpty ? source.text : source.title,
    ),
    r.title,
    r.kind.label,
  ].map((text) => text.trim()).firstWhere((text) => text.isNotEmpty);
  bool hasTone(SchoolRecord r, String value) => switch (value) {
    'positive' => r.positive.isNotEmpty,
    'neutral' => r.neutral.isNotEmpty,
    'negative' => r.negative.isNotEmpty,
    'free' => tags(r).isEmpty,
    _ => true,
  };
  void filter(VoidCallback change) => setState(() {
    change();
    selected.clear();
  });
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
    filter(() {
      from = a;
      to = b;
    });
  }

  Future<void> openRecord(SchoolRecord record) => showFlexDetail<void>(
    context: context,
    builder: (ctx) => AnimatedBuilder(
      animation: widget.controller,
      builder: (ctx, _) {
        final current = widget.controller.records
            .where((r) => r.id == record.id && !r.deleted)
            .firstOrNull;
        return FlexModal(
          title: Text(record.kind.label),
          onClose: () => Navigator.pop(ctx),
          content: current == null
              ? const Text('Dieser Eintrag ist nicht mehr verfügbar.')
              : SchoolRecordCard(
                  controller: widget.controller,
                  record: current,
                ),
        );
      },
    ),
  );

  Widget recordRow(SchoolRecord r) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Checkbox(
        key: ValueKey('development-select-${r.id}'),
        semanticLabel: 'Für Gespräch auswählen: ${recordLabel(r)}',
        value: selected.contains(r.id),
        onChanged: (v) => setState(() {
          v == true ? selected.add(r.id) : selected.remove(r.id);
        }),
      ),
      Expanded(
        child: InkWell(
          key: ValueKey('development-record-${r.id}'),
          onTap: () => openRecord(r),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recordLabel(r),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final t in observationToneColors.entries)
                            if (hasTone(r, t.key))
                              Icon(Icons.circle, size: 7, color: t.value),
                          Text(
                            '${displayDate(r.observedOn)} · ${r.kind == SchoolKind.social ? 'Sozial' : 'Arbeit'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    ],
  );

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
      final all = weeks.expand((w) => w.records).toList();
      final topics = <String, int>{};
      for (final r in all) {
        for (final tag in tags(r)) {
          topics[tag] = (topics[tag] ?? 0) + 1;
        }
      }
      final orderedTopics = topics.entries.toList()
        ..sort((a, b) {
          final count = b.value.compareTo(a.value);
          return count == 0 ? a.key.compareTo(b.key) : count;
        });
      final topicRows = all
          .where((r) => topic.isEmpty || tags(r).contains(topic))
          .toList();
      final rows = topicRows.where((r) => hasTone(r, tone)).toList();
      final visible = rows.map((r) => r.id).toSet();
      final chosen = selected.intersection(visible);
      final activeWeeks = weeks.reversed
          .where((w) => w.records.any((r) => visible.contains(r.id)))
          .toList();
      final goals =
          c.records
              .where(
                (r) =>
                    !r.deleted &&
                    r.pupilId == widget.pupil.id &&
                    r.kind == SchoolKind.goal,
              )
              .toList()
            ..sort(
              (a, b) => (a.nextReviewDate ?? '9999').compareTo(
                b.nextReviewDate ?? '9999',
              ),
            );
      final presets = {'28': '4 Wochen', '84': '12 Wochen', '182': '6 Monate'};
      final preset =
          presets.keys
              .where(
                (n) =>
                    to == dateOnly(DateTime.now()) &&
                    from ==
                        dateOnly(
                          DateTime.now().subtract(
                            Duration(days: int.parse(n) - 1),
                          ),
                        ),
              )
              .firstOrNull ??
          '';
      return FlexModal(
        maxWidth: 720,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Entwicklung'),
            Text(widget.pupil.name, style: Theme.of(ctx).textTheme.bodySmall),
          ],
        ),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            OptionBar(
              keyPrefix: 'development-period',
              options: presets,
              value: preset,
              onChanged: (v) => filter(() {
                to = dateOnly(DateTime.now());
                from = dateOnly(
                  DateTime.now().subtract(Duration(days: int.parse(v) - 1)),
                );
              }),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const ValueKey('development-from'),
                    onPressed: () => choose(true),
                    child: Text('Von ${displayDate(from)}'),
                  ),
                ),
                const Text('–'),
                Expanded(
                  child: TextButton(
                    key: const ValueKey('development-to'),
                    onPressed: () => choose(false),
                    child: Text('Bis ${displayDate(to)}'),
                  ),
                ),
              ],
            ),
            OptionBar(
              keyPrefix: 'development-area',
              options: const {
                'all': 'Alle',
                'social': 'Sozial',
                'work': 'Arbeit',
              },
              value: area,
              onChanged: (v) => filter(() {
                area = v;
                topic = '';
              }),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in const {
                  'positive': 'Positiv',
                  'neutral': 'Neutral',
                  'negative': 'Negativ',
                  'free': 'Ohne Tag',
                }.entries)
                  if (t.key != 'free' ||
                      topicRows.any((r) => hasTone(r, 'free')) ||
                      tone == 'free')
                    FilterChip(
                      key: ValueKey('development-tone-${t.key}'),
                      avatar: Icon(
                        Icons.circle,
                        size: 8,
                        color:
                            observationToneColors[t.key] ??
                            Theme.of(ctx).colorScheme.outline,
                      ),
                      label: Text(
                        '${topicRows.where((r) => hasTone(r, t.key)).length} ${t.value}',
                      ),
                      selected: tone == t.key,
                      onSelected: (_) =>
                          filter(() => tone = tone == t.key ? '' : t.key),
                    ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Dokumentierte Einträge · Mehrfachzuordnung möglich',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            if (orderedTopics.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Häufige Themen', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final t in orderedTopics.take(4))
                    FilterChip(
                      key: ValueKey('development-topic-${t.key}'),
                      label: Text('${t.key} · ${t.value}'),
                      selected: topic == t.key,
                      onSelected: (_) =>
                          filter(() => topic = topic == t.key ? '' : t.key),
                    ),
                ],
              ),
            ],
            if (topic.isNotEmpty &&
                !orderedTopics.take(4).any((t) => t.key == topic))
              InputChip(
                label: Text(topic),
                onDeleted: () => filter(() => topic = ''),
              ),
            const SizedBox(height: 10),
            CollapsibleSearch(
              controller: search,
              fieldKey: const ValueKey('development-search'),
              label: 'Thema / Tag / Freitext',
              iconOnly: true,
              onChanged: (v) => filter(() {
                query = v;
                topic = '';
              }),
              leading: Text(
                'Verlauf · ${rows.length}',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              actions: [
                IconButton(
                  tooltip: chosen.length == visible.length && visible.isNotEmpty
                      ? 'Auswahl aufheben'
                      : 'Alle passenden auswählen',
                  key: const ValueKey('development-select-all'),
                  onPressed: visible.isEmpty
                      ? null
                      : () => setState(() {
                          chosen.length == visible.length
                              ? selected.clear()
                              : selected.addAll(visible);
                        }),
                  icon: const Icon(Icons.checklist_outlined),
                ),
              ],
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  query.isNotEmpty || tone.isNotEmpty || topic.isNotEmpty
                      ? 'Keine Beobachtungen für diese Filter.'
                      : 'In diesem Zeitraum sind noch keine Beobachtungen dokumentiert.',
                ),
              ),
            for (final week in activeWeeks)
              ExpansionTile(
                key: ValueKey('development-week-${week.date}'),
                initiallyExpanded: week == activeWeeks.first,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  'Woche ab ${displayDate(week.date)}',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                subtitle: Text(
                  '${week.records.where((r) => visible.contains(r.id)).length} Einträge',
                ),
                children: [
                  for (final r
                      in (week.records
                          .where((r) => visible.contains(r.id))
                          .toList()
                        ..sort(
                          (
                            a,
                            b,
                          ) => '${b.observedOn} ${b.observedTime} ${b.createdAtUtc}'
                              .compareTo(
                                '${a.observedOn} ${a.observedTime} ${a.createdAtUtc}',
                              ),
                        ))) ...[recordRow(r), const Divider(height: 1)],
                ],
              ),
            const SizedBox(height: 12),
            ExpansionTile(
              key: const ValueKey('development-goals'),
              tilePadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Ziele und Überprüfungen'),
              subtitle: Text(
                '${goals.where((g) => g.goalStatus == 'active').length} aktiv · ${goals.length} insgesamt',
              ),
              children: [
                if (goals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Noch keine Ziele dokumentiert.'),
                  ),
                for (final g in goals)
                  ListTile(
                    key: ValueKey('development-goal-${g.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      g.title.isEmpty ? g.body : g.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${g.goalStatus == 'active'
                          ? 'Aktiv'
                          : g.goalStatus == 'achieved'
                          ? 'Erreicht'
                          : 'Beendet'}${g.nextReviewDate == null ? '' : ' · Überprüfung ${displayDate(g.nextReviewDate)}'}',
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => openRecord(g),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          if (chosen.isNotEmpty)
            TextButton(
              onPressed: () => setState(selected.clear),
              child: const Text('Auswahl leeren'),
            ),
          FilledButton.icon(
            key: const ValueKey('development-brief'),
            onPressed: chosen.isEmpty
                ? null
                : () => showBrief(
                    ctx,
                    c,
                    widget.pupil,
                    initialFrom: from,
                    initialTo: to,
                    initialSelection: chosen,
                  ),
            icon: const Icon(Icons.description_outlined),
            label: Text(
              chosen.isEmpty
                  ? 'Für Gespräch auswählen'
                  : 'Gespräch vorbereiten · ${chosen.length}',
            ),
          ),
        ],
      );
    },
  );
}
