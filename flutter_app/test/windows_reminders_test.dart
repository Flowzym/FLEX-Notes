import 'package:flex_notizbuch/domain/reminder_action.dart';
import 'package:flex_notizbuch/services/reminders.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

class _Notifications extends Fake implements FlutterLocalNotificationsPlugin {
  final pending = <int>{19}, cancelled = <int>[], sent = <ReminderAction>[];
  List<WindowsAction> buttons = [];
  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => [
    for (final id in pending) PendingNotificationRequest(id, null, null, null),
  ];
  @override
  Future<void> cancel({required int id, String? tag}) async {
    pending.remove(id);
    cancelled.add(id);
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    expect(title, 'FLEX · Aufgabe');
    expect(body, 'FLEX öffnen, um den Eintrag anzusehen.');
    expect(pending.add(id), isTrue);
    sent.add(ReminderAction.parse(payload!)!);
    buttons = notificationDetails.windows!.actions;
  }
}

void main() {
  test(
    'Windows gleicht die Systemwarteschlange ab und behält den geprüften Eintrag für beide Aktionen',
    () async {
      final notifications = _Notifications(),
          date = DateTime.utc(2027, 5, 7, 10);
      final port = WindowsReminderPort(notifications: notifications);
      ReminderRequest request(DateTime when, int revision) => ReminderRequest(
        id: 8,
        target: 'orga:example',
        when: when,
        label: 'Aufgabe',
        revision: revision,
        completable: true,
      );
      await port.apply([request(date, 1)], exact: true);
      expect(notifications.cancelled, [19]);
      await port.apply([request(date, 1)], exact: true);
      expect(notifications.sent, hasLength(1));
      await port.apply([
        request(date.add(const Duration(hours: 1)), 2),
      ], exact: true);
      expect(notifications.cancelled, [19, 8]);
      expect(notifications.sent.last.revision, 2);
      final actions = notifications.buttons
          .map((b) => ReminderAction.parse(b.arguments)!)
          .toList();
      expect(actions.map((a) => a.action), ['done', 'snooze']);
      expect(
        actions.every((a) => a.target == 'orga:example' && a.revision == 2),
        isTrue,
      );
      await port.apply([], exact: true);
      expect(notifications.pending, isEmpty);
    },
  );
}
