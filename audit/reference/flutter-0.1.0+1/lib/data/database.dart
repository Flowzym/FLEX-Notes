import 'package:drift/drift.dart';

/// Explicit, reviewed SQL instead of generated tables. All mutations are in
/// SqliteNotebook; UI refreshes use its controller, not untracked SQL streams.
class NotebookDatabase extends GeneratedDatabase {
  NotebookDatabase(QueryExecutor executor, this.schemaSql) : super(executor);
  final String schemaSql;
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      for (final statement in schemaSql.split(';')) {
        if (statement.trim().isNotEmpty) await customStatement(statement);
      }
    },
    onUpgrade: (_, from, to) async => throw StateError('Keine Migration von $from nach $to vorhanden. Die Datenbank bleibt erhalten.'),
    beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
  );
}
