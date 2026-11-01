import 'package:drift/drift.dart';

/// Explicit, reviewed SQL instead of generated tables. All mutations are in
/// SqliteNotebook; UI refreshes use its controller, not untracked SQL streams.
class NotebookDatabase extends GeneratedDatabase {
  NotebookDatabase(super.executor, this.schemaSql);
  final String schemaSql;
  @override
  int get schemaVersion => 7;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      for (final statement in schemaSql.split(';')) {
        if (statement.trim().isNotEmpty) await customStatement(statement);
      }
    },
    onUpgrade: (_, from, to) async {
      if (from != 1 || to != 7) {
        throw StateError(
          'Keine verifizierte Migration von $from nach $to vorhanden. Die Datenbank bleibt erhalten.',
        );
      }
      for (final column in [
        "deleted INTEGER NOT NULL DEFAULT 0 CHECK(deleted IN (0,1))",
        "reminder_text TEXT NOT NULL DEFAULT ''",
        "observed_on TEXT NOT NULL DEFAULT ''",
        "observed_time TEXT NOT NULL DEFAULT ''",
      ]) {
        await customStatement('ALTER TABLE orga ADD COLUMN $column');
      }
      for (final statement in schemaSql.split(';')) {
        if (statement.trim().isNotEmpty) {
          await customStatement(
            statement
                .replaceAll('CREATE TABLE ', 'CREATE TABLE IF NOT EXISTS ')
                .replaceAll('CREATE INDEX ', 'CREATE INDEX IF NOT EXISTS '),
          );
        }
      }
    },
    beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
  );
}
