import 'package:flutter/material.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';
import '../services/material_files.dart';
import '../services/material_storage.dart';
import '../services/material_thumbnails.dart';

class MaterialThumbnail extends StatelessWidget {
  const MaterialThumbnail({
    super.key,
    required this.material,
    this.files = const LocalMaterialFiles(),
    this.width = 56,
    this.height = 72,
  });
  final ClassroomDocument material;
  final MaterialFiles files;
  final double width, height;
  @override
  Widget build(BuildContext context) => DocumentThumbnailView(
    identity:
        '${material.id}:${material.revision}:${material.text('etag')}:${material.text('localKey')}',
    title: material.title,
    fileKey: material.text('localKey'),
    extension: material.text('extension'),
    driveId: material.text('driveId'),
    itemId: material.text('itemId'),
    files: files,
    width: width,
    height: height,
  );
}

class ScanDraftThumbnail extends StatelessWidget {
  const ScanDraftThumbnail({
    super.key,
    required this.draft,
    this.files = const LocalMaterialFiles(),
  });
  final DialogDraft draft;
  final MaterialFiles files;
  @override
  Widget build(BuildContext context) {
    final pages = draft.data['pages'] as List? ?? [];
    final key = pages.isEmpty ? '' : pages.first['key'] as String;
    return DocumentThumbnailView(
      identity: '${draft.id}:${draft.revision}:$key',
      title: draft.data['title'] as String? ?? 'Scanentwurf',
      fileKey: key,
      extension: 'jpg',
      files: files,
      width: 48,
      height: 56,
    );
  }
}

class DocumentThumbnailView extends StatefulWidget {
  const DocumentThumbnailView({
    super.key,
    required this.identity,
    required this.title,
    required this.fileKey,
    required this.extension,
    this.driveId = '',
    this.itemId = '',
    this.files = const LocalMaterialFiles(),
    this.width = 56,
    this.height = 72,
  });
  final String identity, title, fileKey, extension, driveId, itemId;
  final MaterialFiles files;
  final double width, height;
  @override
  State<DocumentThumbnailView> createState() => _DocumentThumbnailViewState();
}

class _DocumentThumbnailViewState extends State<DocumentThumbnailView> {
  late String identity;
  late Future<DocumentThumbnail> result;
  String get currentIdentity =>
      '${identityHashCode(widget.files)}:${widget.identity}:${widget.fileKey}:${widget.extension}:${widget.driveId}:${widget.itemId}:${materialThumbnails.version(widget.fileKey)}';
  void load() {
    identity = currentIdentity;
    result = materialThumbnails.load(
      identity: identity,
      files: widget.files,
      fileKey: widget.fileKey,
      extension: widget.extension,
      driveId: widget.driveId,
      itemId: widget.itemId,
    );
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(DocumentThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identity != currentIdentity) load();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey('thumbnail-${widget.identity}'),
    width: widget.width,
    height: widget.height,
    child: FutureBuilder<DocumentThumbnail>(
      key: ValueKey(identity),
      future: result,
      builder: (ctx, s) {
        final data = s.data;
        final missing = data?.unavailable == true;
        return Semantics(
          image: true,
          label:
              '${s.connectionState != ConnectionState.done
                  ? 'Vorschau wird geladen'
                  : missing
                  ? 'Vorschau nicht verfügbar'
                  : 'Vorschau'}: ${widget.title}',
          child: ExcludeSemantics(
            child: Tooltip(
              message: missing
                  ? 'Vorschau nicht verfügbar · Datei öffnen oder offline laden'
                  : widget.extension == 'docx'
                  ? 'Textvorschau'
                  : 'Vorschau',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: data?.image != null || data?.text != null
                        ? Colors.white
                        : Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  ),
                  child: data?.image != null
                      ? Image.memory(
                          data!.image!,
                          fit: BoxFit.contain,
                          gaplessPlayback: false,
                        )
                      : data?.text != null
                      ? Padding(
                          padding: const EdgeInsets.all(5),
                          child: Text(
                            data!.text!.isEmpty
                                ? 'Leeres Dokument'
                                : data.text!,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontSize: 6,
                              height: 1.25,
                              color: Colors.black,
                            ),
                            maxLines: 10,
                            overflow: TextOverflow.clip,
                          ),
                        )
                      : Center(
                          child: Icon(
                            s.connectionState != ConnectionState.done
                                ? Icons.more_horiz
                                : missing
                                ? Icons.image_not_supported_outlined
                                : Icons.description_outlined,
                            size: 22,
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
