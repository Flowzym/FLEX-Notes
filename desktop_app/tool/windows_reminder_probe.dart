import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flex_notizbuch/services/reminders.dart';

/// Run as a separate CI executable, after the production packages are sealed.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isWindows ||
      Platform.environment['FLEX_REMINDER_PROBE'] != '1') {
    exit(2);
  }
  final port = WindowsReminderPort(
    appId: 'at.flowzym.FLEXDesktop.BuildCheck',
    guid: '88ba53ab-2b09-4590-9fb1-a8b8e6f645b9',
  );
  const id = 82743;
  try {
    await port.initialize((_) {});
    if (args.single == 'plan') {
      await port.apply([
        ReminderRequest(
          id: id,
          target: 'orga:ci-check',
          when: DateTime.now().add(const Duration(minutes: 20)),
          label: 'Aufgabe',
        ),
      ], exact: true);
    } else if (args.single != 'inspect') {
      exit(2);
    }
    if (!(await port.scheduledIds()).contains(id)) exit(3);
    if (args.single == 'inspect') {
      await port.apply([], exact: true);
      if ((await port.scheduledIds()).contains(id)) exit(4);
    }
    exit(0);
  } catch (e) {
    stderr.writeln(e.runtimeType);
    exit(1);
  }
}
