import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/ui/app_guard.dart';
import 'package:flex_notizbuch/ui/merge_dialog.dart';
import 'package:flex_notizbuch/ui/school_workspace.dart';
import 'package:flex_notizbuch/services/app_lock.dart';
import 'device_features_test.dart'
    show MemorySecrets, MemoryBackupFiles, FakeReminders;
import 'package:flex_notizbuch/services/automatic_backup.dart';
import 'package:flex_notizbuch/services/reminders.dart';
import 'package:flex_notizbuch/services/device_services.dart';
import 'package:flex_notizbuch/ui/device_settings.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  SqliteNotebook memory() => SqliteNotebook(
    NotebookDatabase(
      NativeDatabase.memory(),
      File('assets/schema.sql').readAsStringSync(),
    ),
  );
  testWidgets(
    'backup preview shows date/time conflicts and applies only selected field',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final local = memory(), source = memory(), c = NotebookController(local);
      await c.initialize();
      await source.initialize();
      final entry = await local.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Termin',
          body: 'Lokal',
          appointmentDate: '2026-11-10',
          appointmentTime: '09:00',
        ),
      );
      await source.restoreBackup(await local.exportBackup());
      await source.saveEntry(
        entry.copyWith(
          body: 'Quelle',
          appointmentDate: '2026-11-11',
          appointmentTime: '15:30',
        ),
      );
      final text = await source.exportBackup();
      await c.reload();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showMergeReview(context, c, text),
                child: const Text('Import'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      expect(find.text('Termindatum'), findsOneWidget);
      expect(find.text('Terminzeit'), findsOneWidget);
      await tester.ensureVisible(find.text('Sicherung: 11.11.2026'));
      await tester.tap(find.text('Sicherung: 11.11.2026'));
      await tester.tap(find.text('Auswahl zusammenführen'));
      await tester.pumpAndSettle();
      final result = (await local.entries()).single;
      expect(result.appointmentDate, '2026-11-11');
      expect(result.appointmentTime, '09:00');
      expect(result.body, 'Lokal');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await local.close();
      await source.close();
    },
  );
  testWidgets(
    'brief PDF uses current selection and invalidates stale preview',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = NotebookController(memory());
      await c.initialize();
      final pupil = await c.repository.savePupil(
        const Pupil(id: 'p', name: 'Testkind'),
      );
      await c.repository.saveEntry(
        OrgaEntry.empty(pupilId: pupil.id).copyWith(
          title: 'Termin',
          appointmentDate: '2026-12-01',
          appointmentTime: '10:30',
        ),
      );
      await c.reload();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showBrief(context, c, pupil),
                child: const Text('Vorbereiten'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Vorbereiten'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Als PDF sichern'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Alle auswählen'));
      await tester.tap(find.text('Auswahl zusammenstellen'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Als PDF sichern'),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.textContaining('Termin: 01.12.2026 10:30'), findsWidgets);
      await tester.tap(find.text('Auswahl leeren'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Als PDF sichern'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await c.repository.close();
    },
  );
  testWidgets('Android back cannot dismiss an editor behind the app lock', (
    tester,
  ) async {
    final lock = AppLock(
      MemorySecrets(),
      authenticate: () async => true,
      protectScreen: (_) async {},
    );
    await tester.runAsync(() async {
      await lock.load();
      await lock.configure('123456', useBiometrics: false);
    });
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [navigationLock(lock)],
        builder: (context, child) => AppGuard(lock: lock, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    const AlertDialog(content: Text('Offener Entwurf')),
              ),
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
    lock.lock();
    await tester.pump();
    expect(find.text('Offener Entwurf'), findsNothing);
    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    await tester.runAsync(() => lock.unlockPin('123456'));
    await tester.pumpAndSettle();
    expect(find.text('Offener Entwurf'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    lock.dispose();
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'device settings and setup dialogs fit a phone at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = memory(), secrets = MemorySecrets();
        final lock = AppLock(
          secrets,
          authenticate: () async => true,
          protectScreen: (_) async {},
        );
        final backup = AutomaticBackup(
          store: secrets,
          files: MemoryBackupFiles(),
          export: repo.exportBackup,
          schedule: (_) async {},
          withLock: (f) => f(),
        );
        final reminders = Reminders(secrets, FakeReminders());
        final services = DeviceServices(
          lock: lock,
          backup: backup,
          reminders: reminders,
        );
        final c = NotebookController(repo, services: services);
        await c.initialize();
        await lock.load();
        await reminders.initialize();
        for (final backups in [true, false]) {
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: DeviceSettings(controller: c, backups: backups),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Einrichten'));
          await tester.tap(find.text('Einrichten'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final field = find.byType(TextField).first;
          await tester.ensureVisible(field);
          await tester.tap(field);
          await tester.pump();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
        c.dispose();
        await repo.close();
      },
    );
  }
}
