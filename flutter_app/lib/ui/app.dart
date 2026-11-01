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
      onPrimary: dark
          ? legibleOn(Color(appearance.accent))
          : baseScheme.onPrimary,
      surfaceContainerHigh: dark
          ? const Color(0xff35432e)
          : baseScheme.surfaceContainerHigh,
      outlineVariant: dark
          ? const Color(0x24e9efcf)
          : baseScheme.outlineVariant,
      outline: dark ? const Color(0x45dbe6bf) : baseScheme.outline,
      onSurfaceVariant: dark
          ? const Color(0xffc2cbb6)
          : baseScheme.onSurfaceVariant,
    );
    final bar = appearance.dialogColor == 0
        ? dark
              ? const Color(0xff2a3926)
              : scheme.surfaceContainerHigh
        : Color(appearance.dialogColor);
    final button =
        (appearance.buttonColor == 0
                ? dark
                      ? const Color(0xfff9f8ef)
                      : scheme.primary
                : Color(appearance.buttonColor))
            .withValues(alpha: appearance.buttonOpacity);
    final buttonText = legibleOn(Color.alphaBlend(button, scheme.surface));
    final card = appearance.cardColor == 0
        ? (dark ? const Color(0xfff2f7d5) : const Color(0xff253222)).withValues(
            alpha: .07 * appearance.cardOpacity,
          )
        : Color(appearance.cardColor).withValues(alpha: appearance.cardOpacity);
    final base = ThemeData(colorScheme: scheme, fontFamily: 'FlexSans');
    final textTheme = base.textTheme.copyWith(
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontSize: 14,
        height: 1.5,
        letterSpacing: 0,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.5,
        letterSpacing: 0,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.4,
        letterSpacing: 0,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 18,
        height: 1.3,
        letterSpacing: 0,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 24,
        height: 1.3,
        letterSpacing: 0,
      ),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      extensions: [
        FlexSurfaces(
          appearance: appearance,
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
          fontSize: 13,
          height: 1.3,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? legibleOn(scheme.primary)
                : appearance.buttonColor == 0
                ? scheme.onSurface
                : buttonText,
          ),
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: 'FlexSans',
          color: legibleOn(scheme.primary),
        ),
      ),
      textTheme: appearance.serifHeaders
          ? textTheme.copyWith(
              titleLarge: textTheme.titleLarge?.copyWith(
                fontFamily: 'FlexSerif',
              ),
              headlineSmall: textTheme.headlineSmall?.copyWith(
                fontFamily: 'FlexSerif',
              ),
              headlineMedium: base.textTheme.headlineMedium?.copyWith(
                fontFamily: 'FlexSerif',
              ),
            )
          : textTheme,
      fontFamily: 'FlexSans',
      visualDensity: appearance.compact
          ? VisualDensity.compact
          : VisualDensity.standard,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: dark ? const Color(0x0bffffff) : const Color(0x08ffffff),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
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
