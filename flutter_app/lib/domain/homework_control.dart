import 'models.dart';
import 'school.dart';

/// Append a normal task feedback entry; never overwrite sibling tasks or history.
SchoolRecord reviewHomeworkTask(
  SchoolRecord record,
  String taskId,
  TaskState state,
  DateTime now,
) {
  final task = record.tasks.where((t) => t.id == taskId).firstOrNull;
  if (record.deleted || record.kind != SchoolKind.homework || task == null) {
    throw const DomainError(
      'Diese Hausübungsaufgabe ist nicht mehr verfügbar.',
    );
  }
  if (record.taskState(task) == state) return record;
  final feedback = SchoolFeedback(
    id: newId(),
    observedOn: dateOnly(now),
    observedTime:
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    createdAtUtc: now.toUtc().toIso8601String(),
    taskId: task.id,
    taskText: task.text,
    state: state,
  );
  if (record.liveFeedback.any(
    (f) =>
        f.taskId == taskId &&
        f.state != null &&
        f.sortKey.compareTo(feedback.sortKey) > 0,
  )) {
    throw const DomainError(
      'Eine später datierte Rückmeldung ist vorhanden. Bitte den Stand in den Aufgabendetails prüfen.',
    );
  }
  return record.patch({
    'feedback': [...record.feedback.map((f) => f.toJson()), feedback.toJson()],
  });
}
