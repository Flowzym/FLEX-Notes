import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import 'notebook_screen.dart';
import 'surfaces.dart';
import 'app_scale.dart';

class FlexApp extends StatelessWidget {
  const FlexApp({super.key, required this.controller});
  final NotebookController controller;
  ThemeData _theme(Appearance appearance, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final palette = FlexPalette(appearance, brightness);
    final baseScheme = ColorScheme.fromSeed(
      seedColor: Color(appearance.accent),
      brightness: brightness,
    );
    final scheme = baseScheme.copyWith(
      primary: Color(appearance.accent),
      surface: palette.panel,
      onSurface: palette.modalInk,
      onPrimary: legibleOn(Color(appearance.accent)),
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
    final button = palette.button;
    final buttonText = palette.buttonInk;
    final card = palette.card;
    final base = ThemeData(colorScheme: scheme, fontFamily: 'FlexSans');
    final textTheme = base.textTheme.copyWith(
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: palette.fieldInk,
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
          palette: palette,
          header: palette.header,
          footer: palette.footer,
          foreground: legibleOn(
            Color.alphaBlend(palette.header, palette.modalPerceived),
          ),
        ),
      ],
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appearance.buttonRadius),
          ),
          backgroundColor: button,
          foregroundColor: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appearance.buttonRadius),
          ),
          backgroundColor: button,
          foregroundColor: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appearance.buttonRadius),
          ),
          backgroundColor: button,
          foregroundColor: buttonText,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: button,
        selectedColor: scheme.primary,
        labelStyle: TextStyle(
          fontFamily: 'FlexSans',
          fontSize: 13,
          height: 1.3,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? legibleOn(scheme.primary)
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(appearance.fieldRadius),
        ),
        filled: true,
        fillColor: palette.field,
        labelStyle: TextStyle(color: palette.fieldInk),
        hintStyle: TextStyle(color: palette.fieldInk),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appearance.cardRadius),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, child) => MaterialApp(
      title: 'FLEX-Notizbuch',
      debugShowCheckedModeBanner: false,
      themeAnimationDuration: Duration.zero,
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
      builder: (context, child) => FlexAppScale(
        scale: controller.appearance.uiScale,
        textScale: controller.appearance.textScale * .95,
        child: FlexBackground(appearance: controller.appearance, child: child!),
      ),
      home: NotebookScreen(controller: controller),
    ),
  );
}
