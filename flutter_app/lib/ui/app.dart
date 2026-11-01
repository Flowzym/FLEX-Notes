import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import 'notebook_screen.dart';

class FlexApp extends StatelessWidget {
  const FlexApp({super.key, required this.controller});
  final NotebookController controller;
  ThemeData _theme(Appearance appearance, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: Color(appearance.accent),
      brightness: brightness,
    );
    final scheme = baseScheme.copyWith(
      primary: dark ? Color(appearance.accent) : baseScheme.primary,
      surface: dark ? const Color(0xff303e2b) : const Color(0xfff7f8f0),
      onSurface: dark ? const Color(0xfff6f5eb) : const Color(0xff23311e),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xff253222)
          : const Color(0xffeef1e6),
      fontFamily: 'FlexSans',
      visualDensity: appearance.compact
          ? VisualDensity.compact
          : VisualDensity.standard,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, child) => MaterialApp(
      title: 'FLEX-Notizbuch',
      debugShowCheckedModeBanner: false,
      locale: const Locale('de', 'AT'),
      supportedLocales: const [Locale('de', 'AT'), Locale('de'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: _theme(controller.appearance, Brightness.light),
      darkTheme: _theme(controller.appearance, Brightness.dark),
      themeMode: switch (controller.appearance.mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            MediaQuery.textScalerOf(context).scale(1) *
                controller.appearance.textScale,
          ),
        ),
        child: child!,
      ),
      home: NotebookScreen(controller: controller),
    ),
  );
}
