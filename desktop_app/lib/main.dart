import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'application/workspace_controller.dart';
import 'data/open_workspace.dart';
import 'data/demo_workspace.dart';
import 'domain/core.dart';
import 'ui/design.dart';
import 'ui/workspace.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1440, 900),
        minimumSize: Size(980, 650),
        center: true,
        title: 'FLEX Desktop',
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  final demo =
      Uri.base.queryParameters['demo'] == '1' ||
      const bool.fromEnvironment('FLEX_DESKTOP_DEMO');
  try {
    final repo = await openDesktopWorkspace(demo: demo);
    final notebook = NotebookController(repo);
    await notebook.initialize();
    final controller = WorkspaceController(notebook, demo: demo);
    if (demo) {
      var day = DateTime.now();
      while (day.weekday != DateTime.monday) {
        day = day.add(const Duration(days: 1));
      }
      await seedDemo(notebook, controller.files, day);
      final samples =
          notebook.classroom
              .where(
                (d) =>
                    !d.deleted &&
                    d.kind == ClassroomKind.lesson &&
                    d.text('date').isNotEmpty,
              )
              .map((d) => d.text('date'))
              .toList()
            ..sort();
      controller.date = samples.isEmpty ? day : schoolDay(samples.first);
    }
    if (Uri.base.queryParameters['ansicht'] == 'woche') {
      controller.navigate(WorkspaceSection.week);
    }
    runApp(DesktopApp(controller: controller));
  } catch (e) {
    runApp(
      MaterialApp(
        theme: desktopTheme(),
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FLEX Desktop',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Der Arbeitsplatz konnte nicht geöffnet werden.',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      e is DomainError
                          ? e.message
                          : 'Bitte die Anwendung erneut öffnen. Die vorhandenen Daten wurden nicht zurückgesetzt.',
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Falls der Fehler bleibt: Keine Browserdaten oder App-Dateien löschen.',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DesktopApp extends StatelessWidget {
  const DesktopApp({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FLEX Desktop',
    debugShowCheckedModeBanner: false,
    theme: desktopTheme(),
    locale: const Locale('de', 'AT'),
    supportedLocales: const [Locale('de', 'AT')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: DesktopWorkspace(controller: controller),
  );
}
