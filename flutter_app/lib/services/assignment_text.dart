import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';
import '../domain/assignment_sources.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';
import 'docx_preview.dart';
import 'material_files.dart';

List<String> assignmentParagraphs(Iterable<String> values) => {
  for (final value in values)
    for (final line in value.split(RegExp(r'[\r\n]+')))
      if (line.trim().isNotEmpty && line.trim().length <= 4000) line.trim(),
}.take(300).toList();

Future<List<AssignmentSource>> readAssignmentText(
  ClassroomDocument document,
  MaterialFiles files,
) async {
  List<AssignmentSource> from(Iterable<String> texts, {int? page}) => [
    for (final text in assignmentParagraphs(texts))
      AssignmentSource(
        documentId: document.id,
        title: document.title,
        text: text,
        page: page,
      ),
  ];
  if (document.kind == ClassroomKind.plan) return from([document.text('note')]);
  final bytes = await files.read(document.text('localKey'));
  validateMaterialBytes(bytes, document.text('extension'));
  if (document.text('extension') == 'docx') {
    final blocks = await compute(readDocxPreview, bytes);
    return from([
      for (final b in blocks)
        if (b['type'] == 'table') ...[
          for (final row in b['rows'] as List) (row as List).join(' · '),
        ] else
          b['text'] as String,
    ]);
  }
  if (document.text('extension') != 'pdf') return [];
  await pdfrxFlutterInitialize();
  final pdf = await PdfDocument.openData(
    bytes,
    passwordProvider: () async => null,
  );
  try {
    if (pdf.pages.length > 100) {
      throw const DomainError(
        'Bitte für die Aufgabenauswahl eine Planung mit höchstens 100 Seiten verwenden.',
      );
    }
    final result = <AssignmentSource>[];
    for (final page in pdf.pages) {
      result.addAll(
        from([
          (await page.loadStructuredText()).fullText,
        ], page: page.pageNumber),
      );
      if (result.length >= 300) break;
    }
    return result.take(300).toList();
  } finally {
    await pdf.dispose();
  }
}
