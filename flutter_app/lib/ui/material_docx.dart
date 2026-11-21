import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../domain/models.dart';
import '../services/docx_preview.dart';
import 'common.dart';
import 'flex_modal.dart';

class MaterialDocx extends StatelessWidget {
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
  Widget build(BuildContext context) => FlexModal(
    title: Text(title),
    maxWidth: 980,
    scrollable: false,
    onClose: () => Navigator.pop(context),
    content: SizedBox(
      height: MediaQuery.sizeOf(context).height * .68,
      child: DocxPreview(bytes: bytes),
    ),
    actions: [
      FilledButton.icon(
        onPressed: () => guarded(context, openOriginal),
        icon: const Icon(Icons.open_in_new),
        label: const Text('Original öffnen'),
      ),
    ],
  );
}

class DocxPreview extends StatefulWidget {
  const DocxPreview({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<DocxPreview> createState() => _DocxPreviewState();
}

class _DocxPreviewState extends State<DocxPreview> {
  late Future<List<Json>> content = compute(readDocxDocument, widget.bytes);
  @override
  void didUpdateWidget(DocxPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bytes != widget.bytes) {
      content = compute(readDocxDocument, widget.bytes);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Json>>(
    key: ObjectKey(widget.bytes),
    future: content,
    builder: (context, s) {
      if (s.hasError) return Center(child: Text(friendlyError(s.error!)));
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final blocks = s.requireData;
      if (blocks.isEmpty) {
        return const Center(
          child: Text('Keine darstellbaren Inhalte im Dokument.'),
        );
      }
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: SelectionArea(
            child: ListView.builder(
              primary: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              itemCount: blocks.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DocxBlock(blocks[i]),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DocxBlock extends StatelessWidget {
  const _DocxBlock(this.block);
  final Json block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (block['type']) {
      case 'table':
        return _DocxTable(block);
      case 'image':
        final alt = block['alt'] as String;
        return Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 460),
            child: Image(
              image: ResizeImage(
                MemoryImage(block['bytes'] as Uint8List),
                width: 1440,
                height: 1440,
                policy: ResizeImagePolicy.fit,
              ),
              fit: BoxFit.contain,
              semanticLabel: alt.isEmpty ? 'Abbildung' : alt,
              errorBuilder: (_, _, _) =>
                  Text(alt.isEmpty ? 'Abbildung im Original öffnen' : alt),
            ),
          ),
        );
      case 'notice':
        return Text(block['text'] as String, style: theme.textTheme.bodySmall);
      default:
        return Text.rich(
          TextSpan(
            children: [
              for (final r in block['runs'] as List)
                TextSpan(
                  text: r['text'] as String,
                  style: TextStyle(
                    fontWeight: r['b'] == true ? FontWeight.bold : null,
                    fontStyle: r['i'] == true ? FontStyle.italic : null,
                    decoration: r['u'] == true
                        ? TextDecoration.underline
                        : null,
                  ),
                ),
            ],
          ),
          style: block['type'] == 'heading'
              ? theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                )
              : theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          textAlign: switch (block['align']) {
            'center' => TextAlign.center,
            'right' || 'end' => TextAlign.end,
            'both' => TextAlign.justify,
            _ => TextAlign.start,
          },
        );
    }
  }
}

class _DocxTable extends StatelessWidget {
  const _DocxTable(this.block);
  final Json block;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rows = block['rows'] as List, count = block['columns'] as int;
    if (rows.isEmpty || count == 0) return const SizedBox.shrink();
    final widths = (block['widths'] as List).cast<int>();
    final headers = (block['headers'] as List).cast<int>();
    final useWidths = widths.length == count && widths.every((w) => w > 0);
    final total = useWidths ? widths.fold(0, (a, b) => a + b) : count;
    final border = BorderSide(color: colors.outlineVariant);
    return LayoutBuilder(
      builder: (context, space) {
        final minWidth = MediaQuery.textScalerOf(context).scale(76);
        final stops = <double>[0];
        for (var col = 0; col < count; col++) {
          final share = (useWidths ? widths[col] : 1) / total;
          stops.add(
            stops.last + math.max(minWidth, (space.maxWidth - 2) * share),
          );
        }
        Widget row(int index) {
          final cells = (rows[index] as List).cast<Json>();
          final pieces = <Widget>[], dividers = <Widget>[];
          var col = 0;
          for (final cell in cells) {
            final end = col + (cell['span'] as int);
            if (col > 0) {
              dividers.add(
                Positioned(
                  left: stops[col],
                  top: 0,
                  bottom: 0,
                  child: ColoredBox(
                    color: colors.outlineVariant,
                    child: const SizedBox(width: 1),
                  ),
                ),
              );
            }
            pieces.add(
              SizedBox(
                width: stops[end] - stops[col],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final p in cell['blocks'] as List)
                        _DocxBlock(p as Json),
                    ],
                  ),
                ),
              ),
            );
            col = end;
          }
          return DecoratedBox(
            decoration: BoxDecoration(
              color: headers.contains(index)
                  ? colors.secondaryContainer
                  : index.isOdd
                  ? colors.surfaceContainerLow
                  : colors.surface,
              border: index == 0 ? null : Border(top: border),
            ),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: pieces,
                ),
                ...dividers,
              ],
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          primary: false,
          child: Container(
            decoration: BoxDecoration(border: Border.fromBorderSide(border)),
            child: SizedBox(
              width: stops.last,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (var i = 0; i < rows.length; i++) row(i)],
              ),
            ),
          ),
        );
      },
    );
  }
}
