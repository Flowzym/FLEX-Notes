import 'classroom.dart';
import 'models.dart';

const drivePurposes = {
  'all': 'Alle Unterlagen',
  'homework': 'Hausübungen',
  'return': 'Rückläufe',
  'observation': 'Beobachtungen',
  'orga': 'Organisation',
};
String driveBinding(ClassroomDocument f) => [
  f.flag('personal') ? 'pupil' : 'class',
  ...f.strings('pupilIds'),
].join(':');
bool isDriveRule(ClassroomDocument d) =>
    d.kind == ClassroomKind.folder &&
    !d.deleted &&
    d.text('accountDrive').isNotEmpty;
bool usableDriveRule(ClassroomDocument d, Iterable<Pupil> pupils) =>
    isDriveRule(d) &&
    (!d.flag('personal') ||
        (d.strings('pupilIds').length == 1 &&
            pupils.any(
              (p) =>
                  p.id == d.strings('pupilIds').single &&
                  !p.archived &&
                  !p.deleted,
            )));

bool scanAwaitsEntry(Json data) =>
    (data['links'] as List? ?? []).whereType<Map>().any(
      (link) => {
        'schoolDraft',
        'bulkDraft',
        'classroomDraft',
        'orgaDraft',
      }.contains(link['kind']),
    );

String scanPurpose(Json data) {
  final links = (data['links'] as List? ?? []).whereType<Map>();
  final tags = List<String>.from(data['tags'] as List? ?? []);
  if (links.any((l) => l['taskId'] != null) ||
      tags.contains('Hausübung') ||
      data['documentType'] == 'pupilWork' &&
          links.any(
            (l) => {'school', 'schoolDraft', 'bulkDraft'}.contains(l['kind']),
          )) {
    return 'homework';
  }
  if (tags.contains('Rücklauf') ||
      data['documentType'] == 'form' &&
          links.any(
            (l) => {'classroom', 'classroomDraft'}.contains(l['kind']),
          )) {
    return 'return';
  }
  if (links.any(
    (l) => {'school', 'schoolDraft', 'bulkDraft'}.contains(l['kind']),
  )) {
    return 'observation';
  }
  if (links.any((l) => {'orga', 'orgaDraft'}.contains(l['kind']))) {
    return 'orga';
  }
  return 'all';
}

List<ClassroomDocument> scanTargets(
  Json data,
  Iterable<ClassroomDocument> rules,
) {
  final ids = List<String>.from(data['pupilIds'] as List? ?? []);
  if (ids.length > 1 || scanAwaitsEntry(data)) return [];
  final purpose = scanPurpose(data),
      subject = (data['subject'] as String? ?? '').trim().toLowerCase();
  final matches = <ClassroomDocument>[];
  var best = -1;
  for (final f in rules.where((f) => isDriveRule(f) && f.flag('outgoing'))) {
    if (f.flag('personal') != ids.isNotEmpty ||
        ids.isNotEmpty && !f.strings('pupilIds').contains(ids.single)) {
      continue;
    }
    final kind = f.text('purpose', 'all'),
        field = f.text('subject').trim().toLowerCase();
    if (kind != 'all' && kind != purpose ||
        field.isNotEmpty && field != subject) {
      continue;
    }
    final score = (kind == 'all' ? 0 : 1) + (field.isEmpty ? 0 : 1);
    if (score < best) continue;
    if (score > best) {
      best = score;
      matches.clear();
    }
    matches.add(f);
  }
  return matches;
}

Json scanUploadJob(
  Json data,
  String key,
  String name,
  Iterable<ClassroomDocument> rules,
) {
  if (!rules.any((f) => isDriveRule(f) && f.flag('outgoing'))) return {};
  final targets = scanTargets(data, rules);
  final dot = name.lastIndexOf('.');
  var base = (dot < 0 ? name : name.substring(0, dot))
      .replaceAll(RegExp(r'[<>:"/\\|?*#%\x00-\x1f]'), ' ')
      .trim();
  if (base.length > 90) base = String.fromCharCodes(base.runes.take(80));
  final ext = dot < 0 ? 'pdf' : name.substring(dot + 1);
  return {
    'key': key,
    'name': '${base.isEmpty ? 'Scan' : base} [FLEX-$key].$ext',
    'state': scanAwaitsEntry(data)
        ? 'entry'
        : targets.length == 1
        ? 'pending'
        : 'review',
    if (targets.length == 1) ...routeUpload(targets.single, data),
  };
}

Json routeUpload(ClassroomDocument folder, Json data) => {
  'ruleId': folder.id,
  'accountDrive': folder.text('accountDrive'),
  'state': 'pending',
  'targetPupils': folder.strings('pupilIds'),
  'personal': folder.flag('personal'),
  'pupilIds': List<String>.from(data['pupilIds'] as List? ?? []),
  'purpose': folder.text('purpose', 'all'),
  'subject': folder.text('subject'),
};
String uploadLabel(ClassroomDocument m) =>
    switch (m.map('cloudUpload')['state']) {
      'entry' => 'Ablage nach Speichern des Eintrags',
      'pending' => 'Upload ausstehend',
      'review' => 'Ablageziel prüfen',
      'sent' => 'In OneDrive',
      _ => '',
    };
