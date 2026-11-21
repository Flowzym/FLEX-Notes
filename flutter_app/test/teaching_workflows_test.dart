import 'dart:typed_data';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/calendar.dart';
import 'package:flex_notizbuch/ui/general_orga_page.dart';
import 'package:flex_notizbuch/ui/material_library.dart' show browseOneDrive;
import 'package:flex_notizbuch/ui/share_documents.dart';
import 'package:flex_notizbuch/services/material_sharing.dart';
import 'package:flex_notizbuch/domain/material_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/ui/school_workspace.dart' show showBrief;
import 'package:flex_notizbuch/ui/scan_editor.dart' show ScanEditor;
import 'classroom_test.dart' show classroomMemory;
import 'document_scanner_test.dart' show scannerImage;
import 'material_workspace_test.dart' show MemoryMaterialFiles, FolderDrive;

class NamedPhoto extends XFile {
  NamedPhoto(this.name, Uint8List bytes, {this.oversized = false})
    : super.fromData(bytes, mimeType: 'image/jpeg');
  @override
  final String name;
  final bool oversized;
  @override
  Future<int> length() => oversized ? Future.value(20000001) : super.length();
}

const pupil = Pupil(id: 'review-p', name: 'Testperson');
Future<NotebookController> setup() async {
  final c = NotebookController(classroomMemory());
  await c.initialize();
  await c.savePupil(pupil);
  addTearDown(() async {
    c.dispose();
    await c.repository.close();
  });
  return c;
}

Future<void> host(WidgetTester t, void Function(BuildContext) open) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => open(ctx),
            child: const Text('Öffnen'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('Öffnen'));
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> waitFor(WidgetTester t, bool Function() ready) async {
  for (var i = 0; i < 140; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await t.pump(const Duration(milliseconds: 50));
    if (ready()) return;
  }
  fail(
    'Zielzustand fehlt: ${t.widgetList<Text>(find.byType(Text)).map((v) => v.data).join(' | ')}',
  );
}

void main() {
  testWidgets('Ziel mit Überprüfung auswählen und Gesprächsvorschau lesen', (
    t,
  ) async {
    final c = await setup();
    const review = GoalReview(
      id: 'r',
      observedOn: '2026-11-12',
      decision: 'continue',
      note: 'Zeilen bereits selbst gelesen',
      nextStep: 'Beim nächsten Mal gemeinsam vorlesen',
      nextReviewDate: '2026-11-22',
    );
    final goal = SchoolRecord.empty(SchoolKind.goal, pupil.id).patch({
      'observedOn': '2026-10-06',
      'title': 'Lesen üben',
      'criterion': 'Eine Seite lesen',
      'nextReviewDate': '2026-11-22',
      'reviews': [review.toJson()],
    });
    await c.saveRecord(goal);
    await host(
      t,
      (ctx) => showBrief(
        ctx,
        c,
        pupil,
        initialSelection: {goal.id},
        initialTo: '2026-11-18',
      ),
    );
    await t.pumpAndSettle();
    final select = find.text('Auswahl zusammenstellen');
    await t.ensureVisible(select);
    await t.tap(select);
    await t.pumpAndSettle();
    final text = t
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((w) => w.data ?? '')
        .join(' ');
    expect(text, contains('Eine Seite lesen'));
    expect(text, contains(review.note));
    expect(text, contains(review.nextStep));
  });

  testWidgets(
    'alle Formulare retour, Kalender und Aufgabenfilter vergleichen',
    (t) async {
      final c = await setup();
      final doc = ClassroomDocument.create(
        ClassroomKind.returnList,
        'Ausflug Formular',
        {
          'type': 'form',
          'dueDate': '2026-11-18',
          'closed': false,
          'participants': [
            {
              'pupilId': pupil.id,
              'name': pupil.name,
              'status': 'received',
              'note': '',
              'paid': 0,
            },
          ],
        },
      );
      await c.saveClassroom(doc);
      final event = calendarItems(
        c.currentSnapshot,
        '2026-11-18',
        '2026-11-18',
      ).single;
      expect(event.done, true);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeneralOrgaPage(
              controller: c,
              kind: 'task',
              onEdit: (_) async {},
              onEditDraft: (_) {},
              entryBuilder: (_) => const SizedBox(),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Offen'));
      await t.pumpAndSettle();
      expect(find.text('Ausflug Formular'), findsNothing);
      await t.tap(find.text('Erledigt'));
      await t.pumpAndSettle();
      expect(find.text('Ausflug Formular'), findsOneWidget);
    },
  );

  testWidgets(
    'OneDrive-Ordnersuche und gemeinsame Zuordnung über zwei Ordner behalten das Einsatzdatum',
    (t) async {
      final c = await setup();
      final drive = FolderDrive({
        'root': [
          {
            'id': 'a',
            'name': 'Lesen.pdf',
            'size': 10,
            'webUrl': 'https://example.org/a',
          },
          {
            'id': 'unter',
            'name': 'Textarbeit',
            'folder': {},
            'webUrl': 'https://example.org/f',
          },
        ],
        'unter': [
          {
            'id': 'b',
            'name': 'Fragen.docx',
            'size': 20,
            'webUrl': 'https://example.org/b',
          },
        ],
      });
      addTearDown(drive.dispose);
      final folder = ClassroomDocument.create(ClassroomKind.folder, 'Klasse', {
        'driveId': 'drive',
        'itemId': 'root',
        'url': 'https://example.org/f',
      });
      await host(t, (ctx) => browseOneDrive(ctx, c, drive, folder: folder));
      await t.pumpAndSettle();
      Future<void> tap(Finder target) async {
        await t.ensureVisible(target);
        await t.tap(target);
        await t.pumpAndSettle();
      }

      await tap(find.byTooltip('Übernehmen'));
      await tap(find.byKey(const ValueKey('material-assignment-review-p')));
      await tap(find.text('Abbrechen'));
      expect(await c.repository.classroomDocuments(), isEmpty);
      await t.longPress(find.text('Lesen.pdf'));
      await t.pumpAndSettle();
      expect(find.text('1 ausgewählt'), findsOneWidget);
      final search = find.widgetWithText(TextField, 'In diesem Ordner suchen');
      await t.enterText(search, 'Lesen');
      await t.pumpAndSettle();
      expect(find.text('Textarbeit'), findsNothing);
      await tap(find.byTooltip('Angezeigte abwählen'));
      await tap(find.byTooltip('Alle angezeigten auswählen'));
      await t.enterText(search, '');
      await t.pumpAndSettle();
      await tap(find.text('Textarbeit'));
      await tap(find.text('Fragen.docx'));
      await tap(find.text('2 übernehmen und zuordnen'));
      await tap(find.byKey(const ValueKey('material-assignment-review-p')));
      await tap(find.byKey(const ValueKey('assignment-plan-review-p')));
      await tap(find.text('Übernehmen').last);
      await tap(find.byKey(const ValueKey('material-assignment-save')));
      await c.reload();
      expect(
        c.classroom.map((m) => m.text('remoteName')),
        unorderedEquals(['Lesen.pdf', 'Fragen.docx']),
      );
      for (final m in c.classroom) {
        expect(pupilMaterialDates(m, pupil.id), [dateOnly(DateTime.now())]);
        expect(hasMaterialSource(m.patch({'url': ''})), isTrue);
      }
    },
  );

  testWidgets('Freigabe prüft die gerenderten Bilddaten vor dem Teilen', (
    t,
  ) async {
    final bytes = scannerImage();
    final doc = SharedDocument('Probe.jpg', bytes, 'image/jpeg');
    await host(
      t,
      (ctx) => sharePreparedDocuments(ctx, [doc], previewIndices: {0}),
    );
    await waitFor(
      t,
      () =>
          find.byType(FilledButton).evaluate().isNotEmpty &&
          t.widget<FilledButton>(find.byType(FilledButton)).onPressed != null,
    );
    expect(find.text('Vorschau vor dem Teilen'), findsOneWidget);
    expect(
      (t.widget<Image>(find.byType(Image)).image as MemoryImage).bytes,
      same(bytes),
    );
    await t.tap(find.text('Abbrechen'));
    await t.pumpAndSettle();
    expect(find.text('Teilen'), findsNothing);
  });
  testWidgets(
    'Fehlende erste Seite im gespeicherten Stapel an der ursprünglichen Position ergänzen',
    (t) async {
      final c = await setup(), files = MemoryMaterialFiles();
      final first = scannerImage(width: 180, height: 240),
          second = scannerImage(width: 240, height: 180);
      var retry = false;
      Future<List<XFile>> select() async => retry
          ? [NamedPhoto('Deckblatt.jpg', first)]
          : [
              NamedPhoto('Deckblatt.jpg', first, oversized: true),
              NamedPhoto('Aufgabe.jpg', second),
            ];
      await host(
        t,
        (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => ScanEditor(
            controller: c,
            files: files,
            importOnOpen: true,
            pickFiles: select,
          ),
        ),
      );
      await waitFor(
        t,
        () =>
            find.text('Deckblatt.jpg – Größer als 20 MB').evaluate().isNotEmpty,
      );
      expect(find.text('Übernommen · Aufgabe.jpg'), findsOneWidget);
      final initial = await c.repository.dialogDrafts();
      final existingKey = (initial.single.data['pages'] as List).single['key'];
      await t.tap(find.text('Später fortsetzen'));
      await t.pumpAndSettle();
      retry = true;
      await host(
        t,
        (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => ScanEditor(
            controller: c,
            files: files,
            draft: c.dialogDrafts.single,
            pickFiles: select,
          ),
        ),
      );
      final again = find.text('Fehlgeschlagene erneut wählen');
      await t.ensureVisible(again);
      await t.tap(again);
      await waitFor(
        t,
        () =>
            (c.dialogDrafts.single.data['pages'] as List).length == 2 &&
            again.evaluate().isEmpty,
      );
      final result = c.dialogDrafts.single.data['pages'] as List;
      expect(result.first['width'], lessThan(result.first['height'] as int));
      expect(result.last['key'], existingKey);
    },
  );
  testWidgets(
    'Beim erneuten Wählen einer gleichnamigen Datei bleibt die bereits gespeicherte Seite unangetastet',
    (t) async {
      final c = await setup(), files = MemoryMaterialFiles();
      final first = scannerImage(),
          second = scannerImage(width: 240, height: 180);
      var calls = 0;
      await host(
        t,
        (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => ScanEditor(
            controller: c,
            files: files,
            importOnOpen: true,
            pickFiles: () async => ++calls == 1
                ? [
                    NamedPhoto('Foto.jpg', first),
                    NamedPhoto('Foto.jpg', second, oversized: true),
                  ]
                : [NamedPhoto('Foto.jpg', second)],
          ),
        ),
      );
      final retry = find.text('Fehlgeschlagene erneut wählen');
      await waitFor(t, () => retry.evaluate().isNotEmpty);
      final key = (c.dialogDrafts.single.data['pages'] as List).first['key'];
      await t.ensureVisible(retry);
      await t.tap(retry);
      await waitFor(
        t,
        () =>
            retry.evaluate().isEmpty &&
            (c.dialogDrafts.single.data['pages'] as List).length == 2,
      );
      final saved = c.dialogDrafts.single.data['pages'] as List;
      expect(saved.first['key'], key);
      expect(saved.last['width'], greaterThan(saved.last['height'] as int));
    },
  );
  testWidgets('Scan-Stapel mit zu großer zweiter Datei erneut importieren', (
    t,
  ) async {
    final c = await setup();
    final files = MemoryMaterialFiles();
    final picture = scannerImage();
    var requested = 0;
    await host(
      t,
      (ctx) => showDialog<void>(
        context: ctx,
        builder: (_) => ScanEditor(
          controller: c,
          files: files,
          importOnOpen: true,
          pickFiles: () async {
            requested++;
            return [
              XFile.fromData(
                picture,
                name: 'Seite1.jpg',
                mimeType: 'image/jpeg',
              ),
              XFile.fromData(
                Uint8List(20000001),
                name: 'Anhang.pdf',
                mimeType: 'application/pdf',
              ),
            ];
          },
        ),
      ),
    );
    const message = 'Datei 2 – Größer als 20 MB';
    await waitFor(t, () => find.text(message).evaluate().isNotEmpty);
    final before = (await c.repository.dialogDrafts()).single;
    expect(before.data['pages'], hasLength(1));
    final button = find.byKey(const ValueKey('scanner-import'));
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pump();
    await waitFor(
      t,
      () =>
          requested == 2 &&
          find.text('1 Datei übernommen · 1 ausständig').evaluate().isNotEmpty,
    );
    final after = (await c.repository.dialogDrafts()).single;
    expect(after.data['pages'], before.data['pages']);
    expect(find.text('Übernommen · Datei 1'), findsOneWidget);
  });
}
