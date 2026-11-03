import 'models.dart';

enum SchoolKind { social, work, goal, homework }

extension SchoolKindLabel on SchoolKind {
  String get label => switch (this) {
    SchoolKind.social => 'Sozialverhalten',
    SchoolKind.work => 'Arbeitsverhalten',
    SchoolKind.goal => 'Ziele',
    SchoolKind.homework => 'Hausübung',
  };
}

enum TaskState { open, complete, partial, missing }

extension TaskStateLabel on TaskState {
  String get label => switch (this) {
    TaskState.open => 'Offen',
    TaskState.complete => 'Vollständig',
    TaskState.partial => 'Teilweise',
    TaskState.missing => 'Nicht erledigt',
  };
}

class HomeworkTask {
  const HomeworkTask({
    required this.id,
    required this.text,
    this.parentId,
    this.initialState = TaskState.open,
  });
  final String id, text;
  final String? parentId;
  final TaskState initialState;
  HomeworkTask copyWith({
    String? text,
    String? parentId,
    bool clearParent = false,
  }) => HomeworkTask(
    id: id,
    text: text ?? this.text,
    parentId: clearParent ? null : parentId ?? this.parentId,
    initialState: initialState,
  );
  Json toJson() => {
    'id': id,
    'text': text,
    'parentId': parentId,
    'initialState': initialState.name,
  };
  factory HomeworkTask.fromJson(Json j) => HomeworkTask(
    id: j['id'] as String,
    text: j['text'] as String,
    parentId: j['parentId'] as String?,
    initialState: TaskState.values.byName(
      j['initialState'] as String? ?? 'open',
    ),
  );
}

class SchoolFeedback {
  const SchoolFeedback({
    required this.id,
    required this.observedOn,
    required this.createdAtUtc,
    this.observedTime = '',
    this.taskId,
    this.taskText = '',
    this.state,
    this.delivery,
    this.note = '',
    this.deleted = false,
  });
  final String id, observedOn, observedTime, createdAtUtc, taskText, note;
  final String? taskId, delivery;
  final TaskState? state;
  final bool deleted;
  String get sortKey =>
      '$observedOn ${observedTime.isEmpty ? '00:00' : observedTime} $createdAtUtc $id';
  SchoolFeedback copyWith({
    String? note,
    TaskState? state,
    String? delivery,
    bool? deleted,
  }) => SchoolFeedback(
    id: id,
    observedOn: observedOn,
    observedTime: observedTime,
    createdAtUtc: createdAtUtc,
    taskId: taskId,
    taskText: taskText,
    state: state ?? this.state,
    delivery: delivery ?? this.delivery,
    note: note ?? this.note,
    deleted: deleted ?? this.deleted,
  );
  Json toJson() => {
    'id': id,
    'observedOn': observedOn,
    'observedTime': observedTime,
    'createdAtUtc': createdAtUtc,
    'taskId': taskId,
    'taskText': taskText,
    'state': state?.name,
    'delivery': delivery,
    'note': note,
    'deleted': deleted,
  };
  factory SchoolFeedback.fromJson(Json j) => SchoolFeedback(
    id: j['id'] as String,
    observedOn: j['observedOn'] as String,
    observedTime: j['observedTime'] as String? ?? '',
    createdAtUtc: j['createdAtUtc'] as String,
    taskId: j['taskId'] as String?,
    taskText: j['taskText'] as String? ?? '',
    state: j['state'] == null
        ? null
        : TaskState.values.byName(j['state'] as String),
    delivery: j['delivery'] as String?,
    note: j['note'] as String? ?? '',
    deleted: j['deleted'] == true,
  );
}

class GoalReview {
  const GoalReview({
    required this.id,
    required this.decision,
    required this.observedOn,
    this.note = '',
    this.nextStep = '',
    this.nextReviewDate,
  });
  final String id, decision, observedOn, note, nextStep;
  final String? nextReviewDate;
  Json toJson() => {
    'id': id,
    'decision': decision,
    'observedOn': observedOn,
    'note': note,
    'nextStep': nextStep,
    'nextReviewDate': nextReviewDate,
  };
  factory GoalReview.fromJson(Json j) => GoalReview(
    id: j['id'] as String,
    decision: j['decision'] as String,
    observedOn: j['observedOn'] as String,
    note: j['note'] as String? ?? '',
    nextStep: j['nextStep'] as String? ?? '',
    nextReviewDate: j['nextReviewDate'] as String?,
  );
}

/// Newly reconstructed payload. Unknown historical formats are never silently
/// interpreted as this format or rewritten by opening the application.
class SchoolRecord {
  SchoolRecord({
    required this.id,
    required this.pupilId,
    required this.kind,
    required this.observedOn,
    required this.createdAtUtc,
    this.revision = 0,
    this.title = '',
    this.body = '',
    this.observedTime = '',
    this.subject = '',
    this.taskFree,
    List<String> taskTags = const [],
    this.context = '',
    this.situation = '',
    this.source = 'self',
    this.support = '',
    this.criterion = '',
    this.pupilPerspective = '',
    this.goalStatus = 'active',
    this.dueDate,
    this.nextReviewDate,
    this.goalId,
    this.goalSnapshot = '',
    this.situationId,
    this.needsCompletion = false,
    this.deleted = false,
    List<String> positive = const [],
    List<String> neutral = const [],
    List<String> negative = const [],
    List<String> participantIds = const [],
    this.otherParticipants = '',
    List<HomeworkTask> tasks = const [],
    List<SchoolFeedback> feedback = const [],
    List<GoalReview> reviews = const [],
  }) : taskTags = List.unmodifiable(taskTags),
       positive = List.unmodifiable(positive),
       neutral = List.unmodifiable(neutral),
       negative = List.unmodifiable(negative),
       participantIds = List.unmodifiable(participantIds),
       tasks = List.unmodifiable(tasks),
       feedback = List.unmodifiable(feedback),
       reviews = List.unmodifiable(reviews);
  factory SchoolRecord.empty(SchoolKind kind, String pupilId) => SchoolRecord(
    id: newId(),
    pupilId: pupilId,
    kind: kind,
    observedOn: dateOnly(DateTime.now()),
    createdAtUtc: utcNow(),
  );
  final String id,
      pupilId,
      title,
      body,
      observedOn,
      observedTime,
      createdAtUtc,
      subject,
      context,
      situation,
      source,
      support,
      criterion,
      pupilPerspective,
      goalStatus,
      goalSnapshot,
      otherParticipants;
  final String? dueDate, nextReviewDate, goalId, situationId;
  // Old free-form assignments remain whole; never split narrative on " · ".
  final String? taskFree;
  final List<String> taskTags;
  String get assignmentFree => taskFree ?? subject;
  final SchoolKind kind;
  final int revision;
  final bool needsCompletion, deleted;
  final List<String> positive, neutral, negative, participantIds;
  final List<HomeworkTask> tasks;
  final List<SchoolFeedback> feedback;
  final List<GoalReview> reviews;
  List<String> observations(String tone) => switch (tone) {
    'positive' => positive,
    'neutral' => neutral,
    'negative' => negative,
    _ => throw const DomainError('Unbekannte Beobachtungsart.'),
  };
  List<SchoolFeedback> get liveFeedback =>
      feedback.where((f) => !f.deleted).toList()
        ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
  TaskState taskState(HomeworkTask task) {
    final changes = liveFeedback.where(
      (f) => f.taskId == task.id && f.state != null,
    );
    return changes.isEmpty ? task.initialState : changes.last.state!;
  }

  String get delivery {
    final changes = liveFeedback.where((f) => f.delivery != null);
    return changes.isEmpty ? 'unknown' : changes.last.delivery!;
  }

  bool get pending =>
      !deleted &&
      (kind == SchoolKind.goal
          ? goalStatus == 'active'
          : kind == SchoolKind.homework &&
                tasks.any((t) => taskState(t) != TaskState.complete));
  String get searchText => [
    title,
    body,
    subject,
    context,
    support,
    criterion,
    goalSnapshot,
    otherParticipants,
    ...positive,
    ...neutral,
    ...negative,
    ...tasks.map((t) => t.text),
    ...liveFeedback.map((f) => f.note),
  ].join(' ');
  Json toJson() => {
    'rebuildFormat': 1,
    'id': id,
    'pupilId': pupilId,
    'kind': kind.name,
    'revision': revision,
    'title': title,
    'body': body,
    'observedOn': observedOn,
    'observedTime': observedTime,
    'createdAtUtc': createdAtUtc,
    'subject': subject,
    'taskTags': taskTags,
    'taskFree': taskFree,
    'context': context,
    'situation': situation,
    'source': source,
    'support': support,
    'criterion': criterion,
    'pupilPerspective': pupilPerspective,
    'goalStatus': goalStatus,
    'dueDate': dueDate,
    'nextReviewDate': nextReviewDate,
    'goalId': goalId,
    'goalSnapshot': goalSnapshot,
    'situationId': situationId,
    'needsCompletion': needsCompletion,
    'deleted': deleted,
    'positive': positive,
    'neutral': neutral,
    'negative': negative,
    'participantIds': participantIds,
    'otherParticipants': otherParticipants,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'feedback': feedback.map((f) => f.toJson()).toList(),
    'reviews': reviews.map((r) => r.toJson()).toList(),
  };
  factory SchoolRecord.fromJson(Json j) {
    if (j['rebuildFormat'] != 1) {
      throw const DomainError(
        'Dieser fachliche Datenstand stammt aus einer anderen Fassung. Er bleibt unverändert; eine Migration ist erforderlich.',
      );
    }
    return SchoolRecord(
      id: j['id'] as String,
      pupilId: j['pupilId'] as String,
      kind: SchoolKind.values.byName(j['kind'] as String),
      revision: j['revision'] as int,
      title: j['title'] as String,
      body: j['body'] as String,
      observedOn: j['observedOn'] as String,
      observedTime: j['observedTime'] as String,
      createdAtUtc: j['createdAtUtc'] as String,
      subject: j['subject'] as String,
      taskTags: List<String>.from(j['taskTags'] as List? ?? const []),
      taskFree: j['taskFree'] as String?,
      context: j['context'] as String,
      situation: j['situation'] as String,
      source: j['source'] as String,
      support: j['support'] as String,
      criterion: j['criterion'] as String,
      pupilPerspective: j['pupilPerspective'] as String,
      goalStatus: j['goalStatus'] as String,
      dueDate: j['dueDate'] as String?,
      nextReviewDate: j['nextReviewDate'] as String?,
      goalId: j['goalId'] as String?,
      goalSnapshot: j['goalSnapshot'] as String,
      situationId: j['situationId'] as String?,
      needsCompletion: j['needsCompletion'] as bool,
      deleted: j['deleted'] as bool,
      positive: List<String>.from(j['positive'] as List),
      neutral: List<String>.from(j['neutral'] as List? ?? const []),
      negative: List<String>.from(j['negative'] as List),
      participantIds: List<String>.from(j['participantIds'] as List),
      otherParticipants: j['otherParticipants'] as String,
      tasks: (j['tasks'] as List)
          .map((v) => HomeworkTask.fromJson(Json.from(v as Map)))
          .toList(),
      feedback: (j['feedback'] as List)
          .map((v) => SchoolFeedback.fromJson(Json.from(v as Map)))
          .toList(),
      reviews: (j['reviews'] as List)
          .map((v) => GoalReview.fromJson(Json.from(v as Map)))
          .toList(),
    );
  }
  SchoolRecord patch(Json changes) =>
      SchoolRecord.fromJson({...toJson(), ...changes});
  void validate({bool draft = false}) {
    if (id.isEmpty ||
        pupilId.isEmpty ||
        revision < 0 ||
        !validDate(observedOn) ||
        DateTime.tryParse(createdAtUtc) == null ||
        !validTime(observedTime)) {
      throw const DomainError('Ungültige Zuordnung oder Datumsangabe.');
    }
    if (dueDate != null && !validDate(dueDate!) ||
        nextReviewDate != null && !validDate(nextReviewDate!)) {
      throw const DomainError('Ungültiger Termin.');
    }
    if (!['active', 'achieved', 'ended'].contains(goalStatus) ||
        !['', 'before', 'during', 'after', 'break'].contains(situation) ||
        !['self', 'reported', 'interpretation'].contains(source)) {
      throw const DomainError('Ungültiger fachlicher Stand.');
    }
    if (!draft && kind == SchoolKind.goal && title.trim().isEmpty) {
      throw const DomainError('Bitte ein Ziel formulieren.');
    }
    if (!draft &&
        [SchoolKind.social, SchoolKind.work].contains(kind) &&
        body.trim().isEmpty &&
        positive.isEmpty &&
        neutral.isEmpty &&
        negative.isEmpty &&
        (situationId == null || context.trim().isEmpty) &&
        (kind != SchoolKind.work || subject.trim().isEmpty)) {
      throw DomainError(
        kind == SchoolKind.work
            ? 'Bitte einen Auftrag, eine Auswahl oder eine Beobachtung eingeben.'
            : 'Bitte kurz beschreiben, was passiert ist, oder eine Beobachtung auswählen.',
      );
    }
    if (body.length > 12000 ||
        title.length > 3000 ||
        criterion.length > 2000 ||
        pupilPerspective.length > 2000 ||
        reviews.any((r) => r.note.length > 2000 || r.nextStep.length > 2000) ||
        tasks.any((t) => t.text.length > 1000) ||
        (kind == SchoolKind.homework && subject.length > 100) ||
        taskTags.toSet().length != taskTags.length ||
        positive.toSet().length != positive.length ||
        neutral.toSet().length != neutral.length ||
        negative.toSet().length != negative.length ||
        [
          ...positive,
          ...neutral,
          ...negative,
        ].any((t) => t.trim().isEmpty || t.length > 1000) ||
        taskTags.any((t) => t.trim().isEmpty || t.length > 1000)) {
      throw const DomainError(
        'Eine Eingabe ist zu lang oder enthält ungültige Tags.',
      );
    }
    if (!draft &&
        kind == SchoolKind.homework &&
        (tasks.isEmpty || tasks.any((t) => t.text.trim().isEmpty))) {
      throw const DomainError('Bitte mindestens eine Aufgabe eingeben.');
    }
    final ids = tasks.map((t) => t.id).toSet();
    if (ids.length != tasks.length ||
        ids.contains('') ||
        tasks.any(
          (t) =>
              t.parentId != null &&
              (!ids.contains(t.parentId) ||
                  t.parentId == t.id ||
                  tasks.firstWhere((p) => p.id == t.parentId).parentId != null),
        )) {
      throw const DomainError('Ungültige Aufgabenstruktur.');
    }
    if (feedback.map((f) => f.id).toSet().length != feedback.length) {
      throw const DomainError('Doppelte Rückmeldungen.');
    }
    for (final f in feedback) {
      if (f.id.isEmpty ||
          !validDate(f.observedOn) ||
          !validTime(f.observedTime) ||
          DateTime.tryParse(f.createdAtUtc) == null ||
          f.state != null && f.taskId == null ||
          f.delivery != null &&
              ![
                'unknown',
                'submitted',
                'missing',
                'absent',
              ].contains(f.delivery)) {
        throw const DomainError('Ungültige Rückmeldung.');
      }
    }
    for (final r in reviews) {
      if (r.id.isEmpty ||
          !validDate(r.observedOn) ||
          !['continue', 'achieved', 'ended', 'reopen'].contains(r.decision) ||
          r.nextReviewDate != null && !validDate(r.nextReviewDate!) ||
          !draft && r.decision == 'continue' && r.nextReviewDate == null) {
        throw const DomainError(
          'Fortführen benötigt einen nächsten Prüftermin.',
        );
      }
    }
  }
}

bool validTime(String value) =>
    value.isEmpty || RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);

class SchoolDraft {
  const SchoolDraft({
    required this.id,
    required this.record,
    required this.updatedAtUtc,
    this.recipients = const [],
    this.editRevision = 0,
    this.mode = 'entry',
    this.taskId,
    this.feedbackId,
    this.baseline,
  });
  final String id, updatedAtUtc;
  final SchoolRecord record;
  final List<String> recipients;
  final int editRevision;
  final String mode;
  final String? taskId, feedbackId, baseline;
  Json toJson() => {
    'record': record.toJson(),
    'recipients': recipients,
    'editRevision': editRevision,
    'mode': mode,
    'taskId': taskId,
    'feedbackId': feedbackId,
    'baseline': ?baseline,
  };
}
