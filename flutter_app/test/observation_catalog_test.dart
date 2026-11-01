import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/models.dart';

SqliteNotebook fresh() => SqliteNotebook(
  NotebookDatabase(
    NativeDatabase.memory(),
    File('assets/schema.sql').readAsStringSync(),
  ),
);
void main() {
  test(
    'catalog edits and concurrent favorites survive a full backup and invalid restoration rolls back',
    () async {
      final repo = fresh(), restored = fresh(), invalid = fresh();
      await repo.initialize();
      await restored.initialize();
      await invalid.initialize();
      try {
        await repo.saveObservationOptions('work-negative', [
          'Eins',
          'Zwei',
          'Drei',
        ]);
        await Future.wait([
          repo.toggleObservationFavorite('work-negative', 'Eins'),
          repo.toggleObservationFavorite('work-negative', 'Zwei'),
        ]);
        expect(
          (await repo.observationCatalog('work-negative')).favorites.toSet(),
          {'Eins', 'Zwei'},
        );
        await repo.saveObservationOptions('work-negative', [
          'Zwei',
          'Drei',
          'Vier',
        ]);
        final text = await repo.exportBackup();
        await restored.restoreBackup(text);
        final catalog = await restored.observationCatalog('work-negative');
        expect(catalog.options, ['Zwei', 'Drei', 'Vier']);
        expect(catalog.favorites, ['Zwei']);
        final broken = jsonDecode(text) as Map<String, dynamic>;
        final prefs = broken['tables']['preferences'] as List;
        (prefs.first as Map)['payload'] = jsonEncode({
          'version': 1,
          'options': ['Zwei'],
          'favorites': ['Unbekannt'],
        });
        await expectLater(
          invalid.restoreBackup(jsonEncode(broken)),
          throwsA(isA<DomainError>()),
        );
        expect(
          (await invalid.observationCatalog('work-negative')).options,
          contains('Beginnt erst nach mehreren Aufforderungen'),
        );
      } finally {
        await repo.close();
        await restored.close();
        await invalid.close();
      }
    },
  );
}
