import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../domain/classroom.dart';
import '../domain/drive_rules.dart';
import '../domain/models.dart';
import '../domain/repository.dart';
import 'material_files.dart';
import 'material_index.dart';
import 'onedrive.dart';

class MaterialSyncResult {
  int imported = 0, uploaded = 0, paused = 0;
  final List<String> errors = [];
  String get summary => [
    '$imported aktualisiert',
    '$uploaded hochgeladen',
    if (paused > 0) '$paused Ordner pausiert (Konto oder Schüler prüfen)',
  ].join(' · ');
}

class MaterialSync {
  MaterialSync(this.repo, this.drive, this.files, {this.writer});
  final NotebookRepository repo;
  final OneDriveClient drive;
  final OneDriveClient? writer;
  final MaterialFiles files;

  Future<MaterialSyncResult> run() async {
    final result = MaterialSyncResult();
    var docs = await repo.classroomDocuments();
    final pupils = await repo.pupils();
    final all = docs.where(isDriveRule).toList();
    if (all.isEmpty) return result;
    final account = (await drive.graph('/me/drive'))['id'] as String;
    final rules = all
        .where(
          (f) =>
              f.text('accountDrive') == account && usableDriveRule(f, pupils),
        )
        .toList();
    result.paused = all.length - rules.length;
    final byId = {for (final f in rules) f.id: f};
    // Reconcile the outgoing item before indexing it back into the notebook.
    for (final m in docs.where(
      (d) =>
          d.kind == ClassroomKind.material &&
          !d.deleted &&
          d.map('cloudUpload')['state'] == 'pending',
    )) {
      final job = m.map('cloudUpload');
      if (job['accountDrive'] != account) continue;
      final rule = byId[job['ruleId']];
      try {
        if (rule == null ||
            !rule.flag('outgoing') ||
            rule.flag('personal') != job['personal'] ||
            !setEquals(
              rule.strings('pupilIds').toSet(),
              (job['targetPupils'] as List? ?? []).toSet(),
            ) ||
            rule.text('purpose', 'all') != job['purpose'] ||
            rule.text('subject') != job['subject'] ||
            !setEquals(
              m.strings('pupilIds').toSet(),
              (job['pupilIds'] as List? ?? []).toSet(),
            )) {
          await repo.saveClassroomDocument(
            m.patch({
              'cloudUpload': {...job, 'state': 'review'},
            }),
          );
          continue;
        }
        await _upload(m, rule, account);
        result.uploaded++;
      } catch (e) {
        result.errors.add('${m.title} · ${_reason(e)}');
        if (e is StaleRevision) continue;
        final conflict =
            e is OneDriveResponseError && (e.status == 409 || e.status == 412);
        final error = _reason(e);
        if (job['error'] != error || conflict) {
          try {
            await repo.saveClassroomDocument(
              m.patch({
                'cloudUpload': {
                  ...job,
                  'error': error,
                  if (conflict) 'conflict': true,
                  if (conflict) 'state': 'review',
                },
              }),
            );
          } on StaleRevision {
            /* Newer edit wins. */
          }
        }
      }
    }
    docs = await repo.classroomDocuments();
    final known = {for (final d in docs) d.id: d};
    final found = <String>{};
    final complete = <String>{};
    final changes = <String, ClassroomDocument>{};
    final pendingNames = {
      for (final m in docs.where(
        (d) =>
            d.kind == ClassroomKind.material && d.map('cloudUpload').isNotEmpty,
      ))
        if (m.map('cloudUpload')['state'] != 'sent')
          (m.map('cloudUpload')['ruleId'], m.map('cloudUpload')['name']),
    };
    for (final f in rules.where((f) => f.flag('incoming'))) {
      try {
        final values = await scanMaterialFolder(
          drive,
          f,
          docs,
          boundaryFolders: {
            for (final other in all)
              if (other.id != f.id &&
                  other.text('driveId') == f.text('driveId'))
                other.text('itemId'),
          },
        );
        final current = (await repo.classroomDocuments())
            .where((d) => d.id == f.id)
            .firstOrNull;
        if (current?.revision != f.revision) continue;
        for (var m in values) {
          final old = known[m.id];
          found.add(m.id);
          if (m.deleted ||
              pendingNames.contains((f.id, m.text('remoteName'))) &&
                  m.text('sourcePath') ==
                      '${f.title}/${m.text('remoteName')}') {
            continue;
          }
          final previous = old?.text('cloudRule') ?? '';
          if (previous != f.id ||
              old != null &&
                  old.text('cloudBinding', driveBinding(f)) !=
                      driveBinding(f)) {
            final existing = old?.strings('pupilIds') ?? [];
            final target = f.strings('pupilIds');
            if (previous.isNotEmpty ||
                existing.isNotEmpty &&
                    !setEquals(existing.toSet(), target.toSet())) {
              m = m.patch({'cloudReview': f.id, 'sourceMissing': false});
            } else {
              m = m.patch({
                'cloudRule': f.id,
                'cloudBinding': driveBinding(f),
                'cloudReview': '',
                'sourceMissing': false,
                'pupilIds': target,
                if (m.text('subject').isEmpty) 'subject': f.text('subject'),
              });
            }
          } else {
            m = m.patch({'sourceMissing': false, 'cloudReview': ''});
          }
          if (old == null ||
              jsonEncode(old.toJson()) != jsonEncode(m.toJson())) {
            changes[m.id] = m;
          }
        }
        complete.add(f.id);
        changes[f.id] = f.patch({'lastSync': utcNow(), 'syncError': ''});
      } catch (e) {
        final message = _reason(e);
        result.errors.add('${f.title} · $message');
        if (f.text('syncError') != message) {
          changes[f.id] = f.patch({'syncError': message});
        }
      }
    }
    for (final m in docs.where(
      (m) =>
          m.kind == ClassroomKind.material &&
          !m.deleted &&
          complete.contains(m.text('cloudRule')) &&
          !found.contains(m.id) &&
          !m.flag('sourceMissing'),
    )) {
      changes[m.id] = m.patch({'sourceMissing': true, 'cloudReview': ''});
    }
    if (changes.isNotEmpty) {
      await repo.saveClassroomDocuments(changes.values.toList());
    }
    result.imported = changes.values
        .where((d) => d.kind == ClassroomKind.material)
        .length;
    return result;
  }

  String _reason(Object e) => e is DomainError
      ? e.message
      : 'Abgleich unterbrochen. Bei Verbindung erneut versuchen.';

  Future<void> _upload(
    ClassroomDocument m,
    ClassroomDocument rule,
    String account,
  ) async {
    final cloud = writer ?? drive;
    final job = m.map('cloudUpload'),
        key = m.text('localKey'),
        name = job['name'] as String;
    if (key.isEmpty || key != job['key']) throw const StaleRevision();
    final driveId = rule.text('driveId'), parent = rule.text('itemId');
    if (account != driveId) {
      throw const DomainError('Der Zielordner gehört zu einem anderen Konto.');
    }
    await cloud.verifyAppFolder(driveId, parent, rule.text('appRoot'));
    final bytes = await files.read(key);
    validateMaterialBytes(bytes, m.text('extension'));
    final latest = await repo.classroomDocuments();
    if (!latest.any(
          (d) => d.id == m.id && d.revision == m.revision && !d.deleted,
        ) ||
        !latest.any(
          (f) => f.id == rule.id && f.revision == rule.revision && !f.deleted,
        )) {
      throw const StaleRevision();
    }
    Json remote;
    try {
      remote = await cloud.uploadNew(driveId, parent, name, bytes);
    } on OneDriveResponseError catch (e) {
      if (e.status != 409 && e.status != 412) rethrow;
      remote = await cloud.graph(cloud.childPath(driveId, parent, name));
      if (remote['size'] != bytes.length ||
          !listEquals(await cloud.download(remote), bytes)) {
        rethrow;
      }
    }
    if (remote['id'] is! String || remote['name'] != name) {
      throw const DomainError('OneDrive hat die Ablage noch nicht bestätigt.');
    }
    await repo.saveClassroomDocument(
      m.patch({
        'cloudUpload': {...job, 'state': 'sent', 'error': ''},
        'driveId': driveId,
        'itemId': remote['id'],
        'url': remote['webUrl'] ?? '',
        'remoteName': name,
        'remoteEtag': remote['eTag'] ?? '',
        'etag': remote['eTag'] ?? '',
        'cachedAt': utcNow(),
        'remoteModifiedAt': remote['lastModifiedDateTime'] ?? '',
        'sourceModifiedAt': remote['lastModifiedDateTime'] ?? '',
        'sourcePath': '${rule.title}/$name',
        'cloudRule': rule.id,
        'cloudBinding': driveBinding(rule),
        'sourceMissing': false,
      }),
    );
  }
}

/// Background and foreground can retry the same durable job. Cloud names and
/// local revisions protect both sides if the two isolates overlap.
Future<MaterialSyncResult> syncNotebookMaterials(
  NotebookRepository repo,
  MaterialFiles files,
) async {
  final reader = OneDriveClient(),
      writer = OneDriveClient(appFolderAccess: true);
  try {
    if (!(await repo.classroomDocuments()).any(
      (f) => isDriveRule(f) && (f.flag('incoming') || f.flag('outgoing')),
    )) {
      return MaterialSyncResult();
    }
    await reader.load();
    if (!reader.connected) {
      throw const DomainError('Zum Abgleichen bitte OneDrive verbinden.');
    }
    await writer.load();
    return await MaterialSync(repo, reader, files, writer: writer).run();
  } finally {
    reader.dispose();
    writer.dispose();
  }
}
