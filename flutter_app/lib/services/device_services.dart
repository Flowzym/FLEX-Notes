import 'dart:async';
import 'dart:ui';
import 'package:flex_device/flex_device.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:workmanager/workmanager.dart';
import '../data/open_notebook.dart';
import '../domain/repository.dart';
import '../platform/backup_mutex.dart';
import 'app_lock.dart';
import 'automatic_backup.dart';
import 'reminders.dart';
import 'secret_store.dart';

const backupTask = 'flex.encrypted-backup.v1';
Future<void> scheduleBackup(int? hours) async {
  if (hours == null) {
    await Workmanager().cancelByUniqueName(backupTask);
    return;
  }
  await Workmanager().registerPeriodicTask(
    backupTask,
    backupTask,
    frequency: Duration(hours: hours),
    initialDelay: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    constraints: Constraints(
      requiresBatteryNotLow: true,
      requiresStorageNotLow: true,
    ),
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(minutes: 15),
  );
}

AutomaticBackup makeBackup(NotebookRepository repository) => AutomaticBackup(
  store: DeviceSecretStore(),
  files: const DeviceBackupFiles(),
  export: repository.exportBackup,
  schedule: scheduleBackup,
  withLock: backupMutex,
);

@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    if (task != backupTask) return true;
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    NotebookRepository? repository;
    AutomaticBackup? backup;
    try {
      repository = await openNotebook();
      await repository.initialize();
      backup = makeBackup(repository);
      await backup.run();
      return true;
    } catch (_) {
      return false;
    } finally {
      backup?.dispose();
      await repository?.close();
    }
  });
}

class DeviceServices {
  DeviceServices({
    required this.lock,
    required this.backup,
    required this.reminders,
  });
  final AppLock lock;
  final AutomaticBackup backup;
  final Reminders reminders;
  Timer? _backupTimer;
  NotebookSnapshot? _snapshot;
  static Future<DeviceServices> create(NotebookRepository repository) async {
    final auth = LocalAuthentication();
    final lock = AppLock(
      DeviceSecretStore(),
      authenticate: () => auth.authenticate(
        localizedReason: 'FLEX entsperren',
        biometricOnly: true,
      ),
      protectScreen: const FlexDevice().protectScreen,
    );
    await lock.load(); // A storage error must leave the application locked.
    final backup = makeBackup(repository);
    try {
      await Workmanager().initialize(backgroundDispatcher);
      await backup.load();
      if (backup.enabled) await scheduleBackup(backup.intervalHours);
    } catch (_) {
      backup.error =
          'Automatische Sicherung nicht verfügbar. Bitte in den Einstellungen erneut einrichten.';
    }
    final reminders = Reminders(DeviceSecretStore(), AndroidReminderPort());
    try {
      await reminders.initialize();
    } catch (_) {
      reminders.error = 'Android-Erinnerungen konnten nicht geladen werden.';
    }
    return DeviceServices(lock: lock, backup: backup, reminders: reminders);
  }

  void updated(NotebookSnapshot data) {
    _snapshot = data;
    unawaited(reminders.sync(data));
    // Coalesce writes without postponing a due backup indefinitely.
    _backupTimer ??= Timer(const Duration(seconds: 15), () {
      _backupTimer = null;
      unawaited(backup.run().catchError((Object _) {}));
    });
  }

  void resume() {
    unawaited(backup.load().catchError((Object _) {}));
    if (_snapshot != null) updated(_snapshot!);
  }

  void dispose() {
    _backupTimer?.cancel();
    // Services live for the app process; outstanding platform operations may finish.
  }
}
