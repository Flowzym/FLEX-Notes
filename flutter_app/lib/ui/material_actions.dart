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
      uri.userInfo.isNotEmpty ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw const DomainError('Der Link konnte nicht geöffnet werden.');
  }
}

Future<void> connectOneDrive(BuildContext context, OneDriveClient drive) async {
  if (drive.nativeAuthentication) {
    await connectNativeOneDrive(context, drive);
    return;
  }
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

Future<void> removeUnusedMaterialFile(
  NotebookController c,
  MaterialFiles files,
  String key,
) async {
  if (key.isNotEmpty) await removeUnusedScanFiles(c.repository, files, [key]);
}

Future<ClassroomDocument> cacheMaterial(
  NotebookController c,
  ClassroomDocument material,
  OneDriveClient drive,
  MaterialFiles files,
) async {
  final saved = await cacheDriveMaterial(c.repository, material, drive, files);
  await c.reload();
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
  if (current.text('extension') == 'link') {
    var url = current.text('url');
    if (url.isEmpty && current.text('itemId').isNotEmpty) {
      final client = drive ?? OneDriveClient();
      try {
        if (drive == null) await client.load();
        if (!client.connected && context.mounted) {
          await connectOneDrive(context, client);
        }
        if (!client.connected) return;
        final info = await client.item(
          current.text('driveId'),
          current.text('itemId'),
        );
        url = info['webUrl'] as String? ?? '';
      } finally {
        if (drive == null) client.dispose();
      }
    }
    if (url.isEmpty) {
      throw const DomainError(
        'OneDrive liefert keinen Link zu diesem Lernmedium.',
      );
    }
    await _launchMaterial(url);
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
    // Open durable local bytes immediately. Source refresh is an explicit
    // action in material details, so poor reception cannot delay a lesson.
    if (!await files.exists(current.text('localKey'))) {
      if (ownDrive) await client.load();
      if (current.text('itemId').isNotEmpty &&
          current.text('url').isEmpty &&
          !client.connected &&
          !current.flag('sourceMissing')) {
        if (!context.mounted) return;
        await connectOneDrive(context, client);
        if (!client.connected) return;
      }
      if (current.text('itemId').isNotEmpty && client.connected) {
        current = await cacheMaterial(c, current, client, files);
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
    if (current.text('itemId').isNotEmpty && current.text('cachedAt').isEmpty) {
      final correction = legacyCloudCorrection(
        current.toJson(),
        await files.read(current.text('localKey')),
      );
      if (correction != null) {
        current = await c.repository.saveClassroomDocument(
          current.patch(correction),
        );
        await c.reload();
      }
    }
    if (!context.mounted) return;
    if ({'jpg', 'png'}.contains(current.text('extension'))) {
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
