import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../domain/models.dart';
import '../domain/repository.dart';
import '../domain/school.dart';
import 'secret_store.dart';

class ReminderRequest {
  const ReminderRequest({
    required this.id,
    required this.target,
    required this.when,
    required this.label,
  });
  final int id;
  final String target, label;
  final DateTime when;
  String get fingerprint =>
      '$id|$target|${when.toUtc().toIso8601String()}|$label';
}

List<ReminderRequest> planReminders(
  NotebookSnapshot data,
  Map<String, dynamic> settings,
  DateTime now,
) {
  final active = data.pupils.where((p) => !p.archived).map((p) => p.id).toSet();
  final hour = (settings['hour'] as int? ?? 9).clamp(0, 23);
  final minute = (settings['minute'] as int? ?? 0).clamp(0, 59);
  final candidates = <({String target, DateTime when, String label})>[];
  DateTime date(String value, [String? time]) => DateTime.parse(
    '${value}T${time == null || time.isEmpty ? '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}' : time}:00',
  );
  for (final entry in data.entries.where(
    (e) => !e.deleted && (e.pupilId == null || active.contains(e.pupilId)),
  )) {
    if (entry.isTask && entry.done ||
        entry.reminderState == ReminderState.cancelled ||
        entry.reminderState == ReminderState.acknowledged) {
      continue;
    }
    DateTime? when;
    String label = 'Erinnerung';
    if (entry.reminderState == ReminderState.planned &&
        entry.reminderAtUtc != null) {
      when = DateTime.parse(entry.reminderAtUtc!);
    } else if (entry.isAppointment && settings['appointments'] != false) {
      when = date(entry.appointmentDate!, entry.appointmentTime);
      label = 'Termin';
    } else if (entry.isTask &&
        !entry.done &&
        entry.dueDate != null &&
        settings['tasks'] != false) {
      when = date(entry.dueDate!);
      label = 'Aufgabe';
    }
    if (when != null && when.isAfter(now)) {
      candidates.add((target: 'orga:${entry.id}', when: when, label: label));
    }
  }
  for (final record in data.records.where(
    (r) => !r.deleted && active.contains(r.pupilId),
  )) {
    String? due;
    String label = 'Hausübung';
    if (record.kind == SchoolKind.goal &&
        record.goalStatus == 'active' &&
        settings['goals'] != false) {
      due = record.nextReviewDate;
      label = 'Ziel überprüfen';
    } else if (record.kind == SchoolKind.homework &&
        record.pending &&
        settings['tasks'] != false) {
      due = record.dueDate;
    }
    if (due != null && date(due).isAfter(now)) {
      candidates.add((
        target: 'school:${record.id}',
        when: date(due),
        label: label,
      ));
    }
  }
  candidates.sort((a, b) => a.target.compareTo(b.target));
  final used = <int>{};
  return candidates.map((item) {
    var id = 0x811c9dc5;
    for (final byte in utf8.encode(item.target)) {
      id = ((id ^ byte) * 0x01000193) & 0x7fffffff;
    }
    while (!used.add(id)) {
      id = (id + 1) & 0x7fffffff;
    }
    return ReminderRequest(
      id: id,
      target: item.target,
      when: item.when,
      label: item.label,
    );
  }).toList();
}

abstract interface class ReminderPort {
  Future<String?> initialize(ValueChanged<String> onTap);
  Future<bool> permission({bool request = false});
  Future<bool> exactPermission({bool request = false});
  Future<void> apply(List<ReminderRequest> requests, {required bool exact});
}

class AndroidReminderPort implements ReminderPort {
  final plugin = FlutterLocalNotificationsPlugin();
  AndroidFlutterLocalNotificationsPlugin get android => plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()!;
  @override
  Future<String?> initialize(ValueChanged<String> onTap) async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) onTap(response.payload!);
      },
    );
    final launch = await plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true
        ? launch?.notificationResponse?.payload
        : null;
  }

  @override
  Future<bool> permission({bool request = false}) async =>
      (request
          ? await android.requestNotificationsPermission()
          : await android.areNotificationsEnabled()) ==
      true;
  @override
  Future<bool> exactPermission({bool request = false}) async =>
      (request
          ? await android.requestExactAlarmsPermission()
          : await android.canScheduleExactNotifications()) ==
      true;
  @override
  Future<void> apply(
    List<ReminderRequest> requests, {
    required bool exact,
  }) async {
    final wanted = requests.map((r) => r.id).toSet();
    for (final existing in await plugin.pendingNotificationRequests()) {
      if (!wanted.contains(existing.id)) await plugin.cancel(id: existing.id);
    }
    for (final delivered in await plugin.getActiveNotifications()) {
      if (delivered.id != null && !wanted.contains(delivered.id)) {
        await plugin.cancel(id: delivered.id!);
      }
    }
    for (final request in requests) {
      await plugin.zonedSchedule(
        id: request.id,
        scheduledDate: tz.TZDateTime.from(request.when, tz.UTC),
        title: 'FLEX · ${request.label}',
        body: 'FLEX öffnen, um den Eintrag anzusehen.',
        payload: request.target,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'flex_reminders',
            'FLEX-Erinnerungen',
            channelDescription: 'Termine, Aufgaben und Zielüberprüfungen',
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.private,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
      );
    }
  }
}

class Reminders extends ChangeNotifier {
  Reminders(this.store, this.port, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final SecretStore store;
  final ReminderPort port;
  final DateTime Function() now;
  static const key = 'flex.reminders.v1';
  Map<String, dynamic> settings = {};
  String? pendingTarget, error, _applied;
  bool permitted = false, exact = false;
  bool get enabled => settings['enabled'] == true;
  int count = 0;
  NotebookSnapshot? _snapshot;
  Future<void> _pending = Future.value();
  Future<void> initialize() async {
    final raw = await store.read(key);
    settings = raw == null
        ? {}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    pendingTarget = await port.initialize((value) {
      pendingTarget = value;
      notifyListeners();
    });
    permitted = await port.permission();
    exact = await port.exactPermission();
    notifyListeners();
  }

  Future<void> configure(Map<String, dynamic> changes) async {
    if (changes['enabled'] == true && !await port.permission(request: true)) {
      throw const DomainError('Android hat Benachrichtigungen nicht erlaubt.');
    }
    final value = {...settings, ...changes};
    await store.write(key, jsonEncode(value));
    settings = value;
    _applied = null;
    if (_snapshot != null) await sync(_snapshot!);
    notifyListeners();
  }

  Future<void> requestExact() async {
    await port.exactPermission(request: true);
    _applied = null;
    if (_snapshot != null) await sync(_snapshot!);
  }

  Future<void> sync(NotebookSnapshot snapshot) {
    _snapshot = snapshot;
    _pending = _pending.catchError((Object _) {}).then((_) async {
      try {
        permitted = await port.permission();
        exact = await port.exactPermission();
        final plan = enabled && permitted
            ? planReminders(_snapshot!, settings, now())
            : <ReminderRequest>[];
        final stamp = '$exact|${plan.map((r) => r.fingerprint).join('\n')}';
        if (stamp != _applied) {
          await port.apply(plan, exact: exact);
          _applied = stamp;
        }
        count = plan.length;
        error = enabled && !permitted
            ? 'Benachrichtigungen sind in Android ausgeschaltet.'
            : null;
      } catch (_) {
        error =
            'Erinnerungen konnten nicht aktualisiert werden. Bitte Android-Berechtigungen prüfen.';
      }
      notifyListeners();
    });
    return _pending;
  }

  void consumeTarget() {
    pendingTarget = null;
  }
}
