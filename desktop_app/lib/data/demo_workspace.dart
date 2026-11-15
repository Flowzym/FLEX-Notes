import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/core.dart';

/// Explicit demo mode uses a different database, never the user's workspace.
Future<void> seedDemo(
  NotebookController c,
  MaterialFiles files,
  DateTime day,
) async {
  if (c.pupils.isNotEmpty || c.entries.isNotEmpty || c.classroom.isNotEmpty) {
    return;
  }
  final pupils = [
    for (final name in [
      'Aylin Demir',
      'Emil Berger',
      'Hanna Reiter',
      'Ivan Petrovic',
      'Lara Koller',
      'Leon Hofer',
      'Mia Steiner',
      'Noah Wagner',
    ])
      Pupil(id: newId(), name: name),
  ];
  final materials = <ClassroomDocument>[];
  for (final (title, subject) in [
    ('Brüche entdecken', 'Mathematik'),
    ('My school day', 'Englisch'),
    ('Lesetagebuch', 'Deutsch'),
    ('Elterninformation Ausflug', 'Organisation'),
  ]) {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'FLEX. / DEMOMATERIAL',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 40),
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text('$subject - Arbeitsblatt'),
            pw.SizedBox(height: 35),
            for (var i = 1; i <= 4; i++) ...[
              pw.Text(
                '$i. Bearbeite die Aufgabe und beschreibe deinen Loesungsweg.',
              ),
              pw.SizedBox(height: 70),
              pw.Divider(color: PdfColors.grey300),
            ],
          ],
        ),
      ),
    );
    final bytes = await pdf.save(), key = newId();
    await files.write(key, bytes);
    materials.add(
      ClassroomDocument.create(ClassroomKind.material, title, {
        'name': '$title.pdf',
        'extension': 'pdf',
        'size': bytes.length,
        'localKey': key,
        'subject': subject,
        'documentType': 'worksheet',
        'tags': [subject],
        'pupilIds': [pupils.first.id],
        'pupilDates': [
          {'pupilId': pupils.first.id, 'date': dateOnly(day)},
        ],
      }),
    );
  }
  final plan = ClassroomDocument.create(ClassroomKind.plan, 'Brüche im Alltag', {
    'date': dateOnly(day),
    'subject': 'Mathematik',
    'status': 'planned',
    'note':
        'Einstieg · 10 Min: Brüche im Alltag sammeln.\nArbeitsphase · 25 Min: In Partnerarbeit Brüche legen und vergleichen.\nAbschluss · 10 Min: Einen Lösungsweg vorstellen.',
    'materialIds': [materials.first.id],
    'pupilIds': pupils.take(4).map((p) => p.id).toList(),
  });
  final returns = ClassroomDocument.create(
    ClassroomKind.returnList,
    'Einverständnis · Museum',
    {
      'type': 'consent',
      'dueDate': dateOnly(day.add(const Duration(days: 3))),
      'note': 'Rückmeldungen zum gemeinsamen Museumsbesuch.',
      'materialIds': [materials.last.id],
      'participants': [
        for (var i = 0; i < pupils.length; i++)
          {
            'pupilId': pupils[i].id,
            'name': pupils[i].name,
            'status': i < 5 ? 'yes' : 'open',
            'paid': 0,
            'note': '',
          },
      ],
    },
  );
  final docs = [...materials, plan, returns];
  for (var i = 0; i < 5; i++) {
    final d = day.add(Duration(days: i));
    docs.add(
      ClassroomDocument.create(ClassroomKind.lesson, 'Flex · Lernzeit', {
        'date': dateOnly(d),
        'start': '08:00',
        'end': '09:40',
        'subject': 'Freies Lernen',
        'room': 'FLEX-Klasse',
        'materialIds': [materials.first.id],
      }),
    );
    docs.add(
      ClassroomDocument.create(
        ClassroomKind.lesson,
        i.isEven ? 'Englisch' : 'Deutsch',
        {'date': dateOnly(d), 'start': '10:00', 'end': '10:50'},
      ),
    );
  }
  for (final p in pupils) {
    await c.repository.savePupil(p);
  }
  await c.repository.saveClassroomDocuments(docs);
  for (var i = 0; i < 5; i++) {
    await c.repository.saveSchoolRecord(
      SchoolRecord.empty(
        i.isEven ? SchoolKind.social : SchoolKind.work,
        pupils[i].id,
      ).patch({
        'body': [
          'Unterstützt die Partnergruppe beim Einstieg.',
          'Arbeitet konzentriert am eigenen Wochenziel.',
          'Fragt nach, wenn ein Schritt unklar ist.',
          'Bearbeitet die Aufgaben zunehmend selbstständig.',
          'Bringt eine eigene Lösung in die Runde ein.',
        ][i],
        'observedOn': dateOnly(day),
        'positive': i.isEven ? ['Arbeitet selbstständig'] : <String>[],
      }),
    );
  }
  await c.repository.saveSchoolRecord(
    SchoolRecord.empty(SchoolKind.homework, pupils.first.id).patch({
      'title': 'Brüche üben',
      'subject': 'Mathematik',
      'dueDate': dateOnly(day),
      'tasks': [
        HomeworkTask(id: newId(), text: 'Seite 42, Aufgaben 1 und 2').toJson(),
        HomeworkTask(id: newId(), text: 'Ein eigenes Beispiel finden').toJson(),
      ],
    }),
  );
  await c.repository.saveSchoolRecord(
    SchoolRecord.empty(SchoolKind.goal, pupils[1].id).patch({
      'title': 'Den Arbeitsbeginn selbst organisieren',
      'body': 'Material bereitlegen und den ersten Schritt auswählen.',
      'nextReviewDate': dateOnly(day.add(const Duration(days: 4))),
    }),
  );
  for (final (title, offset) in [
    ('Material für morgen bereitlegen', 0),
    ('Ausflug: Rückmeldungen prüfen', 2),
    ('Lesetagebücher durchsehen', -2),
  ]) {
    await c.repository.saveEntry(
      OrgaEntry.empty().copyWith(
        title: title,
        isTask: true,
        dueDate: dateOnly(day.add(Duration(days: offset))),
      ),
    );
  }
  await c.repository.saveEntry(
    OrgaEntry.empty(pupilId: pupils.first.id).copyWith(
      title: 'Lernentwicklungsgespräch',
      appointmentDate: dateOnly(day.add(const Duration(days: 1))),
      appointmentTime: '11:00',
      appointmentEndTime: '11:45',
      tags: ['Gespräch'],
    ),
  );
  await c.reload();
}
