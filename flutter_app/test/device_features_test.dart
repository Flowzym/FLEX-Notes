import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/repository.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/services/app_lock.dart';
import 'package:flex_notizbuch/services/automatic_backup.dart';
import 'package:flex_notizbuch/services/brief_pdf.dart';
import 'package:flex_notizbuch/services/reminders.dart';
import 'package:flex_notizbuch/services/secret_store.dart';
import 'package:flex_notizbuch/ui/app_guard.dart';

class MemorySecrets implements SecretStore {
  final values = <String, String>{};
  bool broken = false;
  Future<void> Function()? beforeWrite;
  @override
  Future<String?> read(String key) async {
    if (broken) throw StateError('unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    await beforeWrite?.call();
    if (broken) throw StateError('unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (broken) throw StateError('unavailable');
    values.remove(key);
  }
}

class MemoryBackupFiles implements BackupFiles {
  final data = <String, Uint8List>{};
  final names = <String, String>{};
  bool corrupt = false, failWrite = false, failDelete = false;
  @override
  Future<Map<String, dynamic>?> chooseDirectory() async => {
    'uri': 'folder',
    'name': 'Testordner',
  };
  @override
  Future<List<Map<String, dynamic>>> list(String folder) async => [
    for (final item in names.entries)
      {'uri': item.key, 'name': item.value, 'size': data[item.key]!.length},
  ];
  @override
  Future<String> write(String folder, String name, Uint8List bytes) async {
    if (failWrite) throw StateError('offline');
    names[name] = name;
    data[name] = corrupt ? Uint8List.fromList([0]) : bytes;
    return name;
  }

  @override
  Future<Uint8List> read(String folder, String uri) async => data[uri]!;
  @override
  Future<void> delete(String folder, String uri) async {
    if (failDelete) throw StateError('read-only');
    data.remove(uri);
    names.remove(uri);
  }
}

class FakeReminders implements ReminderPort {
  bool allowed = true, exact = false;
  final applied = <List<ReminderRequest>>[];
  late ValueChanged<String> tap;
  @override
  Future<String?> initialize(ValueChanged<String> onTap) async {
    tap = onTap;
    return 'orga:launch';
  }

  @override
  Future<bool> permission({bool request = false}) async => allowed;
  @override
  Future<bool> exactPermission({bool request = false}) async => exact;
  @override
  Future<void> apply(
    List<ReminderRequest> requests, {
    required bool exact,
  }) async {
    applied.add(requests);
  }
}

NotebookSnapshot snapshot({
  List<OrgaEntry> entries = const [],
  List<SchoolRecord> records = const [],
  List<Pupil> pupils = const [Pupil(id: 'p', name: 'Kind')],
}) => NotebookSnapshot(
  pupils: pupils,
  entries: entries,
  records: records,
  drafts: [],
  schoolDrafts: [],
  appearance: const Appearance(),
  legacyCount: 0,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppLock lockFor(
    MemorySecrets store, {
    DateTime Function()? now,
    Future<bool> Function()? auth,
  }) => AppLock(
    store,
    authenticate: auth ?? () async => true,
    protectScreen: (_) async {},
    now: now,
  );
  test(
    'PIN persists hashed, locks on restart, checks old PIN for changes',
    () async {
      final secrets = MemorySecrets(), lock = lockFor(MemorySecrets());
      await lock.load();
      expect(lock.locked, false);
      await lock.configure('123456', useBiometrics: false);
      expect(lock.enabled, true);
      lock.lock();
      expect(await lock.unlockPin('000000'), false);
      expect(lock.locked, true);
      expect(await lock.unlockPin('123456'), true);
      await expectLater(
        lock.configure('999999', useBiometrics: false, currentPin: '000000'),
        throwsA(isA<DomainError>()),
      );
      secrets.values.addAll((lock.store as MemorySecrets).values);
      expect(secrets.values.values.single, isNot(contains('123456')));
      final restarted = lockFor(secrets);
      await restarted.load();
      expect(restarted.locked, true);
      await restarted.disable('123456');
      expect(restarted.enabled, false);
    },
  );
  test(
    'PIN throttles across restarts and storage errors fail closed',
    () async {
      var now = DateTime.utc(2026, 11, 4);
      final secrets = MemorySecrets(),
          lock = lockFor(MemorySecrets(), now: () => now);
      await lock.load();
      await lock.configure('123456', useBiometrics: false);
      lock.lock();
      for (var n = 0; n < 5; n++) {
        expect(await lock.unlockPin('000000'), false);
      }
      secrets.values.addAll((lock.store as MemorySecrets).values);
      final restarted = lockFor(secrets, now: () => now);
      await restarted.load();
      expect(await restarted.unlockPin('123456'), false);
      expect(restarted.locked, true);
      now = now.add(const Duration(minutes: 2));
      expect(await restarted.unlockPin('123456'), true);
      secrets.broken = true;
      await restarted.load();
      expect(restarted.locked, true);
      expect(restarted.ready, false);
    },
  );
  test(
    'backgrounding during successful unlock cannot expose the app',
    () async {
      final secrets = MemorySecrets(), lock = lockFor(MemorySecrets());
      await lock.load();
      await lock.configure('123456', useBiometrics: true);
      lock.lock();
      final saving = Completer<void>();
      (lock.store as MemorySecrets).beforeWrite = () => saving.future;
      final result = lock.unlockBiometric();
      await Future<void>.delayed(Duration.zero);
      lock.lock(background: true);
      saving.complete();
      expect(await result, false);
      expect(lock.locked, true);
      secrets.broken = true;
      final failed = lockFor(secrets);
      await failed.load();
      expect(failed.locked, true);
    },
  );
  testWidgets(
    'lock hides navigation and input without recreating entered data',
    (tester) async {
      final lock = lockFor(MemorySecrets());
      await tester.runAsync(() async {
        await lock.load();
        await lock.configure('123456', useBiometrics: false);
      });
      final input = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [navigationLock(lock)],
          builder: (context, child) => AppGuard(lock: lock, child: child!),
          home: Scaffold(
            body: TextField(key: const ValueKey('draft'), controller: input),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('draft')),
        'Entwurf erhalten',
      );
      lock.lock();
      await tester.pump();
      expect(find.byKey(const ValueKey('draft')), findsNothing);
      expect(find.text('FLEX entsperren'), findsOneWidget);
      await tester.runAsync(() => lock.unlockPin('123456'));
      await tester.pump();
      expect(input.text, 'Entwurf erhalten');
      expect(find.byKey(const ValueKey('draft')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      input.dispose();
      lock.dispose();
    },
  );
  test(
    'automatic backup encrypts, verifies, rotates only own files, and restores',
    () async {
      final store = MemorySecrets(), files = MemoryBackupFiles();
      var now = DateTime.utc(2026, 11, 4);
      final scheduled = <int?>[];
      final backup = AutomaticBackup(
        store: store,
        files: files,
        export: () async => '{"secret":"Testkind"}',
        schedule: (hours) async {
          scheduled.add(hours);
        },
        withLock: (f) => f(),
        now: () => now,
      );
      await backup.configure(
        folder: (await files.chooseDirectory())!,
        password: 'a-secure-password-37',
        hours: 24,
        retention: 7,
      );
      expect(scheduled, [24]);
      expect(backup.lastSuccess, now);
      expect(
        utf8.decode(files.data.values.single),
        isNot(contains('Testkind')),
      );
      expect(
        await backup.open(files.data.keys.single),
        '{"secret":"Testkind"}',
      );
      await backup.run();
      expect(files.data.length, 1);
      // A backup from a different installation in the same folder is not rotated.
      await files.write(
        'folder',
        'FLEX-Auto-2020-other-device.json',
        Uint8List(1),
      );
      final own = files.names.keys.first;
      final group =
          (jsonDecode(store.values[AutomaticBackup.key]!) as Map)['groupId'];
      for (var n = 0; n < 8; n++) {
        await files.write(
          'folder',
          'FLEX-Auto-2020-$group-$n.json',
          files.data[own]!,
        );
      }
      now = now.add(const Duration(days: 1));
      await backup.run();
      expect(files.data.length, 8);
      expect(files.data.containsKey('FLEX-Auto-2020-other-device.json'), true);
      final successful = backup.lastSuccess;
      final count = files.data.length;
      files.corrupt = true;
      now = now.add(const Duration(days: 1));
      await expectLater(backup.run(), throwsA(isA<DomainError>()));
      expect(backup.lastSuccess, successful);
      expect(files.data.length, count);
      expect(backup.lastFailure, isNotNull);
      await backup.disable();
      expect(scheduled.last, isNull);
    },
  );
  test('failed document write preserves the last successful backup', () async {
    final store = MemorySecrets(), files = MemoryBackupFiles();
    final backup = AutomaticBackup(
      store: store,
      files: files,
      export: () async => '{}',
      schedule: (_) async {},
      withLock: (f) => f(),
    );
    await backup.configure(
      folder: (await files.chooseDirectory())!,
      password: 'a-secure-password-37',
      hours: 24,
      retention: 7,
    );
    final previous = Map.of(files.data);
    files.failWrite = true;
    await expectLater(backup.run(force: true), throwsStateError);
    expect(files.data, previous);
    expect(backup.lastSuccess, isNotNull);
  });
  test(
    'reminders include future appointment/task/goal, exclude complete/deleted/archived',
    () {
      final now = DateTime(2026, 11, 4, 8);
      final appointment = OrgaEntry.empty(pupilId: 'p').copyWith(
        title: 'Gespräch',
        appointmentDate: '2026-11-05',
        appointmentTime: '14:30',
      );
      final task = OrgaEntry.empty(
        pupilId: 'p',
      ).copyWith(title: 'Aufgabe', isTask: true, dueDate: '2026-11-06');
      final goal = SchoolRecord.empty(
        SchoolKind.goal,
        'p',
      ).patch({'nextReviewDate': '2026-11-07', 'title': 'Ziel'});
      final data = snapshot(
        entries: [
          appointment,
          task,
          OrgaEntry.fromJson({...task.toJson(), 'id': 'done', 'done': true}),
          OrgaEntry.fromJson({
            ...task.toJson(),
            'id': 'deleted',
            'deleted': true,
          }),
        ],
        records: [goal],
      );
      final plan = planReminders(data, {}, now);
      expect(plan.length, 3);
      expect(plan.map((r) => r.id).toSet().length, 3);
      expect(
        plan.singleWhere((r) => r.target == 'orga:${appointment.id}').when,
        DateTime(2026, 11, 5, 14, 30),
      );
      expect(
        planReminders(
          snapshot(
            entries: [task],
            pupils: [const Pupil(id: 'p', name: 'Kind', archived: true)],
          ),
          {},
          now,
        ),
        isEmpty,
      );
      expect(
        planReminders(data, {
          'appointments': false,
          'tasks': false,
          'goals': false,
        }, now),
        isEmpty,
      );
      expect(planReminders(data, {}, DateTime(2027)), isEmpty);
      expect(
        planReminders(data, {}, now).map((r) => r.id),
        plan.map((r) => r.id),
      );
    },
  );
  test(
    'editing and disabling reminders reconciles OS schedule without duplicates',
    () async {
      final store = MemorySecrets(),
          port = FakeReminders(),
          task = OrgaEntry.empty().copyWith(
            title: 'Termin',
            appointmentDate: '2030-11-05',
          );
      final reminders = Reminders(store, port, now: () => DateTime(2026));
      await reminders.initialize();
      expect(reminders.pendingTarget, 'orga:launch');
      reminders.consumeTarget();
      await reminders.sync(snapshot(entries: [task]));
      await reminders.configure({'enabled': true});
      expect(port.applied.last.length, 1);
      final count = port.applied.length;
      await reminders.sync(snapshot(entries: [task]));
      expect(port.applied.length, count);
      await reminders.sync(
        snapshot(entries: [task.copyWith(appointmentDate: '2030-11-06')]),
      );
      expect(port.applied.last.single.when, DateTime(2030, 11, 6, 9));
      await reminders.configure({'enabled': false});
      expect(port.applied.last, isEmpty);
      port.allowed = false;
      await expectLater(
        reminders.configure({'enabled': true}),
        throwsA(isA<DomainError>()),
      );
      expect(reminders.enabled, false);
    },
  );
  test(
    'PDF embeds fonts, handles German text and many long notes across pages',
    () async {
      final pdf = await briefPdf(
        text:
            'Gesprächsvorbereitung · Änne\nZeitraum: 01.11.2026 bis 04.11.2026\n${List.filled(300, 'Förderung: hört zu, übt und äußert Wünsche. ${'Sehr langer Text ' * 50}').join('\n')}\nNächste Schritte',
        regularFont: ByteData.sublistView(
          await File('assets/fonts/Selawik-Regular.ttf').readAsBytes(),
        ),
        boldFont: ByteData.sublistView(
          await File('assets/fonts/Selawik-Bold.ttf').readAsBytes(),
        ),
      );
      expect(ascii.decode(pdf.take(5).toList()), '%PDF-');
      final raw = latin1.decode(pdf);
      expect(RegExp(r'/Type\s*/Page\b').allMatches(raw).length, greaterThan(1));
      expect(raw, contains('/FontFile2'));
      final artifactDirectory = Platform.environment['FLEX_TEST_ARTIFACT_DIR'];
      if (artifactDirectory != null && artifactDirectory.isNotEmpty) {
        await Directory(artifactDirectory).create(recursive: true);
        await File('$artifactDirectory/brief-test.pdf').writeAsBytes(pdf);
      }
    },
  );
  test(
    'failed Android scheduling does not report an active automatic backup',
    () async {
      final files = MemoryBackupFiles(), store = MemorySecrets();
      final backup = AutomaticBackup(
        store: store,
        files: files,
        export: () async => '{}',
        schedule: (_) async {
          throw StateError('scheduler unavailable');
        },
        withLock: (f) => f(),
      );
      await expectLater(
        backup.configure(
          folder: (await files.chooseDirectory())!,
          password: 'a-secure-password-37',
          hours: 24,
          retention: 7,
        ),
        throwsA(isA<DomainError>()),
      );
      expect(backup.enabled, false);
      expect(backup.lastFailure, isNotNull);
      expect(backup.lastSuccess, isNull);
      expect(files.data, isEmpty);
    },
  );
}
