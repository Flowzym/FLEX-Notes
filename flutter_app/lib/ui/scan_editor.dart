import '../domain/drive_rules.dart';
import 'scan_batch_filter.dart';
import 'share_documents.dart';
import '../services/material_sharing.dart';
import 'detail_flow.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:cryptography/cryptography.dart' show Sha256;
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
import '../domain/material_versions.dart';
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

part 'scan_editor_view.dart';

Future<ClassroomDocument?> showDocumentScanner(
  BuildContext context,
  NotebookController c, {
  ScanContext scope = const ScanContext(),
  DialogDraft? draft,
  ClassroomDocument? source,
  bool importOnOpen = false,
}) => showFlexDetail<ClassroomDocument>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ScanEditor(
    controller: c,
    scope: scope,
    draft: draft,
    source: source,
    importOnOpen: importOnOpen,
  ),
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
  if (link.kind == 'classroomDraft') {
    final draft = c.dialogDrafts.where((d) => d.id == link.id).firstOrNull;
    return 'Entwurf · ${draft?.data['title'] ?? 'Rücklauf'}';
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
                  'orgaDraft' ||
                  'schoolDraft' ||
                  'bulkDraft' ||
                  'classroomDraft' => 'Entwurf',
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
    this.importOnOpen = false,
  });
  final NotebookController controller;
  final bool importOnOpen;
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
  bool get collecting => data['collection'] == true;
  bool get photoOutput => data['outputFormat'] == 'jpg';
  bool get nativeCamera =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool busy = false, canPop = false, committed = false, replace = false;
  String? error;
  String progress = '';
  String? cameraNotice;
  ScanPage? removedPage;
  Map<String, ScanPage> get filterUndo => {
    for (final e in (data['filterUndo'] as Map? ?? {}).entries)
      e.key as String: ScanPage.fromJson(Json.from(e.value as Map)),
  };
  int removedIndex = 0;
  String scanError(Object e) {
    if (e is PlatformException &&
        {
          'scanner_unavailable',
          'scanner_busy',
          'scanner_read',
          'scanner_ack',
          'scanner_cleanup',
          'scanner_closed',
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
      return 'Die Kamerafunktion fehlt in dieser App-Version. Bitte FLEX aktualisieren oder ein Bild aus Dateien hinzufügen.';
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
        if (source.previewBeforeSharing) 'sourceRedacted': true,
        'sourceRevision': source.revision,
      };
    }
    title = TextEditingController(text: data['title'] as String);
    knownKeys.addAll(scanFileKeys(data));
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
    if (collecting &&
        nativeCamera &&
        widget.draft == null &&
        widget.initialImages.isEmpty &&
        !widget.importOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(capture());
      });
    }
    if (widget.importOnOpen &&
        source == null &&
        widget.draft == null &&
        widget.initialImages.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(pick());
      });
    }
    if (data['scanPending'] == true && nativeCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        action(recoverScan);
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
    data = {...data, ...patch, if (collecting) 'outputFormat': 'pdf'};
    if (data['filterUndo'] is Map) {
      final keys = pages.map((p) => p.key).toSet();
      data['filterUndo'] = {
        for (final e in (data['filterUndo'] as Map).entries)
          if (keys.contains(e.key)) e.key: e.value,
      };
    }
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
    List<dynamic>? nativeCorners,
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
    var page = ScanPage(
      key,
      image['width'] as int,
      image['height'] as int,
      photo: photo,
      captureToken: captureToken,
    );
    final undo = filterUndo;
    if (nativeCorners?.length == 4) {
      try {
        final cropped = await compute(transformScanPixels, {
          'bytes': image['bytes'],
          'corners': nativeCorners,
        });
        final croppedKey = newId();
        await widget.files.write(croppedKey, cropped['bytes'] as Uint8List);
        knownKeys.add(croppedKey);
        undo[croppedKey] = page;
        page = ScanPage(
          croppedKey,
          cropped['width'] as int,
          cropped['height'] as int,
          captureToken: captureToken,
        );
      } on DomainError {
        /* An uncertain outline keeps the complete original. */
      }
    }
    final next = pages;
    if (replacement < 0) {
      final parts = captureToken?.split('/');
      final later =
          parts != null && parts.length == 5 && parts.first == 'import'
          ? next.indexWhere((p) {
              final other = p.captureToken?.split('/');
              return other != null &&
                  other.length == 5 &&
                  other[0] == 'import' &&
                  other[1] == parts[1] &&
                  (other[2].compareTo(parts[2]) > 0 ||
                      other[2] == parts[2] &&
                          (int.tryParse(other.last) ?? 0) >
                              (int.tryParse(parts.last) ?? 0));
            })
          : -1;
      next.insert(later < 0 ? next.length : later, page);
    } else {
      next[replacement] = page;
    }
    change({
      'pages': next.map((p) => p.toJson()).toList(),
      'filterUndo': {for (final e in undo.entries) e.key: e.value.toJson()},
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

  // The slot identifies a file in its batch. The digest distinguishes a
  // corrected copy from a retry of identical bytes.
  Map<int, ScanPage> importedPages(String slot) => {
    for (final page in pages)
      if (page.captureToken?.startsWith(slot) == true)
        ?int.tryParse(page.captureToken!.split('/').last): page,
  };

  Future<void> finishImport(String slot, int count) async {
    final extra = importedPages(
      slot,
    ).entries.where((e) => e.key > count).map((e) => e.value.key).toSet();
    if (extra.isEmpty) return;
    final undo = filterUndo..removeWhere((key, _) => extra.contains(key));
    change({
      'pages': [
        for (final page in pages)
          if (!extra.contains(page.key)) page.toJson(),
      ],
      'filterUndo': {for (final e in undo.entries) e.key: e.value.toJson()},
    });
    await buffer.flush();
    await cleanupPages();
  }

  Future<void> addPdf(Uint8List bytes, {String? importToken}) async {
    final slot = importToken?.substring(0, importToken.lastIndexOf('/') + 1);
    final existing = slot == null ? <int, ScanPage>{} : importedPages(slot);
    var index = 0;
    await for (final image in importPdfPages(
      bytes,
      limit: scanPageLimit - pages.length + existing.length,
    )) {
      index++;
      final token = importToken == null ? null : '$importToken/$index';
      final previous = existing[index];
      if (token != null && previous?.captureToken == token) continue;
      if (mounted) {
        setState(() => progress = 'PDF-Seite $index wird eingelesen …');
      }
      await addImage(image, captureToken: token, replaceKey: previous?.key);
    }
    if (slot != null) await finishImport(slot, index);
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
            files.single.name.toLowerCase().endsWith('.pdf') ||
            files.single.mimeType == 'application/pdf')) {
      throw const DomainError(
        'Zum Ersetzen bitte genau ein Bild auswählen. PDFs über „Bilder / PDF hinzufügen“ ergänzen.',
      );
    }
    if (files.isEmpty) return;
    final batch = data['importBatchId'] as String? ?? newId();
    final names = List<String>.from(data['importNames'] as List? ?? []);
    final errors = Map<String, String>.from(data['importErrors'] as Map? ?? {});
    final successful = Set<int>.from(data['importSuccess'] as List? ?? []);
    final used = <int>{};
    final ready = <(int, XFile)>[];
    for (final (position, file) in files.indexed) {
      final name = file.name.isEmpty ? 'Datei ${position + 1}' : file.name;
      final matches = names.indexed
          .where((e) => e.$2 == name && !used.contains(e.$1))
          .map((e) => e.$1)
          .toList();
      final partialSelection =
          files.where((f) => f.name == name).length <
          names.where((v) => v == name).length;
      var slot =
          (partialSelection
              ? matches.where((i) => errors.containsKey('$i')).firstOrNull
              : null) ??
          matches.firstOrNull;
      if (slot == null) {
        slot = names.length;
        names.add(name);
      }
      used.add(slot);
      errors.remove('$slot');
      try {
        if (await file.length() > 20000000) {
          throw const DomainError('Größer als 20 MB');
        }
        ready.add((slot, file));
      } catch (e) {
        successful.remove(slot);
        errors['$slot'] = scanError(e);
      }
    }
    change({
      'importBatchId': batch,
      'importNames': names,
      'importErrors': errors,
    });
    for (final (slot, file) in ready) {
      final before = pages.map((p) => p.key).toList();
      try {
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in file.openRead()) {
          if (bytes.length + chunk.length > 20000000) {
            throw const DomainError('Größer als 20 MB');
          }
          bytes.add(chunk);
        }
        final content = bytes.takeBytes();
        final digest = (await Sha256().hash(
          content,
        )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        final prefix = "import/$batch/${slot.toString().padLeft(4, '0')}/";
        final token = '$prefix$digest';
        if (file.name.toLowerCase().endsWith('.pdf') ||
            file.mimeType == 'application/pdf') {
          await addPdf(content, importToken: token);
        } else {
          final previous = importedPages(prefix)[1];
          if (previous?.captureToken != '$token/1') {
            await addImage(
              content,
              photo: photoOutput,
              replaceKey: replaceKey ?? previous?.key,
              captureToken: '$token/1',
            );
          }
          await finishImport(prefix, 1);
        }
        successful.add(slot);
      } catch (e) {
        // If the draft write failed after adding a page, preserve the buffered
        // metadata and original file until the next explicit save.
        if (buffer.dirty &&
            !listEquals(before, pages.map((p) => p.key).toList())) {
          rethrow;
        }
        successful.remove(slot);
        errors['$slot'] = scanError(e);
      }
    }
    final failed = [
      for (var i = 0; i < names.length; i++)
        if (errors.containsKey('$i')) '${names[i]} – ${errors['$i']}',
    ];
    final complete = failed.isEmpty;
    change({
      'importBatchId': complete ? null : batch,
      'importNames': complete ? [] : names,
      'importErrors': complete ? {} : errors,
      'importSuccess': complete ? [] : successful.toList(),
      'importFailures': failed,
    });
    await buffer.flush();
    if (!complete && mounted) {
      setState(
        () => error =
            '${successful.length} ${successful.length == 1 ? 'Datei' : 'Dateien'} übernommen · ${failed.length} ausständig',
      );
    }
  });

  Future<void> capture({
    String? replaceKey,
    bool photo = false,
  }) => action(() async {
    // The native document camera detects boundaries before taking the shot.
    // Series and replacement must use this path too, not the plain photo intent.
    await buffer.flush(force: true);
    final remaining = replaceKey == null ? scanPageLimit - pages.length : 1;
    if (remaining < 1) {
      throw const DomainError('Pro PDF sind bis zu 25 Seiten möglich.');
    }
    List<Uint8List>? values;
    try {
      if (widget.capturePages != null) {
        values = await widget.capturePages!(remaining);
      } else {
        change({'scanPending': true, 'scanReplaceKey': replaceKey});
        await buffer.flush(force: true);
        final captured = await FlexDevice.channel.invokeListMethod<dynamic>(
          'scanDocument',
          {'limit': remaining, 'draftId': buffer.draft.id, 'photo': photo},
        );
        await acceptNativeScans(captured);
        return;
      }
    } on PlatformException catch (e) {
      if (e.code != 'scanner_unavailable' || !nativeCamera) rethrow;
      // No native session was created. A fallback photo has its own durable
      // recovery flag and must not also recover a nonexistent scan session.
      change({'scanPending': false, 'scanReplaceKey': null});
      await buffer.flush(force: true);
      if (!mounted) return;
      final usePhoto = await showDialog<bool>(
        context: context,
        builder: (ctx) => FlexModal(
          title: Text(
            photo
                ? 'Kamera nicht verfügbar'
                : 'Live-Randerkennung nicht verfügbar',
          ),
          onClose: () => Navigator.pop(ctx, false),
          content: Text(
            photo
                ? 'Die Kamera konnte nicht starten. Prüfe den Kamerazugriff in den Android-App-Einstellungen. Alternativ kannst du die Kamera-App deines Handys verwenden.'
                : 'Die Dokumentkamera konnte nicht starten. Prüfe den Kamerazugriff in den Android-App-Einstellungen und versuche es erneut. Alternativ kannst du ein Foto aufnehmen und die Ränder anschließend anpassen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Zurück'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(photo ? 'Kamera-App öffnen' : 'Ohne Randerkennung'),
            ),
          ],
        ),
      );
      if (usePhoto == true && mounted) {
        setState(
          () => cameraNotice = photo
              ? 'Aufnahme mit der Kamera-App.'
              : 'Foto ohne Live-Randerkennung · Zuschnitt unter Bearbeiten.',
        );
        await captureStill(document: !photo, replaceKey: replaceKey);
      }
      buffer.change(data);
      await buffer.flush();
      return;
    }
    if (values == null) {
      buffer.change(data);
      await buffer.flush();
      return;
    }
    if (values.length > remaining) {
      throw const DomainError('Die Kamera hat zu viele Seiten zurückgegeben.');
    }
    if (mounted) setState(() => cameraNotice = null);
    for (final bytes in values) {
      await addImage(bytes, replaceKey: replaceKey);
    }
  });
  Future<void> recoverScan() async {
    final result = await FlexDevice.channel.invokeListMethod<dynamic>(
      'recoverScan',
      {'draftId': buffer.draft.id},
    );
    await acceptNativeScans(result);
  }

  Future<void> acceptNativeScans(List<dynamic>? result) async {
    if ((result?.length ?? 0) > scanPageLimit) {
      throw const DomainError('Zu viele Aufnahmen.');
    }
    if (pages.isEmpty &&
        result != null &&
        result.isNotEmpty &&
        data['sourceId'] == null) {
      change({
        'outputFormat':
            result.every((value) => value is Map && value['photo'] == true)
            ? 'jpg'
            : 'pdf',
      });
    }
    for (final value in result ?? const []) {
      if (value is! Map ||
          value['token'] is! String ||
          value['bytes'] is! Uint8List) {
        throw const DomainError('Ungültige Kameraaufnahme.');
      }
      final token = value['token'] as String;
      if (!pages.any((p) => p.captureToken == token)) {
        await addImage(
          value['bytes'] as Uint8List,
          captureToken: token,
          photo: value['photo'] == true,
          nativeCorners: value['photo'] == true
              ? null
              : value['corners'] as List?,
          replaceKey: data['scanReplaceKey'] as String?,
        );
        change({'scanReplaceKey': null});
      }
      await buffer.flush();
      await FlexDevice.channel.invokeMethod<void>('finishScanPage', {
        'draftId': buffer.draft.id,
        'token': token,
      });
    }
    change({'scanPending': false, 'scanReplaceKey': null});
    await buffer.flush();
    if (mounted) {
      setState(
        () => cameraNotice = filterUndo.isEmpty
            ? null
            : 'Ränder automatisch zugeschnitten · über „Bearbeitung zurücknehmen“ wiederherstellbar.',
      );
    }
  }

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

  Future<void> takePhoto() => nativeCamera && widget.capturePhoto == null
      ? capture(photo: true)
      : action(() async {
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
    } else if (nativeCamera && widget.capturePhoto == null ||
        !page.photo && widget.capturePages != null) {
      await capture(replaceKey: page.key, photo: page.photo);
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
    change({
      'pages': next.map((p) => p.toJson()).toList(),
      if (edited['redacted'] == true) 'redacted': true,
    });
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
    change({
      'pages': next.map((p) => p.toJson()).toList(),
      'filterUndo': {for (final e in undo.entries) e.key: e.value.toJson()},
    });
    await buffer.flush();
    await cleanupPages();
  });
  Future<void> undoFilter() => action(() async {
    change({
      'pages': [
        for (final page in pages) (filterUndo[page.key] ?? page).toJson(),
      ],
      'filterUndo': <String, dynamic>{},
    });
    await buffer.flush();
    await cleanupPages();
  });

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
    if (mounted) {
      await sharePreparedDocuments(
        context,
        documents,
        previewIndices: {
          if (data['redacted'] == true ||
              data['sourceRedacted'] == true ||
              widget.source?.previewBeforeSharing == true)
            ...List.generate(documents.length, (i) => i),
        },
      );
    }
  });

  Future<void> save() => action(() async {
    final discard =
        replace && data['redacted'] == true && data['discardVersions'] != false;
    if (discard &&
        !await confirmFlex(
          context,
          'Original und frühere Versionen entfernen?',
          'Die geschwärzte Datei ersetzt dieses Dokument. Seine bisherigen Versionen werden entfernt. '
              'Andere Kopien, offene Entwürfe und bereits erstellte Sicherungen bleiben unverändert.',
          accept: 'Ersetzen und entfernen',
        )) {
      return;
    }
    if (!mounted) return;
    await retainSourceCopy();
    if (nativeCamera && data['capturePending'] == true) await recoverPhoto();
    await buffer.flush();
    var cleanupFailed = false;
    final saved = await saveScan(
      c.repository,
      widget.files,
      buffer.draft,
      replace: replace,
      discardVersions: discard,
      onCleanupFailure: () => cleanupFailed = true,
    );
    committed = true;
    await cleanupPages();
    await c.reload();
    if (cleanupFailed && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Datei gespeichert. Einige alte Dateien konnten noch nicht entfernt werden.',
          ),
        ),
      );
    }
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

  void updateScanView(VoidCallback work) => setState(work);
  @override
  Widget build(BuildContext context) => scannerView(context);
}
