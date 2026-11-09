import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/ui/detail_flow.dart';
import 'package:flex_notizbuch/ui/flex_modal.dart';

void main() {
  testWidgets(
    'nested details use one surface and back preserves parent input',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      String? result;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () async {
                  result = await showFlexDetail<String>(
                    context: ctx,
                    builder: (_) => const _Parent(),
                  );
                },
                child: const Text('Öffnen'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Öffnen'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Unverlorene Eingabe');
      await t.tap(find.text('Details'));
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Unterdetails'), findsOneWidget);
      await t.tap(find.byTooltip('Zurück'));
      await t.pumpAndSettle();
      expect(find.text('Unverlorene Eingabe'), findsOneWidget);
      await t.tap(find.byTooltip('Schließen'));
      await t.pumpAndSettle();
      expect(result, 'fertig');
      expect(find.byType(Dialog), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'system back honors child pop guard before leaving the detail flow',
    (t) async {
      var blocked = false;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => showFlexDetail<void>(
                  context: ctx,
                  builder: (detail) => PopScope(
                    canPop: false,
                    onPopInvokedWithResult: (didPop, _) {
                      blocked = !didPop;
                    },
                    child: FlexModal(
                      title: const Text('Guard'),
                      content: const Text('Unsaved'),
                      onClose: () => Navigator.pop(detail),
                    ),
                  ),
                ),
                child: const Text('Öffnen'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Öffnen'));
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(blocked, isTrue);
      expect(find.text('Unsaved'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}

class _Parent extends StatelessWidget {
  const _Parent();
  @override
  Widget build(BuildContext context) => FlexModal(
    title: const Text('Parent'),
    onClose: () => Navigator.pop(context, 'fertig'),
    content: Column(
      children: [
        const TextField(),
        TextButton(
          onPressed: () => showFlexDetail<void>(
            context: context,
            builder: (child) => FlexModal(
              title: const Text('Unterdetails'),
              onClose: () => Navigator.pop(child),
              content: const Text('Inhalt'),
            ),
          ),
          child: const Text('Details'),
        ),
      ],
    ),
  );
}
