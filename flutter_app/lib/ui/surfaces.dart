import 'package:flutter/material.dart';
import '../domain/models.dart';

Color legibleOn(Color background) {
  final luminance = background.computeLuminance();
  return (1.05 / (luminance + .05)) > ((luminance + .05) / .05)
      ? Colors.white
      : Colors.black;
}

/// Fixed tokens shared by every page, editor, sheet and preview.
class FlexDesign {
  static const fieldRadius = 14.0;
  static const buttonRadius = 24.0;
  static const modalRadius = 24.0;
  static const cardRadius = 16.0;
}

class FlexPalette {
  FlexPalette(this.appearance, this.brightness);
  final Appearance appearance;
  final Brightness brightness;
  bool get dark => brightness == Brightness.dark;
  Color get backdrop =>
      dark ? const Color(0xff20231f) : const Color(0xfff8f5f0);
  Color get panel => dark ? const Color(0xff282c26) : const Color(0xfffcfaf6);
  Color get primary => dark ? const Color(0xffb6c29c) : const Color(0xff606d48);
  Color get selection =>
      dark ? const Color(0xff4a563c) : const Color(0xffb2b99e);
  Color get line => dark ? const Color(0xff44493d) : const Color(0xffdedbd2);
  Color get ink => dark ? const Color(0xfff1eee6) : const Color(0xff292c27);
  Color get secondaryInk =>
      dark ? const Color(0xffc4c9bb) : const Color(0xff606655);
  Color get workspace => panel;
  Color get card => panel;
  Color get modal => backdrop;
  Color get modalPerceived => modal;
  Color get header => backdrop;
  Color get footer => backdrop;
  Color get button => dark ? const Color(0xff343a2f) : const Color(0xffeeeee5);
  Color get field => dark ? const Color(0xff252923) : const Color(0xfffdfbf7);
  Color get buttonInk => ink;
  Color get fieldInk => ink;
  Color get modalInk => ink;
  Color get cardInk => ink;
  Color get workspaceInk => ink;
}

class FlexSurfaces extends ThemeExtension<FlexSurfaces> {
  const FlexSurfaces({
    required this.header,
    required this.footer,
    required this.foreground,
    this.appearance,
    this.palette,
  });
  final Color header, footer, foreground;
  final Appearance? appearance;
  final FlexPalette? palette;
  @override
  FlexSurfaces copyWith({Color? header, Color? footer, Color? foreground}) =>
      FlexSurfaces(
        header: header ?? this.header,
        footer: footer ?? this.footer,
        foreground: foreground ?? this.foreground,
        appearance: appearance,
        palette: palette,
      );
  @override
  FlexSurfaces lerp(covariant FlexSurfaces? other, double t) => other ?? this;
}

// RawChip's Material defaults to canvasColor, which otherwise paints an opaque
// green layer below translucent chip colors. Scope this override to chips only.
Widget transparentChip(Widget chip) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
    child: chip,
  ),
);

class FlexCard extends StatelessWidget {
  const FlexCard({super.key, this.child, this.builder})
    : assert(child != null || builder != null);
  final Widget? child;
  final WidgetBuilder? builder;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground =
        theme.extension<FlexSurfaces>()?.palette?.cardInk ??
        theme.colorScheme.onSurface;
    return Card(
      child: Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            onSurface: foreground,
            onSurfaceVariant: foreground,
          ),
          textTheme: theme.textTheme.apply(
            bodyColor: foreground,
            displayColor: foreground,
          ),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: IconTheme.merge(
            data: IconThemeData(color: foreground),
            child: builder == null ? child! : Builder(builder: builder!),
          ),
        ),
      ),
    );
  }
}

class FlexBackground extends StatelessWidget {
  const FlexBackground({
    super.key,
    required this.appearance,
    required this.child,
  });
  final Appearance appearance;
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: FlexPalette(appearance, Theme.of(context).brightness).backdrop,
    child: child,
  );
}
