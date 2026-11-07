// Synthetic classroom data shared by the browser fixture and UI journeys.
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/domain/timetable.dart';

Future<void> seedUiAudit(NotebookController c) async {
  await initializeFlexTimetable(c.repository);
  final today = dateOnly(DateTime.now());
  final tomorrow = dateOnly(DateTime.now().add(const Duration(days: 1)));
  for (var i = 0; i < 12; i++) {
    final name = [
      'Alex Beispiel',
      'Sam Muster',
      'Charlie Test',
      'Kim Beispiel mit langem Doppelnamen',
    ][i % 4];
    await c.repository.savePupil(
      Pupil(
        id: 'audit-p$i',
        name: '$name ${i + 1}',
        color: [0xff53747e, 0xff756582, 0xff6d8053][i % 3],
      ),
    );
    for (final kind in SchoolKind.values) {
      final record = SchoolRecord.empty(kind, 'audit-p$i').patch({
        'title': switch (kind) {
          SchoolKind.goal => 'Beginnt Aufgaben selbstständig',
          SchoolKind.social => 'Zusammenarbeit in der Gruppe',
          SchoolKind.work => 'Arbeiten mit dem Wochenplan',
          SchoolKind.homework => 'Englisch · More! Unit 3',
        },
        'body':
            'Synthetisches Beispiel: arbeitet nach kurzer Erinnerung selbstständig weiter.',
        if (kind == SchoolKind.goal) ...{
          'criterion': 'Startet in drei von vier Stunden ohne Erinnerung.',
          'nextReviewDate': tomorrow,
        },
        if (kind == SchoolKind.social) ...{
          'positive': ['Hilft anderen', 'Hält Gesprächsregeln ein'],
          'neutral': ['Beteiligt sich am Gespräch'],
          'negative': ['Unterbricht andere'],
        },
        if (kind == SchoolKind.work) 'neutral': ['Arbeitet an der Aufgabe'],
        if (kind == SchoolKind.homework) ...{
          'dueDate': today,
          'tasks': [
            {
              'id': 'vocabulary',
              'text': 'Vokabeln Unit 3 lernen',
              'status': 'open',
              'comment': '',
            },
            {
              'id': 'reading',
              'text': 'Workbook Seite 24, Aufgabe 1 und 2',
              'status': 'partial',
              'comment': '',
            },
          ],
        },
      });
      await c.repository.saveSchoolRecord(record);
    }
    await c.repository.saveEntry(
      OrgaEntry.empty(pupilId: 'audit-p$i').copyWith(
        title: 'Einverständnis Ausflug nachfragen',
        body: 'Rückmeldung bis Montag einholen.',
        isTask: true,
        dueDate: tomorrow,
      ),
    );
  }
  for (var i = 0; i < 9; i++) {
    final title = [
      'Kopien für Montag vorbereiten',
      'Idee für die Projektwoche',
      'Teamgespräch zur nächsten Unterrichtswoche',
    ][i % 3];
    await c.repository.saveEntry(
      OrgaEntry.empty().copyWith(
        title: title,
        body: title,
        isTask: i % 3 == 0,
        done: i == 6,
        dueDate: i % 3 == 0 ? today : null,
        appointmentDate: i % 3 == 2 ? today : null,
        appointmentTime: i % 3 == 2 ? '15:00' : '',
        items: i == 0
            ? [
                CheckItem(id: 'paper', text: 'Papier prüfen'),
                CheckItem(id: 'copies', text: 'Arbeitsblätter kopieren'),
              ]
            : [],
      ),
    );
  }
  final files = <ClassroomDocument>[];
  for (var i = 0; i < 8; i++) {
    final d = ClassroomDocument.create(
      ClassroomKind.material,
      [
        'Englisch · Unit 3 · Arbeitsblatt',
        'Lesetraining · Sachtexte',
        'Brüche verstehen',
      ][i % 3],
      {
        'extension': i.isEven ? 'pdf' : 'docx',
        'url': 'https://example.org/fixture-$i',
        'subject': ['Englisch', 'Deutsch', 'Mathematik'][i % 3],
        'tags': ['Arbeitsblatt', 'Übung'],
      },
    );
    files.add(d);
    await c.repository.saveClassroomDocument(d);
  }
  await c.repository.saveClassroomDocument(
    ClassroomDocument.create(
      ClassroomKind.returnList,
      'Wandertag · Einverständnis',
      {
        'type': 'consent',
        'dueDate': tomorrow,
        'materialIds': <String>[],
        'participants': [
          for (var i = 0; i < 12; i++)
            {
              'pupilId': 'audit-p$i',
              'name': 'Testkind ${i + 1}',
              'status': i < 4 ? 'yes' : 'open',
              'note': '',
              'paid': 0,
            },
        ],
      },
    ),
  );
  await c.repository.saveClassroomDocument(
    ClassroomDocument.create(ClassroomKind.materialSet, 'Englisch · Unit 3', {
      'materialIds': files.take(3).map((d) => d.id).toList(),
    }),
  );
  await c.repository.saveClassroomDocument(
    ClassroomDocument.create(ClassroomKind.plan, 'Englisch · Wochenplanung', {
      'materialIds': [files.first.id],
      'lessonIds': <String>[],
      'note': 'Wortschatz wiederholen, Dialoge üben und schreiben.',
    }),
  );

  await c.reload();
}
