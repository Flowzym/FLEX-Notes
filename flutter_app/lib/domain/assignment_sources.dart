import 'models.dart';

class AssignmentSource {
  const AssignmentSource({
    required this.documentId,
    required this.title,
    this.text = '',
    this.page,
  });
  final String documentId, title, text;
  final int? page;
  String get identity => '$documentId:${page ?? ''}:$text';
  Json toJson() => {
    'documentId': documentId,
    'title': title,
    'text': text,
    if (page != null) 'page': page,
  };
  factory AssignmentSource.fromJson(Json data) {
    final value = AssignmentSource(
      documentId: data['documentId'] as String,
      title: data['title'] as String,
      text: data['text'] as String? ?? '',
      page: data['page'] as int?,
    );
    if (value.documentId.isEmpty ||
        value.documentId.length > 250 ||
        value.title.isEmpty ||
        value.title.length > 300 ||
        value.text.length > 4000 ||
        value.page != null && (value.page! < 1 || value.page! > 1000) ||
        data.keys.any(
          (k) => !{'documentId', 'title', 'text', 'page'}.contains(k),
        )) {
      throw const DomainError('Ungültiger Auftragsverweis.');
    }
    return value;
  }
}
