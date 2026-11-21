import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/core.dart';
import '../domain/week_folder.dart';
import '../ui/design.dart' show dayName, monthName, weekRange;

Future<Uint8List> weekFolderPdf(
  List<WeekDayFolder> week,
  String Function(String?) name,
) async {
  final fonts = await Future.wait([
    rootBundle.load('assets/fonts/Inter-Regular.ttf'),
    rootBundle.load('assets/fonts/Inter-Semibold.ttf'),
  ]);
  final doc = pw.Document(title: 'FLEX Wochenmappe', author: 'FLEX Desktop');
  const olive = PdfColor.fromInt(0xff526342);
  final heading = pw.TextStyle(fontWeight: pw.FontWeight.bold, color: olive);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(fonts.first),
        bold: pw.Font.ttf(fonts.last),
      ),
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 14),
        child: pw.Text('FLEX.   /   Wochenmappe', style: heading),
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${ctx.pageNumber} / ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
      build: (_) => [
        pw.Text(
          weekRange(week.first.day, week.last.day),
          style: heading.copyWith(fontSize: 20),
        ),
        for (final folder in week) ...[
          pw.SizedBox(height: 14),
          pw.Header(
            level: 2,
            text:
                '${dayName(folder.day)}, ${folder.day.day}. ${monthName(folder.day)}',
          ),
          if (folder.agenda.isEmpty && folder.materials.isEmpty)
            pw.Text('Keine Einträge', style: const pw.TextStyle(fontSize: 10)),
          for (final e in folder.agenda)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                [
                  if (e.time.isNotEmpty)
                    [e.time, if (e.end.isNotEmpty) e.end].join('–'),
                  calendarCategories[e.category],
                  e.title,
                  if (e.detail.isNotEmpty) e.detail,
                  if (e.done) 'Erledigt',
                ].nonNulls.join(' · '),
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          if (folder.materials.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 5, bottom: 4),
              child: pw.Text('Unterlagen', style: heading),
            ),
          for (final m in folder.materials)
            pw.Text(
              [
                m.title,
                materialDayOwners(m, dateOnly(folder.day), name),
              ].where((s) => s.isNotEmpty).join(' · '),
              style: const pw.TextStyle(fontSize: 10),
            ),
        ],
      ],
    ),
  );
  return doc.save();
}
