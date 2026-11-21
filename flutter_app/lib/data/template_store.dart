part of 'sqlite_notebook.dart';

mixin TemplateStore {
  NotebookDatabase get db;
  Future<ObservationCatalog> observationCatalog(String key);
  Future<ObservationCatalog> _saveCatalog(String key, ObservationCatalog value);
  Future<List<EntryTemplate>> entryTemplates() async {
    final rows = await db
        .customSelect(
          "SELECT key,payload FROM preferences WHERE key LIKE 'entry-template:%' ORDER BY key",
        )
        .get();
    return rows.map((row) {
        final template = EntryTemplate.fromJson(
          Json.from(jsonDecode(row.read<String>('payload')) as Map),
        );
        if (row.read<String>('key') != 'entry-template:${template.id}') {
          throw const DomainError(
            'Die Eintragsvorlage konnte nicht zugeordnet werden.',
          );
        }
        return template;
      }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> saveEntryTemplate(
    EntryTemplate template,
  ) => db.transaction(() async {
    EntryTemplate.fromJson(template.toJson());
    final existing = await entryTemplates();
    if (existing.length >= 200 && existing.every((t) => t.id != template.id)) {
      throw const DomainError(
        'Bitte eine bestehende Vorlage entfernen (höchstens 200).',
      );
    }
    await db.customStatement(
      'INSERT INTO preferences(key,payload) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload',
      ['entry-template:${template.id}', jsonEncode(template.toJson())],
    );
  });
  Future<void> deleteEntryTemplate(String id) => db.customStatement(
    'DELETE FROM preferences WHERE key=?',
    ['entry-template:$id'],
  );
  Future<CatalogBundle> exportCatalogs() => db.transaction(
    () async => CatalogBundle({
      for (final key in observationDefaults.keys)
        key: await observationCatalog(key),
    }),
  );
  Future<void> importCatalogs(CatalogBundle bundle, {required bool replace}) =>
      db.transaction(() async {
        final checked = CatalogBundle.decode(bundle.encode());
        for (final item in checked.catalogs.entries) {
          final old = await observationCatalog(item.key);
          final options = replace
              ? item.value.options
              : {...old.options, ...item.value.options}.toList();
          final favorites = replace
              ? item.value.favorites
              : {...old.favorites, ...item.value.favorites}.toList();
          final merged = ObservationCatalog.fromJson(
            ObservationCatalog(options: options, favorites: favorites).toJson(),
          );
          await _saveCatalog(item.key, merged);
        }
      });
}
