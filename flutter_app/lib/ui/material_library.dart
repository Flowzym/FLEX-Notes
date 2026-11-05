import 'dart:async';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flex_device/flex_device.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';
import '../services/material_files.dart';
import '../services/onedrive.dart';
import 'backup_dialog.dart';
import 'classroom_editor.dart';
import 'common.dart';
import 'draft_buffer.dart';
import 'flex_modal.dart';
import 'material_pdf.dart';
import 'surfaces.dart';

bool get materialDeviceAvailable =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
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
  OneDriveAuthorization? auth;
  var cancelled = false, busy = true;
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
                                'sourceModifiedAt':
                                    item['lastModifiedDateTime'] ?? '',
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
  final docs = await c.repository.classroomDocuments();
  final drafts = await c.repository.dialogDrafts();
  if (docs.any((d) => d.text('localKey') == key) ||
      drafts.any((d) => d.data['localKey'] == key)) {
    return;
  }
  await files.remove(key);
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
  MaterialFiles files = const DeviceMaterialFiles(),
}) async {
  var current = material;
  if (current.text('extension') != 'pdf' && current.text('url').isNotEmpty) {
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
        'Die lokale Datei fehlt. Bitte das Materialpaket wiederherstellen.',
      );
    }
    if (!context.mounted) return;
    if (current.text('extension') == 'pdf') {
      await showDialog<void>(
        context: context,
        builder: (_) => MaterialPdf(
          fileKey: current.text('localKey'),
          title: current.title,
        ),
      );
    } else {
      await FlexDevice.channel.invokeMethod('openMaterial', {
        'key': current.text('localKey'),
        'extension': current.text('extension'),
        'name': current.text('name', '${current.title}.docx'),
      });
    }
  } finally {
    if (ownDrive) client.dispose();
  }
}

class MaterialLibraryPage extends StatefulWidget {
  const MaterialLibraryPage({super.key, required this.controller});
  final NotebookController controller;
  @override
  State<MaterialLibraryPage> createState() => _MaterialLibraryPageState();
}

class _MaterialLibraryPageState extends State<MaterialLibraryPage>
    with AutomaticKeepAliveClientMixin {
  NotebookController get c => widget.controller;
  final drive = OneDriveClient();
  final files = const DeviceMaterialFiles();
  String query = '';
  bool busy = false, trash = false;
  String? error;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    drive.load().catchError((Object e) {
      if (mounted) setState(() => error = friendlyError(e));
    });
  }

  @override
  void dispose() {
    drive.dispose();
    super.dispose();
  }

  Future<void> action(Future<void> Function() run) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await run();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> importFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'DOCX / PDF',
          extensions: ['docx', 'pdf'],
          mimeTypes: [
            'application/pdf',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          ],
        ),
      ],
    );
    if (file == null) return;
    if (await file.length() > 20000000) {
      throw const DomainError('Bitte eine Datei bis zu 20 MB auswählen.');
    }
    final bytes = BytesBuilder();
    await for (final chunk in file.openRead()) {
      if (bytes.length + chunk.length > 20000000) {
        throw const DomainError('Die Datei überschreitet 20 MB.');
      }
      bytes.add(chunk);
    }
    final data = bytes.takeBytes(),
        ext = file.name.split('.').last.toLowerCase();
    validateMaterialBytes(data, ext);
    final key = newId();
    await files.write(key, data);
    try {
      await c.repository.saveClassroomDocument(
        ClassroomDocument.create(ClassroomKind.material, file.name, {
          'localKey': key,
          'name': file.name,
          'extension': ext,
          'size': data.length,
          'sourceModifiedAt': utcNow(),
        }),
      );
    } catch (_) {
      await files.remove(key);
      rethrow;
    }
    await c.reload();
  }

  Future<void> exportBundle() async {
    final materials = c.classroom
        .where((d) => !d.deleted && d.kind == ClassroomKind.material)
        .toList();
    if (materials.isEmpty) {
      throw const DomainError('Noch keine Materialien vorhanden.');
    }
    final chosen = await chooseMaterials(
      context,
      c,
      materials.map((d) => d.id).toList(),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    final password = await backupPassword(context, opening: false);
    if (password == null || !mounted) return;
    final selected = materials.where((d) => chosen.contains(d.id)).toList(),
        data = <String, Uint8List>{};
    for (final d in selected) {
      if (d.text('localKey').isNotEmpty) {
        data[d.text('localKey')] = await files.read(d.text('localKey'));
      }
    }
    final bytes = await compute(_packMaterials, {
      'documents': selected.map((d) => d.toJson()).toList(),
      'files': data,
      'password': password,
    });
    await saveBytesFile(
      'FLEX-Materialien-${dateOnly(DateTime.now())}.flexmaterials',
      bytes,
      mime: 'application/octet-stream',
    );
  }

  Future<void> importBundle() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'FLEX-Materialpaket',
          extensions: ['flexmaterials'],
          mimeTypes: ['application/octet-stream'],
        ),
      ],
    );
    if (file == null) return;
    if (await file.length() > MaterialBundle.maxPlain + 52) {
      throw const DomainError('Das Materialpaket ist zu groß.');
    }
    final buffer = BytesBuilder();
    await for (final chunk in file.openRead()) {
      if (buffer.length + chunk.length > MaterialBundle.maxPlain + 52) {
        throw const DomainError('Das Materialpaket ist zu groß.');
      }
      buffer.add(chunk);
    }
    if (!mounted) return;
    final password = await backupPassword(context, opening: true);
    if (password == null || !mounted) return;
    final bundle = await compute(_unpackMaterials, {
      'bytes': buffer.takeBytes(),
      'password': password,
    });
    if (!mounted) return;
    final before = {for (final d in c.classroom) d.id: d};
    final selected = {
      for (final d in bundle.documents)
        if (!before.containsKey(d.id)) d.id,
    };
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => FlexModal(
          title: const Text('Materialpaket prüfen'),
          onClose: () => Navigator.pop(ctx, false),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in bundle.documents)
                CheckboxListTile(
                  title: Text(d.title),
                  subtitle: Text(
                    before.containsKey(d.id)
                        ? 'Vorhandene Metadaten und Offlinekopie ersetzen'
                        : 'Neues Material',
                  ),
                  value: selected.contains(d.id),
                  onChanged: (v) => update(() {
                    if (v == true) {
                      selected.add(d.id);
                    } else {
                      selected.remove(d.id);
                    }
                  }),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    final written = <String>[], documents = <ClassroomDocument>[];
    try {
      for (final doc in bundle.documents.where(
        (d) => selected.contains(d.id),
      )) {
        var next = doc;
        if (doc.text('localKey').isNotEmpty) {
          final key = newId();
          await files.write(key, bundle.files[doc.text('localKey')]!);
          written.add(key);
          next = next.patch({'localKey': key});
        }
        final old = before[doc.id];
        documents.add(
          next.patch({
            'revision': old?.revision ?? 0,
            'createdAtUtc':
                old?.text('createdAtUtc') ?? next.text('createdAtUtc'),
            'deleted': false,
          }),
        );
      }
      await c.repository.saveClassroomDocuments(documents);
    } catch (_) {
      for (final key in written) {
        await files.remove(key);
      }
      rethrow;
    }
    await c.reload();
    for (final doc in documents) {
      try {
        await removeUnusedMaterialFile(
          c,
          files,
          before[doc.id]?.text('localKey') ?? '',
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: Listenable.merge([c, drive]),
      builder: (ctx, _) {
        final materials = c.classroom
            .where(
              (d) =>
                  d.kind == ClassroomKind.material &&
                  d.deleted == trash &&
                  '${d.title} ${d.text('subject')} ${d.text('topic')} ${d.text('note')}'
                      .toLowerCase()
                      .contains(query.toLowerCase()),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Materialien & Planungen',
              style: Theme.of(ctx).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => action(() => connectOneDrive(ctx, drive)),
                  icon: Icon(
                    drive.connected
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_outlined,
                  ),
                  label: Text(
                    drive.connected
                        ? 'OneDrive verbunden'
                        : 'OneDrive verbinden',
                  ),
                ),
                if (drive.connected) ...[
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => action(() => browseOneDrive(ctx, c, drive)),
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Ordner wählen'),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => action(drive.disconnect),
                    child: const Text('Trennen'),
                  ),
                ],
                OutlinedButton.icon(
                  onPressed: busy || !materialDeviceAvailable
                      ? null
                      : () => action(importFile),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Datei hinzufügen'),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () =>
                            showClassroomEditor(ctx, c, ClassroomKind.material),
                  icon: const Icon(Icons.link),
                  label: const Text('Link hinzufügen'),
                ),
              ],
            ),
            for (final f in c.classroom.where(
              (d) => !d.deleted && d.kind == ClassroomKind.folder,
            ))
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(f.title),
                onTap: busy
                    ? null
                    : () => action(
                        () => browseOneDrive(ctx, c, drive, folder: f),
                      ),
                trailing: IconButton(
                  tooltip: 'Ordnerverknüpfung entfernen',
                  onPressed: busy
                      ? null
                      : () => action(
                          () => c.saveClassroom(f.patch({'deleted': true})),
                        ),
                  icon: const Icon(Icons.link_off),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Materialien durchsuchen',
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Aktiv'),
                  selected: !trash,
                  onSelected: (_) => setState(() => trash = false),
                ),
                ChoiceChip(
                  label: const Text('Papierkorb'),
                  selected: trash,
                  onSelected: (_) => setState(() => trash = true),
                ),
                TextButton.icon(
                  onPressed: busy || !materialDeviceAvailable
                      ? null
                      : () => action(exportBundle),
                  icon: const Icon(Icons.enhanced_encryption_outlined),
                  label: const Text('Materialpaket sichern'),
                ),
                TextButton.icon(
                  onPressed: busy || !materialDeviceAvailable
                      ? null
                      : () => action(importBundle),
                  icon: const Icon(Icons.restore),
                  label: const Text('Materialpaket öffnen'),
                ),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ),
            if (materials.isEmpty)
              const EmptyState(
                'Noch keine passenden Materialien.',
                icon: Icons.folder_open,
              ),
            for (final d in materials)
              FlexCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(d.title, style: Theme.of(ctx).textTheme.titleMedium),
                      Text(
                        [
                          d.text('extension').toUpperCase(),
                          d.text('subject'),
                          d.text('topic'),
                        ].where((s) => s.isNotEmpty).join(' · '),
                      ),
                      if (d.text('week').isNotEmpty)
                        Text('Wochenplanung ab ${displayDate(d.text('week'))}'),
                      FutureBuilder<bool>(
                        future: materialDeviceAvailable
                            ? files.exists(d.text('localKey'))
                            : Future.value(false),
                        builder: (ctx, s) => Text(
                          s.data == true
                              ? 'Auf diesem Gerät · ${displayDate(d.text('sourceModifiedAt').isEmpty ? null : d.text('sourceModifiedAt'))}'
                              : d.text('localKey').isNotEmpty &&
                                    d.text('url').isEmpty
                              ? 'Datei fehlt · Materialpaket öffnen'
                              : 'Online',
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (!trash) ...[
                            TextButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => action(
                                      () => openMaterial(
                                        ctx,
                                        c,
                                        d,
                                        drive: drive,
                                        files: files,
                                      ),
                                    ),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Öffnen'),
                            ),
                            TextButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => showClassroomEditor(
                                      ctx,
                                      c,
                                      ClassroomKind.material,
                                      document: d,
                                    ),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Bearbeiten'),
                            ),
                            if (d.text('itemId').isNotEmpty &&
                                materialDeviceAvailable)
                              TextButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => action(() async {
                                        await cacheMaterial(c, d, drive, files);
                                      }),
                                icon: const Icon(Icons.download_outlined),
                                label: const Text(
                                  'Offline laden / aktualisieren',
                                ),
                              ),
                            if (materialDeviceAvailable &&
                                d.text('localKey').isNotEmpty &&
                                (d.text('itemId').isNotEmpty ||
                                    d.text('url').isNotEmpty))
                              TextButton.icon(
                                icon: const Icon(Icons.cloud_outlined),
                                label: const Text('Offline-Kopie entfernen'),
                                onPressed: busy
                                    ? null
                                    : () => action(() async {
                                        await c.saveClassroom(
                                          d.patch({'localKey': ''}),
                                        );
                                        await removeUnusedMaterialFile(
                                          c,
                                          files,
                                          d.text('localKey'),
                                        );
                                      }),
                              ),
                          ],
                          IconButton(
                            tooltip: trash
                                ? 'Wiederherstellen'
                                : 'In Papierkorb',
                            onPressed: busy
                                ? null
                                : () => action(
                                    () => c.saveClassroom(
                                      d.patch({'deleted': !trash}),
                                    ),
                                  ),
                            icon: Icon(
                              trash ? Icons.restore : Icons.delete_outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
