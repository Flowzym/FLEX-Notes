import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/models.dart';
import 'surfaces.dart';
part 'flex_date_picker.dart';

/// Shared shell for entry editors, secondary dialogs and confirmations.
class FlexModal extends StatelessWidget {
  const FlexModal({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.headerActions = const [],
    this.onClose,
    this.scrollable = true,
    this.maxWidth = 640,
    this.headerContent,
    this.footerContent,
    this.appearance,
    this.accentColor,
  });
  final Widget title, content;
  final Widget? headerContent, footerContent;
  final Appearance? appearance;
  final Color? accentColor;
  final List<Widget> actions, headerActions;
  final VoidCallback? onClose;
  final bool scrollable;
  final double maxWidth;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mobile = MediaQuery.sizeOf(context).width <= 700;
    final surfaces = Theme.of(context).extension<FlexSurfaces>();
    final appearance = this.appearance ?? surfaces?.appearance;
    final referenceStyle = appearance != null;
    final headerColor = surfaces?.header ?? scheme.surfaceContainerHigh;
    final footerColor = surfaces?.footer ?? scheme.surfaceContainerHigh;
    final palette = surfaces?.palette;
    final headerForeground = legibleOn(
      Color.alphaBlend(headerColor, palette?.modalPerceived ?? scheme.surface),
    );
    final footerForeground = legibleOn(
      Color.alphaBlend(footerColor, palette?.modalPerceived ?? scheme.surface),
    );
    final baseTheme = Theme.of(context);
    final referenceTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.copyWith(
        bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: baseTheme.textTheme.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            baseTheme.textButtonTheme.style?.copyWith(
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontFamily: 'FlexSans', fontSize: 15),
              ),
            ) ??
            TextButton.styleFrom(
              textStyle: const TextStyle(
                fontFamily: 'FlexSans',
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette?.button,
          foregroundColor: palette?.buttonInk,
          textStyle: const TextStyle(
            fontFamily: 'FlexSans',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ).merge(baseTheme.filledButtonTheme.style),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurface.withValues(alpha: .10),
        ),
        trackOutlineColor: WidgetStatePropertyAll(
          scheme.onSurface.withValues(alpha: .4),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: baseTheme.chipTheme.backgroundColor,
        labelStyle: TextStyle(
          fontFamily: 'FlexSans',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? legibleOn(scheme.primary)
                : palette?.buttonInk ?? scheme.onSurface,
          ),
        ),
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(appearance?.fieldRadius ?? 14),
          borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: .3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(appearance?.fieldRadius ?? 14),
          borderSide: BorderSide(color: scheme.primary),
        ),
        fillColor: baseTheme.inputDecorationTheme.fillColor,
      ),
    );
    final dialog = Dialog(
      insetPadding: EdgeInsets.all(mobile ? 10 : 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appearance?.modalRadius ?? 24),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Theme(
        data: referenceStyle ? referenceTheme : baseTheme,
        child: ConstrainedBox(
          key: const ValueKey('flex-modal-frame'),
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 440;
              final header = Container(
                key: const ValueKey('modal-header'),
                color: headerColor,
                foregroundDecoration: BoxDecoration(
                  border: accentColor == null
                      ? null
                      : Border(left: BorderSide(color: accentColor!, width: 4)),
                ),
                padding: EdgeInsets.fromLTRB(
                  mobile ? 12 : 20,
                  compact
                      ? 4
                      : mobile
                      ? 6
                      : 8,
                  mobile ? 8 : 14,
                  compact
                      ? 4
                      : mobile
                      ? 6
                      : 8,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: IconTheme.merge(
                    data: IconThemeData(color: headerForeground),
                    child:
                        (headerContent == null
                            ? null
                            : DefaultTextStyle.merge(
                                style: TextStyle(color: headerForeground),
                                child: headerContent!,
                              )) ??
                        Row(
                          children: [
                            Expanded(
                              child: DefaultTextStyle(
                                style: Theme.of(context).textTheme.titleLarge!
                                    .copyWith(
                                      color: headerForeground,
                                      fontFamily: 'FlexSerif',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                    ),
                                child: title,
                              ),
                            ),
                            ...headerActions,
                            if (onClose != null)
                              IconButton(
                                tooltip: 'Schließen und Eingaben sichern',
                                onPressed: onClose,
                                color: headerForeground,
                                icon: const Icon(Icons.close_rounded),
                              ),
                          ],
                        ),
                  ),
                ),
              );
              final footer = Container(
                key: const ValueKey('modal-footer'),
                width: double.infinity,
                color: footerColor,
                padding: EdgeInsets.symmetric(
                  horizontal: mobile ? 16 : 24,
                  vertical: compact
                      ? 8
                      : mobile
                      ? 7
                      : 8,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              appearance?.buttonRadius ?? 28,
                            ),
                          ),
                          backgroundColor: palette?.button,
                          foregroundColor:
                              palette?.buttonInk ?? footerForeground,
                          textStyle: referenceStyle
                              ? const TextStyle(
                                  fontFamily: 'FlexSans',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                )
                              : null,
                        ),
                      ),
                      outlinedButtonTheme: OutlinedButtonThemeData(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              appearance?.buttonRadius ?? 28,
                            ),
                          ),
                          backgroundColor: palette?.button,
                          foregroundColor:
                              palette?.buttonInk ?? footerForeground,
                          textStyle: referenceStyle
                              ? const TextStyle(
                                  fontFamily: 'FlexSans',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                )
                              : null,
                        ),
                      ),
                    ),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: footerForeground,
                        fontSize: 11,
                        height: 1.3,
                      ),
                      child:
                          footerContent ??
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: actions,
                          ),
                    ),
                  ),
                ),
              );
              final body = Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: mobile ? 16 : 24,
                  vertical: compact ? 10 : 16,
                ),
                child: content,
              );
              final Widget layout;
              // With large type or a keyboard the complete dialog must scroll;
              // fixed header/footer otherwise consume the available height.
              if (constraints.maxHeight < 520 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.5) {
                layout = SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [header, body, footer],
                  ),
                );
              } else {
                layout = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    header,
                    Flexible(
                      child: scrollable
                          ? SingleChildScrollView(child: body)
                          : body,
                    ),
                    if (actions.isNotEmpty || footerContent != null) footer,
                  ],
                );
              }
              final surface = ColoredBox(
                key: const ValueKey('modal-surface'),
                color: palette?.modal ?? scheme.surface,
                child: Material(type: MaterialType.transparency, child: layout),
              );
              return appearance == null
                  ? surface
                  : FlexBackground(appearance: appearance, child: surface);
            },
          ),
        ),
      ),
    );
    return referenceStyle
        ? BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: dialog,
          )
        : dialog;
  }
}

Future<bool> confirmFlex(
  BuildContext context,
  String title,
  String message, {
  String accept = 'Bestätigen',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => FlexModal(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(accept),
          ),
        ],
      ),
    ) ??
    false;

Future<(String, String)?> pickFlexDate(
  BuildContext context, {
  required String date,
  String time = '',
  bool allowTime = true,
  bool requireTime = false,
  String? title,
}) async {
  return showDialog<(String, String)>(
    context: context,
    builder: (_) => _FlexDatePicker(
      date: date,
      time: time,
      allowTime: allowTime,
      requireTime: requireTime,
      title: title ?? (allowTime ? 'Datum & Uhrzeit' : 'Datum wählen'),
    ),
  );
}
