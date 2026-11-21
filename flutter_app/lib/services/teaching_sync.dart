import 'package:flutter/foundation.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';
import '../domain/repository.dart';
import '../domain/planning_import.dart';
import '../domain/teaching_sheet.dart';
import 'material_cache.dart';
import 'material_files.dart';
import 'onedrive.dart';
import 'teaching_sheet_reader.dart';
import 'teaching_exchange.dart';

Future<ClassroomDocument> readTeachingSource(
  NotebookRepository repo,
  OneDriveClient reader,
  MaterialFiles files,
  ClassroomDocument m,
) async {
  final cached = sheetUsable(m) && await files.exists(m.text('localKey'));
  if (cached && m.map('planSheet')['parser'] == 2) return m;
  final source = cached ? m : await cacheDriveMaterial(repo, m, reader, files);
  final sheet = <String, dynamic>{
    'parser': 2,
    'stamp': sourceStamp(source),
    'drive': source.text('driveId'),
    'item': source.text('itemId'),
    'rows': <Json>[],
  };
  if (source.text('extension') == 'docx') {
    final bytes = await files.read(source.text('localKey'));
    try {
      sheet['rows'] = await compute(readTeachingRows, bytes);
      validateTeachingSheet(sheet);
    } catch (_) {
      final old = m.map('planSheet');
      if (sheetList(old, 'rows').isNotEmpty) {
        return repo.saveClassroomDocument(
          source.patch({
            'planSheet': {
              ...old,
              'parser': 1,
              'issue':
                  'Die neue Fassung konnte nicht gelesen werden. Der letzte lesbare Plan ist gespeichert.',
            },
          }),
        );
      }
      sheet['rows'] = <Json>[];
      sheet['issue'] =
          'Die Tabellen konnten nicht vollständig gelesen werden. Bitte das Original prüfen.';
    }
  } else {
    sheet['issue'] =
        'Für dieses Format steht das Original bereit. Tabellen lassen sich aus einer DOCX-Planung übernehmen.';
  }
  final edits = source.map('planEdits');
  return repo.saveClassroomDocument(
    source.patch({
      'planSheet': sheet,
      if (edits.isNotEmpty)
        'planEdits': rebaseTeachingEdits(
          sheetList(m.map('planSheet'), 'rows'),
          sheetList(sheet, 'rows'),
          edits,
        ),
    }),
  );
}

Future<int> syncTeachingSources(
  NotebookRepository repo,
  OneDriveClient reader,
  OneDriveClient? writer,
  MaterialFiles files,
  String account,
  Set<String> ruleIds,
  Set<String> archived,
  List<String> errors,
) async {
  final docs = await repo.classroomDocuments(), pupils = await repo.pupils();
  final sources = docs
      .where(
        (d) =>
            !archived.contains(d.id) &&
            isTeachingSource(d) &&
            d.text('driveId') == account &&
            ruleIds.contains(d.text('cloudRule')) &&
            {'docx', 'pdf'}.contains(d.text('extension')),
      )
      .toList();
  if (sources.isEmpty) return 0;
  final now = schoolDay(dateOnly(DateTime.now()));
  int distance(ClassroomDocument m) =>
      DateTime.tryParse(
        teachingDay(m).isEmpty ? teachingWeek(m) : teachingDay(m),
      )?.difference(now).inDays.abs() ??
      99999;
  sources.sort((a, b) => distance(a).compareTo(distance(b)));
  TeachingExchange? exchange;
  if (writer?.connected == true) {
    try {
      final client = await TeachingExchange.open(writer!, account);
      await client.listAvailable();
      exchange = client;
    } catch (e) {
      errors.add(
        e is DomainError
            ? e.message
            : 'Planstände konnten nicht abgeglichen werden.',
      );
    }
  }
  final linked = <String>{};
  var parsed = 0;
  for (final source in sources) {
    try {
      var current = await readTeachingSource(repo, reader, files, source);
      if (current.revision != source.revision) parsed++;
      if (exchange != null) {
        final folder = docs
            .where((d) => d.id == source.text('cloudRule'))
            .firstOrNull;
        if (folder != null) {
          current = await exchange.pull(repo, current, folder);
        }
      }
      if (distance(source) <= 7) {
        final resolver = TeachingLinks(current, docs, pupils);
        for (final r in teachingRows(current)) {
          linked.addAll(resolver.rowMaterials(r));
        }
      }
    } catch (e) {
      errors.add(
        '${source.title} · ${e is DomainError ? e.message : 'Planung konnte nicht geladen werden.'}',
      );
    }
  }
  // Most urgently needed sheets go offline automatically. Respect a bounded
  // transfer per sync. A later run skips cached items and continues the queue.
  var budget = 40000000, downloads = 0;
  for (final m in docs.where(
    (m) =>
        linked.contains(m.id) &&
        !archived.contains(m.id) &&
        m.text('extension') != 'link',
  )) {
    if (downloads >= 16) break;
    if (m.text('localKey').isNotEmpty &&
        m.text('etag') == m.text('remoteEtag') &&
        await files.exists(m.text('localKey'))) {
      continue;
    }
    if (m.number('size') > budget) continue;
    try {
      final cached = await cacheDriveMaterial(repo, m, reader, files);
      budget -= cached.number('size');
      downloads++;
    } catch (e) {
      errors.add('${m.title} · Offlinekopie ausstehend');
    }
  }
  return parsed;
}
