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

  static List<BoxShadow> shadows(BuildContext context) => [
    BoxShadow(
      color: Theme.of(context).colorScheme.shadow.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? .18 : .065,
      ),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
    BoxShadow(
      color: Theme.of(context).colorScheme.shadow.withValues(alpha: .035),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static LinearGradient wash(Color color) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.lerp(color, Colors.white, .07)!, color],
  );

  static BoxDecoration capsule(BuildContext context) => BoxDecoration(
    gradient: wash(Theme.of(context).colorScheme.surface),
    border: Border.all(
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .7),
      width: .7,
    ),
    borderRadius: BorderRadius.circular(28),
    boxShadow: shadows(context),
  );
}

/// Raised, quiet icon controls for page headings and date navigation.
class FlexCircleButton extends StatelessWidget {
  const FlexCircleButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: FlexDesign.capsule(context),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(shape: const CircleBorder()),
      icon: icon,
    ),
  );
}

class FlexPalette {
  const FlexPalette(this.brightness);
  final Brightness brightness;
  bool get dark => brightness == Brightness.dark;
  Color get backdrop =>
      dark ? const Color(0xff20231f) : const Color(0xfff8f4ef);
  Color get panel => dark ? const Color(0xff282c26) : const Color(0xfffcf9f5);
  Color get primary => dark ? const Color(0xffb6c29c) : const Color(0xff606d48);
  Color get selection =>
      dark ? const Color(0xff4a563c) : const Color(0xffb2b89b);
  Color get line => dark ? const Color(0xff44493d) : const Color(0xffdedbd2);
  Color get ink => dark ? const Color(0xfff1eee6) : const Color(0xff292c27);
  Color get secondaryInk =>
      dark ? const Color(0xffc4c9bb) : const Color(0xff606655);
  Color get card => panel;
  Color get button => dark ? const Color(0xff343a2f) : const Color(0xfff8f5ef);
  Color get field => dark ? const Color(0xff252923) : const Color(0xfffdfbf7);
}

class FlexSurfaces extends ThemeExtension<FlexSurfaces> {
  const FlexSurfaces({required this.appearance, required this.palette});
  final Appearance appearance;
  final FlexPalette palette;
  @override
  FlexSurfaces copyWith({Appearance? appearance, FlexPalette? palette}) =>
      FlexSurfaces(
        appearance: appearance ?? this.appearance,
        palette: palette ?? this.palette,
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
  Widget build(BuildContext context) =>
      Card(child: builder == null ? child! : Builder(builder: builder!));
}

class FlexBackground extends StatelessWidget {
  const FlexBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final p = FlexPalette(Theme.of(context).brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-.85, -.7),
          radius: 1.5,
          colors: [p.panel, p.backdrop],
        ),
      ),
      child: child,
    );
  }
}
