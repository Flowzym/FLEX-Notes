import 'material_tags.dart';
import 'classroom.dart';
import 'models.dart';

const scanPageLimit = 25;
const scanTypes = {
  'pupilWork': 'Schülerarbeit',
  'worksheet': 'Arbeitsblatt',
  'form': 'Formular',
  'protocol': 'Gesprächsunterlage',
  'planning': 'Planung',
  'receipt': 'Beleg',
  'other': 'Sonstiges',
};

/// Stable references, independent of filenames. A date narrows a lesson link
/// to an occurrence; other classroom links refer to the entire source document.
class DocumentLink {
  const DocumentLink(this.kind, this.id, {this.date = '', this.taskId = ''});
  final String kind, id, date, taskId;
  Json toJson() => {
    'kind': kind,
    'id': id,
    if (date.isNotEmpty) 'date': date,
    if (taskId.isNotEmpty) 'taskId': taskId,
  };
  factory DocumentLink.fromJson(Json j) {
    final link = DocumentLink(
      j['kind'] as String? ?? '',
      j['id'] as String? ?? '',
      date: j['date'] as String? ?? '',
      taskId: j['taskId'] as String? ?? '',
    );
    if (!{
          'orga',
          'school',
          'orgaDraft',
          'schoolDraft',
          'bulkDraft',
          'classroom',
          'lesson',
        }.contains(link.kind) ||
        link.id.isEmpty ||
        link.id.length > 250 ||
        (link.kind == 'lesson'
            ? !validDate(link.date)
            : link.date.isNotEmpty) ||
        (link.taskId.isNotEmpty &&
            !{'school', 'schoolDraft', 'bulkDraft'}.contains(link.kind)) ||
        link.taskId.length > 250 ||
        j.keys.any((k) => !{'kind', 'id', 'date', 'taskId'}.contains(k))) {
      throw const DomainError('Ungültige Dokumentzuordnung.');
    }
    return link;
  }
  String get identity =>
      '$kind:$id:$date${taskId.isEmpty ? '' : ':task:$taskId'}';

  bool includes(DocumentLink other, {bool includeTasks = true}) =>
      identity == other.identity ||
      includeTasks &&
          {'school', 'schoolDraft', 'bulkDraft'}.contains(kind) &&
          taskId.isEmpty &&
          other.kind == kind &&
          other.id == id;
}

class ScanContext {
  const ScanContext({
    this.pupilIds = const [],
    this.links = const [],
    this.title = '',
    this.category = 'other',
    this.subject = '',
    this.includeTasks = true,
    this.unassignedPupilsOnly = false,
  });
  final List<String> pupilIds;
  final List<DocumentLink> links;
  final String title, category, subject;
  final bool includeTasks, unassignedPupilsOnly;
  Json initial({DateTime? now}) => {
    'title':
        '${dateOnly(now ?? DateTime.now())} · ${title.isEmpty ? 'Scan' : title.substring(0, title.length.clamp(0, 180))}',
    'documentType': category,
    'subject': subject,
    'pupilIds': pupilIds,
    'links': links.map((v) => v.toJson()).toList(),
    'pages': <Json>[],
    'tags': <String>[],
    'outputFormat': 'pdf',
  };
  bool matchesMaterial(ClassroomDocument d) =>
      d.kind == ClassroomKind.material &&
      !d.deleted &&
      (!unassignedPupilsOnly || d.strings('pupilIds').isEmpty) &&
      (pupilIds.isEmpty || pupilIds.every(d.strings('pupilIds').contains)) &&
      (links.isEmpty ||
          links.every(
            (link) => d
                .rows('links')
                .any(
                  (r) => link.includes(
                    DocumentLink.fromJson(r),
                    includeTasks: includeTasks,
                  ),
                ),
          ));
  bool matchesDraft(DialogDraft d) =>
      d.type == 'scan' &&
      (!unassignedPupilsOnly || (d.data['pupilIds'] as List).isEmpty) &&
      (pupilIds.isEmpty ||
          pupilIds.every(
            List<String>.from(d.data['pupilIds'] as List).contains,
          )) &&
      (links.isEmpty ||
          links.every(
            (link) => (d.data['links'] as List).any(
              (r) => link.includes(
                DocumentLink.fromJson(Json.from(r as Map)),
                includeTasks: includeTasks,
              ),
            ),
          ));
}

class ScanPage {
  const ScanPage(
    this.key,
    this.width,
    this.height, {
    this.photo = false,
    this.captureToken,
  });
  final bool photo;
  final String? captureToken;
  final String key;
  final int width, height;
  Json toJson() => {
    'key': key,
    'width': width,
    'height': height,
    if (photo) 'photo': true,
    if (captureToken != null) 'captureToken': captureToken,
  };
  factory ScanPage.fromJson(Json j) {
    final p = ScanPage(
      j['key'] as String? ?? '',
      j['width'] as int? ?? 0,
      j['height'] as int? ?? 0,
      photo: j['photo'] as bool? ?? false,
      captureToken: j['captureToken'] as String?,
    );
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,120}$').hasMatch(p.key) ||
        p.width < 1 ||
        p.height < 1 ||
        p.width > 2400 ||
        p.height > 2400) {
      throw const DomainError('Ungültige Scanseite.');
    }
    return p;
  }
}

void validateScanData(Json j) {
  if (j['outputFormat'] != null &&
          !{'pdf', 'jpg'}.contains(j['outputFormat']) ||
      j['capturePending'] != null && j['capturePending'] is! bool ||
      j['captureAsDocument'] != null && j['captureAsDocument'] is! bool ||
      j['captureReplaceKey'] != null &&
          (j['captureReplaceKey'] is! String ||
              (j['captureReplaceKey'] as String).length > 250) ||
      j['tags'] != null &&
          (j['tags'] is! List ||
              (j['tags'] as List).length > 30 ||
              !(j['tags'] as List).every(
                (t) => t is String && t.trim().isNotEmpty && t.length <= 64,
              )) ||
      j['title'] is! String ||
      (j['title'] as String).length > 200 ||
      !scanTypes.containsKey(j['documentType']) ||
      j['subject'] is! String ||
      (j['subject'] as String).length > 200 ||
      j['pupilIds'] is! List ||
      j['links'] is! List ||
      j['pages'] is! List ||
      (j['pages'] as List).length > scanPageLimit ||
      (j['links'] as List).length > 100 ||
      (j['pupilIds'] as List).length > 500 ||
      !(j['pupilIds'] as List).every(
        (id) => id is String && id.isNotEmpty && id.length <= 250,
      )) {
    throw const DomainError('Ungültiger Scanentwurf.');
  }
  final pages = (j['pages'] as List)
      .map((p) => ScanPage.fromJson(Json.from(p as Map)))
      .toList();
  final links = (j['links'] as List)
      .map((p) => DocumentLink.fromJson(Json.from(p as Map)))
      .toList();
  if (pages.map((p) => p.key).toSet().length != pages.length ||
      links.map((l) => l.identity).toSet().length != links.length ||
      (j['pupilIds'] as List).toSet().length !=
          (j['pupilIds'] as List).length ||
      j['sourceId'] != null &&
          (j['sourceId'] is! String ||
              j['sourceRevision'] is! int ||
              j['sourceRevision'] < 1)) {
    throw const DomainError('Ungültiger Scanentwurf.');
  }
}

List<String> scanTags(String text) => normalizeMaterialTags(text.split(','));

String scanFilename(String title, {String extension = 'pdf'}) {
  var name = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
  name = name.replaceFirst(RegExp(r'\.(pdf|jpe?g)$', caseSensitive: false), '');
  if (name.isEmpty) name = 'Scan';
  return '${name.substring(0, name.length.clamp(0, 160))}.$extension';
}
