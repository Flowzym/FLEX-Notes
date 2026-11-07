import 'package:flex_device/flex_device.dart';
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
  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      draft.data['capturePending'] == true) {
    await FlexDevice.channel.invokeMethod<void>('discardPhoto', {
      'draftId': draft.id,
    });
  }
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
    throw const DomainError('Bitte die Datei benennen.');
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
  final photo = data['outputFormat'] == 'jpg';
  if (replace && photo && pages.length != 1) {
    throw const DomainError(
      'Zum Ersetzen eines Fotos bitte genau ein Bild behalten.',
    );
  }
  final outputs = photo ? inputs : [await compute(scanPdf, inputs)];
  final keys = <String>[];
  final documents = <ClassroomDocument>[];
  late ClassroomDocument saved;
  try {
    for (final item in outputs.indexed) {
      final key = newId();
      keys.add(key);
      final title =
          '${(data['title'] as String).trim()}${outputs.length > 1 ? ' · ${item.$1 + 1}' : ''}';
      final fields = <String, dynamic>{
        'title': title,
        'name': scanFilename(title, extension: photo ? 'jpg' : 'pdf'),
        'documentType': data['documentType'], 'subject': data['subject'],
        'pupilIds': data['pupilIds'],
        'links': data['links'],
        'tags': data['tags'] ?? <String>[],
        'extension': photo ? 'jpg' : 'pdf',
        'localKey': key,
        'size': item.$2.length,
        'scanner': true, 'scan': !photo, 'pageCount': photo ? 1 : pages.length,
        // Edited files are local copies, independent of remote originals.
        'url': '', 'driveId': '', 'itemId': '', 'etag': '', 'sourcePath': '',
      };
      documents.add(
        source == null
            ? ClassroomDocument.create(
                ClassroomKind.material,
                title,
                fields,
                id: item.$1 == 0 ? draft.ownerId : newId(),
              )
            : source.patch(fields),
      );
      await files.write(key, item.$2);
    }
    if (documents.length == 1) {
      saved = await repo.saveClassroomDocument(documents.single, draft: draft);
    } else {
      await repo.saveClassroomDocuments(documents, draft: draft);
      saved = documents.first.patch({'revision': 1});
    }
  } catch (_) {
    for (final key in keys) {
      try {
        await files.remove(key);
      } catch (_) {}
    }
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
