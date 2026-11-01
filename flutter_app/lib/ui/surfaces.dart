import 'dart:convert';
import 'package:flutter/material.dart';
import '../domain/models.dart';

Color legibleOn(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : const Color(0xff172016);

class FlexSurfaces extends ThemeExtension<FlexSurfaces> {
  const FlexSurfaces({
    required this.header,
    required this.footer,
    required this.foreground,
  });
  final Color header, footer, foreground;
  @override
  FlexSurfaces copyWith({Color? header, Color? footer, Color? foreground}) =>
      FlexSurfaces(
        header: header ?? this.header,
        footer: footer ?? this.footer,
        foreground: foreground ?? this.foreground,
      );
  @override
  FlexSurfaces lerp(covariant FlexSurfaces? other, double t) => other == null
      ? this
      : FlexSurfaces(
          header: Color.lerp(header, other.header, t)!,
          footer: Color.lerp(footer, other.footer, t)!,
          foreground: Color.lerp(foreground, other.foreground, t)!,
        );
}

BoxFit backgroundFit(String value) => switch (value) {
  'contain' => BoxFit.contain,
  'fitWidth' => BoxFit.fitWidth,
  'fitHeight' => BoxFit.fitHeight,
  'fill' => BoxFit.fill,
  _ => BoxFit.cover,
};

class FlexCard extends StatelessWidget {
  const FlexCard({super.key, this.child, this.builder})
    : assert(child != null || builder != null);
  final Widget? child;
  final WidgetBuilder? builder;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paint =
        theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow;
    final foreground = legibleOn(
      Color.alphaBlend(paint, theme.colorScheme.surface),
    );
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
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 650;
    final image = mobile ? appearance.mobileImage : appearance.desktopImage;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: Theme.of(context).brightness == Brightness.dark
              ? const [Color(0xff1d2b21), Color(0xff4f6038), Color(0xff253522)]
              : const [Color(0xfff7f8f0), Color(0xffeef1e6), Color(0xffe3e9d8)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image.isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: appearance.backgroundOpacity,
                child: Image.memory(
                  base64Decode(image),
                  fit: backgroundFit(
                    mobile ? appearance.mobileFit : appearance.desktopFit,
                  ),
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
