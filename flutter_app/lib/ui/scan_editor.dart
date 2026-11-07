import 'dart:async';
import 'dart:typed_data' show BytesBuilder;
import '../domain/school.dart';
import 'draft_actions.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flex_device/flex_device.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/document_scanner.dart';
import '../domain/models.dart';
import '../services/material_files.dart';
import '../services/material_storage.dart';
import '../services/scan_images.dart';
import '../services/scan_pdf_import.dart';
import '../services/scan_store.dart';
import 'classroom_editor.dart';
import 'common.dart';
import 'draft_buffer.dart';
import 'flex_modal.dart';
import 'scan_page_editor.dart';

Future<ClassroomDocument?> showDocumentScanner(
  BuildContext context,
  NotebookController c, {
  ScanContext scope = const ScanContext(),
  DialogDraft? draft,
  ClassroomDocument? source,
}) => showDialog<ClassroomDocument>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      ScanEditor(controller: c, scope: scope, draft: draft, source: source),
);

String documentLinkLabel(NotebookController c, DocumentLink link) {
  final title = switch (link.kind) {
    'orga' =>
      c.entries.where((e) => e.id == link.id).firstOrNull?.title ??
          'Orga-Eintrag',
    'school' =>
      c.records
              .where((r) => r.id == link.id)
              .map(
                (r) =>
                    '${r.kind.label} · ${c.pupils.where((p) => p.id == r.pupilId).firstOrNull?.name ?? ''}',
              )
              .firstOrNull ??
          'Schülereintrag',
    _ =>
      c.classroom.where((d) => d.id == link.id).firstOrNull?.title ??
          'Klassen-Eintrag',
  };
  return '${title.length > 90 ? title.substring(0, 90) : title}${link.date.isNotEmpty ? ' · ${displayDate(link.date)}' : ''}';
}

Set<String> documentLinkPupils(
  NotebookController c,
  Iterable<DocumentLink> links,
) => {
  for (final l in links)
    if (l.kind == 'orga')
      ...c.entries
          .where((e) => e.id == l.id && e.pupilId != null)
          .map((e) => e.pupilId!),
  for (final l in links)
    if (l.kind == 'school')
      ...c.records.where((r) => r.id == l.id).map((r) => r.pupilId),
};

Future<List<DocumentLink>?> chooseDocumentLinks(
  BuildContext context,
  NotebookController c,
  List<DocumentLink> selected,
) {
  var query = '';
  final chosen = {for (final l in selected) l.identity: l};
  final options = {
    for (final l in selected) l.identity: l,
    for (final e in c.entries.where((e) => !e.deleted))
      'orga:${e.id}:': DocumentLink('orga', e.id),
    for (final r in c.records.where((r) => !r.deleted))
      'school:${r.id}:': DocumentLink('school', r.id),
    for (final d in c.classroom.where(
      (d) =>
          !d.deleted &&
          {
            ClassroomKind.lesson,
            ClassroomKind.plan,
            ClassroomKind.returnList,
            ClassroomKind.materialSet,
          }.contains(d.kind),
    ))
      'classroom:${d.id}:': DocumentLink('classroom', d.id),
  };
  return showDialog<List<DocumentLink>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => FlexModal(
        title: const Text('Einträgen zuordnen'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Einträge suchen',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => update(() => query = v.toLowerCase()),
            ),
            const SizedBox(height: 8),
            for (final l in options.values.where(
              (l) => documentLinkLabel(c, l).toLowerCase().contains(query),
            ))
              CheckboxListTile(
                value: chosen.containsKey(l.identity),
                title: Text(documentLinkLabel(c, l)),
                subtitle: Text(switch (l.kind) {
                  'orga' => 'Orga',
                  'school' => 'Schüler',
                  'lesson' => 'Unterrichtsstunde',
                  _ => 'Klasse',
                }),
                onChanged: (v) => update(() {
                  if (v == true) {
                    chosen[l.identity] = l;
                  } else {
                    chosen.remove(l.identity);
                  }
                }),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, chosen.values.toList()),
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    ),
  );
}

class ScanEditor extends StatefulWidget {
  const ScanEditor({
    super.key,
    required this.controller,
    this.scope = const ScanContext(),
    this.draft,
    this.source,
    this.files = const LocalMaterialFiles(),
    this.initialImages = const [],
    this.pickFiles,
    this.capturePages,
  });
  final NotebookController controller;
  final ScanContext scope;
  final DialogDraft? draft;
  final ClassroomDocument? source;
  final MaterialFiles files;
  final List<Uint8List> initialImages;
  final Future<List<XFile>> Function()? pickFiles;
  final Future<List<Uint8List>?> Function(int)? capturePages;
  @override
  State<ScanEditor> createState() => _ScanEditorState();
}

class _ScanEditorState extends State<ScanEditor> with WidgetsBindingObserver {
  NotebookController get c => widget.controller;
  late Json data;
  late DraftBuffer buffer;
  late TextEditingController title;
  bool busy = false, canPop = false, committed = false, replace = false;
  String? error;
  String progress = '';
  final knownKeys = <String>{};
  List<ScanPage> get pages => (data['pages'] as List)
      .map((p) => ScanPage.fromJson(Json.from(p as Map)))
      .toList();
  List<String> get pupilIds => List<String>.from(data['pupilIds'] as List);
  List<DocumentLink> get links => (data['links'] as List)
      .map((p) => DocumentLink.fromJson(Json.from(p as Map)))
      .toList();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final source = widget.source;
    data = {...widget.draft?.data ?? widget.scope.initial()};
    if (widget.draft == null && source != null) {
      data = {
        'title': source.title,
        'documentType': scanTypes.containsKey(source.text('documentType'))
            ? source.text('documentType')
            : 'other',
        'subject': source.text('subject'),
        'pupilIds': source.strings('pupilIds'),
        'links': source.rows('links'),
        'pages': <Json>[],
        'sourceId': source.id,
        'sourceRevision': source.revision,
      };
    }
    title = TextEditingController(text: data['title'] as String);
    knownKeys.addAll(pages.map((p) => p.key));
    buffer = DraftBuffer(
      c.repository,
      type: 'scan',
      ownerId: widget.draft?.ownerId ?? newId(),
      data: data,
      initial: widget.draft,
      onPersisted: c.reload,
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    if (source != null && widget.draft == null ||
        widget.initialImages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        action(() async {
          if (source != null) {
            final bytes = await widget.files.read(source.text('localKey'));
            await addPdf(bytes);
          }
          for (final image in widget.initialImages) {
            await addImage(image);
          }
        });
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !committed) {
      unawaited(
        buffer.flush().catchError((Object e) {
          if (mounted) setState(() => error = friendlyError(e));
        }),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    buffer.dispose();
    title.dispose();
    super.dispose();
  }

  void change(Json patch) {
    data = {...data, ...patch};
    buffer.change(data);
    if (mounted) setState(() {});
  }

  Future<void> action(Future<void> Function() callback) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await callback();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          progress = '';
        });
      }
    }
  }

  Future<void> pop([ClassroomDocument? result]) async {
    if (!mounted) return;
    setState(() => canPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, result);
  }

  Future<void> close() => action(() async {
    await buffer.flush();
    await cleanupPages();
    await c.reload();
    await pop();
  });
  Future<void> addImage(Uint8List bytes) async {
    if (pages.length >= scanPageLimit) {
      throw const DomainError('Pro PDF sind bis zu 25 Seiten möglich.');
    }
    final image = await compute(normalizeScan, bytes);
    final key = newId();
    await widget.files.write(key, image['bytes'] as Uint8List);
    knownKeys.add(key);
    change({
      'pages': [
        ...pages.map((p) => p.toJson()),
        ScanPage(key, image['width'] as int, image['height'] as int).toJson(),
      ],
    });
    // A failed metadata write must retain both the buffered page and its bytes:
    // the next flush can safely retry without creating a dangling file reference.
    await buffer.flush();
  }

  Future<void> cleanupPages() async {
    try {
      await removeUnusedScanFiles(c.repository, widget.files, knownKeys);
    } catch (_) {
      // Cleanup must not turn a successful save into a reported failure.
    }
  }

  Future<void> addPdf(Uint8List bytes) async {
    var index = 0;
    await for (final image in importPdfPages(
      bytes,
      limit: scanPageLimit - pages.length,
    )) {
      if (mounted) {
        setState(() => progress = 'PDF-Seite ${++index} wird eingelesen …');
      }
      await addImage(image);
    }
  }

  Future<void> pick() => action(() async {
    final files =
        await (widget.pickFiles?.call() ??
            openFiles(
              acceptedTypeGroups: [
                const XTypeGroup(
                  label: 'Bilder und PDF',
                  extensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
                  mimeTypes: [
                    'image/jpeg',
                    'image/png',
                    'image/webp',
                    'application/pdf',
                  ],
                ),
              ],
            ));
    for (final file in files) {
      if (await file.length() > 20000000) {
        throw const DomainError('Bitte Dateien bis zu 20 MB auswählen.');
      }
      final bytes = BytesBuilder();
      await for (final chunk in file.openRead()) {
        if (bytes.length + chunk.length > 20000000) {
          throw const DomainError('Die Datei überschreitet 20 MB.');
        }
        bytes.add(chunk);
      }
      final content = bytes.takeBytes();
      if (file.name.toLowerCase().endsWith('.pdf')) {
        await addPdf(content);
      } else {
        await addImage(content);
      }
    }
  });
  Future<void> capture() => action(() async {
    await buffer.flush();
    final remaining = scanPageLimit - pages.length;
    if (remaining < 1) {
      throw const DomainError('Pro PDF sind bis zu 25 Seiten möglich.');
    }
    final values = widget.capturePages != null
        ? await widget.capturePages!(remaining)
        : (await FlexDevice.channel.invokeListMethod<Uint8List>(
            'scanDocument',
            {'limit': remaining},
          ));
    if (values == null) return;
    for (final bytes in values) {
      await addImage(bytes);
    }
  });
  Future<void> editPage(int index) => action(() async {
    final page = pages[index],
        bytes = await widget.files.read(pages[index].key);
    if (!mounted) return;
    final edited = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ScanPageEditor(
        bytes: bytes,
        pageNumber: index + 1,
        width: page.width,
        height: page.height,
      ),
    );
    if (edited == null) return;
    final key = newId();
    await widget.files.write(key, edited['bytes'] as Uint8List);
    knownKeys.add(key);
    final next = pages;
    next[index] = ScanPage(
      key,
      edited['width'] as int,
      edited['height'] as int,
    );
    change({'pages': next.map((p) => p.toJson()).toList()});
    await buffer.flush();
    await removeUnusedScanFiles(c.repository, widget.files, [page.key]);
  });
  Future<void> deletePage(int index) => action(() async {
    final next = pages, removed = next.removeAt(index);
    change({'pages': next.map((p) => p.toJson()).toList()});
    await buffer.flush();
    await removeUnusedScanFiles(c.repository, widget.files, [removed.key]);
  });
  Future<void> movePage(int index, int step) => action(() async {
    final next = pages, item = next.removeAt(index);
    next.insert(index + step, item);
    change({'pages': next.map((p) => p.toJson()).toList()});
    await buffer.flush();
  });
  Future<void> save() => action(() async {
    await buffer.flush();
    final saved = await saveScan(
      c.repository,
      widget.files,
      buffer.draft,
      replace: replace,
    );
    committed = true;
    await cleanupPages();
    await c.reload();
    await pop(saved);
  });
  Future<void> deleteDraft() async {
    if (busy) return;
    if (!await confirmEditorDraftDeletion(context) || !mounted) return;
    await action(() async {
      await buffer.flush();
      await discardScan(c.repository, widget.files, buffer.draft);
      await cleanupPages();
      committed = true;
      await c.reload();
      await pop();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: canPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !busy) close();
    },
    child: FlexModal(
      maxWidth: 900,
      title: const Text('Dokument scannen'),
      onClose: busy ? null : close,
      headerActions: [
        if (buffer.hasContent || buffer.draft.revision > 0)
          IconButton(
            tooltip: 'Scanentwurf löschen',
            onPressed: busy ? null : deleteDraft,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) const LinearProgressIndicator(),
          if (progress.isNotEmpty) Text(progress),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.capturePages != null ||
                  !kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                FilledButton.icon(
                  key: const ValueKey('scanner-camera'),
                  onPressed: busy || pages.length >= scanPageLimit
                      ? null
                      : capture,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scannen'),
                ),
              OutlinedButton.icon(
                key: const ValueKey('scanner-import'),
                onPressed: busy || pages.length >= scanPageLimit ? null : pick,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Bilder / PDF hinzufügen'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('scan-title'),
            controller: title,
            enabled: !busy,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'PDF-Name',
              suffixText: '.pdf',
            ),
            onChanged: (v) => change({'title': v}),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: data['documentType'] as String,
            decoration: const InputDecoration(labelText: 'Kategorie'),
            items: scanTypes.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: busy ? null : (v) => change({'documentType': v}),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final ids = await chooseMaterialPupils(
                          context,
                          c,
                          pupilIds,
                        );
                        if (ids != null && mounted) {
                          change({
                            'pupilIds': {
                              ...ids,
                              ...documentLinkPupils(c, links),
                            }.toList(),
                          });
                        }
                      },
                icon: const Icon(Icons.people_outline),
                label: Text(
                  pupilIds.isEmpty
                      ? 'FLEX-Klasse'
                      : '${pupilIds.length} Schüler',
                ),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final next = await chooseDocumentLinks(
                          context,
                          c,
                          links,
                        );
                        if (next != null && mounted) {
                          final owners = {
                            ...pupilIds,
                            ...documentLinkPupils(c, next),
                          };
                          change({
                            'links': next.map((l) => l.toJson()).toList(),
                            'pupilIds': owners.toList(),
                          });
                        }
                      },
                icon: const Icon(Icons.link),
                label: Text('Einträge · ${links.length}'),
              ),
            ],
          ),
          if (pupilIds.isNotEmpty)
            Text(
              c.pupils
                  .where((p) => pupilIds.contains(p.id))
                  .map((p) => p.name)
                  .join(', '),
            ),
          for (final link in links)
            Text(
              documentLinkLabel(c, link),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 16),
          Text(
            '${pages.length} ${pages.length == 1 ? 'Seite' : 'Seiten'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (pages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Seiten scannen oder Bilder/PDF hinzufügen.'),
            ),
          for (final item in pages.indexed)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 72,
                          height: 100,
                          child: FutureBuilder<Uint8List>(
                            future: widget.files.read(item.$2.key),
                            builder: (ctx, s) => s.hasError
                                ? const Icon(Icons.broken_image_outlined)
                                : s.hasData
                                ? Image.memory(s.data!, fit: BoxFit.contain)
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Seite ${item.$1 + 1}'),
                              Wrap(
                                children: [
                                  IconButton(
                                    tooltip: 'Seite nach vorne',
                                    onPressed: busy || item.$1 == 0
                                        ? null
                                        : () => movePage(item.$1, -1),
                                    icon: const Icon(Icons.arrow_upward),
                                  ),
                                  IconButton(
                                    tooltip: 'Seite nach hinten',
                                    onPressed:
                                        busy || item.$1 == pages.length - 1
                                        ? null
                                        : () => movePage(item.$1, 1),
                                    icon: const Icon(Icons.arrow_downward),
                                  ),
                                  IconButton(
                                    tooltip: 'Seite entfernen',
                                    onPressed: busy
                                        ? null
                                        : () => deletePage(item.$1),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              OutlinedButton.icon(
                                key: ValueKey('scan-edit-page-${item.$1}'),
                                onPressed: busy
                                    ? null
                                    : () => editPage(item.$1),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Bearbeiten'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (data['sourceId'] != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vorhandene PDF ersetzen'),
              subtitle: Text(
                replace
                    ? 'Die lokale Fassung wird ersetzt. Bereits exportierte Kopien bleiben erhalten.'
                    : 'Es wird eine neue PDF-Kopie gespeichert.',
              ),
              value: replace,
              onChanged: busy
                  ? null
                  : (v) => setState(() => replace = v ?? false),
            ),
          DraftStatus(buffer: buffer),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : close,
          child: const Text('Später fortsetzen'),
        ),
        FilledButton.icon(
          key: const ValueKey('save-scan'),
          onPressed: busy || pages.isEmpty ? null : save,
          icon: const Icon(Icons.picture_as_pdf),
          label: Text(replace ? 'PDF ersetzen' : 'PDF speichern'),
        ),
      ],
    ),
  );
}
