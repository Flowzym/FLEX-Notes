import 'package:flutter/services.dart';

/// Use the production faces and weights in layout tests; Ahem or a regular-only
/// substitute conceals real wrapping and heading overflows.
Future<void> loadAppTestFonts() async {
  for (final family in const {
    'FlexSans': [
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Semibold.ttf',
      'assets/fonts/Inter-Bold.ttf',
    ],
    'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
  }.entries) {
    final loader = FontLoader(family.key);
    for (final asset in family.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}
