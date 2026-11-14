import 'dart:convert';
import 'models.dart';
import 'school.dart';
import 'observation_catalog.dart';

const templateKinds = {
  'social': 'Sozialverhalten',
  'work': 'Arbeitsverhalten',
  'goal': 'Ziele',
  'homework': 'Hausübung',
  'orga-note': 'Notiz',
  'orga-task': 'Aufgabe',
  'orga-appointment': 'Termin',
};

class EntryTemplate {
  EntryTemplate({
    required this.id,
    required this.name,
    required this.kind,
    required Json fields,
  }) : fields = Map.unmodifiable(fields);
  final String id, name, kind;
  final Json fields;
  static const textKeys = {
    'title',
    'body',
    'subject',
    'criterion',
    'support',
    'taskFree',
  };
  static const listKeys = {
    'positive',
    'neutral',
    'negative',
    'taskTags',
    'items',
    'tasks',
  };
  Json toJson() => {
    'version': 1,
    'id': id,
    'name': name,
    'kind': kind,
    'fields': fields,
  };
  factory EntryTemplate.fromJson(Json json) {
    if (json.keys.toSet().difference({
          'version',
          'id',
          'name',
          'kind',
          'fields',
        }).isNotEmpty ||
        json['version'] != 1 ||
        json['fields'] is! Map ||
        json['id'] is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(json['id']) ||
        json['name'] is! String ||
        (json['name'] as String).trim().isEmpty ||
        (json['name'] as String).length > 100 ||
        !templateKinds.containsKey(json['kind'])) {
      throw const DomainError('Ungültige Eintragsvorlage.');
    }
    final fields = Json.from(json['fields'] as Map);
    for (final item in fields.entries) {
      if (textKeys.contains(item.key)) {
        if (item.value is! String || (item.value as String).length > 12000) {
          throw const DomainError('Die Vorlage enthält einen ungültigen Text.');
        }
      } else if (listKeys.contains(item.key)) {
        if (item.value is! List || (item.value as List).length > 200) {
          throw const DomainError('Die Vorlage enthält zu viele Zeilen.');
        }
        if (item.key == 'tasks') {
          final tasks = item.value as List;
          for (var i = 0; i < tasks.length; i++) {
            final task = tasks[i];
            if (task is! Map ||
                task.keys.toSet().difference({'text', 'parent'}).isNotEmpty ||
                task['text'] is! String ||
                (task['text'] as String).length > 1000 ||
                task['parent'] != null &&
                    (task['parent'] is! int ||
                        task['parent'] < 0 ||
                        task['parent'] >= i ||
                        tasks[task['parent']]['parent'] != null)) {
              throw const DomainError('Ungültige Aufgabe in der Vorlage.');
            }
          }
        } else if ((item.value as List).any(
          (v) => v is! String || v.length > 1000,
        )) {
          throw const DomainError('Ungültige Auswahl in der Vorlage.');
        }
      } else {
        throw const DomainError('Die Vorlage enthält nicht erlaubte Daten.');
      }
    }
    final kind = json['kind'] as String;
    final allowed = kind.startsWith('orga-')
        ? {'title', 'body', 'items'}
        : {
            'title',
            'body',
            'subject',
            'criterion',
            'support',
            'taskFree',
            'positive',
            'neutral',
            'negative',
            'taskTags',
            if (kind == 'homework') 'tasks',
          };
    if (fields.keys.any((key) => !allowed.contains(key))) {
      throw const DomainError('Die Felder passen nicht zum Vorlagentyp.');
    }
    return EntryTemplate(
      id: json['id'],
      name: json['name'],
      kind: kind,
      fields: fields,
    );
  }
  factory EntryTemplate.school(SchoolRecord record, String name) =>
      EntryTemplate.fromJson({
        'version': 1,
        'id': newId(),
        'name': name.trim(),
        'kind': record.kind.name,
        'fields': {
          for (final key in [
            ...textKeys,
            'positive',
            'neutral',
            'negative',
            'taskTags',
          ])
            if (record.toJson()[key] != null) key: record.toJson()[key],
          if (record.kind == SchoolKind.homework)
            'tasks': [
              for (final task in record.tasks)
                {
                  'text': task.text,
                  'parent': task.parentId == null
                      ? null
                      : record.tasks.indexWhere((t) => t.id == task.parentId),
                },
            ],
        },
      });
  factory EntryTemplate.orga(OrgaEntry entry, String name) =>
      EntryTemplate.fromJson({
        'version': 1,
        'id': newId(),
        'name': name.trim(),
        'kind': orgaKind(entry),
        'fields': {
          'title': entry.title,
          'body': entry.body,
          'items': entry.items.map((t) => t.text).toList(),
        },
      });
  static String orgaKind(OrgaEntry entry) =>
      'orga-${entry.isAppointment
          ? 'appointment'
          : entry.isTask
          ? 'task'
          : 'note'}';
  String append(String old, String next) => next.isEmpty || old == next
      ? old
      : old.isEmpty
      ? next
      : '$old\n$next';
  SchoolRecord applySchool(SchoolRecord record) {
    if (record.kind.name != kind) {
      throw const DomainError('Die Vorlage passt nicht zu diesem Bereich.');
    }
    final values = record.toJson(), patch = <String, dynamic>{};
    for (final field in fields.entries.where((e) => e.key != 'tasks')) {
      patch[field.key] = textKeys.contains(field.key)
          ? (field.key == 'title' && record.title.isNotEmpty
                ? record.title
                : append(
                    values[field.key] as String? ?? '',
                    field.value as String,
                  ))
          : {
              ...(values[field.key] as List? ?? []),
              ...(field.value as List),
            }.toList();
    }
    final tasks = fields['tasks'] as List? ?? [];
    final ids = [for (final _ in tasks) newId()];
    if (tasks.isNotEmpty) {
      patch['tasks'] = [
        for (final task in record.tasks)
          if (task.text.trim().isNotEmpty) task.toJson(),
        for (var i = 0; i < tasks.length; i++)
          HomeworkTask(
            id: ids[i],
            text: tasks[i]['text'],
            parentId: tasks[i]['parent'] == null
                ? null
                : ids[tasks[i]['parent']],
          ).toJson(),
      ];
    }
    final result = record.patch(patch);
    result.validate(draft: true);
    return result;
  }

  OrgaEntry applyOrga(OrgaEntry entry) {
    if (orgaKind(entry) != kind) {
      throw const DomainError('Die Vorlage passt nicht zu diesem Bereich.');
    }
    final result = entry.copyWith(
      title: entry.title.isEmpty
          ? fields['title'] as String? ?? ''
          : entry.title,
      body: append(entry.body, fields['body'] as String? ?? ''),
      items: [
        ...entry.items,
        for (final text in fields['items'] as List? ?? [])
          CheckItem(id: newId(), text: text as String),
      ],
    );
    result
        .copyWith(title: result.title.trim().isEmpty ? 'Vorlage' : result.title)
        .validate();
    return result;
  }

  String get preview => fields.entries
      .map(
        (e) => e.value is List
            ? (e.value as List).map((v) => v is Map ? v['text'] : v).join(' · ')
            : e.value,
      )
      .where((s) => s != '')
      .join('\n');
}

class CatalogBundle {
  CatalogBundle(this.catalogs);
  final Map<String, ObservationCatalog> catalogs;
  String encode() => const JsonEncoder.withIndent('  ').convert({
    'format': 'FLEX-Catalogs',
    'version': 1,
    'catalogs': catalogs.map((k, v) => MapEntry(k, v.toJson())),
  });
  factory CatalogBundle.decode(String text) {
    try {
      if (utf8.encode(text).length > 1000000) throw const FormatException();
      final json = jsonDecode(text) as Map;
      if (json.keys.toSet().difference({
            'format',
            'version',
            'catalogs',
          }).isNotEmpty ||
          json['format'] != 'FLEX-Catalogs' ||
          json['version'] != 1 ||
          json['catalogs'] is! Map) {
        throw const FormatException();
      }
      final result = <String, ObservationCatalog>{};
      for (final item in (json['catalogs'] as Map).entries) {
        if (!observationDefaults.containsKey(item.key) ||
            item.value is! Map ||
            (item.value as Map).keys.toSet().difference({
              'version',
              'options',
              'favorites',
            }).isNotEmpty) {
          throw const FormatException();
        }
        result[item.key as String] = ObservationCatalog.fromJson(
          Json.from(item.value as Map),
        );
      }
      if (result.isEmpty) throw const FormatException();
      return CatalogBundle(result);
    } catch (_) {
      throw const DomainError('Keine gültige FLEX-Katalogdatei.');
    }
  }
}
