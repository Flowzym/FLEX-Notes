import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import 'notebook_screen.dart';
import 'surfaces.dart';
import 'app_scale.dart';
import 'common.dart';
import 'app_guard.dart';

class FlexApp extends StatelessWidget {
  const FlexApp({super.key, required this.controller});
  final NotebookController controller;
  ThemeData _theme(Appearance appearance, Brightness brightness) {
    final p = FlexPalette(appearance, brightness);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: p.primary,
          brightness: brightness,
        ).copyWith(
          primary: p.primary,
          onPrimary: legibleOn(p.primary),
          primaryContainer: p.selection,
          onPrimaryContainer: p.ink,
          secondary: p.primary,
          onSecondary: legibleOn(p.primary),
          secondaryContainer: p.button,
          onSecondaryContainer: p.ink,
          surface: p.panel,
          onSurface: p.ink,
          onSurfaceVariant: p.secondaryInk,
          surfaceContainerLowest: p.backdrop,
          surfaceContainerLow: p.field,
          surfaceContainer: p.panel,
          surfaceContainerHigh: p.button,
          surfaceContainerHighest: p.button,
          outline: p.secondaryInk.withValues(alpha: .45),
          outlineVariant: p.line,
        );
    final base = ThemeData(colorScheme: scheme, fontFamily: 'FlexSans');
    final textTheme = base.textTheme
        .copyWith(
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontSize: 15,
            height: 1.4,
            letterSpacing: 0,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.4,
            letterSpacing: 0,
          ),
          bodySmall: base.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            height: 1.35,
            letterSpacing: 0,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            height: 1.25,
            fontWeight: FontWeight.w600,
            letterSpacing: -.3,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontSize: 25,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
          ),
        )
        .apply(bodyColor: p.ink, displayColor: p.ink);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FlexDesign.buttonRadius),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(FlexDesign.fieldRadius),
      borderSide: BorderSide(color: p.line),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'FlexSans',
      textTheme: textTheme,
      iconTheme: IconThemeData(color: p.primary, size: 24),
      colorScheme: scheme,
      scaffoldBackgroundColor: p.backdrop,
      canvasColor: p.panel,
      dividerTheme: DividerThemeData(color: p.line, thickness: .8, space: 24),
      extensions: [
        FlexSurfaces(
          appearance: appearance,
          palette: p,
          header: p.header,
          footer: p.footer,
          foreground: p.ink,
        ),
      ],
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          alignment: Alignment.center,
          foregroundBuilder: centeredButtonLabel,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: shape,
          backgroundColor: p.primary,
          foregroundColor: scheme.onPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          alignment: Alignment.center,
          foregroundBuilder: centeredButtonLabel,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: shape,
          backgroundColor: Colors.transparent,
          foregroundColor: p.primary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          alignment: Alignment.center,
          foregroundBuilder: centeredButtonLabel,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: shape,
          side: BorderSide(color: p.line),
          backgroundColor: p.panel,
          foregroundColor: p.ink,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size(44, 44),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: p.line),
        backgroundColor: p.button,
        selectedColor: p.selection,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        labelStyle: TextStyle(
          fontFamily: 'FlexSans',
          fontSize: 12,
          height: 1.3,
          color: p.ink,
        ),
        secondaryLabelStyle: TextStyle(fontFamily: 'FlexSans', color: p.ink),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.onPrimary : p.panel,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : p.line,
        ),
        trackOutlineColor: WidgetStatePropertyAll(p.line),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        filled: true,
        fillColor: p.field,
        labelStyle: TextStyle(color: p.secondaryInk),
        hintStyle: TextStyle(color: p.secondaryInk),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: p.backdrop,
        foregroundColor: p.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.backdrop,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlexDesign.modalRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.backdrop,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlexDesign.cardRadius),
          side: BorderSide(color: p.line, width: .7),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, child) => MaterialApp(
      title: 'FLEX-Notizbuch',
      navigatorObservers: [
        if (controller.services != null)
          navigationLock(controller.services!.lock),
      ],
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
        textScale: controller.appearance.textScale,
        child: FlexBackground(
          appearance: controller.appearance,
          child: controller.services == null
              ? child!
              : AppGuard(
                  lock: controller.services!.lock,
                  onResume: controller.services!.resume,
                  child: child!,
                ),
        ),
      ),
      home: NotebookScreen(controller: controller),
    ),
  );
}
