import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../domain/classroom.dart';
import '../services/material_sharing.dart';
import '../services/material_storage.dart';
import 'common.dart';
import 'flex_modal.dart';

Future<void> sharePreparedDocuments(
  BuildContext context,
  List<SharedDocument> documents, {
  Set<int> previewIndices = const {},
}) async {
  // Browser sharing needs a fresh user gesture after reading/rendering files.
  if (documents.isEmpty) return;
  final previewRedactions = previewIndices.isNotEmpty;
  if (kIsWeb || previewRedactions) {
    var index = previewRedactions ? previewIndices.first : 0;
    final remaining = previewIndices.toSet();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final currentIndex = index;
          final document = documents[currentIndex];
          void previewReady() {
            if (!remaining.contains(currentIndex)) return;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted && remaining.contains(currentIndex)) {
                update(() => remaining.remove(currentIndex));
              }
            });
          }

          return FlexModal(
            maxWidth: 880,
            title: Text(
              previewRedactions ? 'Vorschau vor dem Teilen' : 'Dateien teilen',
            ),
            onClose: () => Navigator.pop(ctx),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (previewRedactions) ...[
                  if (documents.length > 1)
                    DropdownButton<int>(
                      isExpanded: true,
                      value: index,
                      items: [
                        for (final (i, d) in documents.indexed)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              d.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (i) {
                        if (i != null) update(() => index = i);
                      },
                    )
                  else
                    Text(document.name),
                  SizedBox(
                    height: MediaQuery.sizeOf(ctx).height * .48,
                    width: double.infinity,
                    child: document.mime == 'application/pdf'
                        ? PdfViewer.data(
                            document.bytes,
                            key: ObjectKey(document),
                            params: PdfViewerParams(
                              onViewerReady: (_, _) => previewReady(),
                            ),
                            sourceName:
                                '${document.name}-${identityHashCode(document)}',
                          )
                        : document.mime.startsWith('image/')
                        ? InteractiveViewer(
                            child: Image.memory(
                              document.bytes,
                              fit: BoxFit.contain,
                              semanticLabel: 'Zu teilendes Bild',
                              frameBuilder: (_, child, frame, sync) {
                                if (frame != null || sync) previewReady();
                                return child;
                              },
                            ),
                          )
                        : Center(child: Text(document.name)),
                  ),
                  if (remaining.isNotEmpty && documents.length > 1)
                    Text(
                      'Noch ${remaining.length} Vorschau${remaining.length == 1 ? '' : 'en'} ansehen.',
                    ),
                ] else
                  for (final d in documents) Text(d.name),
                const SizedBox(height: 12),
                if (kIsWeb)
                  const Text(
                    'Falls der Browser das Teilen nicht unterstützt, werden die Dateien heruntergeladen.',
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen'),
              ),
              FilledButton.icon(
                onPressed: remaining.isNotEmpty
                    ? null
                    : () => guarded(ctx, () async {
                        final box = ctx.findRenderObject();
                        await shareDocuments(
                          documents,
                          origin: box is RenderBox && box.hasSize
                              ? box.localToGlobal(Offset.zero) & box.size
                              : null,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      }),
                icon: const Icon(Icons.ios_share),
                label: const Text('Teilen'),
              ),
            ],
          );
        },
      ),
    );
    return;
  }
  final box = context.findRenderObject();
  await shareDocuments(
    documents,
    origin: box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null,
  );
}

Future<void> shareMaterials(
  BuildContext context,
  Iterable<ClassroomDocument> materials,
) async {
  final selection = materials.toList();
  if (selection.isEmpty) return;
  final prepared = await prepareMaterialShare(
    selection,
    const LocalMaterialFiles(),
  );
  if (context.mounted) {
    await sharePreparedDocuments(
      context,
      prepared,
      previewIndices: {
        for (final (index, m) in selection.indexed)
          if (m.previewBeforeSharing &&
              {'pdf', 'jpg'}.contains(m.text('extension')))
            index,
      },
    );
  }
}
