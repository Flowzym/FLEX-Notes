import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/school_year.dart';
import '../domain/school.dart';
import '../platform/backup_transfer.dart';
import '../services/material_storage.dart';
import '../services/stream_backup.dart';
import 'backup_dialog.dart';
import 'common.dart';
import 'compact_switch.dart';
import 'flex_modal.dart';
import 'material_library.dart';
import 'material_thumbnail.dart';

Future<void> showSchoolYearCloseout(
  BuildContext context,
  NotebookController c,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => SchoolYearDialog(controller: c),
);

class SchoolYearDialog extends StatefulWidget {
  const SchoolYearDialog({super.key, required this.controller});
  final NotebookController controller;
  @override
  State<SchoolYearDialog> createState() => _SchoolYearDialogState();
}

class _SchoolYearDialogState extends State<SchoolYearDialog> {
  late final year = DateTime.now().month >= 9
      ? DateTime.now().year - 1
      : DateTime.now().year - 2;
  late String from = '$year-09-01', to = '${year + 1}-08-31';
  late final title = TextEditingController(
    text: 'Schuljahr $year/${(year + 1) % 100}',
  );
  String? reviewOn, captured, error;
  bool keepOpen = true, confirmed = false, busy = false;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  SchoolYearArchive get preview => SchoolYearArchive.preview(
    widget.controller.currentSnapshot,
    title: title.text,
    from: from,
    to: to,
    reviewOn: reviewOn,
    keepOpen: keepOpen,
  );
  void change(VoidCallback f) => setState(() {
    f();
    captured = null;
    confirmed = false;
  });
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> date(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(start ? from : to),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: start ? 'Zeitraum ab' : 'Zeitraum bis',
    );
    if (picked == null || !mounted) return;
    change(() {
      if (start) {
        from = dateOnly(picked);
      } else {
        to = dateOnly(picked);
      }
    });
  }

  Future<void> backup() async {
    preview; // Validate before starting encryption.
    final password = await backupPassword(context, opening: false);
    if (password == null) return;
    final snapshot = await widget.controller.repository.exportBackup();
    final saved = await saveBackupStream(
      'FLEX-Schuljahresabschluss-$from-bis-$to.flexbackup',
      StreamBackup.capture(
        widget.controller.repository,
        const LocalMaterialFiles(),
        password: password,
        capturedNotebook: snapshot,
      ),
    );
    if (saved && mounted) {
      setState(() {
        captured = snapshot;
        confirmed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    SchoolYearArchive? plan;
    try {
      plan = preview;
    } on DomainError {
      /* Invalid dates/title are corrected in place. */
    }
    return PopScope(
      canPop: !busy,
      child: FlexModal(
        title: const Text('Schuljahr abschließen'),
        maxWidth: 620,
        onClose: busy ? null : () => Navigator.pop(context),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: title,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Bezeichnung'),
              onChanged: (_) => change(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => date(true),
                  child: Text('Ab ${displayDate(from)}'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => date(false),
                  child: Text('Bis ${displayDate(to)}'),
                ),
              ],
            ),
            CompactSwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: keepOpen,
              title: const Text('Offene Aufgaben und Ziele behalten'),
              onChanged: busy ? null : (v) => change(() => keepOpen = v),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_outlined),
              label: Text(
                'Löschprüfung: ${reviewOn == null ? 'Keine Frist' : displayDate(reviewOn)}',
              ),
              onPressed: busy
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: reviewOn == null
                            ? DateTime.now().add(const Duration(days: 365))
                            : DateTime.parse(reviewOn!),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        helpText:
                            'Ab wann soll FLEX eine Löschprüfung anbieten?',
                      );
                      if (picked != null && mounted) {
                        change(() => reviewOn = dateOnly(picked));
                      }
                    },
            ),
            if (reviewOn != null)
              TextButton(
                onPressed: busy ? null : () => change(() => reviewOn = null),
                child: const Text('Frist entfernen'),
              ),
            const SizedBox(height: 12),
            Text(
              plan == null
                  ? 'Bitte Bezeichnung und Zeitraum prüfen.'
                  : '${plan.recordIds.length} Schüler-Einträge · ${plan.orgaIds.length} Orga-Einträge · ${plan.documentIds.length} Stunden/Planungen',
            ),
            const SizedBox(height: 8),
            const Text(
              'Die Schüler bleiben in der Klasse. Archivierte Einträge sind unter Mehr → Archiv erreichbar und können wieder eingeblendet werden.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.lock_outline),
              onPressed: busy || plan == null ? null : () => run(backup),
              label: Text(
                captured == null
                    ? 'Verschlüsselte Sicherung erstellen'
                    : 'Sicherung erneut erstellen',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: confirmed,
              onChanged: busy || captured == null
                  ? null
                  : (v) => setState(() => confirmed = v == true),
              title: const Text(
                'Sicherungsdatei gespeichert und Passwort bekannt',
              ),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: busy || captured == null || !confirmed || plan == null
                ? null
                : () => run(() async {
                    await widget.controller.repository.archiveSchoolYear(
                      preview,
                      captured!,
                    );
                    await widget.controller.reload();
                    if (context.mounted) Navigator.pop(context);
                  }),
            child: const Text('Archivieren'),
          ),
        ],
      ),
    );
  }
}

Future<void> showSchoolYearArchive(
  BuildContext context,
  NotebookController c,
  SchoolYearArchive year,
) async {
  final snapshot = await c.repository.snapshot();
  if (!context.mounted) return;
  String owner(String? id) => id == null
      ? 'FLEX-Klasse'
      : snapshot.pupils.where((p) => p.id == id).firstOrNull?.name ?? 'Schüler';
  Future<void> detail(BuildContext ctx, String id, String title, String body) =>
      showDialog<void>(
        context: ctx,
        builder: (dialog) => FlexModal(
          title: Text(title),
          onClose: () => Navigator.pop(dialog),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(body),
              for (final d in snapshot.classroom.where(
                (d) => d.rows('links').any((l) => l['id'] == id),
              ))
                ListTile(
                  leading: MaterialThumbnail(
                    material: d,
                    width: 40,
                    height: 48,
                  ),
                  title: Text(d.title),
                  onTap: () =>
                      guarded(dialog, () => openMaterial(dialog, c, d)),
                ),
            ],
          ),
        ),
      );
  await showDialog<void>(
    context: context,
    builder: (ctx) => FlexModal(
      title: Text(year.title),
      maxWidth: 800,
      onClose: () => Navigator.pop(ctx),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${displayDate(year.from)}–${displayDate(year.to)}'),
          for (final r in snapshot.records.where(
            (r) => year.recordIds.contains(r.id),
          ))
            ListTile(
              title: Text(
                '${owner(r.pupilId)} · ${r.title.isEmpty ? r.kind.label : r.title}',
              ),
              subtitle: Text(displayDate(r.observedOn)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => detail(
                ctx,
                r.id,
                r.kind.label,
                [
                  r.body,
                  ...r.positive,
                  ...r.neutral,
                  ...r.negative,
                  ...r.tasks.map((t) => t.text),
                  ...r.liveFeedback.map((f) => f.note),
                ].where((s) => s.isNotEmpty).join('\n'),
              ),
            ),
          for (final e in snapshot.entries.where(
            (e) => year.orgaIds.contains(e.id),
          ))
            ListTile(
              title: Text(e.title),
              subtitle: Text(owner(e.pupilId)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => detail(
                ctx,
                e.id,
                e.title,
                [e.body, ...e.items.map((i) => i.text)].join('\n'),
              ),
            ),
          for (final d in snapshot.classroom.where(
            (d) => year.documentIds.contains(d.id),
          ))
            ListTile(
              title: Text(d.title),
              subtitle: Text(
                '${d.text('date')} ${d.text('start')}–${d.text('end')}',
              ),
              onTap: () => detail(ctx, d.id, d.title, d.text('note')),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => guarded(ctx, () async {
            if (!await confirmFlex(
              ctx,
              'Schuljahr wieder öffnen?',
              'Die Einträge erscheinen wieder in den regulären Ansichten.',
              accept: 'Wieder öffnen',
            )) {
              return;
            }
            await c.repository.reopenSchoolYear(year.id);
            await c.reload();
            if (ctx.mounted) Navigator.pop(ctx);
          }),
          child: const Text('Schuljahr wieder öffnen'),
        ),
      ],
    ),
  );
}
