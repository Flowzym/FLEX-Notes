import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/material_workspace.dart';
import '../domain/models.dart';
import 'common.dart';
import 'dialog_workflows.dart';
import 'flex_modal.dart';
import 'repeat_editor.dart';

Json classroomInitial(
  ClassroomKind kind,
  NotebookController c, {
  String? date,
}) => {
  'format': 'flex-classroom-1',
  'id': newId(),
  'kind': kind.name,
  'title': '',
  'revision': 0,
  'deleted': false,
  'createdAtUtc': utcNow(),
  'updatedAtUtc': utcNow(),
  if (kind == ClassroomKind.lesson) ...{
    'date': date ?? dateOnly(DateTime.now()),
    'start': '08:00',
    'end': '08:50',
    'subject': '',
    'room': '',
    'note': '',
    'materialIds': <String>[],
    'repeat': const RepeatRule().toJson(),
    'exceptions': <Json>[],
    'remindMinutes': 0,
  },
  if (kind == ClassroomKind.holiday) ...{
    'date': date ?? dateOnly(DateTime.now()),
    'endDate': date ?? dateOnly(DateTime.now()),
  },
  if (kind == ClassroomKind.material) ...{
    'url': '',
    'extension': 'link',
    'subject': '',
    'topic': '',
    'note': '',
    'week': '',
  },
  if (kind == ClassroomKind.materialSet || kind == ClassroomKind.plan) ...{
    'materialIds': <String>[],
    'pupilIds': <String>[],
    'subject': '',
    'topic': '',
    'note': '',
  },
  if (kind == ClassroomKind.plan) ...{
    'date': date ?? '',
    'endDate': '',
    'lessonIds': <String>[],
    'status': 'planned',
    'followUp': '',
  },
  if (kind == ClassroomKind.returnList) ...{
    'type': 'form',
    'dueDate': date ?? '',
    'note': '',
    'materialIds': <String>[],
    'amountDue': 0,
    'closed': false,
    'remindDays': 0,
    'participants': [
      for (final p in c.pupils.where((p) => !p.archived))
        {
          'pupilId': p.id,
          'name': p.name,
          'status': 'open',
          'note': '',
          'paid': 0,
        },
    ],
  },
};

Future<List<String>?> chooseMaterials(
  BuildContext context,
  NotebookController c,
  List<String> selected,
) async {
  final ids = selected.toSet();
  var query = '';
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => FlexModal(
        title: const Text('Materialien zuordnen'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Datei oder Paket suchen',
              ),
              onChanged: (v) => update(() => query = v),
            ),
            for (final package in c.classroom.where(
              (d) =>
                  !d.deleted &&
                  d.kind == ClassroomKind.materialSet &&
                  materialMatches(d, query),
            ))
              CheckboxListTile(
                secondary: const Icon(Icons.folder_copy_outlined),
                title: Text(package.title),
                subtitle: Text(
                  '${resolveMaterials(c.classroom, package.strings('materialIds')).length} Dateien',
                ),
                value:
                    resolveMaterials(
                      c.classroom,
                      package.strings('materialIds'),
                    ).isNotEmpty &&
                    ids.containsAll(
                      resolveMaterials(
                        c.classroom,
                        package.strings('materialIds'),
                      ).map((m) => m.id),
                    ),
                onChanged: (v) => update(() {
                  final valid = resolveMaterials(
                    c.classroom,
                    package.strings('materialIds'),
                  ).map((m) => m.id);
                  if (v == true) {
                    ids.addAll(valid);
                  } else {
                    ids.removeAll(valid);
                  }
                }),
              ),
            if (!c.classroom.any(
              (d) => !d.deleted && d.kind == ClassroomKind.material,
            ))
              const Text(
                'Noch keine Materialien. Dateien oder Links unter Materialien hinzufügen.',
              ),
            for (final m in c.classroom.where(
              (d) =>
                  !d.deleted &&
                  d.kind == ClassroomKind.material &&
                  materialMatches(d, query, pupils: c.pupils),
            ))
              CheckboxListTile(
                title: Text(m.title),
                subtitle: Text(
                  [
                    m.text('subject'),
                    m.text('topic'),
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
                value: ids.contains(m.id),
                onChanged: (v) => update(() {
                  if (v == true) {
                    ids.add(m.id);
                  } else {
                    ids.remove(m.id);
                  }
                }),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ids.toList()),
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showClassroomEditor(
  BuildContext context,
  NotebookController c,
  ClassroomKind kind, {
  ClassroomDocument? document,
  DialogDraft? draft,
  String? date,
  String? occurrenceDate,
  bool following = false,
  Json? fields,
}) async {
  final initial =
      draft?.data ??
      document?.toJson() ??
      {...classroomInitial(kind, c, date: date), ...?fields};
  if (draft == null && occurrenceDate != null && document != null) {
    if (following && occurrenceDate.compareTo(document.text('date')) > 0) {
      initial.addAll({
        'id': newId(),
        'revision': 0,
        'createdAtUtc': utcNow(),
        'date': occurrenceDate,
        '_splitFrom': occurrenceDate,
        '_sourceId': document.id,
        '_sourceRevision': document.revision,
        'exceptions': document
            .rows('exceptions')
            .where((e) => (e['date'] as String).compareTo(occurrenceDate) >= 0)
            .toList(),
      });
    } else if (!following) {
      final occurrence =
          lessonOccurrences(c.classroom, occurrenceDate, occurrenceDate)
              .where(
                (l) =>
                    l.document.id == document.id &&
                    l.originalDate == occurrenceDate,
              )
              .firstOrNull;
      final exception = document
          .rows('exceptions')
          .where((e) => e['date'] == occurrenceDate)
          .firstOrNull;
      initial.addAll({
        '_occurrenceDate': occurrenceDate,
        'date': exception?['movedTo'] ?? occurrenceDate,
        'start':
            exception?['start'] ?? occurrence?.start ?? document.text('start'),
        'end': exception?['end'] ?? occurrence?.end ?? document.text('end'),
        'title': exception?['title'] ?? document.title,
        'note': exception?['note'] ?? document.text('note'),
        'materialIds':
            exception?['materialIds'] ?? document.strings('materialIds'),
      });
    }
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ProtectedDialog(
      controller: c,
      type: 'classroom',
      ownerId: initial['id'] as String,
      title: switch (kind) {
        ClassroomKind.lesson => 'Unterricht · FLEX-Klasse',
        ClassroomKind.holiday => 'Ferien / Ausfall',
        ClassroomKind.returnList => 'Rücklauf · FLEX-Klasse',
        ClassroomKind.materialSet => 'Unterrichtspaket',
        ClassroomKind.plan => 'Planung',
        _ => 'Material',
      },
      initial: initial,
      draft: draft,
      save: (data, buffer) async {
        final clean = <String, dynamic>{
          for (final e in data.entries)
            if (!e.key.startsWith('_')) e.key: e.value,
        };
        if (data['_occurrenceDate'] is String) {
          clean['repeat'] = const RepeatRule().toJson();
          clean['exceptions'] = <Json>[];
        }
        final value = ClassroomDocument.fromJson(clean);
        if (data['_occurrenceDate'] is String) {
          final source = c.classroom.where((d) => d.id == value.id).firstOrNull;
          if (source == null || source.revision != value.revision) {
            throw const StaleRevision();
          }
          final original = data['_occurrenceDate'] as String;
          final old =
              source
                  .rows('exceptions')
                  .where((e) => e['date'] == original)
                  .firstOrNull ??
              <String, dynamic>{};
          await c.repository.saveClassroomDocument(
            patchLessonOccurrence(source, original, {
              'cancelled': false,
              if (value.text('date') != original || old.containsKey('movedTo'))
                'movedTo': value.text('date'),
              if (value.text('start') != source.text('start') ||
                  value.text('end') != source.text('end') ||
                  old.containsKey('start')) ...{
                'start': value.text('start'),
                'end': value.text('end'),
              },
              if (value.title != source.title || old.containsKey('title'))
                'title': value.title,
              if (value.text('note') != source.text('note') ||
                  old.containsKey('note'))
                'note': value.text('note'),
              if (old.containsKey('materialIds') ||
                  value.strings('materialIds').join('\n') !=
                      source.strings('materialIds').join('\n'))
                'materialIds': value.strings('materialIds'),
            }),
            draft: buffer,
          );
        } else if (data['_splitFrom'] is String) {
          final source = c.classroom
              .where((d) => d.id == data['_sourceId'])
              .firstOrNull;
          if (source == null || source.revision != data['_sourceRevision']) {
            throw const StaleRevision();
          }
          final before = dateOnly(
            schoolDay(
              data['_splitFrom'] as String,
            ).subtract(const Duration(days: 1)),
          );
          await c.repository.saveClassroomDocuments([
            source.patch({
              'repeat': {...source.rule.toJson(), 'until': before},
              'exceptions': source
                  .rows('exceptions')
                  .where((e) => (e['date'] as String).compareTo(before) <= 0)
                  .toList(),
            }),
            value,
            for (final plan in c.classroom.where(
              (p) =>
                  p.kind == ClassroomKind.plan &&
                  p.strings('lessonIds').contains(source.id),
            ))
              plan.patch({
                'lessonIds': {...plan.strings('lessonIds'), value.id}.toList(),
              }),
          ], draft: buffer);
        } else if (kind == ClassroomKind.plan &&
            data['_attachLessonId'] is String) {
          final source = c.classroom
              .where((d) => d.id == data['_attachLessonId'])
              .firstOrNull;
          if (source == null ||
              source.deleted ||
              source.revision != data['_attachLessonRevision']) {
            throw const StaleRevision();
          }
          final original = data['_attachOriginalDate'] as String;
          final prior = source
              .rows('exceptions')
              .where((e) => e['date'] == original)
              .firstOrNull;
          await c.repository.saveClassroomDocuments([
            value,
            patchLessonOccurrence(source, original, {
              'planIds': {
                ...List<String>.from(
                  data['_attachPlanIds'] as List? ??
                      prior?['planIds'] as List? ??
                      [],
                ),
                value.id,
              }.toList(),
            }),
          ], draft: buffer);
        } else {
          await c.repository.saveClassroomDocument(value, draft: buffer);
        }
      },
      body: (ctx, data, change) {
        Widget text(
          String key,
          String label, {
          int lines = 1,
          TextInputType? keyboard,
        }) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            key: ValueKey('classroom-$key'),
            initialValue: data[key] as String? ?? '',
            minLines: lines,
            maxLines: lines == 1 ? 1 : 8,
            keyboardType: keyboard,
            decoration: InputDecoration(labelText: label),
            onChanged: (v) => change({key: v}),
          ),
        );
        Widget day(String key, String label) => TextButton.icon(
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text('$label: ${displayDate(data[key] as String?)}'),
          onPressed: () async {
            final result = await pickFlexDate(
              ctx,
              date: (data[key] as String? ?? '').isEmpty
                  ? dateOnly(DateTime.now())
                  : data[key] as String,
              allowTime: false,
            );
            if (result != null) change({key: result.$1});
          },
        );
        final materialIds = List<String>.from(
          data['materialIds'] as List? ?? [],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (kind == ClassroomKind.plan && data['_attachDate'] is String)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Für diese Stunde · ${displayDate(data['_attachDate'] as String)}',
                ),
              ),
            if (kind == ClassroomKind.lesson)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  data['_occurrenceDate'] != null
                      ? 'Nur diese Stunde'
                      : data['_splitFrom'] != null
                      ? 'Diese und folgende Stunden'
                      : document?.rule.repeats == true
                      ? 'Gesamte Unterrichtsserie'
                      : 'Unterricht anlegen',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
              ),
            text(
              'title',
              kind == ClassroomKind.lesson
                  ? 'Thema / Unterricht'
                  : 'Bezeichnung',
            ),
            if (kind == ClassroomKind.lesson) ...[
              if (data['_occurrenceDate'] == null) ...[
                text('subject', 'Fach'),
                text('room', 'Raum · optional'),
              ],
              day('date', 'Beginn / Datum'),
              Row(
                children: [
                  Expanded(
                    child: text(
                      'start',
                      'Von · HH:MM',
                      keyboard: TextInputType.datetime,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: text(
                      'end',
                      'Bis · HH:MM',
                      keyboard: TextInputType.datetime,
                    ),
                  ),
                ],
              ),
              if (data['_occurrenceDate'] == null)
                RepeatField(
                  rule: RepeatRule.fromJson(
                    Json.from(data['repeat'] as Map? ?? {}),
                  ),
                  onChanged: (v) => change({'repeat': v.toJson()}),
                ),
              const SizedBox(height: 12),
              text('note', 'Ablauf / Notiz', lines: 3),
              if (data['_occurrenceDate'] == null)
                DropdownButtonFormField<int>(
                  initialValue: data['remindMinutes'] as int? ?? 0,
                  decoration: const InputDecoration(labelText: 'Erinnern'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Zum Beginn')),
                    DropdownMenuItem(value: 5, child: Text('5 Minuten vorher')),
                    DropdownMenuItem(
                      value: 15,
                      child: Text('15 Minuten vorher'),
                    ),
                    DropdownMenuItem(value: 60, child: Text('1 Stunde vorher')),
                  ],
                  onChanged: (v) => change({'remindMinutes': v}),
                ),
            ],
            if (kind == ClassroomKind.holiday) ...[
              day('date', 'Von'),
              day('endDate', 'Bis'),
            ],
            if (kind == ClassroomKind.material) ...[
              text(
                'url',
                'OneDrive- oder HTTPS-Link',
                keyboard: TextInputType.url,
              ),
              text('subject', 'Fach · optional'),
              text('topic', 'Thema · optional'),
              day('week', 'Wochenplanung · optional'),
              if ((data['week'] as String? ?? '').isNotEmpty)
                TextButton(
                  onPressed: () => change({'week': ''}),
                  child: const Text('Wochenzuordnung entfernen'),
                ),
              text('note', 'Notiz', lines: 2),
            ],
            if (kind == ClassroomKind.material ||
                kind == ClassroomKind.materialSet ||
                kind == ClassroomKind.plan) ...[
              if (kind != ClassroomKind.material) ...[
                text('subject', 'Fach · optional'),
                text('topic', 'Thema · optional'),
                text('note', 'Notiz · optional', lines: 2),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.people_outline),
                label: Text(
                  'Schüler zuordnen · ${(data['pupilIds'] as List? ?? []).length}',
                ),
                onPressed: () async {
                  final ids = await chooseMaterialPupils(
                    ctx,
                    c,
                    List<String>.from(data['pupilIds'] as List? ?? []),
                  );
                  if (ids != null) change({'pupilIds': ids});
                },
              ),
            ],
            if (kind == ClassroomKind.material) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: data['documentType'] as String? ?? 'other',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Dokumentart'),
                items: [
                  for (final e in materialTypes.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => change({'documentType': v}),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: data['audience'] as String? ?? 'all',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Für wen'),
                items: [
                  for (final e in materialAudiences.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => change({'audience': v}),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: (data['tags'] as List? ?? []).join(', '),
                decoration: const InputDecoration(
                  labelText: 'Schlagwörter · mit Komma trennen',
                ),
                onChanged: (v) => change({
                  'tags': v
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toSet()
                      .toList(),
                }),
              ),
            ],
            if (kind == ClassroomKind.plan) ...[
              day('date', 'Von · optional'),
              day('endDate', 'Bis · optional'),
              if ((data['date'] as String? ?? '').isNotEmpty)
                TextButton(
                  onPressed: () => change({'date': '', 'endDate': ''}),
                  child: const Text('Zeitraum entfernen'),
                ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final e in planStatuses.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: data['status'] == e.key,
                      onSelected: (_) => change({'status': e.key}),
                    ),
                ],
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.school_outlined),
                label: Text(
                  'Unterricht verknüpfen · ${(data['lessonIds'] as List? ?? []).length}',
                ),
                onPressed: () async {
                  final ids = await choosePlanLessons(
                    ctx,
                    c,
                    List<String>.from(data['lessonIds'] as List? ?? []),
                  );
                  if (ids != null) change({'lessonIds': ids});
                },
              ),
              text('followUp', 'Nachbereitung · optional', lines: 2),
            ],
            if (kind == ClassroomKind.returnList) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final type in returnTypes.entries)
                    ChoiceChip(
                      label: Text(type.value),
                      selected: data['type'] == type.key,
                      onSelected: document == null
                          ? (_) => change({'type': type.key})
                          : null,
                    ),
                ],
              ),
              day('dueDate', 'Frist'),
              text('note', 'Hinweis', lines: 2),
              if (data['type'] == 'payment')
                TextFormField(
                  key: const ValueKey('return-amount'),
                  initialValue: ((data['amountDue'] as int? ?? 0) / 100)
                      .toStringAsFixed(2),
                  decoration: const InputDecoration(
                    labelText: 'Betrag pro Schüler · €',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) {
                    final n = double.tryParse(v.replaceAll(',', '.'));
                    change({
                      'amountDue': n == null || !n.isFinite
                          ? -1
                          : (n * 100).round(),
                    });
                  },
                ),
              DropdownButtonFormField<int>(
                initialValue: data['remindDays'] as int? ?? 0,
                decoration: const InputDecoration(labelText: 'Erinnern'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Am Tag der Frist')),
                  DropdownMenuItem(value: 1, child: Text('1 Tag vorher')),
                  DropdownMenuItem(value: 2, child: Text('2 Tage vorher')),
                  DropdownMenuItem(value: 7, child: Text('1 Woche vorher')),
                ],
                onChanged: (v) => change({'remindDays': v}),
              ),
              const SizedBox(height: 12),
              const Text('Teilnehmer'),
              for (final p in c.pupils.where(
                (p) =>
                    !p.archived ||
                    (data['participants'] as List).any(
                      (r) => r['pupilId'] == p.id,
                    ),
              ))
                CheckboxListTile(
                  title: Text(p.name),
                  contentPadding: EdgeInsets.zero,
                  value: (data['participants'] as List).any(
                    (r) => r['pupilId'] == p.id,
                  ),
                  onChanged: (v) => change({
                    'participants': [
                      for (final row in data['participants'] as List)
                        if (row['pupilId'] != p.id) row,
                      if (v == true)
                        {
                          'pupilId': p.id,
                          'name': p.name,
                          'status': 'open',
                          'note': '',
                          'paid': 0,
                        },
                    ],
                  }),
                ),
            ],
            if (kind == ClassroomKind.lesson ||
                kind == ClassroomKind.returnList ||
                kind == ClassroomKind.materialSet ||
                kind == ClassroomKind.plan) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: Text('Materialien zuordnen · ${materialIds.length}'),
                onPressed: () async {
                  final ids = await chooseMaterials(ctx, c, materialIds);
                  if (ids != null) change({'materialIds': ids});
                },
              ),
              for (final id in materialIds)
                Text(
                  c.classroom.where((d) => d.id == id).firstOrNull?.title ??
                      'Material nicht verfügbar',
                ),
            ],
          ],
        );
      },
    ),
  );
}

Future<List<String>?> chooseMaterialPupils(
  BuildContext context,
  NotebookController c,
  List<String> selected,
) => _chooseReferences(context, 'Schüler zuordnen', selected, {
  for (final p in c.pupils.where((p) => !p.archived || selected.contains(p.id)))
    p.id: p.name,
});

Future<List<String>?> choosePlanLessons(
  BuildContext context,
  NotebookController c,
  List<String> selected,
) => _chooseReferences(context, 'Unterricht verknüpfen', selected, {
  for (final d in c.classroom.where(
    (d) => !d.deleted && d.kind == ClassroomKind.lesson,
  ))
    d.id: '${d.title} · ${displayDate(d.text('date'))}',
});

Future<List<String>?> _chooseReferences(
  BuildContext context,
  String title,
  List<String> selected,
  Map<String, String> choices,
) async {
  final ids = selected.toSet();
  var query = '';
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => FlexModal(
        title: Text(title),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Suchen',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => update(() => query = v.toLowerCase()),
            ),
            if (choices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Noch keine Einträge.'),
              ),
            for (final e in choices.entries.where(
              (e) => e.value.toLowerCase().contains(query),
            ))
              CheckboxListTile(
                title: Text(e.value),
                value: ids.contains(e.key),
                onChanged: (v) => update(() {
                  if (v == true) {
                    ids.add(e.key);
                  } else {
                    ids.remove(e.key);
                  }
                }),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ids.toList()),
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    ),
  );
}
