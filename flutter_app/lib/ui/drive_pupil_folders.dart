part of 'material_library.dart';

Future<void> _setupPupilFolders(
  BuildContext context,
  NotebookController c,
  OneDriveClient client,
  _DriveFolder parent,
  String appRoot,
) async {
  final pupils = c.pupils.where((p) => !p.archived && !p.deleted).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  final names = <String, int>{};
  String safeName(String name) => name
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), ' ')
      .trim()
      .replaceAll(RegExp(r'[. ]+$'), '');
  for (final p in pupils) {
    final n = safeName(p.name).toLowerCase();
    names[n] = (names[n] ?? 0) + 1;
  }
  final children = await client.children(
    drive: parent.drive,
    folder: parent.id,
  );
  final options =
      <({Pupil pupil, String name, Json? existing, int count, bool blocked})>[];
  for (final p in pupils) {
    var name = safeName(p.name);
    if (name.isEmpty) name = 'Schüler';
    if (name.runes.length > 100) {
      name = String.fromCharCodes(name.runes.take(100));
    }
    if ((names[safeName(p.name).toLowerCase()] ?? 0) > 1) {
      name += ' · ${p.id.substring(0, p.id.length.clamp(0, 8))}';
    }
    final linkedIds = c.classroom
        .where(
          (d) =>
              isDriveRule(d) &&
              d.text('driveId') == parent.drive &&
              d.flag('personal') &&
              d.strings('pupilIds').contains(p.id) &&
              d.text('purpose', 'all') == 'all' &&
              d.text('subject').isEmpty &&
              (d.flag('incoming') || d.flag('outgoing')),
        )
        .map((d) => d.text('itemId'))
        .toSet();
    final linked = children
        .where((item) => linkedIds.contains(item['id']))
        .firstOrNull;
    if (linked != null) name = linked['name'] as String;
    final item =
        linked ??
        children
            .where(
              (j) =>
                  (j['name'] as String?)?.toLowerCase() == name.toLowerCase(),
            )
            .firstOrNull;
    final rule = c.classroom
        .where(
          (d) =>
              !d.deleted &&
              d.kind == ClassroomKind.folder &&
              d.text('driveId') == parent.drive &&
              d.text('itemId') == item?['id'],
        )
        .firstOrNull;
    final blocked =
        item != null &&
        (item['folder'] == null ||
            item['remoteItem'] != null ||
            rule != null && (rule.flag('incoming') || rule.flag('outgoing')));
    int count = 0;
    if (item != null && !blocked) {
      final doc = ClassroomDocument.create(ClassroomKind.folder, name, {
        'driveId': parent.drive,
        'itemId': item['id'],
      });
      count = (await scanMaterialFolder(
        client,
        doc,
        c.classroom,
        boundaryFolders: {
          for (final r in c.classroom.where(isDriveRule)) r.text('itemId'),
        },
      )).length;
    }
    options.add((
      pupil: p,
      name: name,
      existing: item,
      count: count,
      blocked: blocked,
    ));
  }
  if (!context.mounted) return;
  final chosen = <String>{};
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => FlexModal(
        title: const Text('Schülerordner einrichten'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unter „${parent.name}“ · Neue Dateien zuordnen und Scans des jeweiligen Schülers ablegen.',
            ),
            if (options.isEmpty)
              const Text('Zuerst einen Schüler unter Live → Notizen anlegen.'),
            for (final o in options)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(o.pupil.name),
                subtitle: Text(
                  '${o.name} · ${o.blocked
                      ? 'bereits belegt'
                      : o.existing == null
                      ? 'neuer Ordner'
                      : '${o.count} vorhandene Dateien'}',
                ),
                value: chosen.contains(o.pupil.id),
                onChanged: o.blocked
                    ? null
                    : (v) => update(() {
                        if (v == true) {
                          chosen.add(o.pupil.id);
                        } else {
                          chosen.remove(o.pupil.id);
                        }
                      }),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: chosen.isEmpty ? null : () => Navigator.pop(ctx, true),
            child: Text('${chosen.length} verbinden'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true) return;
  await client.verifyAppFolder(parent.drive, parent.id, appRoot);
  for (final o in options.where((o) => chosen.contains(o.pupil.id))) {
    final item =
        o.existing ??
        await client.createFolder(parent.drive, parent.id, o.name);
    final folderId = item['id'] as String;
    final id = const Uuid().v5(
      Namespace.url.value,
      'flex-folder:${parent.drive}:$folderId',
    );
    final base =
        c.classroom.where((f) => f.id == id).firstOrNull ??
        ClassroomDocument.create(ClassroomKind.folder, o.name, {
          'driveId': parent.drive,
          'itemId': folderId,
        }, id: id);
    await c.saveClassroom(
      base.patch({
        'deleted': false,
        'url': item['webUrl'] ?? '',
        'accountDrive': parent.drive,
        'appRoot': appRoot,
        'personal': true,
        'planningFolder': false,
        'planningReady': false,
        'pupilIds': [o.pupil.id],
        'purpose': 'all',
        'subject': '',
        'incoming': true,
        'outgoing': true,
      }),
    );
  }
  await c.syncMaterials();
}
