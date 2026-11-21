import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/diagnostics.dart';
import 'common.dart';
import 'flex_modal.dart';

Future<void> showDiagnostics(BuildContext context) => showDialog<void>(
  context: context,
  builder: (ctx) => AnimatedBuilder(
    animation: diagnostics,
    builder: (ctx, _) => FlexModal(
      title: const Text('Fehlerbericht'),
      maxWidth: 720,
      onClose: () => Navigator.pop(ctx),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Lokale technische Ereignisse der letzten 14 Tage, höchstens 100. Der Bericht enthält keine Namen, Eintragstexte, Dateien oder Zugangsdaten.',
          ),
          const SizedBox(height: 12),
          Text('${diagnostics.events.length} Ereignisse'),
          const SizedBox(height: 8),
          SelectableText(
            diagnostics.report(),
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => guarded(ctx, diagnostics.clear),
          child: const Text('Protokoll löschen'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.share_outlined),
          label: const Text('Fehlerbericht teilen'),
          onPressed: () => guarded(ctx, () async {
            final box = ctx.findRenderObject() as RenderBox?;
            await SharePlus.instance.share(
              ShareParams(
                title: 'FLEX Fehlerbericht',
                text: diagnostics.report(),
                sharePositionOrigin: box == null
                    ? null
                    : box.localToGlobal(Offset.zero) & box.size,
              ),
            );
          }),
        ),
      ],
    ),
  ),
);
