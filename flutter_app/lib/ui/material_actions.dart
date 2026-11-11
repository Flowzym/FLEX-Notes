part of 'material_library.dart';

bool get materialDeviceAvailable =>
    kIsWeb || defaultTargetPlatform == TargetPlatform.android;
Future<Uint8List> _packMaterials(Map<String, dynamic> args) =>
    MaterialBundle.encode(
      (args['documents'] as List)
          .map((d) => ClassroomDocument.fromJson(Json.from(d as Map)))
          .toList(),
      Map<String, Uint8List>.from(args['files'] as Map),
      args['password'] as String,
    );
Future<({List<ClassroomDocument> documents, Map<String, Uint8List> files})>
_unpackMaterials(Map<String, dynamic> args) => MaterialBundle.decode(
  args['bytes'] as Uint8List,
  args['password'] as String,
);

Future<void> _launchMaterial(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw const DomainError('Der Link konnte nicht geöffnet werden.');
  }
}

Future<void> connectOneDrive(BuildContext context, OneDriveClient drive) async {
  if (!drive.configured && !await setupOneDrive(context, drive)) return;
  if (!context.mounted) return;
  OneDriveAuthorization? auth;
  var cancelled = false, busy = true, reconfigure = false;
  String? error;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) {
        if (auth == null && error == null) {
          // Schedule once, outside build; the local flag also cancels polling when
          // the dialog is closed or the Android back gesture dismisses the route.
          error = '';
          Future<void>(() async {
            try {
              final next = await drive.begin();
              if (!ctx.mounted || cancelled) return;
              update(() {
                auth = next;
                error = null;
                busy = false;
              });
              while (!cancelled && ctx.mounted) {
                await Future<void>.delayed(Duration(seconds: next.interval));
                if (cancelled || !ctx.mounted) return;
                if (await drive.poll(next)) {
                  if (ctx.mounted && !cancelled) Navigator.pop(ctx);
                  return;
                }
              }
            } catch (e) {
              if (ctx.mounted && !cancelled) {
                update(() {
                  error = friendlyError(e);
                  busy = false;
                });
              }
            }
          });
        }
        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) cancelled = true;
          },
          child: FlexModal(
            maxWidth: 520,
            title: const Text('OneDrive verbinden'),
            onClose: () => Navigator.pop(ctx),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (busy) const LinearProgressIndicator(),
                if (error?.isNotEmpty == true) Text(error!),
                if (auth != null) ...[
                  const Text(
                    'Diesen Code auf der Microsoft-Anmeldeseite eingeben:',
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      auth!.userCode,
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx).textTheme.headlineMedium,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () =>
                        guarded(ctx, () => _launchMaterial(auth!.url)),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Bei Microsoft anmelden'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nach der Anmeldung zu FLEX zurückkehren. Der Verbindungsstatus wird automatisch geprüft.',
                  ),
                ],
              ],
            ),
            actions: [
              if (!busy)
                TextButton(
                  onPressed: () {
                    reconfigure = true;
                    Navigator.pop(ctx);
                  },
                  child: const Text('Einrichtung'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen'),
              ),
            ],
          ),
        );
      },
    ),
  );
  cancelled = true;
  drive.cancelAuthorization();
  if (reconfigure &&
      context.mounted &&
      await setupOneDrive(context, drive) &&
      context.mounted) {
    await connectOneDrive(context, drive);
  }
}

Future<void> browseOneDrive(
  BuildContext context,
  NotebookController c,
  OneDriveClient drive, {
  ClassroomDocument? folder,
}) async {
  final root = folder == null ? await drive.graph('/me/drive/root') : null;
  final driveId =
      folder?.text('driveId') ??
      (root!['parentReference'] as Map?)?['driveId'] as String? ??
      (await drive.graph('/me/drive'))['id'] as String;
  final rootId = folder?.text('itemId') ?? root!['id'] as String;
  if (!context.mounted) return;
  final stack = <({String id, String title, String url})>[
    (
      id: rootId,
      title: folder?.title ?? 'OneDrive',
      url: folder?.text('url') ?? root?['webUrl'] as String? ?? '',
    ),
  ];
  var listing = drive.children(drive: driveId, folder: rootId), busy = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => FlexModal(
        maxWidth: 800,
        title: Text(stack.last.title),
        onClose: busy ? null : () => Navigator.pop(ctx),
        headerActions: [
          if (stack.length > 1)
            IconButton(
              tooltip: 'Übergeordneter Ordner',
              onPressed: busy
                  ? null
                  : () => update(() {
                      stack.removeLast();
                      listing = drive.children(
                        drive: driveId,
                        folder: stack.last.id,
                      );
                    }),
              icon: const Icon(Icons.arrow_upward),
            ),
        ],
        content: FutureBuilder<List<Json>>(
          future: listing,
          builder: (ctx, s) {
            if (s.hasError) {
              return Column(
                children: [
                  Text(friendlyError(s.error!)),
                  TextButton(
                    onPressed: () => update(
                      () => listing = drive.children(
                        drive: driveId,
                        folder: stack.last.id,
                      ),
                    ),
                    child: const Text('Erneut laden'),
                  ),
                ],
              );
            }
            if (!s.hasData) return const LinearProgressIndicator();
            final items = s.data!
                .where(
                  (v) =>
                      v['folder'] != null ||
                      RegExp(
                        r'\.(pdf|docx)$',
                        caseSensitive: false,
                      ).hasMatch(v['name'] as String),
                )
                .toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (items.isEmpty)
                  const Text('Keine DOCX- oder PDF-Dateien in diesem Ordner.'),
                for (final item in items)
                  ListTile(
                    leading: Icon(
                      item['folder'] != null
                          ? Icons.folder_outlined
                          : Icons.description_outlined,
                    ),
                    title: Text(item['name'] as String),
                    trailing: Icon(
                      item['folder'] != null ? Icons.chevron_right : Icons.add,
                    ),
                    onTap: busy
                        ? null
                        : () async {
                            if (item['folder'] != null) {
                              update(() {
                                stack.add((
                                  id: item['id'] as String,
                                  title: item['name'] as String,
                                  url: item['webUrl'] as String? ?? '',
                                ));
                                listing = drive.children(
                                  drive: driveId,
                                  folder: stack.last.id,
                                );
                              });
                              return;
                            }
                            update(() => busy = true);
                            final ok = await guarded(ctx, () async {
                              final id = const Uuid().v5(
                                Namespace.url.value,
                                'flex-onedrive:$driveId:${item['id']}',
                              );
                              final old = c.classroom
                                  .where((d) => d.id == id)
                                  .firstOrNull;
                              final fields = <String, dynamic>{
                                'driveId': driveId,
                                'itemId': item['id'],
                                'url': item['webUrl'],
                                'name': item['name'],
                                'extension': (item['name'] as String)
                                    .split('.')
                                    .last
                                    .toLowerCase(),
                                'size': item['size'] ?? 0,
                                if (old == null || old.text('localKey').isEmpty)
                                  'sourceModifiedAt':
                                      item['lastModifiedDateTime'] ?? '',
                                if (old == null)
                                  ...suggestMaterialMetadata(
                                    item['name'] as String,
                                  ),
                                'deleted': false,
                              };
                              await c.saveClassroom(
                                old == null
                                    ? ClassroomDocument.create(
                                        ClassroomKind.material,
                                        item['name'] as String,
                                        fields,
                                        id: id,
                                      )
                                    : old.patch(fields),
                              );
                            });
                            if (ctx.mounted) {
                              update(() => busy = false);
                              if (ok) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Material ist in FLEX verknüpft.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                  ),
              ],
            );
          },
        ),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.folder_open),
            label: const Text('Diesen Ordner merken'),
            onPressed: busy
                ? null
                : () async {
                    update(() => busy = true);
                    final ok = await guarded(ctx, () async {
                      final id = const Uuid().v5(
                        Namespace.url.value,
                        'flex-folder:$driveId:${stack.last.id}',
                      );
                      final old = c.classroom
                          .where((d) => d.id == id)
                          .firstOrNull;
                      await c.saveClassroom(
                        old?.patch({'deleted': false}) ??
                            ClassroomDocument.create(
                              ClassroomKind.folder,
                              stack.last.title,
                              {
                                'driveId': driveId,
                                'itemId': stack.last.id,
                                'url': stack.last.url,
                              },
                              id: id,
                            ),
                      );
                    });
                    if (ctx.mounted) {
                      if (ok) {
                        Navigator.pop(ctx);
                      } else {
                        update(() => busy = false);
                      }
                    }
                  },
          ),
        ],
      ),
    ),
  );
}

Future<void> removeUnusedMaterialFile(
  NotebookController c,
  MaterialFiles files,
  String key,
) async {
  if (key.isEmpty) return;
  await removeUnusedScanFiles(c.repository, files, [key]);
}

Future<ClassroomDocument> cacheMaterial(
  NotebookController c,
  ClassroomDocument material,
  OneDriveClient drive,
  MaterialFiles files,
) async {
  if (material.text('itemId').isEmpty) {
    if (await files.exists(material.text('localKey'))) return material;
    throw const DomainError(
      'Für diesen Link bitte die Datei über die Dateiauswahl hinzufügen.',
    );
  }
  final info = await drive.item(
    material.text('driveId'),
    material.text('itemId'),
  );
  final exists = await files.exists(material.text('localKey'));
  if (exists && material.text('etag') == info['eTag']) return material;
  final bytes = await drive.download(info);
  validateMaterialBytes(bytes, material.text('extension'));
  final key = newId();
  await files.write(key, bytes);
  late ClassroomDocument saved;
  try {
    saved = await c.repository.saveClassroomDocument(
      material.patch({
        'localKey': key,
        'etag': info['eTag'] ?? '',
        'sourceModifiedAt': info['lastModifiedDateTime'] ?? utcNow(),
        'url': info['webUrl'] ?? material.text('url'),
        'size': bytes.length,
      }),
    );
  } catch (_) {
    await files.remove(key);
    rethrow;
  }
  await c.reload();
  try {
    await removeUnusedMaterialFile(c, files, material.text('localKey'));
  } catch (_) {}
  return saved;
}

Future<void> openMaterial(
  BuildContext context,
  NotebookController c,
  ClassroomDocument material, {
  OneDriveClient? drive,
  MaterialFiles files = const LocalMaterialFiles(),
}) async {
  var current = material;
  if (current.text('extension') == 'link' && current.text('url').isNotEmpty) {
    await _launchMaterial(current.text('url'));
    return;
  }
  if (!materialDeviceAvailable) {
    if (current.text('url').isNotEmpty) {
      await _launchMaterial(current.text('url'));
      return;
    }
    throw const DomainError(
      'Lokale Materialdateien sind in der Android-App verfügbar.',
    );
  }
  final ownDrive = drive == null;
  final client = drive ?? OneDriveClient();
  try {
    if (ownDrive) await client.load();
    if (current.text('itemId').isNotEmpty && client.connected) {
      try {
        current = await cacheMaterial(c, current, client, files);
      } catch (e) {
        if (!await files.exists(current.text('localKey'))) rethrow;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Offlinekopie · ${displayDate(current.text('sourceModifiedAt').isEmpty ? null : current.text('sourceModifiedAt'))}',
              ),
            ),
          );
        }
      }
    }
    if (!await files.exists(current.text('localKey'))) {
      if (current.text('url').isNotEmpty) {
        await _launchMaterial(current.text('url'));
        return;
      }
      throw const DomainError(
        'Die lokale Datei fehlt. Bitte die vollständige Sicherung wiederherstellen.',
      );
    }
    if (!context.mounted) return;
    if (current.text('extension') == 'jpg') {
      final bytes = await files.read(current.text('localKey'));
      if (!context.mounted) return;
      await showFlexDetail<void>(
        context: context,
        builder: (ctx) => FlexModal(
          title: Text(current.title),
          maxWidth: 1000,
          onClose: () => Navigator.pop(ctx),
          scrollable: false,
          content: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * .65,
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
            ),
          ),
        ),
      );
    } else if (current.text('extension') == 'pdf') {
      await showFlexDetail<void>(
        context: context,
        builder: (_) => MaterialPdf(
          fileKey: current.text('localKey'),
          title: current.title,
          files: files,
        ),
      );
    } else {
      final bytes = await files.read(current.text('localKey'));
      if (!context.mounted) return;
      await showFlexDetail<void>(
        context: context,
        builder: (_) => MaterialDocx(
          title: current.title,
          bytes: bytes,
          openOriginal: () => kIsWeb
              ? saveBytesFile(
                  current.text('name', '${current.title}.docx'),
                  bytes,
                  mime:
                      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                ).then((_) {})
              : FlexDevice.channel.invokeMethod('openMaterial', {
                  'key': current.text('localKey'),
                  'extension': current.text('extension'),
                  'name': current.text('name', '${current.title}.docx'),
                }),
        ),
      );
    }
  } finally {
    if (ownDrive) client.dispose();
  }
}
