import 'models.dart';
import 'repository.dart';
import 'classroom.dart';
import 'school.dart';

class SchoolYearArchive {
  SchoolYearArchive({
    required this.id,
    required this.title,
    required this.from,
    required this.to,
    required this.closedAtUtc,
    this.reviewOn,
    required Iterable<String> orgaIds,
    required Iterable<String> recordIds,
    required Iterable<String> documentIds,
  }) : orgaIds = Set.unmodifiable(orgaIds),
       recordIds = Set.unmodifiable(recordIds),
       documentIds = Set.unmodifiable(documentIds);
  final String id, title, from, to, closedAtUtc;
  final String? reviewOn;
  final Set<String> orgaIds, recordIds, documentIds;
  int get count => orgaIds.length + recordIds.length + documentIds.length;
  Json toJson() => {
    'format': 'flex-school-year-1',
    'id': id,
    'title': title,
    'from': from,
    'to': to,
    'closedAtUtc': closedAtUtc,
    'reviewOn': reviewOn,
    'orgaIds': orgaIds.toList(),
    'recordIds': recordIds.toList(),
    'documentIds': documentIds.toList(),
  };
  factory SchoolYearArchive.fromJson(Json json) {
    final value = SchoolYearArchive(
      id: json['id'] as String,
      title: json['title'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      closedAtUtc: json['closedAtUtc'] as String,
      reviewOn: json['reviewOn'] as String?,
      orgaIds: List<String>.from(json['orgaIds'] as List),
      recordIds: List<String>.from(json['recordIds'] as List),
      documentIds: List<String>.from(json['documentIds'] as List),
    );
    if (json['format'] != 'flex-school-year-1' ||
        value.id.isEmpty ||
        value.title.trim().isEmpty ||
        value.title.length > 100 ||
        !validDate(value.from) ||
        !validDate(value.to) ||
        value.from.compareTo(value.to) > 0 ||
        DateTime.tryParse(value.closedAtUtc) == null ||
        value.reviewOn != null && !validDate(value.reviewOn!) ||
        value.count > 100000) {
      throw const DomainError('Ungültiges Schuljahresarchiv.');
    }
    return value;
  }

  factory SchoolYearArchive.preview(
    NotebookSnapshot data, {
    required String title,
    required String from,
    required String to,
    String? reviewOn,
    bool keepOpen = true,
  }) {
    bool within(String day) =>
        day.isNotEmpty && day.compareTo(from) >= 0 && day.compareTo(to) <= 0;
    final repeatingSources = data.classroom
        .where((d) => d.kind == ClassroomKind.repeat && !d.deleted)
        .map((d) => d.text('entryId'))
        .toSet();
    return SchoolYearArchive.fromJson(
      SchoolYearArchive(
        id: newId(),
        title: title,
        from: from,
        to: to,
        closedAtUtc: utcNow(),
        reviewOn: reviewOn,
        orgaIds: data.entries
            .where(
              (e) =>
                  !e.deleted &&
                  !repeatingSources.contains(e.id) &&
                  within(
                    e.appointmentDate ??
                        e.dueDate ??
                        (e.observedOn.isEmpty
                            ? e.createdAtUtc.substring(0, 10)
                            : e.observedOn),
                  ) &&
                  (!keepOpen || !e.isTask || e.done),
            )
            .map((e) => e.id),
        recordIds: data.records
            .where(
              (r) =>
                  !r.deleted &&
                  within(r.observedOn) &&
                  (!keepOpen ||
                      !{
                        SchoolKind.goal,
                        SchoolKind.homework,
                      }.contains(r.kind) ||
                      !r.pending),
            )
            .map((r) => r.id),
        documentIds: data.classroom
            .where(
              (d) =>
                  !d.deleted &&
                  (d.kind == ClassroomKind.lesson &&
                          within(d.text('date')) &&
                          (!d.rule.repeats ||
                              d.rule.until != null &&
                                  d.rule.until!.compareTo(to) <= 0) ||
                      d.kind == ClassroomKind.plan &&
                          within(d.text('date')) &&
                          d.text('status') == 'done'),
            )
            .map((d) => d.id),
      ).toJson(),
    );
  }
}

class RetentionPolicy {
  const RetentionPolicy({this.importDays = 90, this.trashDays = 30});
  final int importDays, trashDays;
  Json toJson() => {'importDays': importDays, 'trashDays': trashDays};
  factory RetentionPolicy.fromJson(Json json) {
    final value = RetentionPolicy(
      importDays: json['importDays'] as int? ?? 90,
      trashDays: json['trashDays'] as int? ?? 30,
    );
    if (!{0, 30, 90, 180, 365}.contains(value.importDays) ||
        !{0, 30, 90, 180, 365}.contains(value.trashDays)) {
      throw const DomainError('Ungültige Aufbewahrungsdauer.');
    }
    return value;
  }
}

class RetentionCandidate {
  const RetentionCandidate(
    this.kind,
    this.id,
    this.label,
    this.date, {
    this.count = 0,
  });
  final String kind, id, label, date;
  final int count;
  String get key => '$kind:$id';
}
