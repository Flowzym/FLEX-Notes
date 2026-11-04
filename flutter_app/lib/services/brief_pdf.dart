import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Uses embedded fonts and spanning paragraphs, so long notes continue on
/// following pages rather than overflowing or depending on installed fonts.
Future<Uint8List> briefPdf({
  required String text,
  required ByteData regularFont,
  required ByteData boldFont,
}) async {
  final regular = pw.Font.ttf(regularFont), bold = pw.Font.ttf(boldFont);
  final lines = text.split('\n');
  final title = lines.isEmpty ? 'Gesprächsvorbereitung' : lines.first;
  final blocks = <pw.Widget>[];
  for (final line in lines.skip(1)) {
    if (line.isEmpty) {
      blocks.add(pw.SizedBox(height: 8));
      continue;
    }
    blocks.add(
      pw.Text(
        line,
        overflow: pw.TextOverflow.span,
        style: pw.TextStyle(
          fontSize: 10,
          lineSpacing: 3,
          font: line == 'Nächste Schritte' ? bold : regular,
        ),
      ),
    );
  }
  final document = pw.Document(title: title, author: 'FLEX', compress: true);
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      maxPages: 2000,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 16),
        child: pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 16)),
      ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Text(
          'FLEX · ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (_) => blocks,
    ),
  );
  return document.save();
}
