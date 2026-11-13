import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/ui/app_navigation.dart';
import 'support/app_test_fonts.dart';

void main() {
  setUpAll(loadAppTestFonts);
  testWidgets(
    'navigation keeps equal touch widths and complete words at phone widths and large text',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      for (final width in [320.0, 390.0]) {
        t.view.physicalSize = Size(width, 844);
        for (final scale in [1.0, 1.8]) {
          for (final pages in [
            livePages,
            organisationPages,
            {0: 'Dateien', 1: 'Bereitgelegt', 2: 'Pakete', 3: 'Planungen'},
            {
              0: 'Weitere',
              1: 'Archiv',
              2: 'Papierkorb',
              3: 'Daten',
              4: 'Einstellungen',
              5: 'Scanner',
            },
          ]) {
            for (final selected in [0, pages.length - 1]) {
              await t.pumpWidget(
                MaterialApp(
                  theme: ThemeData(fontFamily: 'FlexSans'),
                  builder: (ctx, child) => MediaQuery(
                    data: MediaQuery.of(
                      ctx,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: FlexPagePills(
                      pages: pages,
                      selected: selected,
                      onSelected: (_) {},
                    ),
                  ),
                ),
              );
              await t.pumpAndSettle();
              final first = t
                  .getSize(find.byKey(const ValueKey('page-0')))
                  .width;
              for (final entry in pages.entries) {
                final button = t.getRect(
                  find.byKey(ValueKey('page-${entry.key}')),
                );
                final label = t.getRect(find.text(entry.value));
                expect(button.width, closeTo(first, .01));
                expect(label.left, greaterThanOrEqualTo(button.left));
                expect(label.right, lessThanOrEqualTo(button.right));
                final text = t.renderObject<RenderParagraph>(
                  find.text(entry.value),
                );
                final lines = text.getBoxesForSelection(
                  TextSelection(
                    baseOffset: 0,
                    extentOffset: entry.value.length,
                  ),
                );
                expect(
                  lines.length,
                  1,
                  reason: '${entry.value} at $width / $scale stays on one line',
                );
              }
              expect(t.takeException(), isNull);
            }
          }
        }
      }
    },
  );
}
