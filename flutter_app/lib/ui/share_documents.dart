import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../domain/classroom.dart';
import '../services/material_sharing.dart';
import '../services/material_storage.dart';
import 'common.dart';
import 'flex_modal.dart';

Future<void> sharePreparedDocuments(
  BuildContext context,
  List<SharedDocument> documents,
) async {
  // Browser sharing needs a fresh user gesture after reading/rendering files.
  if (kIsWeb) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => FlexModal(
        title: const Text('Dateien teilen'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final d in documents) Text(d.name),
            const SizedBox(height: 12),
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
            onPressed: () => guarded(ctx, () async {
              await shareDocuments(documents);
              if (ctx.mounted) Navigator.pop(ctx);
            }),
            icon: const Icon(Icons.ios_share),
            label: const Text('Teilen'),
          ),
        ],
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
  final prepared = await prepareMaterialShare(
    materials,
    const LocalMaterialFiles(),
  );
  if (context.mounted) await sharePreparedDocuments(context, prepared);
}
