import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flex_notizbuch/services/app_lock.dart';
import 'package:flex_notizbuch/services/automatic_backup.dart';
import 'package:flex_notizbuch/services/device_services.dart';
import 'package:flex_notizbuch/services/reminders.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'device_features_test.dart'
    show MemorySecrets, MemoryBackupFiles, FakeReminders;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/services/incoming_shares.dart';
import 'package:flex_notizbuch/ui/incoming_shares.dart';
import 'classroom_test.dart' show classroomMemory, lesson;
import 'material_workspace_test.dart' show MemoryMaterialFiles;

const incomingId = '11111111-2222-4333-8444-555555555555';

class TestIncomingPort implements IncomingSharePort {
  List<Json> items = [];
  bool failAck = false;
  @override
  Future<Json> pending() async => {'items': items, 'error': ''};
  @override
  Future<void> discard(List<String> ids) async {
    if (failAck) throw StateError('ack failure');
    items.removeWhere((d) => ids.contains(d['id']));
  }

  @override
  Future<void> clearError() async {}
}

Future<IncomingShares> incomingFixture(
  TestIncomingPort port,
  MemoryMaterialFiles files,
) async {
  final bytes = Uint8List.fromList(ascii.encode('%PDF-1.4 synthetic'));
  await files.write('incoming_$incomingId', bytes);
  port.items = [
    {
      'id': incomingId,
      'key': 'incoming_$incomingId',
      'kind': 'pdf',
      'name': 'Arbeitsblatt.pdf',
      'size': bytes.length,
    },
  ];
  final service = IncomingShares(port: port, files: files);
  await service.refresh();
  return service;
}

class TestShareLock extends AppLock {
  TestShareLock()
    : super(
        MemorySecrets(),
        authenticate: () async => true,
        protectScreen: (_) async {},
      ) {
    ready = true;
  }
  void allow() {
    locked = false;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'incoming files remain pending; accepted files link pupils, date and lesson atomically',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      await repo.savePupil(const Pupil(id: 'p', name: 'Alex'));
      final block = await repo.saveClassroomDocument(lesson());
      final files = MemoryMaterialFiles(), port = TestIncomingPort();
      final incoming = await incomingFixture(port, files);
      addTearDown(incoming.dispose);
      expect(
        (await repo.classroomDocuments()).where(
          (d) => d.kind == ClassroomKind.material,
        ),
        isEmpty,
      );
      await incoming.accept(
        repo,
        {incomingId},
        pupils: ['p'],
        lessons: [block.id],
        date: '2026-11-16',
        category: 'worksheet',
        names: {incomingId: 'Neue Aufgabe'},
      );
      final docs = await repo.classroomDocuments();
      final material = docs.singleWhere((d) => d.id == incomingId);
      expect(material.title, 'Neue Aufgabe');
      expect(material.text('name'), 'Neue Aufgabe.pdf');
      expect(material.strings('pupilIds'), ['p']);
      expect(material.rows('pupilDates'), [
        {'pupilId': 'p', 'date': '2026-11-16'},
      ]);
      expect(docs.singleWhere((d) => d.id == block.id).strings('materialIds'), [
        incomingId,
      ]);
      expect(port.items, isEmpty);
    },
  );
  test(
    'failed batch preserves pending files and existing file collisions',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final files = MemoryMaterialFiles(), port = TestIncomingPort();
      final incoming = await incomingFixture(port, files);
      addTearDown(incoming.dispose);
      final existing = Uint8List.fromList(ascii.encode('%PDF-1.4 existing'));
      await files.write('received_$incomingId', existing);
      await expectLater(
        incoming.accept(repo, {incomingId}, lessons: ['missing']),
        throwsA(isA<DomainError>()),
      );
      expect(port.items, hasLength(1));
      expect(await repo.classroomDocuments(), isEmpty);
      expect(files.values.keys.toSet(), {
        'incoming_$incomingId',
        'received_$incomingId',
      });
      expect(files.values['received_$incomingId'], existing);
    },
  );
  test(
    'retry after acknowledgement failure does not duplicate or delete accepted files',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final files = MemoryMaterialFiles(), port = TestIncomingPort();
      final incoming = await incomingFixture(port, files);
      addTearDown(incoming.dispose);
      port.failAck = true;
      await expectLater(
        incoming.accept(repo, {incomingId}),
        throwsA(isA<DomainError>()),
      );
      expect(await repo.classroomDocuments(), hasLength(1));
      expect(files.values.containsKey('received_$incomingId'), isTrue);
      port.failAck = false;
      await incoming.accept(repo, {incomingId});
      expect(await repo.classroomDocuments(), hasLength(1));
      expect(port.items, isEmpty);
    },
  );
  test(
    'incoming images become normalized JPEG and invalid batch rolls back',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final files = MemoryMaterialFiles(), port = TestIncomingPort();
      final incoming = await incomingFixture(port, files);
      addTearDown(incoming.dispose);
      final png = img.encodePng(img.Image(width: 40, height: 20));
      await files.write('incoming_$incomingId', png);
      port.items.single.addAll({
        'kind': 'image',
        'size': png.length,
        'name': 'Photo.png',
      });
      await incoming.refresh();
      final normalized = await incoming.read(incoming.items.single);
      expect(normalized.take(2), [255, 216]);
      expect(img.decodeJpg(normalized)!.width, 40);
      const badId = '11111111-2222-4333-8444-555555555556';
      await files.write('incoming_$badId', Uint8List.fromList([1, 2, 3]));
      port.items.add({
        'id': badId,
        'key': 'incoming_$badId',
        'kind': 'pdf',
        'name': 'broken.pdf',
        'size': 3,
      });
      await incoming.refresh();
      await expectLater(
        incoming.accept(repo, {incomingId, badId}),
        throwsA(isA<DomainError>()),
      );
      expect(await repo.classroomDocuments(), isEmpty);
      expect(files.values.keys, everyElement(startsWith('incoming_')));
      expect(incoming.items, hasLength(2));
      await incoming.accept(repo, {incomingId});
      final image = (await repo.classroomDocuments()).single;
      expect(image.text('name'), 'Photo.jpg');
      expect(image.text('extension'), 'jpg');
    },
  );
  testWidgets('incoming review waits for unlock and Later does not reopen it', (
    tester,
  ) async {
    final repo = classroomMemory(),
        secrets = MemorySecrets(),
        lock = TestShareLock();
    final incoming = await incomingFixture(
      TestIncomingPort(),
      MemoryMaterialFiles(),
    );
    final backup = AutomaticBackup(
      store: secrets,
      files: MemoryBackupFiles(),
      export: repo.exportBackup,
      schedule: (_) async {},
      withLock: (f) => f(),
    );
    final reminders = Reminders(secrets, FakeReminders());
    await reminders.initialize();
    final c = NotebookController(
      repo,
      services: DeviceServices(
        lock: lock,
        backup: backup,
        reminders: reminders,
        incoming: incoming,
      ),
    );
    await c.initialize();
    await tester.pumpWidget(FlexApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('Geteilte Dateien'), findsNothing);
    lock.allow();
    await tester.pumpAndSettle();
    expect(find.text('Geteilte Dateien'), findsOneWidget);
    await tester.tap(find.text('Später'));
    await tester.pumpAndSettle();
    await incoming.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Geteilte Dateien'), findsNothing);
    expect(incoming.items, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    lock.dispose();
    backup.dispose();
    reminders.dispose();
    incoming.dispose();
    await repo.close();
  });
  for (final scale in [1.0, 1.6]) {
    testWidgets(
      'share review fits 320px and Later preserves pending files at $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = classroomMemory(), c = NotebookController(repo);
        await c.initialize();
        addTearDown(repo.close);
        addTearDown(c.dispose);
        final incoming = await incomingFixture(
          TestIncomingPort(),
          MemoryMaterialFiles(),
        );
        addTearDown(incoming.dispose);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showIncomingShares(context, c, incoming),
                  child: const Text('Eingang'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Eingang'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Geteilte Dateien'), findsOneWidget);
        expect(find.text('Schüler zuordnen'), findsOneWidget);
        expect(find.text('Unterricht zuordnen'), findsOneWidget);
        await tester.ensureVisible(find.text('Später'));
        await tester.tap(find.text('Später'));
        await tester.pumpAndSettle();
        expect(incoming.items, hasLength(1));
        expect(await repo.classroomDocuments(), isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
