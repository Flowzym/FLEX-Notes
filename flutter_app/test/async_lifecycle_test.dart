import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/repository.dart';
import 'package:flex_notizbuch/services/reminders.dart';
import 'device_features_test.dart' show MemorySecrets, FakeReminders;

class _DelayedSnapshot extends SqliteNotebook {
  _DelayedSnapshot()
    : super(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
  Completer<void>? gate, started;
  @override
  Future<NotebookSnapshot> snapshot() async {
    final result = await super.snapshot();
    final wait = gate;
    started?.complete();
    started = null;
    await wait?.future;
    return result;
  }
}

class _PermissionPrompt extends FakeReminders {
  final answer = Completer<bool>();
  @override
  Future<bool> permission({bool request = false}) =>
      request ? answer.future : super.permission();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a completed reload cannot notify or replace state after disposal',
    () async {
      final repo = _DelayedSnapshot();
      addTearDown(repo.close);
      final controller = NotebookController(repo);
      await controller.initialize();
      repo.gate = Completer();
      repo.started = Completer();
      final started = repo.started!.future;
      final pending = controller.reload();
      await started;
      controller.dispose();
      repo.gate!.complete();
      await expectLater(pending, completes);
    },
  );

  test('a slow old snapshot cannot overwrite a newer pupil', () async {
    final repo = _DelayedSnapshot();
    addTearDown(repo.close);
    final controller = NotebookController(repo);
    await controller.initialize();
    final gate = Completer<void>();
    repo.gate = gate;
    repo.started = Completer();
    final started = repo.started!.future;
    final old = controller.reload();
    await started;
    repo.gate = null;
    await controller.savePupil(const Pupil(id: 'new', name: 'Neuer Eintrag'));
    gate.complete();
    await old;
    expect(controller.pupils.single.name, 'Neuer Eintrag');
    controller.dispose();
  });

  test(
    'rapid reminder switches preserve both changes in memory and storage',
    () async {
      final store = MemorySecrets();
      final gate = Completer<void>(), started = Completer<void>();
      store.beforeWrite = () async {
        if (!started.isCompleted) {
          started.complete();
          await gate.future;
        }
      };
      final reminders = Reminders(store, FakeReminders());
      await reminders.initialize();
      final first = reminders.configure({'tasks': false});
      await started.future;
      final second = reminders.configure({'goals': false});
      gate.complete();
      await Future.wait([first, second]);
      expect(reminders.settings, containsPair('tasks', false));
      expect(reminders.settings, containsPair('goals', false));
      expect(jsonDecode(store.values[Reminders.key]!), reminders.settings);
      reminders.dispose();
    },
  );

  test(
    'switching off while permission is pending wins over late permission',
    () async {
      final port = _PermissionPrompt(), store = MemorySecrets();
      final reminders = Reminders(store, port);
      await reminders.initialize();
      final enable = reminders.configure({'enabled': true});
      final disable = reminders.configure({'enabled': false});
      port.answer.complete(true);
      await Future.wait([enable, disable]);
      expect(reminders.enabled, isFalse);
      expect(jsonDecode(store.values[Reminders.key]!)['enabled'], isFalse);
      reminders.dispose();
    },
  );

  test('a failed reminder write does not prevent the next change', () async {
    final store = MemorySecrets();
    final reminders = Reminders(store, FakeReminders());
    await reminders.initialize();
    store.broken = true;
    await expectLater(reminders.configure({'tasks': false}), throwsStateError);
    store.broken = false;
    await reminders.configure({'goals': false});
    expect(reminders.settings['tasks'], isNull);
    expect(reminders.settings['goals'], isFalse);
    reminders.dispose();
  });
}
