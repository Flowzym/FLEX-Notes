import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/lesson_series.dart';
import 'package:flex_notizbuch/domain/material_workspace.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'classroom_test.dart' show lesson;
import 'material_workspace_test.dart' show material;

void main() {
  test(
    'future split retains history, moved attachments, plans and reminders',
    () {
      var source = lesson(rule: const RepeatRule(frequency: 'weekly'));
      source = patchLessonOccurrence(source, '2026-11-02', {
        'movedTo': '2026-11-20',
      });
      source = patchLessonOccurrence(source, '2026-11-16', {
        'movedTo': '2026-11-17',
        'note': 'Vorbereitet',
      });
      final following = source.patch({
        'id': 'next',
        'revision': 0,
        'date': '2026-11-09',
        'title': 'Neuer Block',
      });
      final pastFile = material('Vergangene Stunde').patch({
        'links': [
          {'kind': 'lesson', 'id': source.id, 'date': '2026-11-20'},
        ],
      });
      final futureFile = material('Künftige Stunde').patch({
        'links': [
          {'kind': 'lesson', 'id': source.id, 'date': '2026-11-17'},
        ],
      });
      final shared = material('Serienmaterial').patch({
        'links': [
          {'kind': 'classroom', 'id': source.id},
        ],
      });
      final plan = ClassroomDocument.create(ClassroomKind.plan, 'Plan', {
        'lessonIds': [source.id],
      });
      final reminder = ClassroomDocument.create(
        ClassroomKind.reminder,
        'Erinnerung',
        {
          'target': 'lesson:${source.id}:2026-11-16',
          'at': '2026-11-16T07:00:00Z',
        },
      );
      final docs = [source, pastFile, futureFile, shared, plan, reminder];
      final changed = splitLessonSeries(docs, source, following, '2026-11-09');
      final merged = {
        for (final d in [...docs, ...changed]) d.id: d,
      }.values.toList();
      expect(
        lessonOccurrences(
          merged,
          '2026-11-20',
          '2026-11-20',
        ).single.document.id,
        source.id,
      );
      expect(
        lessonOccurrences(merged, '2026-11-17', '2026-11-17').single.note,
        'Vorbereitet',
      );
      expect(
        linkedMaterials(merged, source.id, date: '2026-11-20').map((d) => d.id),
        contains(pastFile.id),
      );
      expect(
        linkedMaterials(merged, 'next', date: '2026-11-17').map((d) => d.id),
        containsAll([futureFile.id, shared.id]),
      );
      expect(
        linkedMaterials(merged, source.id, date: '2026-11-17').map((d) => d.id),
        isNot(contains(futureFile.id)),
      );
      expect(
        merged.singleWhere((d) => d.id == plan.id).strings('lessonIds'),
        containsAll([source.id, 'next']),
      );
      expect(
        merged.singleWhere((d) => d.id == reminder.id).text('target'),
        'lesson:next:2026-11-16',
      );
      expect(source.rule.until, isNull);
      expect(
        merged.singleWhere((d) => d.id == source.id).rule.until,
        '2026-11-08',
      );
    },
  );
  test(
    'future split rejects a shifted start or loss of prepared occurrences',
    () {
      final source = patchLessonOccurrence(
        lesson(rule: const RepeatRule(frequency: 'weekly')),
        '2026-11-16',
        {'note': 'Bereits vorbereitet'},
      );
      final following = source.patch({'id': 'next', 'date': '2026-11-09'});
      expect(
        () => splitLessonSeries(
          [source],
          source,
          following.patch({'date': '2026-11-10'}),
          '2026-11-09',
        ),
        throwsA(isA<DomainError>()),
      );
      expect(
        () => splitLessonSeries(
          [source],
          source,
          following.patch({
            'repeat': const RepeatRule(
              frequency: 'weekly',
              until: '2026-11-09',
            ).toJson(),
          }),
          '2026-11-09',
        ),
        throwsA(isA<DomainError>()),
      );
    },
  );
}
