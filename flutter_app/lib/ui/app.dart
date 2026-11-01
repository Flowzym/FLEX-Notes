import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import 'notebook_screen.dart';
import 'surfaces.dart';

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
    final bar = appearance.dialogColor == 0
        ? scheme.surfaceContainerHigh
        : Color(appearance.dialogColor);
    final button =
        (appearance.buttonColor == 0
                ? scheme.primary
                : Color(appearance.buttonColor))
            .withValues(alpha: appearance.buttonOpacity);
    final buttonText = legibleOn(Color.alphaBlend(button, scheme.surface));
    final card =
        (appearance.cardColor == 0
                ? scheme.surfaceContainerLow
                : Color(appearance.cardColor))
            .withValues(alpha: appearance.cardOpacity);
    final base = ThemeData(colorScheme: scheme, fontFamily: 'FlexSans');
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          appearance.desktopImage.isNotEmpty ||
              appearance.mobileImage.isNotEmpty
          ? Colors.transparent
          : dark
          ? const Color(0xff253222)
          : const Color(0xffeef1e6),
      extensions: [
        FlexSurfaces(
          header: bar.withValues(alpha: appearance.headerOpacity),
          footer: bar.withValues(alpha: appearance.footerOpacity),
          foreground: legibleOn(bar),
        ),
      ],
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: button,
          foregroundColor: buttonText,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: button.withValues(
          alpha: appearance.buttonColor == 0 ? 0.12 : appearance.buttonOpacity,
        ),
        selectedColor: scheme.primary,
        labelStyle: TextStyle(
          fontFamily: 'FlexSans',
          color: appearance.buttonColor == 0 ? scheme.onSurface : buttonText,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: 'FlexSans',
          color: legibleOn(scheme.primary),
        ),
      ),
      textTheme: appearance.serifHeaders
          ? base.textTheme.copyWith(
              titleLarge: base.textTheme.titleLarge?.copyWith(
                fontFamily: 'FlexSerif',
              ),
              headlineSmall: base.textTheme.headlineSmall?.copyWith(
                fontFamily: 'FlexSerif',
              ),
              headlineMedium: base.textTheme.headlineMedium?.copyWith(
                fontFamily: 'FlexSerif',
              ),
            )
          : base.textTheme,
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
        color: card,
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
        child: FlexBackground(appearance: controller.appearance, child: child!),
      ),
      home: NotebookScreen(controller: controller),
    ),
  );
}
