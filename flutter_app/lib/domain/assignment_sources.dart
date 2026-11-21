import 'models.dart';

class AssignmentSource {
  const AssignmentSource({
    required this.documentId,
    required this.title,
    this.text = '',
    this.page,
    this.pupilId,
  });
  final String documentId, title, text;
  final int? page;
  final String? pupilId;
  String get identity =>
      '${pupilId == null ? '' : 'pupil:$pupilId:'}$documentId:${page ?? ''}:$text';
  Json toJson() => {
    'documentId': documentId,
    'title': title,
    'text': text,
    if (page != null) 'page': page,
    if (pupilId != null) 'pupilId': pupilId,
  };
  factory AssignmentSource.fromJson(Json data) {
    final value = AssignmentSource(
      documentId: data['documentId'] as String,
      title: data['title'] as String,
      text: data['text'] as String? ?? '',
      page: data['page'] as int?,
      pupilId: data['pupilId'] as String?,
    );
    if (value.pupilId != null &&
            (value.pupilId!.isEmpty || value.pupilId!.length > 250) ||
        value.documentId.isEmpty ||
        value.documentId.length > 250 ||
        value.title.isEmpty ||
        value.title.length > 300 ||
        value.text.length > 4000 ||
        value.page != null && (value.page! < 1 || value.page! > 1000) ||
        data.keys.any(
          (k) =>
              !{'documentId', 'title', 'text', 'page', 'pupilId'}.contains(k),
        )) {
      throw const DomainError('Ungültiger Auftragsverweis.');
    }
    return value;
  }
}

List<Json> homeworkSourcesFor(
  Iterable<AssignmentSource> sources,
  String pupilId,
) {
  final result = <String, Json>{};
  for (final source in sources.where(
    (s) => s.pupilId == null || s.pupilId == pupilId,
  )) {
    final link = AssignmentSource(
      documentId: source.documentId,
      title: source.title,
      text: source.text,
      page: source.page,
    );
    result[link.identity] = link.toJson();
  }
  return result.values.toList();
}
