import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:flex_notizbuch/data/encrypted_database.dart';

void main() {
  final key = List.filled(64, 'a').join();
  late Directory directory;
  setUp(
    () => directory = Directory.systemTemp.createTempSync('flex-vault-test'),
  );
  tearDown(() => directory.deleteSync(recursive: true));
  Map<String, String> args([String? override]) => {
    'directory': directory.path,
    'key': override ?? key,
  };
  void oldDatabase() {
    final db = sqlite3.open('${directory.path}/$legacyDatabaseName');
    db.execute('PRAGMA journal_mode = WAL');
    db.execute(
      'CREATE TABLE secrets(id INTEGER PRIMARY KEY, text TEXT NOT NULL)',
    );
    db.execute('INSERT INTO secrets VALUES (1, ?)', [
      'Vertrauliche Schülernotiz äß',
    ]);
    db.userVersion = 7;
    db.close();
  }

  test('migrates all data and schema into verified encrypted storage', () {
    oldDatabase();
    final path = prepareEncryptedDatabase(args());
    expect(File('${directory.path}/$legacyDatabaseName').existsSync(), false);
    expect(
      latin1.decode(File(path).readAsBytesSync()),
      isNot(contains('Schülernotiz')),
    );
    final noKey = sqlite3.open(path);
    expect(
      () => noKey.select('SELECT * FROM secrets'),
      throwsA(isA<SqliteException>()),
    );
    noKey.close();
    final db = sqlite3.open(path);
    unlockDatabase(db, key);
    expect(db.userVersion, 7);
    expect(
      db.select('SELECT text FROM secrets').single['text'],
      'Vertrauliche Schülernotiz äß',
    );
    db.close();
    expect(prepareEncryptedDatabase(args()), path);
  });
  test(
    'wrong key preserves existing encrypted database and original recovery copy',
    () {
      oldDatabase();
      final path = prepareEncryptedDatabase(args());
      oldDatabase(); // interrupted cleanup from a committed migration
      final before = File(path).readAsBytesSync();
      expect(
        () => prepareEncryptedDatabase(args(List.filled(64, 'b').join())),
        throwsA(anything),
      );
      expect(File(path).readAsBytesSync(), before);
      expect(File('${directory.path}/$legacyDatabaseName').existsSync(), true);
      prepareEncryptedDatabase(args());
      expect(File('${directory.path}/$legacyDatabaseName').existsSync(), false);
    },
  );
  test(
    'interrupted staging is rebuilt; broken original never gets replaced',
    () {
      oldDatabase();
      File(
        '${directory.path}/$encryptedDatabaseName.migrating',
      ).writeAsStringSync('partial');
      prepareEncryptedDatabase(args());
      File('${directory.path}/$encryptedDatabaseName').deleteSync();
      final old = File('${directory.path}/$legacyDatabaseName')
        ..writeAsStringSync('broken');
      expect(() => prepareEncryptedDatabase(args()), throwsA(anything));
      expect(old.readAsStringSync(), 'broken');
      expect(
        File('${directory.path}/$encryptedDatabaseName').existsSync(),
        false,
      );
    },
  );
  test(
    'full application schema, drafts and history retain exactly the same values',
    () {
      final source = sqlite3.open('${directory.path}/$legacyDatabaseName');
      source.execute(File('assets/schema.sql').readAsStringSync());
      source.userVersion = 7;
      source.execute(
        "INSERT INTO pupils(id,name,color,archived,revision) VALUES ('p1','Änne Test',0,0,1)",
      );
      source.execute(
        "INSERT INTO preferences(key,payload) VALUES ('qa','{\"nested\": [1, 2, 3]}')",
      );
      final tables = source
          .select(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
          )
          .map((r) => r['name'] as String)
          .toList();
      final before = {
        for (final name in tables)
          name: jsonEncode(source.select('SELECT * FROM "$name"')),
      };
      source.close();
      final target = sqlite3.open(prepareEncryptedDatabase(args()));
      unlockDatabase(target, key);
      expect({
        for (final name in tables)
          name: jsonEncode(target.select('SELECT * FROM "$name"')),
      }, before);
      target.close();
    },
  );
  test('fresh storage is encrypted and ready for schema creation', () {
    final path = prepareEncryptedDatabase(args());
    final db = sqlite3.open(path);
    unlockDatabase(db, key);
    expect(db.userVersion, 0);
    db.execute('CREATE TABLE example(value TEXT)');
    db.execute("INSERT INTO example VALUES ('private')");
    db.close();
    expect(prepareEncryptedDatabase(args()), path);
  });
}
