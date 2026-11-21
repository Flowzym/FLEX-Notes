import 'package:flex_notizbuch/domain/school_year.dart';
import 'package:flex_notizbuch/domain/document_scanner.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pdf;
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/calendar.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/services/calendar_ics.dart';
import 'package:flex_notizbuch/services/material_index.dart';
import 'package:flex_notizbuch/services/reminders.dart';
import 'package:flex_notizbuch/services/stream_backup.dart';
import 'classroom_test.dart' show classroomMemory;
import 'material_workspace_test.dart' show FolderDrive, MemoryMaterialFiles;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  test('09 Uhr Wiener Ortszeit im Winter und im Sommer importieren', () {
    for (final sample in {'20260115': '08:00', '20260715': '07:00'}.entries) {
      final result = parseCalendarIcs(
        [
          'BEGIN:VCALENDAR',
          'VERSION:2.0',
          'BEGIN:VEVENT',
          'UID:probe${sample.key}',
          'SUMMARY:Elterngespräch',
          'DTSTART;TZID=Europe/Vienna:${sample.key}T090000',
          'DTEND;TZID=Europe/Vienna:${sample.key}T100000',
          'END:VEVENT',
          'END:VCALENDAR',
        ].join('\r\n'),
      );
      expect(result.warnings, isEmpty);
      final item = result.documents.single;
      final expected = DateTime.parse(
        '${sample.key}T${sample.value}:00Z',
      ).toLocal();
      expect(item.calendarCategory, 'appointment');
      expect(
        item.text('start'),
        '${expected.hour.toString().padLeft(2, "0")}:${expected.minute.toString().padLeft(2, "0")}',
      );
    }
  });

  test(
    'Wiener Termin kurz nach Mitternacht behält seinen Zeitpunkt und Kalendertag am Gerät',
    () {
      final event = parseCalendarIcs(
        [
          'BEGIN:VCALENDAR',
          'BEGIN:VEVENT',
          'UID:nacht',
          'SUMMARY:Test',
          'DTSTART;TZID=Europe/Vienna:20260715T001000',
          'DTEND;TZID=Europe/Vienna:20260715T003000',
          'END:VEVENT',
          'END:VCALENDAR',
        ].join('\r\n'),
      ).documents.single;
      final expected = DateTime.utc(2026, 7, 14, 22, 10).toLocal();
      expect(event.text('date'), dateOnly(expected));
      expect(
        event.text('start'),
        '${expected.hour.toString().padLeft(2, '0')}:10',
      );
    },
  );

  test(
    'Schuljahresarchiv mit Scan und bereits falsch bezeichneter Build-84-Offlinekopie wiederherstellen',
    () async {
      final source = classroomMemory(), target = classroomMemory();
      await source.initialize();
      await target.initialize();
      addTearDown(source.close);
      addTearDown(target.close);
      await source.savePupil(const Pupil(id: 'p', name: 'Testperson'));
      final record = await source.saveSchoolRecord(
        SchoolRecord.empty(
          SchoolKind.social,
          'p',
        ).patch({'observedOn': '2025-10-01', 'body': 'Hilft mit.'}),
      );
      final bytes =
          await (pdf.Document()
                ..addPage(pdf.Page(build: (_) => pdf.Text('Arbeitsprobe'))))
              .save();
      final files = MemoryMaterialFiles(),
          restoredFiles = MemoryMaterialFiles();
      for (final legacy in [false, true]) {
        final key = legacy ? 'onedrive' : 'scan';
        await files.write(key, bytes);
        await source.saveClassroomDocument(
          ClassroomDocument.create(ClassroomKind.material, key, {
            'localKey': key,
            'name': legacy ? 'Probe.docx' : 'Scan.pdf',
            'extension': legacy ? 'docx' : 'pdf',
            'size': legacy ? 10 : bytes.length,
            'pupilIds': ['p'],
            'links': [DocumentLink('school', record.id).toJson()],
            if (legacy) ...{
              'driveId': 'drive',
              'itemId': 'probe',
            } else
              'scanner': true,
          }),
        );
      }
      final year = SchoolYearArchive.preview(
        await source.snapshot(),
        title: '2025/26',
        from: '2025-09-01',
        to: '2026-08-31',
      );
      await source.archiveSchoolYear(year, await source.exportBackup());
      final archive = await StreamBackup.capture(
        source,
        files,
      ).expand((v) => v).toList();
      final candidate = await StreamBackup.prepare(
        () => Stream.value(archive),
        restoredFiles,
      );
      await candidate.commit(() => target.restoreBackup(candidate.notebook));
      expect((await target.snapshot()).active().records, isEmpty);
      await target.reopenSchoolYear(year.id);
      expect((await target.snapshot()).active().records.single.id, record.id);
      for (final material in await target.classroomDocuments()) {
        expect(material.text('extension'), 'pdf');
        expect(material.number('size'), bytes.length);
        expect(material.strings('pupilIds'), ['p']);
        expect(material.rows('links').single['id'], record.id);
        expect(await restoredFiles.read(material.text('localKey')), bytes);
      }
    },
  );
  test(
    'lokales PDF sichern, OneDrive-Dateiendung ändern, erneut sichern',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final files = MemoryMaterialFiles();
      final doc = pdf.Document()
        ..addPage(pdf.Page(build: (_) => pdf.Text('FLEX Testblatt')));
      final Uint8List bytes = await doc.save();
      final folder = ClassroomDocument.create(
        ClassroomKind.folder,
        'Unterricht',
        {'driveId': 'd', 'itemId': 'root'},
      );
      await repo.savePupil(const Pupil(id: 'p', name: 'Testperson'));
      final drive = FolderDrive({
        'root': [
          {
            'id': 'same',
            'name': 'Testblatt.pdf',
            'size': bytes.length,
            'webUrl': 'https://example.org/test',
            'eTag': 'v1',
          },
        ],
      });
      final original = (await scanMaterialFolder(drive, folder, [])).single;
      await files.write('testpdf', bytes);
      final saved = await repo.saveClassroomDocument(
        original.patch({
          'localKey': 'testpdf',
          'size': bytes.length,
          'etag': 'v1',
          'pupilIds': ['p'],
        }),
      );
      final before = await StreamBackup.capture(
        repo,
        files,
      ).fold<int>(0, (n, chunk) => n + chunk.length);
      expect(before, greaterThan(0));
      drive.tree['root'] = [
        {
          'id': 'same',
          'name': 'Testblatt.docx',
          'size': bytes.length,
          'webUrl': 'https://example.org/test',
          'eTag': 'v2',
        },
      ];
      final next = (await scanMaterialFolder(drive, folder, [saved])).single;
      final updated = await repo.saveClassroomDocument(next);
      expect(updated.text('extension'), 'pdf');
      expect(updated.text('remoteName'), 'Testblatt.docx');
      expect(updated.text('localKey'), 'testpdf');
      expect(await files.read('testpdf'), bytes);
      final archive = await StreamBackup.capture(
        repo,
        files,
      ).expand((v) => v).toList();
      final target = classroomMemory();
      await target.initialize();
      addTearDown(target.close);
      final restoredFiles = MemoryMaterialFiles();
      final restore = await StreamBackup.prepare(
        () => Stream.value(archive),
        restoredFiles,
      );
      await restore.commit(() => target.restoreBackup(restore.notebook));
      final row = (await target.classroomDocuments()).single;
      expect(row.text('extension'), 'pdf');
      expect(row.strings('pupilIds'), ['p']);
      expect(await restoredFiles.read(row.text('localKey')), bytes);
    },
  );

  test(
    'fehlende HÜ neu aufgeben, Nacharbeit abschließen, alte Fälligkeit prüfen',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      await repo.savePupil(const Pupil(id: 'p', name: 'Testperson'));
      final old = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.homework, 'p').patch({
          'observedOn': '2026-11-10',
          'dueDate': '2026-11-12',
          'tasks': [
            const HomeworkTask(
              id: 'old',
              text: 'Lesen',
              initialState: TaskState.missing,
            ).toJson(),
          ],
        }),
      );
      final next = await repo.reassignHomeworkTask(
        old,
        'old',
        dueDate: '2026-11-18',
      );
      final forwarded = (await repo.schoolRecords()).singleWhere(
        (r) => r.id == old.id,
      );
      expect(forwarded.tasks.single.reassignedTo, next.id);
      expect(forwarded.taskState(forwarded.tasks.single), TaskState.missing);
      // Reopen the exact shape written by older APKs: a reassignment note and
      // a new task, before task records contained a link.
      final legacyTask = forwarded.tasks.single.toJson()
        ..remove('reassignedTo');
      await repo.saveSchoolRecord(
        forwarded.patch({
          'tasks': [legacyTask],
        }),
      );
      final legacy = (await repo.schoolRecords()).singleWhere(
        (r) => r.id == old.id,
      );
      expect(legacy.tasks.single.reassignedTo, next.id);
      final done = SchoolFeedback(
        id: 'r',
        observedOn: '2026-11-18',
        createdAtUtc: utcNow(),
        taskId: next.tasks.single.id,
        taskText: 'Lesen',
        state: TaskState.complete,
      );
      await repo.saveSchoolRecord(
        next.patch({
          'feedback': [done.toJson()],
        }),
      );
      final data = await repo.snapshot();
      final items = calendarItems(data, '2026-11-10', '2026-11-19');
      expect(items.singleWhere((i) => i.date == '2026-11-12').done, true);
      expect(items.singleWhere((i) => i.date == '2026-11-18').done, true);
    },
  );

  test('Android-Benachrichtigungsabgleich nach Fälligkeit', () async {
    final repo = classroomMemory();
    await repo.initialize();
    addTearDown(repo.close);
    await repo.saveEntry(
      OrgaEntry.empty().copyWith(
        isTask: true,
        title: 'Formular',
        dueDate: '2026-11-18',
      ),
    );
    final data = await repo.snapshot();
    final before = planReminders(data, {}, DateTime(2026, 11, 18, 8, 55));
    final retained = <int>{};
    final after = planReminders(
      data,
      {},
      DateTime(2026, 11, 18, 9, 05),
      retainDelivered: retained,
    );
    final id = before.single.id;
    expect(after, isEmpty);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (c) async {
      calls.add(c);
      if (c.method == 'initialize') return true;
      if (c.method == 'pendingNotificationRequests') return [];
      if (c.method == 'getActiveNotifications') {
        return [
          {'id': id},
        ];
      }
      if (c.method == 'getNotificationAppLaunchDetails') return null;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final android = AndroidReminderPort();
    await android.initialize((_) {});
    await android.apply(after, exact: false, retainDelivered: retained);
    expect(
      calls.any((c) => c.method == 'cancel' && c.arguments['id'] == id),
      false,
    );
    await android.apply([], exact: false);
    expect(
      calls.any((c) => c.method == 'cancel' && c.arguments['id'] == id),
      true,
    );
  });
}
