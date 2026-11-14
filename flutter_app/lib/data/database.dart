import 'package:drift/drift.dart';

/// Explicit SQL keeps the native and web database contracts identical.
class NotebookDatabase extends GeneratedDatabase {
  NotebookDatabase(super.executor, this.schemaSql);
  final String schemaSql;
  @override
  int get schemaVersion => 8;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  Iterable<String> get statements => schemaSql.contains('-- flex:statement')
      ? schemaSql.split('-- flex:statement').where((s) => s.contains('CREATE '))
      : schemaSql.split(';').where((s) => s.trim().isNotEmpty);

  Future<void> createSchema({bool existing = false}) async {
    for (var statement in statements) {
      if (existing) {
        statement = statement
            .replaceAll('CREATE TABLE ', 'CREATE TABLE IF NOT EXISTS ')
            .replaceAll(
              'CREATE VIRTUAL TABLE ',
              'CREATE VIRTUAL TABLE IF NOT EXISTS ',
            )
            .replaceAll('CREATE INDEX ', 'CREATE INDEX IF NOT EXISTS ')
            .replaceAll('CREATE TRIGGER ', 'CREATE TRIGGER IF NOT EXISTS ');
      }
      await customStatement(statement);
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => createSchema(),
    onUpgrade: (_, from, to) => transaction(() async {
      if (!{1, 7}.contains(from) || to != 8) {
        throw StateError(
          'Keine verifizierte Migration von $from nach $to vorhanden. Die Datenbank bleibt erhalten.',
        );
      }
      if (from == 1) {
        for (final column in [
          'deleted INTEGER NOT NULL DEFAULT 0 CHECK(deleted IN (0,1))',
          "reminder_text TEXT NOT NULL DEFAULT ''",
          "observed_on TEXT NOT NULL DEFAULT ''",
          "observed_time TEXT NOT NULL DEFAULT ''",
        ]) {
          await customStatement('ALTER TABLE orga ADD COLUMN $column');
        }
      }
      for (final column in [
        'created_at_utc TEXT',
        'updated_at_utc TEXT',
        'deleted INTEGER NOT NULL DEFAULT 0 CHECK(deleted IN (0,1))',
        'deleted_at_utc TEXT',
      ]) {
        await customStatement('ALTER TABLE pupils ADD COLUMN $column');
      }
      await customStatement(
        '''UPDATE pupils SET
        created_at_utc=(SELECT MIN(captured_at_utc) FROM revisions WHERE entity_kind='pupil' AND entity_id=pupils.id),
        updated_at_utc=(SELECT MAX(captured_at_utc) FROM revisions WHERE entity_kind='pupil' AND entity_id=pupils.id)''',
      );
      for (final column in [
        "name TEXT NOT NULL DEFAULT ''",
        "platform TEXT NOT NULL DEFAULT ''",
        'created_at_utc TEXT',
        'last_seen_at_utc TEXT',
        'public_key_metadata TEXT CHECK(public_key_metadata IS NULL OR json_valid(public_key_metadata))',
      ]) {
        await customStatement('ALTER TABLE devices ADD COLUMN $column');
      }
      final operations = statements.firstWhere(
        (s) => s.contains('CREATE TABLE operations '),
      );
      await customStatement(
        operations.replaceFirst(
          'CREATE TABLE operations ',
          'CREATE TABLE operations_new ',
        ),
      );
      await customStatement(
        'INSERT INTO operations_new SELECT * FROM operations',
      );
      await customStatement(
        'CREATE TABLE outbox_new (operation_id TEXT PRIMARY KEY REFERENCES operations_new(id))',
      );
      await customStatement('INSERT INTO outbox_new SELECT * FROM outbox');
      await customStatement('DROP TABLE outbox');
      await customStatement('DROP TABLE operations');
      await customStatement('ALTER TABLE operations_new RENAME TO operations');
      await customStatement('ALTER TABLE outbox_new RENAME TO outbox');
      await createSchema(existing: true);
      // Rebuild with exactly the same fields used by subsequent writes.
      for (final table in ['school_records', 'situations', 'preferences']) {
        await customStatement('UPDATE $table SET payload=payload');
      }
      await customStatement('UPDATE orga SET body=body');
      if ((await customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
        throw StateError(
          'Die Migration hat ungültige Verweise erkannt. Änderungen werden zurückgenommen.',
        );
      }
    }),
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA secure_delete = ON');
    },
  );
}
