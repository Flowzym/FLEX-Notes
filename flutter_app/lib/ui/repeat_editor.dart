import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';
import 'common.dart';
import 'compact_switch.dart';
import 'flex_modal.dart';

class RepeatField extends StatelessWidget {
  const RepeatField({super.key, required this.rule, required this.onChanged});
  final RepeatRule rule;
  final ValueChanged<RepeatRule> onChanged;
  void change(Json values) =>
      onChanged(RepeatRule.fromJson({...rule.toJson(), ...values}));
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Wiederholung'),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final choice in const [
            ('none', 1, 'Einmal'),
            ('daily', 1, 'Täglich'),
            ('weekly', 1, 'Wöchentlich'),
            ('weekly', 2, 'A/B · 14 Tage'),
            ('monthly', 1, 'Monatlich'),
          ])
            ChoiceChip(
              label: Text(choice.$3),
              selected:
                  rule.frequency == choice.$1 && rule.interval == choice.$2,
              onSelected: (_) =>
                  change({'frequency': choice.$1, 'interval': choice.$2}),
            ),
        ],
      ),
      if (rule.frequency == 'weekly')
        Wrap(
          spacing: 4,
          children: [
            for (var i = 1; i <= 7; i++)
              FilterChip(
                label: Text(
                  const ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'][i - 1],
                ),
                selected: rule.weekdays.contains(i),
                onSelected: (v) => change({
                  'weekdays': [
                    for (final day in rule.weekdays)
                      if (day != i) day,
                    if (v) i,
                  ]..sort(),
                }),
              ),
          ],
        ),
      if (rule.repeats) ...[
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.event),
              label: Text(
                'Bis: ${rule.until == null ? 'Ohne Ende' : displayDate(rule.until)}',
              ),
              onPressed: () async {
                final d = await pickFlexDate(
                  context,
                  date:
                      rule.until ??
                      dateOnly(DateTime.now().add(const Duration(days: 180))),
                  allowTime: false,
                );
                if (d != null) change({'until': d.$1.isEmpty ? null : d.$1});
              },
            ),
            if (rule.until != null)
              IconButton(
                tooltip: 'Enddatum entfernen',
                onPressed: () => change({'until': null}),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        CompactSwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ferien / Ausfälle auslassen'),
          value: rule.skipHolidays,
          onChanged: (v) => change({'skipHolidays': v}),
        ),
      ],
    ],
  );
}

Future<void> showOrgaRepeat(
  BuildContext context,
  NotebookController c,
  OrgaEntry entry,
) async {
  final existing = repeatForEntry(c.classroom, entry.id);
  final source = existing == null
      ? entry
      : c.currentSnapshot.entries
            .where((e) => e.id == existing.text('entryId'))
            .firstOrNull;
  if (source == null) return;
  var rule = existing?.rule ?? const RepeatRule();
  var busy = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => FlexModal(
        maxWidth: 600,
        title: const Text('Wiederholung · Aufgabe / Termin'),
        onClose: busy ? null : () => Navigator.pop(ctx),
        content: AbsorbPointer(
          absorbing: busy,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(source.title),
              const SizedBox(height: 12),
              Text(
                'Beginn: ${displayDate(source.appointmentDate ?? source.dueDate)}',
              ),
              RepeatField(rule: rule, onChanged: (v) => update(() => rule = v)),
              const SizedBox(height: 8),
              const Text(
                'Änderungen gelten für kommende, noch unveränderte Durchführungen. Erledigte und einzeln bearbeitete Einträge bleiben erhalten.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    update(() => busy = true);
                    final ok = await guarded(ctx, () async {
                      await c.repository.configureRepeat(source, rule);
                      await c.reload();
                    });
                    if (!ctx.mounted) return;
                    if (ok) {
                      Navigator.pop(ctx);
                    } else {
                      update(() => busy = false);
                    }
                  },
            child: const Text('Speichern'),
          ),
        ],
      ),
    ),
  );
}
