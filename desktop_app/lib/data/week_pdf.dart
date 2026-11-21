import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/core.dart';
import '../domain/week_folder.dart';
import '../ui/design.dart' show dayName, monthName, weekRange;

Future<Uint8List> weekFolderPdf(
  List<WeekDayFolder> week,
  String Function(String?) name, {
  Iterable<Pupil> pupils = const [],
  bool grouped = false,
}) async {
  final regular = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/Inter-Semibold.ttf');
  final doc = pw.Document(title: 'FLEX Wochenmappe', author: 'FLEX Desktop');
  const olive = PdfColor.fromInt(0xff526342);
  final heading = pw.TextStyle(fontWeight: pw.FontWeight.bold, color: olive);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
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
          if (grouped)
            for (final g in pupilFileGroups(
              folder.materials,
              pupils,
              (m) => materialOwnerIds(m, day: dateOnly(folder.day)),
            )) ...[
              pw.Text(g.name, style: heading),
              for (final m in g.files)
                pw.Text(m.title, style: const pw.TextStyle(fontSize: 10)),
            ]
          else
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
