import 'dart:convert';
import 'package:flutter/material.dart';
import '../domain/models.dart';

Color legibleOn(Color background) {
  final luminance = background.computeLuminance();
  return (1.05 / (luminance + .05)) > ((luminance + .05) / .05)
      ? Colors.white
      : Colors.black;
}

/// Shared by the app, every modal and the settings preview. Alpha only affects paint.
class FlexPalette {
  FlexPalette(this.appearance, this.brightness);
  final Appearance appearance;
  final Brightness brightness;
  bool get protected =>
      appearance.imageActive && appearance.readabilityProtection;
  Color get backdrop => appearance.imageActive
      ? appearance.defaultTexture && !appearance.hasImage
            ? const Color(0xff17191c)
            : Color.alphaBlend(
                Colors.black.withValues(alpha: appearance.backgroundDim),
                Color(appearance.backgroundTint),
              )
      : Color(appearance.backgroundColor);
  Color get panel => Color.lerp(
    Color(appearance.backgroundColor),
    brightness == Brightness.dark ? Colors.black : Colors.white,
    .16,
  )!;
  Color base(int value) => value == 0 ? panel : Color(value);
  Color paint(int value, double opacity, {bool reading = false}) =>
      base(value).withValues(alpha: protected && reading ? 1 : opacity);
  Color get workspace => paint(
    appearance.workspaceColor,
    appearance.workspaceOpacity,
    reading: true,
  );
  Color get card =>
      paint(appearance.cardColor, appearance.cardOpacity, reading: true);
  Color get modal =>
      paint(appearance.modalColor, appearance.modalOpacity, reading: true);
  Color get modalPerceived => Color.alphaBlend(modal, backdrop);
  Color get header =>
      paint(appearance.dialogColor, appearance.headerOpacity, reading: true);
  Color get footer =>
      paint(appearance.dialogColor, appearance.footerOpacity, reading: true);
  Color get button => paint(appearance.buttonColor, appearance.buttonOpacity);
  Color get field => paint(appearance.fieldColor, appearance.fieldOpacity);
  Color get buttonInk => legibleOn(Color.alphaBlend(button, modalPerceived));
  Color get fieldInk => legibleOn(Color.alphaBlend(field, modalPerceived));
  Color get modalInk => legibleOn(modalPerceived);
  Color get cardInk => legibleOn(Color.alphaBlend(card, backdrop));
  Color get workspaceInk => legibleOn(Color.alphaBlend(workspace, backdrop));
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

BoxFit backgroundFit(String value) => switch (value) {
  'contain' => BoxFit.contain,
  'fitWidth' => BoxFit.fitWidth,
  'fitHeight' => BoxFit.fitHeight,
  'fill' => BoxFit.fill,
  'none' || 'tile' => BoxFit.none,
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

// Retain only the two selected image providers; unrelated sliders never decode again.
final _images = <String, MemoryImage>{};
ImageProvider backgroundProvider(String data) {
  if (!_images.containsKey(data)) {
    if (_images.length >= 2) _images.remove(_images.keys.first);
    _images[data] = MemoryImage(base64Decode(data));
  }
  return _images[data]!;
}

class FlexBackground extends StatelessWidget {
  static const defaultDarkImage = 'assets/backgrounds/dark-texture.png';
  const FlexBackground({
    super.key,
    required this.appearance,
    required this.child,
    this.previewWidth,
  });
  final Appearance appearance;
  final Widget child;
  final double? previewWidth;
  @override
  Widget build(BuildContext context) {
    final width = previewWidth ?? MediaQuery.sizeOf(context).width;
    final data = appearance.imageForWidth(width);
    final mode = appearance.fitForWidth(width);
    final showDefault =
        data.isEmpty &&
        appearance.defaultTexture &&
        Theme.of(context).brightness == Brightness.dark;
    final active = appearance.imageEnabled && (data.isNotEmpty || showDefault);
    return ColoredBox(
      color: Color(appearance.backgroundColor),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (active)
            Positioned.fill(
              child: Opacity(
                opacity: data.isEmpty ? 1 : appearance.backgroundOpacity,
                child: Image(
                  image: data.isEmpty
                      ? const AssetImage(defaultDarkImage)
                      : backgroundProvider(data),
                  fit: backgroundFit(mode),
                  repeat: mode == 'tile'
                      ? ImageRepeat.repeat
                      : ImageRepeat.noRepeat,
                  alignment: Alignment.center,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              ),
            ),
          if (active && appearance.backgroundTintStrength > 0)
            Positioned.fill(
              child: ColoredBox(
                color: Color(
                  appearance.backgroundTint,
                ).withValues(alpha: appearance.backgroundTintStrength),
              ),
            ),
          if (active && appearance.backgroundDim > 0)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: appearance.backgroundDim),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
