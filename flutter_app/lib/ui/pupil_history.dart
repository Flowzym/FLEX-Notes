import 'dart:convert';
import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import 'common.dart';
import 'flex_modal.dart';
import 'orga_editor.dart';
import 'school_workspace.dart';
import 'surfaces.dart';

String readableRecord(Json value) {
  if (value.containsKey('kind')) {
    final r = SchoolRecord.fromJson(value);
    return [
      '${r.kind.label} · ${displayDate(r.observedOn)} ${r.observedTime}',
      r.title,
      r.subject,
      r.body,
      ...r.positive.map((v) => '+ $v'),
      ...r.negative.map((v) => '− $v'),
      if (r.situation.isNotEmpty)
        'Zeitpunkt: ${{'before': 'Vor Unterricht', 'during': 'Unterricht', 'after': 'Nach Unterricht', 'break': 'Pause'}[r.situation]}',
      if (r.criterion.isNotEmpty) 'Zielkriterium: ${r.criterion}',
      if (r.support.isNotEmpty) 'Reaktion / Unterstützung: ${r.support}',
      if (r.goalSnapshot.isNotEmpty) 'Zielbezug: ${r.goalSnapshot}',
      if (r.otherParticipants.isNotEmpty) 'Beteiligt: ${r.otherParticipants}',
      if (r.context.isNotEmpty) 'Gemeinsamer Ablauf: ${r.context}',
      'Quelle: ${{'self': 'Selbst beobachtet', 'reported': 'Berichtet', 'interpretation': 'Eigene Einordnung'}[r.source]}',
      if (r.dueDate != null) 'Termin: ${displayDate(r.dueDate)}',
      if (r.nextReviewDate != null)
        'Nächste Überprüfung: ${displayDate(r.nextReviewDate)}',
      if (r.kind == SchoolKind.goal)
        'Stand: ${{'active': 'In Arbeit', 'achieved': 'Erreicht', 'ended': 'Beendet'}[r.goalStatus]}',
      for (final task in r.tasks)
        '${task.parentId == null ? '' : '  '}${task.text}: ${r.taskState(task).label}',
      for (final f in r.liveFeedback)
        '${displayDate(f.observedOn)} ${f.observedTime} · ${f.note}${f.delivery == null ? '' : ' · Abgabe: ${f.delivery}'}',
      for (final v in r.reviews)
        '${displayDate(v.observedOn)} · ${v.note} · ${v.decision}\n${v.nextStep}',
      if (r.needsCompletion) 'Später ergänzen',
      if (r.deleted) 'Im Papierkorb',
    ].where((v) => v.trim().isNotEmpty).join('\n');
  }
  final e = OrgaEntry.fromJson(value);
  return [
    'Orga · ${displayDate(e.observedOn)} ${e.observedTime}',
    e.body.isEmpty ? e.title : e.body,
    for (final item in e.items) '${item.checked ? '☑' : '☐'} ${item.text}',
    if (e.isTask) e.done ? 'Aufgabe erledigt' : 'Aufgabe offen',
    if (e.dueDate != null) 'Termin: ${displayDate(e.dueDate)}',
    if (e.reminderAtUtc != null) 'Erinnern am: ${displayReminder(e)}',
    if (e.reminderText.isNotEmpty) 'Erinnerungstext: ${e.reminderText}',
    if (e.reminderState == ReminderState.acknowledged) 'Erinnerung quittiert',
    if (e.reminderState == ReminderState.cancelled) 'Erinnerung beendet',
    if (e.needsCompletion) 'Später ergänzen',
    if (e.deleted) 'Im Papierkorb',
  ].where((v) => v.trim().isNotEmpty).join('\n');
}

Widget readableRevision(Json row) {
  String describe(String? text) {
    if (text == null) return 'Noch kein Eintrag.';
    try {
      return readableRecord(Json.from(jsonDecode(text) as Map));
    } catch (_) {
      return 'Diese historische Fassung verwendet ein anderes Datenformat.';
    }
  }

  return ExpansionTile(
    title: Text(
      'Fassung ${row['revision']} · ${displayDate(row['captured_at_utc'] as String)}',
    ),
    childrenPadding: const EdgeInsets.all(12),
    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Bisherige Fassung',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      SelectableText(describe(row['before_payload'] as String?)),
      const SizedBox(height: 12),
      const Text(
        'Gespeicherte Fassung',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      SelectableText(describe(row['after_payload'] as String?)),
    ],
  );
}

Future<void> showPupilHistory(
  BuildContext context,
  NotebookController c,
  String pupilId, {
  String area = 'all',
}) async {
  var query = '', onlyOpen = false;
  String? from, to;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AnimatedBuilder(
        animation: c,
        builder: (ctx, _) {
          bool accepts(String date, String text, bool incomplete) =>
              (from == null || date.compareTo(from!) >= 0) &&
              (to == null || date.compareTo(to!) <= 0) &&
              (!onlyOpen || incomplete) &&
              text.toLowerCase().contains(query.toLowerCase());
          final records = c.records.where(
            (r) =>
                r.pupilId == pupilId &&
                !r.deleted &&
                (area == 'all' || area == r.kind.name) &&
                accepts(r.observedOn, r.searchText, r.needsCompletion),
          );
          final orga = c.entries.where(
            (e) =>
                e.pupilId == pupilId &&
                (area == 'all' || area == 'orga') &&
                accepts(
                  e.observedOn,
                  '${e.title} ${e.body}',
                  e.needsCompletion,
                ),
          );
          final rows = <({String date, Widget child})>[
            for (final r in records)
              (
                date: '${r.observedOn} ${r.observedTime}',
                child: SchoolRecordCard(controller: c, record: r),
              ),
            for (final e in orga)
              (
                date: '${e.observedOn} ${e.observedTime}',
                child: FlexCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(readableRecord(e.toJson())),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => showDialog<void>(
                                context: ctx,
                                barrierDismissible: false,
                                builder: (_) =>
                                    OrgaEditor(controller: c, entry: e),
                              ),
                              child: const Text('Bearbeiten'),
                            ),
                            TextButton(
                              onPressed: () => guarded(
                                ctx,
                                () => c.saveEntry(
                                  e.copyWith(
                                    needsCompletion: !e.needsCompletion,
                                  ),
                                ),
                              ),
                              child: Text(
                                e.needsCompletion
                                    ? 'Dokumentation vollständig'
                                    : 'Später ergänzen',
                              ),
                            ),
                            TextButton(
                              onPressed: () => guarded(
                                ctx,
                                () => c.saveEntry(e.copyWith(deleted: true)),
                              ),
                              child: const Text('Löschen'),
                            ),
                            TextButton(
                              onPressed: () => showJournal(ctx, c, e.id),
                              child: const Text('Frühere Fassungen'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ]..sort((a, b) => b.date.compareTo(a.date));
          return FlexModal(
            maxWidth: 1000,
            title: const Text('Verlauf'),
            onClose: () => Navigator.pop(ctx),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Verlauf durchsuchen',
                    hintText: 'Suchen …',
                  ),
                  onChanged: (v) => update(() => query = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: area,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Bereich'),
                  items:
                      const {
                            'all': 'Alle Bereiche',
                            'social': 'Sozialverhalten',
                            'work': 'Arbeitsverhalten',
                            'homework': 'Hausübung',
                            'orga': 'Organisatorisches',
                            'goal': 'Ziele',
                          }.entries
                          .map(
                            (v) => DropdownMenuItem(
                              value: v.key,
                              child: Text(v.value),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => update(() => area = v!),
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final start in [true, false])
                      TextButton(
                        onPressed: () async {
                          final result = await pickFlexDate(
                            ctx,
                            date:
                                (start ? from : to) ?? dateOnly(DateTime.now()),
                            allowTime: false,
                          );
                          if (result != null && ctx.mounted) {
                            update(() {
                              if (start) {
                                from = result.$1.isEmpty ? null : result.$1;
                              } else {
                                to = result.$1.isEmpty ? null : result.$1;
                              }
                            });
                          }
                        },
                        child: Text(
                          '${start ? 'Von' : 'Bis'}: ${displayDate(start ? from : to)}',
                        ),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Nur offene Nachbereitung'),
                  value: onlyOpen,
                  onChanged: (v) => update(() => onlyOpen = v),
                ),
                if (rows.isEmpty) const Text('Keine passenden Einträge.'),
                ...rows.map((r) => r.child),
              ],
            ),
          );
        },
      ),
    ),
  );
}
