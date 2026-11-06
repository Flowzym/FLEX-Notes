import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../domain/models.dart';
import '../services/docx_preview.dart';
import 'common.dart';
import 'flex_modal.dart';

class MaterialDocx extends StatefulWidget {
  const MaterialDocx({
    super.key,
    required this.title,
    required this.bytes,
    required this.openOriginal,
  });
  final String title;
  final Uint8List bytes;
  final Future<void> Function() openOriginal;
  @override
  State<MaterialDocx> createState() => _MaterialDocxState();
}

class _MaterialDocxState extends State<MaterialDocx> {
  late final Future<List<Json>> content = compute(
    readDocxPreview,
    widget.bytes,
  );
  @override
  Widget build(BuildContext context) => FlexModal(
    title: Text(widget.title),
    maxWidth: 900,
    onClose: () => Navigator.pop(context),
    content: FutureBuilder<List<Json>>(
      future: content,
      builder: (ctx, s) {
        if (s.hasError) return Text(friendlyError(s.error!));
        if (!s.hasData) return const LinearProgressIndicator();
        return SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Textvorschau · Layout und Abbildungen im Original',
                ),
              ),
              for (final block in s.data!)
                if (block['type'] == 'table')
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final row in block['rows'] as List)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final cell in row as List)
                                  Container(
                                    width: 180,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Theme.of(
                                          ctx,
                                        ).colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Text(cell as String),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      block['text'] as String,
                      style: block['type'] == 'heading'
                          ? Theme.of(ctx).textTheme.titleLarge
                          : null,
                    ),
                  ),
            ],
          ),
        );
      },
    ),
    actions: [
      FilledButton.icon(
        onPressed: () => guarded(context, widget.openOriginal),
        icon: const Icon(Icons.open_in_new),
        label: const Text('Original öffnen'),
      ),
    ],
  );
}
