import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/classroom.dart';
import '../domain/school.dart';
import 'common.dart';
import 'flex_modal.dart';

const conflictFieldLabels = <String, String>{
  'kind': 'Bereich',
  'pupilId': 'Schüler',
  'title': 'Titel',
  'body': 'Notiz',
  'subject': 'Auftrag / Fach',
  'taskFree': 'Freier Auftrag',
  'taskTags': 'Auftrag-Tags',
  'positive': 'Positive Beobachtungen',
  'neutral': 'Neutrale Beobachtungen',
  'negative': 'Negative Beobachtungen',
  'participantIds': 'Beteiligte',
  'otherParticipants': 'Weitere Namen',
  'source': 'Quelle',
  'context': 'Gemeinsamer Ablauf',
  'situation': 'Zeitpunkt',
  'support': 'Reaktion / Unterstützung',
  'goalId': 'Verknüpftes Ziel',
  'goalSnapshot': 'Zielbezug',
  'criterion': 'Zielkriterium',
  'pupilPerspective': 'Schülerperspektive',
  'goalStatus': 'Zielstand',
  'nextReviewDate': 'Nächste Überprüfung',
  'dueDate': 'Termin',
  'appointmentDate': 'Termindatum',
  'appointmentTime': 'Terminzeit',
  'observedOn': 'Datum',
  'observedTime': 'Uhrzeit',
  'needsCompletion': 'Später ergänzen',
  'deleted': 'Im Papierkorb',
  'tasks': 'Aufgaben',
  'feedback': 'Rückmeldungen',
  'reviews': 'Überprüfungen',
  'isTask': 'Als Aufgabe',
  'done': 'Aufgabe erledigt',
  'items': 'Checkliste',
  'reminderAtUtc': 'Erinnerungsdatum',
  'reminderText': 'Erinnerungstext',
  'reminderState': 'Erinnerungsstand',
  'reminderHasTime': 'Erinnerung mit Uhrzeit',
  'reminderZone': 'Zeitzone der Erinnerung',
  'text': 'Text',
  'checked': 'Abgehakt',
  'note': 'Notiz',
  'state': 'Stand',
  'decision': 'Entscheidung',
  'nextStep': 'Nächster Schritt',
  'delivery': 'Abgabe',
  'taskText': 'Aufgabe',
  'date': 'Beginn / Datum',
  'endDate': 'Enddatum',
  'start': 'Beginn',
  'end': 'Ende',
  'room': 'Raum',
  'materialIds': 'Materialien',
  'pupilIds': 'Schülerzuordnungen',
  'lessonIds': 'Unterrichtszuordnungen',
  'documentType': 'Dokumentart',
  'audience': 'Für wen',
  'favorite': 'Favorit',
  'tags': 'Schlagwörter',
  'followUp': 'Nachbereitung',
  'sourcePath': 'Quellordner',
  'repeat': 'Wiederholung',
  'frequency': 'Häufigkeit',
  'interval': 'Abstand',
  'weekdays': 'Wochentage',
  'until': 'Bis',
  'skipHolidays': 'Ferien auslassen',
  'excluded': 'Ausgelassene Tage',
  'exceptions': 'Einzelne Änderungen',
  'cancelled': 'Entfällt',
  'movedTo': 'Verschoben auf',
  'remindMinutes': 'Minuten vorher',
  'remindDays': 'Tage vorher',
  'participants': 'Rückmeldungen',
  'name': 'Name',
  'status': 'Stand',
  'paid': 'Eingegangener Betrag',
  'amountDue': 'Betrag pro Schüler',
  'type': 'Art',
  'closed': 'Abgeschlossen',
  'url': 'Link',
  'extension': 'Dateityp',
  'topic': 'Thema',
  'week': 'Planungswoche',
  'sourceModifiedAt': 'Dateistand',
  'size': 'Dateigröße',
  'localKey': 'Offline-Dateiverweis',
  'etag': 'Dateiversion',
  'driveId': 'OneDrive-Laufwerk',
  'itemId': 'OneDrive-Datei',
  'entryId': 'Serienvorlage',
  'template': 'Vorlage',
  'stopped': 'Serie beendet',
  'target': 'Erinnerungsbezug',
  'at': 'Erinnerungszeit',
  'dismissed': 'Erinnerung ausgeschaltet',
  'icsUid': 'Kalender-ID',
  'icsSource': 'Kalenderquelle',
  'icsStamp': 'Kalenderstand',
};
String conflictText(String key, Object? value, NotebookController c) {
  if ((key == 'paid' || key == 'amountDue') && value is int) {
    return '${(value / 100).toStringAsFixed(2)} €';
  }
  if ((key == 'materialIds' || key == 'lessonIds') && value is String) {
    return c.classroom.where((d) => d.id == value).firstOrNull?.title ??
        'Material nicht verfügbar';
  }
  if (key == 'documentType') return materialTypes[value] ?? '$value';
  if (key == 'audience') return materialAudiences[value] ?? '$value';
  if (key == 'status' && planStatuses.containsKey(value)) {
    return planStatuses[value]!;
  }
  if (key == 'status') {
    return const {
          'open': 'Offen',
          'partial': 'Teilbezahlt',
          'received': 'Erhalten / bezahlt',
          'yes': 'Zugestimmt',
          'no': 'Abgelehnt',
          'exempt': 'Nicht erforderlich',
        }[value] ??
        '$value';
  }
  if (key == 'frequency') {
    return const {
          'none': 'Einmal',
          'daily': 'Täglich',
          'weekly': 'Wöchentlich',
          'monthly': 'Monatlich',
        }[value] ??
        '$value';
  }
  if (key == 'appointmentTime' && value == '') return 'Ganztägig';
  if (key == 'appointmentDate' && value is String && validDate(value)) {
    return displayDate(value);
  }
  if (value == null || value == '') return '—';
  if (value is bool) return value ? 'Ja' : 'Nein';
  if (value is List) {
    return value.map((v) => conflictText(key, v, c)).join('\n');
  }
  if (value is Map) {
    return value.entries
        .where((e) => conflictFieldLabels.containsKey(e.key))
        .map(
          (e) =>
              '${conflictFieldLabels[e.key]}: ${conflictText(e.key as String, e.value, c)}',
        )
        .join(' · ');
  }
  if (key == 'pupilId' || key == 'participantIds' || key == 'pupilIds') {
    return c.pupils.where((p) => p.id == value).firstOrNull?.name ??
        'Nicht mehr vorhanden';
  }
  if (key == 'goalId') {
    return c.records.where((r) => r.id == value).firstOrNull?.title ??
        'Nicht mehr vorhanden';
  }
  return const {
        'social': 'Sozialverhalten',
        'work': 'Arbeitsverhalten',
        'homework': 'Hausübung',
        'goal': 'Ziel',
        'self': 'Selbst beobachtet',
        'reported': 'Berichtet',
        'interpretation': 'Eigene Einordnung',
        'active': 'In Arbeit',
        'achieved': 'Erreicht',
        'ended': 'Beendet',
        'continue': 'Fortführen',
        'reopen': 'Wieder öffnen',
        'planned': 'Geplant',
        'acknowledged': 'Quittiert',
        'cancelled': 'Beendet',
        'none': 'Keine',
        'unknown': 'Nicht überprüft',
        'submitted': 'Vorgelegt',
        'missing': 'Nicht vorgelegt',
        'absent': 'Abwesend',
        'open': 'Offen',
        'complete': 'Vollständig',
        'partial': 'Teilweise',
        'notDone': 'Nicht erledigt',
      }[value] ??
      '$value';
}

class ConflictDialog extends StatefulWidget {
  const ConflictDialog({super.key, required this.controller});
  final NotebookController controller;
  @override
  State<ConflictDialog> createState() => _ConflictDialogState();
}

class _ConflictDialogState extends State<ConflictDialog> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final conflicts =
        <
          ({
            String title,
            Json current,
            Json other,
            Future<void> Function(bool) resolve,
          })
        >[
          for (final draft in c.schoolDrafts)
            for (final current in c.records.where(
              (r) =>
                  r.id == draft.record.id &&
                  r.revision != draft.record.revision,
            ))
              (
                title:
                    '${current.kind.label} · ${c.pupils.firstWhere((p) => p.id == current.pupilId).name}',
                current: current.toJson(),
                other: draft.record.toJson(),
                resolve: (v) =>
                    c.repository.resolveSchoolConflict(draft, useOther: v),
              ),
          for (final draft in c.drafts)
            for (final current in [...c.entries, ...c.trashedEntries].where(
              (r) =>
                  r.id == draft.entry.id && r.revision != draft.entry.revision,
            ))
              (
                title: current.title,
                current: current.toJson(),
                other: draft.entry.toJson(),
                resolve: (v) =>
                    c.repository.resolveOrgaConflict(draft, useOther: v),
              ),
        ];
    Future<void> action(Future<void> Function() work) async {
      if (busy) return;
      setState(() {
        busy = true;
        error = null;
      });
      try {
        await work();
        await c.reload();
      } catch (e) {
        if (mounted) setState(() => error = friendlyError(e));
      }
      if (mounted) setState(() => busy = false);
    }

    return FlexModal(
      maxWidth: 1000,
      title: const Text('Änderungskonflikte'),
      onClose: busy ? null : () => Navigator.pop(context),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (conflicts.isEmpty) const Text('Keine offenen Konflikte.'),
          for (final item in conflicts) ...[
            Text(item.title, style: Theme.of(context).textTheme.titleMedium),
            for (final key in item.other.keys.where(
              (key) =>
                  conflictFieldLabels.containsKey(key) &&
                  '${item.current[key]}' != '${item.other[key]}',
            ))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    Widget side(String label, Object? value) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$label · ${conflictFieldLabels[key]}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: SingleChildScrollView(
                            child: SelectableText(conflictText(key, value, c)),
                          ),
                        ),
                      ],
                    );
                    return constraints.maxWidth < 600
                        ? Column(
                            children: [
                              side('Aktuelle Fassung', item.current[key]),
                              const SizedBox(height: 12),
                              side('Andere Fassung', item.other[key]),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: side(
                                  'Aktuelle Fassung',
                                  item.current[key],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: side('Andere Fassung', item.other[key]),
                              ),
                            ],
                          );
                  },
                ),
              ),
            const Text(
              'Die Auswahl übernimmt die gesamte Fassung. Frühere Fassungen bleiben erhalten.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () => action(() => item.resolve(false)),
                  child: const Text('Aktuelle behalten'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => action(() => item.resolve(true)),
                  child: const Text('Andere übernehmen'),
                ),
              ],
            ),
            const Divider(),
          ],
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
