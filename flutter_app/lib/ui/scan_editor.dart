import 'scan_batch_filter.dart';
import 'share_documents.dart';
import '../services/material_sharing.dart';
import 'detail_flow.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:typed_data' show BytesBuilder;
import '../domain/school.dart';
import '../domain/drafts.dart';
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
import 'scan_tools.dart';
import 'material_thumbnail.dart';
import 'material_tags.dart';

Future<ClassroomDocument?> showDocumentScanner(
  BuildContext context,
  NotebookController c, {
  ScanContext scope = const ScanContext(),
  DialogDraft? draft,
  ClassroomDocument? source,
}) => showFlexDetail<ClassroomDocument>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      ScanEditor(controller: c, scope: scope, draft: draft, source: source),
);

String documentLinkLabel(NotebookController c, DocumentLink link) {
  if (link.kind == 'orgaDraft') {
    final draft = c.drafts.where((d) => d.id == link.id).firstOrNull;
    return 'Entwurf · ${draft == null ? 'Orga' : c.owner(draft.entry)} · ${draft?.entry.title ?? ''}';
  }
  if (link.kind == 'schoolDraft') {
    final r = c.schoolDrafts.where((d) => d.id == link.id).firstOrNull?.record;
    final owner =
        c.pupils.where((p) => p.id == r?.pupilId).firstOrNull?.name ??
        'Schüler';
    final task = r?.tasks.where((t) => t.id == link.taskId).firstOrNull;
    return 'Entwurf · $owner · ${r?.kind.label ?? 'Eintrag'}${task == null ? '' : ' · ${task.text.isEmpty ? 'Aufgabe' : task.text}'}';
  }
  if (link.kind == 'bulkDraft') {
    return 'Entwurf · Gruppeneintrag${link.taskId.isEmpty ? '' : ' · Aufgabe'}';
  }
  if (link.kind == 'school' && link.taskId.isNotEmpty) {
    final record = c.records.where((r) => r.id == link.id).firstOrNull;
    final task = record?.tasks.where((t) => t.id == link.taskId).firstOrNull;
    final owner =
        c.pupils.where((p) => p.id == record?.pupilId).firstOrNull?.name ??
        'Schüler';
    return '$owner · ${task?.parentId == null ? 'Aufgabe' : 'Teilaufgabe'} · ${task?.text ?? 'Entfernte Aufgabe'}';
  }
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
    for (final r in c.records.where(
      (r) => !r.deleted && r.kind == SchoolKind.homework,
    ))
      for (final task in r.tasks)
        DocumentLink('school', r.id, taskId: task.id).identity: DocumentLink(
          'school',
          r.id,
          taskId: task.id,
        ),
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
                  'orgaDraft' || 'schoolDraft' || 'bulkDraft' => 'Entwurf',
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
    this.capturePhoto,
  });
  final NotebookController controller;
  final ScanContext scope;
  final DialogDraft? draft;
  final ClassroomDocument? source;
  final MaterialFiles files;
  final List<Uint8List> initialImages;
  final Future<List<XFile>> Function()? pickFiles;
  final Future<List<Uint8List>?> Function(int)? capturePages;
  final Future<Uint8List?> Function()? capturePhoto;
  @override
  State<ScanEditor> createState() => _ScanEditorState();
}

class _ScanEditorState extends State<ScanEditor> with WidgetsBindingObserver {
  NotebookController get c => widget.controller;
  late Json data;
  late DraftBuffer buffer;
  late TextEditingController title;
  bool pageEditorOpen = false, pageGrid = true;
  String? sourceSignature;
  bool loadingSource = false;
  bool get photoOutput => data['outputFormat'] == 'jpg';
  bool get nativeCamera =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool busy = false, canPop = false, committed = false, replace = false;
  String? error;
  String progress = '';
  String? cameraNotice;
  ScanPage? removedPage;
  final filterUndo = <String, ScanPage>{};
  int removedIndex = 0;
  String scanError(Object e) {
    if (e is PlatformException &&
        {
          'scanner_unavailable',
          'scanner_busy',
          'photo_busy',
          'photo_unavailable',
          'photo_read',
          'photo_closed',
          'material_storage',
        }.contains(e.code) &&
        e.message?.isNotEmpty == true) {
      return e.message!;
    }
    if (e is MissingPluginException) {
      return 'Die Kamerafunktion fehlt in dieser App-Version. Bitte die aktuelle FLEX-Testapp installieren oder ein Bild aus Dateien hinzufügen.';
    }
    return friendlyError(e);
  }

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
        'tags': source.strings('tags'),
        'outputFormat': source.text('extension') == 'jpg' ? 'jpg' : 'pdf',
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
          if (source != null && widget.draft == null) {
            loadingSource = true;
            try {
              final bytes = await widget.files.read(source.text('localKey'));
              if (source.text('extension') == 'jpg') {
                await addImage(bytes, photo: true);
              } else {
                await addPdf(bytes);
              }
            } finally {
              loadingSource = false;
              sourceSignature = dialogDraftSignature('scan', data);
              resetSourceBuffer();
            }
          }
          for (final image in widget.initialImages) {
            await addImage(image);
          }
        });
      });
    }
    if (data['capturePending'] == true && nativeCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        action(recoverPhoto);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !committed) {
      unawaited(
        buffer.flush().catchError((Object e) {
          if (mounted) setState(() => error = scanError(e));
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
    if (!loadingSource) buffer.change(data);
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
      if (mounted) setState(() => error = scanError(e));
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

  void resetSourceBuffer({bool retain = false}) {
    final owner = buffer.draft.ownerId;
    buffer.dispose();
    buffer = DraftBuffer(
      c.repository,
      type: 'scan',
      ownerId: owner,
      data: data,
      baseline: retain ? '' : sourceSignature,
      onPersisted: c.reload,
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    if (retain) buffer.change(data);
  }

  Future<void> retainSourceCopy() async {
    if (widget.draft == null &&
        sourceSignature != null &&
        sourceSignature == dialogDraftSignature('scan', data)) {
      await buffer.flush();
      resetSourceBuffer(retain: true);
    }
  }

  Future<void> close({bool keepDraft = false}) => action(() async {
    if (keepDraft) await retainSourceCopy();
    // Importing the original pages is preparation, not a user edit. Keep an
    // existing draft, real edits, or an explicitly requested resumable copy.
    if (!keepDraft &&
        widget.draft == null &&
        sourceSignature != null &&
        sourceSignature == dialogDraftSignature('scan', data)) {
      await buffer.discard();
    } else {
      await buffer.flush();
    }
    await cleanupPages();
    await c.reload();
    await pop();
  });
  Future<void> addImage(
    Uint8List bytes, {
    bool photo = false,
    String? captureToken,
    String? replaceKey,
  }) async {
    final replacement = replaceKey == null
        ? -1
        : pages.indexWhere((p) => p.key == replaceKey);
    if (replaceKey != null && replacement < 0) {
      throw const DomainError(
        'Die zu ersetzende Seite ist nicht mehr vorhanden.',
      );
    }
    if (replacement < 0 && pages.length >= scanPageLimit) {
      throw const DomainError('Pro PDF sind bis zu 25 Seiten möglich.');
    }
    final image = await compute(normalizeScan, bytes);
    final key = newId();
    await widget.files.write(key, image['bytes'] as Uint8List);
    knownKeys.add(key);
    final page = ScanPage(
      key,
      image['width'] as int,
      image['height'] as int,
      photo: photo,
      captureToken: captureToken,
    );
    final next = pages;
    if (replacement < 0) {
      next.add(page);
    } else {
      next[replacement] = page;
    }
    change({
      'pages': next.map((p) => p.toJson()).toList(),
      if (replaceKey != null) 'captureReplaceKey': null,
    });
    // A failed metadata write must retain both the buffered page and its bytes:
    // the next flush can safely retry without creating a dangling file reference.
    if (!loadingSource) await buffer.flush();
    if (replaceKey != null) {
      await cleanupPages([replaceKey]);
    }
  }

  Future<void> cleanupPages([Iterable<String>? keys]) async {
    try {
      await removeUnusedScanFiles(
        c.repository,
        widget.files,
        keys ?? knownKeys,
      );
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

  Future<void> pick({String? replaceKey}) => action(() async {
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
    if (replaceKey != null &&
        files.isNotEmpty &&
        (files.length != 1 ||
            files.single.name.toLowerCase().endsWith('.pdf'))) {
      throw const DomainError(
        'Zum Ersetzen bitte genau ein Bild auswählen. PDFs über „Bilder / PDF hinzufügen“ ergänzen.',
      );
    }
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
        await addImage(content, photo: photoOutput, replaceKey: replaceKey);
      }
    }
  });
  Future<void> capture() => action(() async {
    await buffer.flush();
    final remaining = scanPageLimit - pages.length;
    if (remaining < 1) {
      throw const DomainError('Pro PDF sind bis zu 25 Seiten möglich.');
    }
    List<Uint8List>? values;
    try {
      values = widget.capturePages != null
          ? await widget.capturePages!(remaining)
          : await FlexDevice.channel.invokeListMethod<Uint8List>(
              'scanDocument',
              {'limit': remaining},
            );
    } on PlatformException catch (e) {
      if (e.code != 'scanner_unavailable' || !nativeCamera) rethrow;
      if (mounted) {
        setState(
          () => cameraNotice =
              'Aufnahme mit der normalen Kamera. Dokumentränder, Zuschnitt und Filter sind unter „Bearbeiten“ verfügbar.',
        );
      }
      await captureStill(document: true);
      return;
    }
    if (values == null) return;
    for (final bytes in values) {
      await addImage(bytes);
    }
  });
  Future<void> acceptPhoto(Map<dynamic, dynamic>? result) async {
    if (result != null) {
      final token = result['token'] as String;
      if (!pages.any((p) => p.captureToken == token)) {
        await addImage(
          result['bytes'] as Uint8List,
          photo: data['captureAsDocument'] != true,
          captureToken: token,
          replaceKey: data['captureReplaceKey'] as String?,
        );
      }
      await buffer.flush();
      await FlexDevice.channel.invokeMethod<void>('finishPhoto', {
        'draftId': buffer.draft.id,
        'token': token,
      });
    }
    change({'capturePending': false, 'captureReplaceKey': null});
    await buffer.flush();
  }

  Future<void> recoverPhoto() async {
    final result = await FlexDevice.channel.invokeMapMethod<String, dynamic>(
      'recoverPhoto',
      {'draftId': buffer.draft.id},
    );
    await acceptPhoto(result);
  }

  Future<void> takePhoto() => action(() async {
    await captureStill(document: false);
  });
  Future<bool> captureStill({
    required bool document,
    String? replaceKey,
  }) async {
    final previousKeys = pages.map((p) => p.key).join(',');
    if (data['capturePending'] == true && nativeCamera) {
      await recoverPhoto();
      return previousKeys != pages.map((p) => p.key).join(',');
    }
    if (pages.isEmpty && !document) change({'outputFormat': 'jpg'});
    if (widget.capturePhoto != null) {
      final bytes = await widget.capturePhoto!();
      if (bytes != null) {
        await addImage(bytes, photo: !document, replaceKey: replaceKey);
      }
      return bytes != null;
    }
    final owner = await FlexDevice.channel.invokeMethod<String>(
      'pendingPhotoOwner',
    );
    if (owner != null &&
        !(await c.repository.dialogDrafts()).any((d) => d.id == owner)) {
      await FlexDevice.channel.invokeMethod<void>('discardPhoto', {
        'draftId': owner,
      });
    }
    change({
      'capturePending': true,
      'captureAsDocument': document,
      'captureReplaceKey': replaceKey,
    });
    await buffer.flush();
    final result = await FlexDevice.channel.invokeMapMethod<String, dynamic>(
      'capturePhoto',
      {'draftId': buffer.draft.id},
    );
    await acceptPhoto(result);
    return result != null;
  }

  Future<void> replacePage(int index) async {
    final page = pages[index];
    final source = await showDialog<String>(
      context: context,
      builder: (ctx) => FlexModal(
        title: Text('${page.photo ? 'Foto' : 'Seite'} ${index + 1} ersetzen'),
        onClose: () => Navigator.pop(ctx),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (nativeCamera || widget.capturePhoto != null)
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, 'camera'),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Neu aufnehmen'),
              ),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'file'),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Bild auswählen'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
    if (!mounted || source == null) return;
    if (source == 'file') {
      await pick(replaceKey: page.key);
    } else {
      await action(() async {
        await captureStill(document: !page.photo, replaceKey: page.key);
      });
    }
  }

  Future<void> captureSeries() => action(() async {
    final document = !photoOutput;
    while (mounted && pages.length < scanPageLimit) {
      if (!await captureStill(document: document) ||
          !mounted ||
          pages.length >= scanPageLimit) {
        break;
      }
      final bytes = await widget.files.read(pages.last.key);
      if (!mounted) return;
      final again = await showDialog<bool>(
        context: context,
        builder: (ctx) => FlexModal(
          title: Text('${pages.length} Aufnahmen'),
          onClose: () => Navigator.pop(ctx, false),
          content: SizedBox(
            height: 200,
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Fertig'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Nächste Aufnahme'),
            ),
          ],
        ),
      );
      if (again != true) break;
    }
  });

  Future<void> editPage(int index) => action(() async {
    final page = pages[index],
        bytes = await widget.files.read(pages[index].key);
    if (!mounted) return;
    setState(() => pageEditorOpen = true);
    final edited = await showFlexDetail<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ScanPageEditor(
        bytes: bytes,
        photo: page.photo,
        pageNumber: index + 1,
        width: page.width,
        height: page.height,
      ),
    );
    if (mounted) setState(() => pageEditorOpen = false);
    if (edited == null) return;
    final key = newId();
    await widget.files.write(key, edited['bytes'] as Uint8List);
    knownKeys.add(key);
    final next = pages;
    next[index] = ScanPage(
      key,
      edited['width'] as int,
      edited['height'] as int,
      photo: page.photo,
      captureToken: page.captureToken,
    );
    change({'pages': next.map((p) => p.toJson()).toList()});
    await buffer.flush();
    await cleanupPages([page.key]);
  });
  Future<void> deletePage(int index) => action(() async {
    final next = pages;
    removedIndex = index;
    removedPage = next.removeAt(index);
    change({'pages': next.map((p) => p.toJson()).toList()});
    await buffer.flush();
    // Keep removed bytes until save/close so an accidental removal is reversible.
  });
  Future<void> undoRemoval() => action(() async {
    if (removedPage == null || pages.length >= scanPageLimit) return;
    final next = pages;
    next.insert(removedIndex.clamp(0, next.length), removedPage!);
    change({'pages': next.map((p) => p.toJson()).toList()});
    await buffer.flush();
    if (mounted) setState(() => removedPage = null);
  });
  Future<void> movePage(int index, int step) => action(() async {
    final next = pages, item = next.removeAt(index);
    next.insert(index + step, item);
    change({'pages': next.map((p) => p.toJson()).toList()});
    await buffer.flush();
  });
  Future<void> reorderPage(int from, int to) => action(() async {
    final next = pages, item = next.removeAt(from);
    next.insert(to, item);
    change({'pages': next.map((p) => p.toJson()).toList()});
    await buffer.flush();
  });
  Future<void> filterPages() => action(() async {
    final originals = pages;
    if (originals.isEmpty) return;
    final choice = await showDialog<(String, Set<String>)>(
      context: context,
      builder: (_) => ScanBatchFilter(pages: originals, files: widget.files),
    );
    if (choice == null || !mounted) return;
    final (filter, selected) = choice;
    final undo = <String, ScanPage>{};
    // Stage all new pixels before switching the ordered draft references. A
    // failure retains the old pages; failed metadata writes remain retryable.
    final next = <ScanPage>[];
    for (final page in originals) {
      if (!selected.contains(page.key)) {
        next.add(page);
        continue;
      }
      setState(
        () => progress = 'Seite ${next.length + 1} von ${originals.length} …',
      );
      final result = await compute(editScanPixels, {
        'bytes': await widget.files.read(page.key),
        'filter': filter,
      });
      final key = newId();
      await widget.files.write(key, result['bytes'] as Uint8List);
      knownKeys.add(key);
      undo[key] = page;
      next.add(
        ScanPage(
          key,
          result['width'] as int,
          result['height'] as int,
          photo: page.photo,
          captureToken: page.captureToken,
        ),
      );
    }
    change({'pages': next.map((p) => p.toJson()).toList()});
    await buffer.flush();
    filterUndo
      ..clear()
      ..addAll(undo);
    // Keep the previous pixels until save/close for a lossless one-step undo.
  });
  Future<void> undoFilter() => action(() async {
    change({
      'pages': [
        for (final page in pages) (filterUndo[page.key] ?? page).toJson(),
      ],
    });
    await buffer.flush();
    filterUndo.clear();
  });

  Widget pageTiles() => LayoutBuilder(
    builder: (_, box) {
      final columns = pages.length == 1
          ? 1
          : (box.maxWidth /
                    (MediaQuery.textScalerOf(context).scale(1) > 1.5
                        ? 220
                        : 145))
                .floor()
                .clamp(1, 4);
      final width = (box.maxWidth - 10 * (columns - 1)) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final item in pages.indexed)
            DragTarget<int>(
              onWillAcceptWithDetails: (d) => !busy && d.data != item.$1,
              onAcceptWithDetails: (d) => reorderPage(d.data, item.$1),
              builder: (ctx, candidates, _) => LongPressDraggable<int>(
                data: item.$1,
                maxSimultaneousDrags: busy ? 0 : 1,
                feedback: Material(
                  elevation: 8,
                  child: SizedBox(
                    width: 100,
                    height: 130,
                    child: pagePreview(item.$2, item.$1, 100, 130),
                  ),
                ),
                child: SizedBox(
                  width: width,
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    color: candidates.isEmpty
                        ? null
                        : Theme.of(ctx).colorScheme.primaryContainer,
                    child: Column(
                      children: [
                        InkWell(
                          key: ValueKey('scan-edit-page-${item.$1}'),
                          onTap: busy ? null : () => editPage(item.$1),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                pagePreview(
                                  item.$2,
                                  item.$1,
                                  width - 16,
                                  pages.length == 1
                                      ? (MediaQuery.sizeOf(context).height *
                                                .38)
                                            .clamp(200, 440)
                                      : 160,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${item.$2.photo ? 'Foto' : 'Seite'} ${item.$1 + 1} · Bearbeiten',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Seite nach vorne',
                              onPressed: busy || item.$1 == 0
                                  ? null
                                  : () => movePage(item.$1, -1),
                              icon: const Icon(Icons.arrow_back, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Seite nach hinten',
                              onPressed: busy || item.$1 == pages.length - 1
                                  ? null
                                  : () => movePage(item.$1, 1),
                              icon: const Icon(Icons.arrow_forward, size: 20),
                            ),
                            IconButton(
                              key: ValueKey('scan-replace-page-${item.$1}'),
                              tooltip: 'Bild ersetzen',
                              onPressed: busy
                                  ? null
                                  : () => replacePage(item.$1),
                              icon: const Icon(Icons.find_replace, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Seite entfernen',
                              onPressed: busy
                                  ? null
                                  : () => deletePage(item.$1),
                              icon: const Icon(Icons.delete_outline, size: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget pagePreview(ScanPage page, int index, double width, double height) =>
      DocumentThumbnailView(
        identity: 'draft-page:${page.key}',
        title: '${page.photo ? 'Foto' : 'Seite'} ${index + 1}',
        fileKey: page.key,
        extension: 'jpg',
        files: widget.files,
        width: width,
        height: height,
      );

  Future<void> shareCurrent() => action(() async {
    await buffer.flush();
    final bytes = [for (final p in pages) await widget.files.read(p.key)];
    final name = title.text.trim().isEmpty ? 'Scan' : title.text.trim();
    final documents = photoOutput
        ? [
            for (final page in bytes.indexed)
              SharedDocument(
                scanFilename(
                  '$name${bytes.length == 1 ? '' : ' · ${page.$1 + 1}'}',
                  extension: 'jpg',
                ),
                page.$2,
                'image/jpeg',
              ),
          ]
        : [
            SharedDocument(
              scanFilename(name),
              await compute(scanPdf, bytes),
              'application/pdf',
            ),
          ];
    if (mounted) await sharePreparedDocuments(context, documents);
  });

  Future<void> save() => action(() async {
    await retainSourceCopy();
    if (nativeCamera && data['capturePending'] == true) await recoverPhoto();
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
      closeLabel: 'Schließen · Änderungen als Entwurf sichern',
      title: const Text('Scan & Foto'),
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
          if (busy && !pageEditorOpen) const LinearProgressIndicator(),
          if (progress.isNotEmpty) Text(progress),
          if (cameraNotice != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(cameraNotice!),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (removedPage != null)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                const Text('Seite entfernt'),
                TextButton.icon(
                  key: const ValueKey('scan-undo-remove'),
                  onPressed: busy || pages.length >= scanPageLimit
                      ? null
                      : undoRemoval,
                  icon: const Icon(Icons.undo),
                  label: const Text('Rückgängig'),
                ),
              ],
            ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('scan-title'),
            controller: title,
            enabled: !busy,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: 'Dateiname',
              counterText: '',
              suffixText: photoOutput ? '.jpg' : '.pdf',
            ),
            onChanged: (v) => change({'title': v}),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final format in const [
                ('pdf', 'PDF'),
                ('jpg', 'Fotos (JPG)'),
              ])
                ChoiceChip(
                  key: ValueKey('scan-format-${format.$1}'),
                  label: Text(format.$2),
                  selected: (data['outputFormat'] ?? 'pdf') == format.$1,
                  onSelected: busy
                      ? null
                      : (_) => change({'outputFormat': format.$1}),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${pages.length} ${pages.length == 1 ? 'Seite' : 'Seiten'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (pages.any((p) => filterUndo.containsKey(p.key)))
                IconButton(
                  tooltip: 'Stapelfilter rückgängig',
                  onPressed: busy ? null : undoFilter,
                  icon: const Icon(Icons.undo),
                ),
              if (pages.isNotEmpty)
                IconButton(
                  tooltip: 'Teilen',
                  onPressed: busy ? null : shareCurrent,
                  icon: const Icon(Icons.ios_share),
                ),
              if (pages.length > 1)
                IconButton(
                  key: const ValueKey('scan-batch-filter'),
                  tooltip: 'Seiten filtern',
                  onPressed: busy ? null : filterPages,
                  icon: const Icon(Icons.auto_fix_high),
                ),
              IconButton(
                tooltip: pageGrid ? 'Seiten als Liste' : 'Seiten als Raster',
                onPressed: () => setState(() => pageGrid = !pageGrid),
                icon: Icon(
                  pageGrid ? Icons.view_list_outlined : Icons.grid_view,
                ),
              ),
            ],
          ),
          if (pages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.document_scanner_outlined, size: 44),
                  SizedBox(height: 12),
                  Text(
                    'Dein Dokument beginnt hier',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Scannen, fotografieren oder eine Datei importieren.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          if (pageGrid)
            pageTiles()
          else
            ReorderableListView(
              key: const ValueKey('scan-page-order'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: busy ? (_, _) {} : reorderPage,
              children: [
                for (final item in pages.indexed)
                  Card(
                    key: ValueKey('scan-row-${item.$2.key}'),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              pagePreview(item.$2, item.$1, 88, 120),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.$2.photo ? 'Foto' : 'Seite'} ${item.$1 + 1}',
                                    ),
                                    Wrap(
                                      children: [
                                        ReorderableDragStartListener(
                                          index: item.$1,
                                          enabled: !busy,
                                          child: const Tooltip(
                                            message: 'Zum Umsortieren ziehen',
                                            child: Padding(
                                              padding: EdgeInsets.all(12),
                                              child: Icon(Icons.drag_handle),
                                            ),
                                          ),
                                        ),
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
                                              busy ||
                                                  item.$1 == pages.length - 1
                                              ? null
                                              : () => movePage(item.$1, 1),
                                          icon: const Icon(
                                            Icons.arrow_downward,
                                          ),
                                        ),
                                        IconButton(
                                          key: ValueKey(
                                            'scan-replace-page-${item.$1}',
                                          ),
                                          tooltip: 'Bild ersetzen',
                                          onPressed: busy
                                              ? null
                                              : () => replacePage(item.$1),
                                          icon: const Icon(Icons.find_replace),
                                        ),
                                        IconButton(
                                          tooltip: 'Seite entfernen',
                                          onPressed: busy
                                              ? null
                                              : () => deletePage(item.$1),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                    OutlinedButton.icon(
                                      key: ValueKey(
                                        'scan-edit-page-${item.$1}',
                                      ),
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
              ],
            ),
          const SizedBox(height: 16),
          const Divider(),
          const Text(
            'Zuordnung & Tags',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          MaterialTagEditor(
            key: const ValueKey('scan-tags'),
            values: List<String>.from(data['tags'] as List? ?? []),
            suggestions: materialTagUsage(c).keys,
            enabled: !busy,
            onChanged: (v) => change({'tags': v}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
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
                      ? (links.any((l) => l.kind.endsWith('Draft'))
                            ? 'Über Entwurf zugeordnet'
                            : 'FLEX-Klasse')
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
          if (data['sourceId'] != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vorhandene Datei ersetzen'),
              subtitle: Text(
                replace
                    ? 'Die lokale Fassung wird ersetzt. Bereits exportierte Kopien bleiben erhalten.'
                    : 'Es wird eine neue Kopie gespeichert.',
              ),
              value: replace,
              onChanged: busy
                  ? null
                  : (v) => setState(() => replace = v ?? false),
            ),
          DraftStatus(buffer: buffer),
        ],
      ),
      footerContent: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.capturePages != null ||
                  !kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                ScanTool(
                  key: const ValueKey('scanner-camera'),
                  onPressed: busy || pages.length >= scanPageLimit
                      ? null
                      : capture,
                  icon: Icons.document_scanner_outlined,
                  label: 'Scannen',
                ),
              if (widget.capturePhoto != null || nativeCamera)
                ScanTool(
                  key: const ValueKey('scanner-batch'),
                  onPressed: busy || pages.length >= scanPageLimit
                      ? null
                      : captureSeries,
                  icon: Icons.burst_mode_outlined,
                  label: 'Serie',
                ),
              if (widget.capturePhoto != null || nativeCamera)
                ScanTool(
                  key: const ValueKey('scanner-photo'),
                  onPressed: busy || pages.length >= scanPageLimit
                      ? null
                      : takePhoto,
                  icon: Icons.photo_camera_outlined,
                  label: data['capturePending'] == true ? 'Fortsetzen' : 'Foto',
                ),
              ScanTool(
                key: const ValueKey('scanner-import'),
                onPressed: busy || pages.length >= scanPageLimit ? null : pick,
                icon: Icons.add_photo_alternate_outlined,
                label: 'Import',
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              TextButton(
                onPressed: busy ? null : () => close(keepDraft: true),
                child: const Text('Später fortsetzen'),
              ),
              FilledButton.icon(
                key: const ValueKey('save-scan'),
                onPressed: busy || pages.isEmpty ? null : save,
                icon: Icon(photoOutput ? Icons.photo : Icons.picture_as_pdf),
                label: Text(
                  photoOutput
                      ? (replace ? 'Foto ersetzen' : 'Fotos speichern')
                      : (replace ? 'PDF ersetzen' : 'PDF speichern'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
