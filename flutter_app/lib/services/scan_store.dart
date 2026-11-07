import 'package:flutter/foundation.dart';

import '../domain/classroom.dart';
import '../domain/document_scanner.dart';
import '../domain/models.dart';
import '../domain/repository.dart';
import 'material_files.dart';
import 'scan_images.dart';

Future<void> removeUnusedScanFiles(
  NotebookRepository repo,
  MaterialFiles files,
  Iterable<String> keys,
) async {
  final docs = await repo.classroomDocuments();
  final drafts = await repo.dialogDrafts();
  final retained = {
    for (final d in docs) d.text('localKey'),
    for (final d in drafts)
      if (d.data['localKey'] is String) d.data['localKey'] as String,
    for (final d in drafts.where((d) => d.type == 'scan'))
      for (final p in d.data['pages'] as List) p['key'] as String,
  };
  for (final key
      in keys.where((k) => k.isNotEmpty && !retained.contains(k)).toSet()) {
    await files.remove(key);
  }
}

Future<void> discardScan(
  NotebookRepository repo,
  MaterialFiles files,
  DialogDraft draft,
) async {
  await repo.discardDialogDraft(draft.id, draft.revision);
  await removeUnusedScanFiles(
    repo,
    files,
    (draft.data['pages'] as List).map((p) => p['key'] as String),
  );
}

Future<ClassroomDocument> saveScan(
  NotebookRepository repo,
  MaterialFiles files,
  DialogDraft draft, {
  bool replace = false,
}) async {
  validateScanData(draft.data);
  final data = draft.data;
  final pages = (data['pages'] as List)
      .map((p) => ScanPage.fromJson(Json.from(p as Map)))
      .toList();
  if ((data['title'] as String).trim().isEmpty) {
    throw const DomainError('Bitte die PDF benennen.');
  }
  if (pages.isEmpty) {
    throw const DomainError('Bitte zuerst eine Seite scannen oder hinzufügen.');
  }
  ClassroomDocument? source;
  if (replace) {
    source = (await repo.classroomDocuments())
        .where((d) => d.id == data['sourceId'])
        .firstOrNull;
    if (source == null ||
        source.deleted ||
        source.revision != data['sourceRevision']) {
      throw const StaleRevision();
    }
  }
  final inputs = <Uint8List>[];
  var total = 0;
  for (final p in pages) {
    final bytes = await files.read(p.key);
    total += bytes.length;
    if (total > 40000000) {
      throw const DomainError(
        'Die Scanseiten sind zu groß. Bitte weniger Seiten speichern.',
      );
    }
    inputs.add(bytes);
  }
  final pdf = await compute(scanPdf, inputs);
  final key = newId();
  final fields = <String, dynamic>{
    'title': (data['title'] as String).trim(),
    'name': scanFilename(data['title'] as String),
    'documentType': data['documentType'],
    'subject': data['subject'],
    'pupilIds': data['pupilIds'],
    'links': data['links'],
    'extension': 'pdf',
    'localKey': key,
    'size': pdf.length,
    'scan': true,
    'pageCount': pages.length,
    // Editing creates a local PDF. It must never silently overwrite, refresh
    // from, or claim to be the original remote OneDrive file.
    'url': '', 'driveId': '', 'itemId': '', 'etag': '', 'sourcePath': '',
  };
  final document = source == null
      ? ClassroomDocument.create(
          ClassroomKind.material,
          fields['title'] as String,
          fields,
          id: draft.ownerId,
        )
      : source.patch(fields);
  await files.write(key, pdf);
  late ClassroomDocument saved;
  try {
    saved = await repo.saveClassroomDocument(document, draft: draft);
  } catch (_) {
    await files.remove(key);
    rethrow;
  }
  // The committed document survives a best-effort cleanup failure.
  try {
    await removeUnusedScanFiles(repo, files, [
      ...pages.map((p) => p.key),
      if (source != null) source.text('localKey'),
    ]);
  } catch (_) {}
  return saved;
}
