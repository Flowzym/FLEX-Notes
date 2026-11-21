import 'dart:convert';
import 'dart:typed_data';
import '../domain/classroom.dart';
import '../domain/models.dart';
import '../domain/repository.dart';
import '../domain/teaching_sheet.dart';
import 'onedrive.dart';

/// Only planning corrections are transferable. The lesson run, observations,
/// roster IDs and original Word document never enter this envelope.
class TeachingExchange {
  TeachingExchange(this.drive, this.account, this.root);
  final OneDriveClient drive;
  final String account, root;
  static Future<TeachingExchange> open(
    OneDriveClient drive,
    String account,
  ) async {
    final app = await drive.graph('/me/drive/special/approot');
    if (account.isEmpty ||
        app['id'] is! String ||
        (app['parentReference'] as Map?)?['driveId'] != account) {
      throw const DomainError(
        'Bitte dasselbe OneDrive-Konto für Planung und FLEX-App-Ordner wählen.',
      );
    }
    return TeachingExchange(drive, account, app['id'] as String);
  }

  String _binding(ClassroomDocument m, ClassroomDocument folder) {
    if (!isTeachingSource(m) ||
        m.text('driveId') != account ||
        folder.deleted ||
        folder.id != m.text('cloudRule') ||
        !folder.flag('incoming') ||
        folder.flag('personal') ||
        folder.text('accountDrive') != account ||
        folder.text('driveId') != account ||
        m.text('itemId').isEmpty) {
      throw const DomainError(
        'Die Planung ist keinem aktiven Klassenordner dieses Kontos zugeordnet.',
      );
    }
    return sheetHash(
      jsonEncode([account, folder.text('itemId'), m.text('itemId')]),
    );
  }

  String _name(String id) => 'FLEX-Unterricht-$id.json';
  Map<String, Json>? _listed;
  Future<void> listAvailable() async {
    final files = await drive.children(drive: account, folder: root);
    _listed = {
      for (final f in files)
        if (f['name'] is String &&
            (f['name'] as String).startsWith('FLEX-Unterricht-'))
          f['name'] as String: f,
    };
  }

  Future<Json?> _remote(String id) async {
    final snapshot = _listed;
    if (snapshot != null) {
      final f = snapshot[_name(id)];
      if (f == null || f.containsKey('@microsoft.graph.downloadUrl')) return f;
      return drive.item(account, f['id'] as String);
    }
    try {
      return await drive.graph(drive.childPath(account, root, _name(id)));
    } on OneDriveResponseError catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<ClassroomDocument> pull(
    NotebookRepository repo,
    ClassroomDocument m,
    ClassroomDocument folder,
  ) async {
    final next = await preview(m, folder);
    return identical(next, m) ? m : repo.saveClassroomDocument(next);
  }

  Future<ClassroomDocument> preview(
    ClassroomDocument m,
    ClassroomDocument folder, {
    bool replaceLocal = false,
  }) async {
    final id = _binding(m, folder), local = m.map('planEdits');
    final remote = await _remote(id);
    if (remote == null) return m;
    final tag = remote['eTag'];
    if (tag is! String || tag.isEmpty) {
      throw const DomainError('OneDrive hat keine prüfbare Version geliefert.');
    }
    if (!replaceLocal && local['cloudTag'] == tag) return m;
    if (local['dirty'] == true && !replaceLocal) {
      throw const DomainError(
        'Ein anderer Planstand ist verfügbar. Eigene Korrekturen zuerst im Planvergleich prüfen.',
      );
    }
    final data = jsonDecode(
      utf8.decode(await drive.download(remote, maxBytes: 150000)),
    );
    if (data is! Map ||
        data['format'] != 'FLEX-Unterricht' ||
        data['version'] != 1 ||
        data['binding'] != id ||
        data['edits'] is! Map) {
      throw const DomainError('Der Planstand gehört nicht zu dieser Planung.');
    }
    final edits = Json.from(data['edits'] as Map);
    if (edits.keys.any((k) => k != 'changes' && k != 'order')) {
      throw const DomainError('Unbekannte Felder im Planstand.');
    }
    validateTeachingSheet(edits, edits: true);
    return m.patch({
      'planEdits': {...edits, 'cloudTag': tag, 'dirty': false},
    });
  }

  Future<ClassroomDocument> publish(
    NotebookRepository repo,
    ClassroomDocument m,
    ClassroomDocument folder,
  ) async {
    final id = _binding(m, folder), local = m.map('planEdits');
    final edits = {
      'changes': [
        for (final r in sheetList(local, 'changes'))
          {
            for (final k in ['id', ...sheetFields.keys])
              if (r.containsKey(k)) k: r[k],
          },
      ],
      'order': local['order'] ?? <String>[],
    };
    validateTeachingSheet(edits, edits: true);
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'FLEX-Unterricht',
          'version': 1,
          'binding': id,
          'edits': edits,
        }),
      ),
    );
    final remote = await _remote(id);
    if ((local['cloudTag'] ?? '') != (remote?['eTag'] ?? '')) {
      throw const DomainError(
        'Ein neuerer Planstand liegt in OneDrive. Bitte zuerst vergleichen.',
      );
    }
    final saved = remote == null
        ? await drive.uploadNew(account, root, _name(id), bytes)
        : await drive.replaceVersion(
            account,
            remote['id'] as String,
            remote['eTag'] as String,
            bytes,
          );
    if (saved['eTag'] is! String || (saved['eTag'] as String).isEmpty) {
      throw const DomainError('Die Freigabe wurde noch nicht bestätigt.');
    }
    return repo.saveClassroomDocument(
      m.patch({
        'planEdits': {...edits, 'cloudTag': saved['eTag'], 'dirty': false},
      }),
    );
  }
}
