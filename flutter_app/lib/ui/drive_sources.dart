part of 'material_library.dart';

Future<String?> _folderName(BuildContext context) async {
  String value = '';
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => FlexModal(
        title: const Text('Neuer OneDrive-Ordner'),
        onClose: () => Navigator.pop(ctx),
        content: TextField(
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Ordnername'),
          onChanged: (v) => update(() => value = v.trim()),
        ),
        actions: [
          FilledButton(
            onPressed:
                value.isEmpty ||
                    value.endsWith('.') ||
                    RegExp(r'[<>:"/\\|?*]').hasMatch(value)
                ? null
                : () => Navigator.pop(ctx, value),
            child: const Text('Anlegen'),
          ),
        ],
      ),
    ),
  );
}

Future<bool> _configureDriveFolder(
  BuildContext context,
  NotebookController c,
  OneDriveClient drive,
  _DriveFolder folder,
  String account,
  String appRoot, {
  String? folderPath,
}) async {
  final old = c.classroom
      .where(
        (f) =>
            f.kind == ClassroomKind.folder &&
            f.text('driveId') == folder.drive &&
            f.text('itemId') == folder.id,
      )
      .firstOrNull;
  final id = const Uuid().v5(
    Namespace.url.value,
    'flex-folder:${folder.drive}:${folder.id}',
  );
  final base =
      old ??
      ClassroomDocument.create(ClassroomKind.folder, folder.name, {
        'driveId': folder.drive,
        'itemId': folder.id,
        'url': folder.url,
      }, id: id);
  final pupils = c.pupils.where((p) => !p.archived && !p.deleted).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  var pupil = base.strings('pupilIds').firstOrNull ?? '',
      purpose = base.text('purpose', 'all'),
      subject = base.text('subject');
  var incoming = old == null || !isDriveRule(base) || base.flag('incoming'),
      outgoing = base.flag('outgoing') && folder.writable,
      planning = base.flag('planningFolder'),
      busy = false,
      error = '';
  if (!pupils.any((p) => p.id == pupil) && base.flag('personal')) {
    pupil = 'missing';
  }
  return (await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => FlexModal(
            title: Text(folder.name),
            onClose: busy ? null : () => Navigator.pop(ctx),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: planning ? 'planning' : pupil,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Zuordnung in FLEX',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('FLEX-Klasse'),
                    ),
                    const DropdownMenuItem(
                      value: 'planning',
                      child: Text('Unterrichtsplanung'),
                    ),
                    if (pupil == 'missing')
                      const DropdownMenuItem(
                        value: 'missing',
                        child: Text('Schüler neu auswählen'),
                      ),
                    for (final p in pupils)
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => update(() {
                          planning = v == 'planning';
                          pupil = planning ? '' : v!;
                          if (planning) {
                            incoming = true;
                            outgoing = false;
                          }
                        }),
                ),
                if (planning)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'FLEX liest Schuljahr und Unterrichtstag aus dem Ordner. Eindeutige Materialkürzel ordnen auch vorhandene Dateien den Schülern zu.',
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: subject,
                  enabled: !busy,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Fach · optional',
                    counterText: '',
                  ),
                  onChanged: (v) => subject = v.trim(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dateien in FLEX zuordnen'),
                  value: incoming,
                  onChanged: busy ? null : (v) => update(() => incoming = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('FLEX-Scans hier ablegen'),
                  subtitle: folder.writable
                      ? null
                      : const Text(
                          'Für Uploads einen Ordner im FLEX-App-Ordner wählen.',
                        ),
                  value: outgoing,
                  onChanged: busy || !folder.writable || planning
                      ? null
                      : (v) => update(() => outgoing = v),
                ),
                if (outgoing)
                  DropdownButtonFormField<String>(
                    initialValue: purpose,
                    decoration: const InputDecoration(
                      labelText: 'Für welche Scans?',
                    ),
                    items: [
                      for (final e in drivePurposes.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: busy ? null : (v) => purpose = v!,
                  ),
                if (busy) const LinearProgressIndicator(),
                if (error.isNotEmpty) Text(error),
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: busy || pupil == 'missing'
                    ? null
                    : () async {
                        update(() {
                          busy = true;
                          error = '';
                        });
                        try {
                          final next = base.patch({
                            'title': folder.name,
                            'deleted': false,
                            'accountDrive': account,
                            'incoming': incoming,
                            'planningFolder': planning,
                            'planningReady':
                                planning &&
                                base.flag('planningFolder') &&
                                base.flag('planningReady') &&
                                base.flag('incoming'),
                            'folderPath': folderPath ?? driveFolderPath(base),
                            'outgoing': outgoing,
                            'personal': pupil.isNotEmpty,
                            'pupilIds': [if (pupil.isNotEmpty) pupil],
                            'purpose': purpose,
                            'subject': subject,
                            'appRoot': folder.writable
                                ? appRoot
                                : base.text('appRoot'),
                            'syncError': '',
                          });
                          if (incoming) {
                            final items = await scanMaterialFolder(
                              drive,
                              next,
                              c.classroom,
                              boundaryFolders: {
                                for (final d in c.classroom.where(isDriveRule))
                                  if (d.id != next.id &&
                                      d.text('driveId') == next.text('driveId'))
                                    d.text('itemId'),
                              },
                            );
                            if (!ctx.mounted) return;
                            final dest =
                                pupils
                                    .where((p) => p.id == pupil)
                                    .firstOrNull
                                    ?.name ??
                                'FLEX-Klasse';
                            if (!await confirmFlex(
                              ctx,
                              'Ordner verbinden?',
                              planning ||
                                      pupil.isEmpty &&
                                          items.any(
                                            (d) => isPlanningSourcePath(
                                              d.text('sourcePath'),
                                            ),
                                          )
                                  ? _planningPreview(items, c, next)
                                  : '${items.length} vorhandene Dateien in „${folder.name}“. Neue Materialien werden „$dest“ zugeordnet.\n\n${items.take(4).map((d) => d.title).join('\n')}',
                              accept: 'Verbinden',
                            )) {
                              return;
                            }
                          }
                          await c.saveClassroom(next);
                          unawaited(c.syncMaterials());
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            update(() => error = friendlyError(e));
                          }
                        } finally {
                          if (ctx.mounted) update(() => busy = false);
                        }
                      },
                child: Text(incoming ? 'Vorschau prüfen' : 'Regel speichern'),
              ),
            ],
          ),
        ),
      )) ??
      false;
}

class _DriveSources extends StatelessWidget {
  const _DriveSources(this.c, this.drive, this.run);
  final NotebookController c;
  final OneDriveClient drive;
  final Future<void> Function(Future<void> Function()) run;

  Future<void> browse(
    BuildContext ctx, {
    bool app = false,
    ClassroomDocument? folder,
    bool configure = false,
    bool review = false,
  }) async {
    final client = app ? OneDriveClient(appFolderAccess: true) : drive;
    try {
      if (app) await client.load();
      if (!ctx.mounted) return;
      if (!client.connected) await connectOneDrive(ctx, client);
      if (!ctx.mounted || !client.connected) return;
      if (app) {
        try {
          await client.graph('/me/drive/special/approot');
        } on DomainError catch (e) {
          if (e is! OneDriveSignInRequired &&
              !(e is OneDriveResponseError && e.status == 403)) {
            rethrow;
          }
          if (!ctx.mounted) return;
          await connectOneDrive(ctx, client);
          if (!ctx.mounted || !client.connected) return;
          await client.graph('/me/drive/special/approot');
        }
      }
      if (!ctx.mounted) return;
      if (folder != null && (configure || review)) {
        final account = (await client.graph('/me/drive'))['id'] as String;
        if (folder.text('accountDrive').isNotEmpty &&
            account != folder.text('accountDrive')) {
          throw const DomainError(
            'Dieser Ordner gehört zu einem anderen OneDrive-Konto.',
          );
        }
        if (app) {
          await client.verifyAppFolder(
            folder.text('driveId'),
            folder.text('itemId'),
            folder.text('appRoot'),
          );
        }
        if (!ctx.mounted) return;
        if (review) {
          await reviewOneDriveFolder(ctx, c, client, folder);
        } else {
          await _configureDriveFolder(
            ctx,
            c,
            client,
            (
              id: folder.text('itemId'),
              drive: folder.text('driveId'),
              name: folder.title,
              url: folder.text('url'),
              writable: app,
            ),
            account,
            folder.text('appRoot'),
          );
        }
        return;
      }
      await browseOneDrive(ctx, c, client, folder: folder, appFolder: app);
    } finally {
      if (app) {
        client.dispose();
        await drive.load();
      }
    }
  }

  Future<void> resolveUpload(BuildContext ctx, ClassroomDocument m) async {
    final options = c.classroom
        .where((d) => usableDriveRule(d, c.pupils) && d.flag('outgoing'))
        .toList();
    final target = await showDialog<String>(
      context: ctx,
      builder: (dia) => FlexModal(
        title: Text(m.title),
        onClose: () => Navigator.pop(dia),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (options.isEmpty)
              const Text('Zuerst im FLEX-App-Ordner ein Ablageziel verbinden.'),
            for (final f in options)
              ListTile(
                title: Text(f.title),
                subtitle: Text(_target(f)),
                onTap: () => Navigator.pop(dia, f.id),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dia, 'local'),
            child: const Text('Nur auf dem Gerät behalten'),
          ),
        ],
      ),
    );
    if (target == null || !ctx.mounted) return;
    if (target == 'local') {
      await c.saveClassroom(m.patch({'cloudUpload': {}}));
      return;
    }
    final job = m.map('cloudUpload');
    final conflict = job['conflict'] == true;
    await c.saveClassroom(
      m.patch({
        'cloudUpload': {
          ...job,
          ...routeUpload(
            options.singleWhere((f) => f.id == target),
            m.toJson(),
          ),
          'conflict': false,
          'error': '',
          if (conflict)
            'name': (job['name'] as String).replaceFirst(
              '[FLEX-',
              '[${newId().substring(0, 8)} FLEX-',
            ),
        },
      }),
    );
    await c.syncMaterials();
  }

  String _target(ClassroomDocument f) => [
    f.flag('personal')
        ? c.pupils
                  .where((p) => f.strings('pupilIds').contains(p.id))
                  .firstOrNull
                  ?.name ??
              'Schüler nicht verfügbar'
        : 'FLEX-Klasse',
    if (f.text('subject').isNotEmpty) f.text('subject'),
    drivePurposes[f.text('purpose', 'all')]!,
  ].join(' · ');
  Future<void> reviewMove(
    BuildContext ctx,
    ClassroomDocument m,
    ClassroomDocument f,
  ) async {
    final use = await showDialog<bool>(
      context: ctx,
      builder: (dia) => FlexModal(
        title: const Text('Zuordnung prüfen'),
        onClose: () => Navigator.pop(dia),
        content: Text(
          '„${m.title}“ liegt in „${f.title}“. Zuordnung zu ${_target(f)} übernehmen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dia, false),
            child: const Text('Bisherige behalten'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dia, true),
            child: const Text('Neue übernehmen'),
          ),
        ],
      ),
    );
    if (use == null) return;
    final retain = m.strings('pupilIds').toSet();
    final oldBinding = m.text('cloudBinding');
    if (oldBinding.startsWith('pupil:')) retain.remove(oldBinding.substring(6));
    retain.addAll(f.strings('pupilIds'));
    await c.saveClassroom(
      m.patch({
        'cloudRule': f.id,
        'cloudReview': '',
        'cloudBinding': driveBinding(f),
        if (use) 'pupilIds': retain.toList(),
        if (use && f.text('subject').isNotEmpty) 'subject': f.text('subject'),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folders = c.classroom
        .where((f) => f.kind == ClassroomKind.folder && !f.deleted)
        .toList();
    final issues = c.classroom
        .where(
          (d) =>
              d.kind == ClassroomKind.material &&
              !d.deleted &&
              (d.text('cloudReview').isNotEmpty ||
                  [
                    'review',
                    'pending',
                  ].contains(d.map('cloudUpload')['state']) ||
                  d.flag('sourceMissing')),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActionHeading(
          leading: Text(
            'OneDrive',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          actions: [
            if (drive.hasAccount)
              IconButton(
                tooltip: 'Konto trennen',
                onPressed: () => run(drive.disconnect),
                icon: const Icon(Icons.logout),
              ),
          ],
        ),
        if ((drive.accountName ?? '').isNotEmpty) Text(drive.accountName!),
        _PlanningInbox(c),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => run(() => browse(context)),
              icon: const Icon(Icons.folder_open),
              label: Text(
                drive.connected ? 'Dateien durchsuchen' : 'OneDrive verbinden',
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => run(() => browse(context, app: true)),
              icon: const Icon(Icons.drive_folder_upload_outlined),
              label: const Text('FLEX-App-Ordner'),
            ),
          ],
        ),
        if (folders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Öffne einen Ordner und wähle „Ordner verknüpfen“. Im FLEX-App-Ordner kannst du auch Scans ablegen.',
            ),
          ),
        if (folders.isNotEmpty) ...[
          const Divider(),
          ActionHeading(
            leading: const Text('Verknüpfte Ordner'),
            actions: [
              TextButton.icon(
                onPressed: c.syncingMaterials ? null : c.syncMaterials,
                icon: const Icon(Icons.sync),
                label: const Text('Jetzt abgleichen'),
              ),
            ],
          ),
          if (c.syncingMaterials) const LinearProgressIndicator(),
          if (c.syncMessage.isNotEmpty) Text(c.syncMessage),
          for (final f in folders)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(f.title),
              subtitle: Text(
                [
                  if (f.flag('planningFolder'))
                    'Unterrichtsplanung'
                  else
                    _target(f),
                  if (f.flag('incoming')) 'Einlesen',
                  if (f.flag('outgoing')) 'Scans ablegen',
                  if (f.text('lastSync').isNotEmpty)
                    'Abgleich ${displayDate(dateOnly(DateTime.parse(f.text('lastSync')).toLocal()))}',
                  if (f.text('syncError').isNotEmpty) f.text('syncError'),
                ].join(' · '),
              ),
              onTap: () => run(
                () => browse(
                  context,
                  app: f.text('appRoot').isNotEmpty,
                  folder: f,
                ),
              ),
              trailing: PopupMenuButton<String>(
                tooltip: 'Ordner verwalten',
                onSelected: (value) => run(() async {
                  if (value == 'edit' || value == 'review') {
                    await browse(
                      context,
                      app: f.text('appRoot').isNotEmpty,
                      folder: f,
                      configure: value == 'edit',
                      review: value == 'review',
                    );
                  } else if (await confirmFlex(
                    context,
                    'Ordnerverknüpfung entfernen?',
                    f.title,
                    accept: 'Entfernen',
                  )) {
                    await c.saveClassroom(f.patch({'deleted': true}));
                  }
                }),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Regel bearbeiten')),
                  PopupMenuItem(
                    value: 'review',
                    child: Text('Dateien einzeln prüfen'),
                  ),
                  PopupMenuItem(
                    value: 'unlink',
                    child: Text('Verknüpfung entfernen'),
                  ),
                ],
              ),
            ),
        ],
        if (issues.isNotEmpty) ...[
          const Divider(),
          const Text('Offene Zuordnungen und Übertragungen'),
          for (final m in issues)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(m.title),
              subtitle: Text(
                m.text('cloudReview').isNotEmpty
                    ? 'Ziel geändert · Zuordnung prüfen'
                    : m.flag('sourceMissing')
                    ? 'Quelle im Ordner fehlt'
                    : [
                        uploadLabel(m),
                        if ((m.map('cloudUpload')['error'] ?? '') != '')
                          m.map('cloudUpload')['error'],
                      ].join(' · '),
              ),
              onTap: () => run(() async {
                if (m.text('cloudReview').isNotEmpty) {
                  final f = folders
                      .where((f) => f.id == m.text('cloudReview'))
                      .firstOrNull;
                  if (f != null) await reviewMove(context, m, f);
                } else if (m.map('cloudUpload')['state'] == 'review') {
                  await resolveUpload(context, m);
                } else if (m.map('cloudUpload')['state'] == 'pending') {
                  await resolveUpload(context, m);
                } else {
                  await showMaterialDetails(context, c, m);
                }
              }),
            ),
        ],
      ],
    );
  }
}
