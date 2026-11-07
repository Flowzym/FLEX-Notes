import 'material_thumbnail.dart';
import 'action_heading.dart';
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
import '../domain/material_workspace.dart';
import '../domain/models.dart';
import '../services/material_files.dart';
import '../services/material_storage.dart';
import '../domain/document_scanner.dart';
import 'scan_editor.dart';
import 'document_attachments.dart';
import '../services/onedrive.dart';
import 'backup_dialog.dart';
import 'classroom_editor.dart';
import 'common.dart';
import 'draft_buffer.dart';
import 'flex_modal.dart';
import 'material_pdf.dart';
import '../services/material_index.dart';
import 'material_docx.dart';

part 'material_workspace_views.dart';
part 'material_index_review.dart';
part 'material_browser.dart';

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
  final docs = await c.repository.classroomDocuments();
  final drafts = await c.repository.dialogDrafts();
  if (docs.any((d) => d.text('localKey') == key) ||
      drafts.any(
        (d) =>
            d.data['localKey'] == key ||
            d.type == 'scan' &&
                (d.data['pages'] as List).any((p) => p['key'] == key),
      )) {
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
        'Die lokale Datei fehlt. Bitte die Materialsicherung wiederherstellen.',
      );
    }
    if (!context.mounted) return;
    if (current.text('extension') == 'jpg') {
      final bytes = await files.read(current.text('localKey'));
      if (!context.mounted) return;
      await showDialog<void>(
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
      await showDialog<void>(
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
      await showDialog<void>(
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

class MaterialLibraryPage extends StatefulWidget {
  const MaterialLibraryPage({
    super.key,
    required this.controller,
    this.externalView,
    this.initialTrash = false,
  });
  final String? externalView;
  final bool initialTrash;
  final NotebookController controller;
  @override
  State<MaterialLibraryPage> createState() => _MaterialLibraryPageState();
}

class _MaterialLibraryPageState extends State<MaterialLibraryPage>
    with AutomaticKeepAliveClientMixin {
  NotebookController get c => widget.controller;
  final drive = OneDriveClient();
  final files = const LocalMaterialFiles();
  String query = '', view = 'files', typeFilter = 'all', subjectFilter = '';
  String formatFilter = 'all', sort = 'recent';
  bool grid = true;
  final search = TextEditingController();
  final selection = <String>{};
  bool busy = false,
      trash = false,
      searching = false,
      filters = false,
      favorites = false,
      selecting = false;
  bool progress = false;
  String? error;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    view = widget.externalView ?? view;
    trash = widget.initialTrash;
    drive.load().catchError((Object e) {
      if (mounted) setState(() => error = friendlyError(e));
    });
  }

  @override
  void didUpdateWidget(covariant MaterialLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalView != null &&
        widget.externalView != oldWidget.externalView) {
      view = widget.externalView!;
      selecting = false;
      selection.clear();
    }
  }

  @override
  void dispose() {
    drive.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> action(
    Future<void> Function() run, {
    bool showProgress = true,
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      progress = showProgress;
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
          ...suggestMaterialMetadata(file.name),
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
          label: 'FLEX-Materialsicherung',
          extensions: ['flexmaterials'],
          mimeTypes: ['application/octet-stream'],
        ),
      ],
    );
    if (file == null) return;
    if (await file.length() > MaterialBundle.maxPlain + 52) {
      throw const DomainError('Die Materialsicherung ist zu groß.');
    }
    final buffer = BytesBuilder();
    await for (final chunk in file.openRead()) {
      if (buffer.length + chunk.length > MaterialBundle.maxPlain + 52) {
        throw const DomainError('Die Materialsicherung ist zu groß.');
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
    final knownPupils = c.pupils.map((p) => p.id).toSet();
    final missingPupils = bundle.documents
        .expand((d) => d.strings('pupilIds'))
        .where((id) => !knownPupils.contains(id))
        .toSet();
    final selected = {
      for (final d in bundle.documents)
        if (!before.containsKey(d.id)) d.id,
    };
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => FlexModal(
          title: const Text('Materialsicherung prüfen'),
          onClose: () => Navigator.pop(ctx, false),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (missingPupils.isNotEmpty)
                Text(
                  '${missingPupils.length} Schüler sind hier nicht vorhanden. Ihre Dateizuordnungen werden nicht übernommen. Für eine vollständige Wiederherstellung zuerst die Notizbuchsicherung öffnen.',
                ),
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
            'pupilIds': next
                .strings('pupilIds')
                .where(knownPupils.contains)
                .toList(),
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

  Future<void> assignSelection() async {
    final ids = await chooseMaterialPupils(context, c, []);
    if (ids == null || ids.isEmpty) return;
    await c.repository.saveClassroomDocuments([
      for (final d in c.classroom.where((d) => selection.contains(d.id)))
        d.patch({
          'pupilIds': {...d.strings('pupilIds'), ...ids}.toList(),
        }),
    ]);
    await c.reload();
    if (mounted) {
      setState(() {
        selection.clear();
        selecting = false;
      });
    }
  }

  Future<void> togglePreparedToday(String id) async {
    final date = dateOnly(DateTime.now());
    final current = preparationFor(c.classroom, date);
    final ids = current.strings('materialIds');
    await c.saveClassroom(
      !current.deleted && ids.contains(id)
          ? current.patch({
              'materialIds': ids.where((value) => value != id).toList(),
            })
          : prepareMaterials(c.classroom, date, [id]),
    );
  }

  Future<void> addSelectionToPackage() async {
    final packages = c.classroom
        .where((d) => !d.deleted && d.kind == ClassroomKind.materialSet)
        .toList();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => FlexModal(
        title: const Text('Zu Unterrichtspaket hinzufügen'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Neues Paket'),
              onTap: () => Navigator.pop(ctx, 'new'),
            ),
            for (final p in packages)
              ListTile(
                leading: const Icon(Icons.folder_copy_outlined),
                title: Text(p.title),
                onTap: () => Navigator.pop(ctx, p.id),
              ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (result == 'new') {
      await showClassroomEditor(
        context,
        c,
        ClassroomKind.materialSet,
        fields: {'materialIds': selection.toList()},
      );
    } else {
      final p = c.classroom.firstWhere((d) => d.id == result);
      await c.saveClassroom(
        p.patch({
          'materialIds': {...p.strings('materialIds'), ...selection}.toList(),
        }),
      );
    }
  }

  Widget selectionBar(BuildContext ctx) => Material(
    color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('${selection.length} ausgewählt')),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          selection.clear();
                          selecting = false;
                        }),
                  child: const Text('Fertig'),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: busy || selection.isEmpty
                      ? null
                      : () => action(
                          () => prepareForDate(ctx, c, selection.toList()),
                        ),
                  icon: const Icon(Icons.today_outlined),
                  label: const Text('Bereitlegen'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || selection.isEmpty
                      ? null
                      : () => action(assignSelection, showProgress: false),
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Schüler'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || selection.isEmpty
                      ? null
                      : () =>
                            action(addSelectionToPackage, showProgress: false),
                  icon: const Icon(Icons.folder_copy_outlined),
                  label: const Text('Paket'),
                ),
                IconButton(
                  tooltip: 'Auswahl offline laden',
                  onPressed:
                      busy || selection.isEmpty || !materialDeviceAvailable
                      ? null
                      : () => action(
                          () => cacheMaterials(
                            ctx,
                            c,
                            resolveMaterials(c.classroom, selection),
                            drive: drive,
                          ),
                        ),
                  icon: const Icon(Icons.download_outlined),
                ),
                IconButton(
                  tooltip: 'Auswahl in Papierkorb',
                  onPressed: busy || selection.isEmpty
                      ? null
                      : () => action(() async {
                          final docs = c.classroom
                              .where((d) => selection.contains(d.id))
                              .toList();
                          await c.repository.saveClassroomDocuments([
                            for (final d in docs) d.patch({'deleted': true}),
                          ]);
                          await c.reload();
                          if (mounted) {
                            setState(() {
                              selection.clear();
                              selecting = false;
                            });
                          }
                        }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget materialBrowserToolbar(BuildContext ctx, int count) {
    final countLabel = Text('$count ${count == 1 ? 'Datei' : 'Dateien'}');
    final layout = IconButton(
      key: const ValueKey('material-layout'),
      tooltip: grid ? 'Listenansicht' : 'Rasteransicht',
      onPressed: () => setState(() => grid = !grid),
      icon: Icon(grid ? Icons.view_list_outlined : Icons.grid_view_outlined),
    );
    final sorting = PopupMenuButton<String>(
      key: const ValueKey('material-sort'),
      tooltip: 'Materialien sortieren',
      initialValue: sort,
      onSelected: (value) => setState(() => sort = value),
      itemBuilder: (_) => [
        for (final entry in _materialSortLabels.entries)
          CheckedPopupMenuItem(
            value: entry.key,
            checked: sort == entry.key,
            child: Text(entry.value),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 18),
            const SizedBox(width: 6),
            Flexible(child: Text(_materialSortLabels[sort]!, maxLines: 2)),
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth < 480 &&
            MediaQuery.textScalerOf(ctx).scale(1) > 1.4) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: countLabel),
                  layout,
                ],
              ),
              sorting,
            ],
          );
        }
        return Row(
          children: [
            countLabel,
            Expanded(child: sorting),
            layout,
          ],
        );
      },
    );
  }

  List<Widget> materialFiles(
    BuildContext ctx,
    List<ClassroomDocument> documents,
    double availableWidth,
  ) {
    final preparation = preparationFor(c.classroom, dateOnly(DateTime.now()));
    final prepared = preparation.deleted
        ? <String>[]
        : preparation.strings('materialIds');
    Widget card(ClassroomDocument d) => _MaterialBrowserCard(
      key: ValueKey(d.id),
      document: d,
      files: files,
      pupils: c.pupils,
      grid: grid,
      prepared: prepared.contains(d.id),
      selected: selecting ? selection.contains(d.id) : null,
      onSelect: (value) => setState(() {
        if (value) {
          selection.add(d.id);
        } else {
          selection.remove(d.id);
        }
      }),
      onOpen: () => action(
        () => trash
            ? showMaterialDetails(ctx, c, d, drive: drive)
            : openMaterial(ctx, c, d, drive: drive, files: files),
      ),
      onEdit: () => showMaterialDetails(ctx, c, d, drive: drive),
      onFavorite: trash
          ? null
          : () => action(
              () => c.saveClassroom(d.patch({'favorite': !d.flag('favorite')})),
              showProgress: false,
            ),
      onPrepare: trash
          ? null
          : () => action(() => togglePreparedToday(d.id), showProgress: false),
      onRestore: trash
          ? () => action(() => c.saveClassroom(d.patch({'deleted': false})))
          : null,
    );
    final minWidth = MediaQuery.textScalerOf(ctx).scale(1) > 1.4
        ? 270.0
        : 160.0;
    final columns = grid
        ? ((availableWidth + 12) / (minWidth + 12)).floor().clamp(1, 5)
        : 1;
    // Separate rows let the outer ListView load previews only near the viewport.
    return [
      for (var start = 0; start < documents.length; start += columns)
        Padding(
          key: start == 0
              ? ValueKey(grid ? 'material-grid' : 'material-list')
              : null,
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) const SizedBox(width: 12),
                Expanded(
                  child: start + column < documents.length
                      ? card(documents[start + column])
                      : const SizedBox(),
                ),
              ],
            ],
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (layoutContext, constraints) => AnimatedBuilder(
        animation: Listenable.merge([c, drive]),
        builder: (ctx, _) {
          final kind = view == 'packages'
              ? ClassroomKind.materialSet
              : view == 'plans'
              ? ClassroomKind.plan
              : ClassroomKind.material;
          final documents =
              c.classroom
                  .where(
                    (d) =>
                        d.kind == kind &&
                        d.deleted == trash &&
                        materialMatches(d, query, pupils: c.pupils) &&
                        (kind != ClassroomKind.material ||
                            (!favorites || d.flag('favorite')) &&
                                (formatFilter == 'all' ||
                                    d.text('extension') == formatFilter) &&
                                (typeFilter == 'all' ||
                                    d.text('documentType', 'other') ==
                                        typeFilter) &&
                                (subjectFilter.isEmpty ||
                                    d.text('subject') == subjectFilter)),
                  )
                  .toList()
                ..sort((a, b) {
                  final primary = kind != ClassroomKind.material
                      ? 0
                      : switch (sort) {
                          'recent' =>
                            b
                                .text('updatedAtUtc')
                                .compareTo(a.text('updatedAtUtc')),
                          'subject' =>
                            a
                                .text('subject')
                                .toLowerCase()
                                .compareTo(b.text('subject').toLowerCase()),
                          'format' =>
                            a.text('extension').compareTo(b.text('extension')),
                          _ => 0,
                        };
                  if (primary != 0) return primary;
                  final name = a.title.toLowerCase().compareTo(
                    b.title.toLowerCase(),
                  );
                  return name != 0 ? name : a.id.compareTo(b.id);
                });
          final subjects =
              c.classroom
                  .where((d) => !d.deleted && d.kind == ClassroomKind.material)
                  .map((d) => d.text('subject'))
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          return Column(
            children: [
              Expanded(
                child: ListView(
                  key: const PageStorageKey('materials-library'),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    ActionHeading(
                      leading: Text(switch (view) {
                        'prepared' => 'Bereitgelegt',
                        'packages' => 'Pakete',
                        'plans' => 'Planungen',
                        _ => 'Materialien',
                      }, style: Theme.of(ctx).textTheme.headlineSmall),
                      actions: [
                        if (view != 'files')
                          IconButton(
                            tooltip: drive.connected
                                ? 'OneDrive-Ordner öffnen'
                                : 'OneDrive verbinden',
                            icon: Icon(
                              drive.connected
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_outlined,
                            ),
                            onPressed: busy
                                ? null
                                : () => action(
                                    () => drive.connected
                                        ? browseOneDrive(ctx, c, drive)
                                        : connectOneDrive(ctx, drive),
                                    showProgress: false,
                                  ),
                          ),
                        IconButton(
                          tooltip: 'Materialien suchen',
                          isSelected: searching,
                          icon: const Icon(Icons.search),
                          onPressed: () =>
                              setState(() => searching = !searching),
                        ),
                        if (view == 'files' && !trash)
                          IconButton(
                            tooltip: 'Mehrere Dateien auswählen',
                            isSelected: selecting,
                            icon: const Icon(Icons.checklist),
                            onPressed: () => setState(() {
                              selecting = !selecting;
                              if (!selecting) selection.clear();
                            }),
                          ),
                        if (view == 'packages' || view == 'plans')
                          IconButton(
                            tooltip: view == 'plans'
                                ? 'Planung anlegen'
                                : 'Paket anlegen',
                            onPressed: busy
                                ? null
                                : () => showClassroomEditor(ctx, c, kind),
                            icon: const Icon(Icons.add),
                          ),
                      ],
                    ),
                    if (view == 'files' && !trash)
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final columns =
                              MediaQuery.textScalerOf(ctx).scale(1) > 1.4
                              ? 2
                              : 4;
                          final actions =
                              <
                                ({
                                  String label,
                                  IconData icon,
                                  VoidCallback? run,
                                })
                              >[
                                (
                                  label: 'Scannen',
                                  icon: Icons.document_scanner_outlined,
                                  run: busy
                                      ? null
                                      : () => scanAndShow(
                                          ctx,
                                          c,
                                          const ScanContext(),
                                        ),
                                ),
                                (
                                  label: 'Datei',
                                  icon: Icons.upload_file,
                                  run: busy || !materialDeviceAvailable
                                      ? null
                                      : () => action(importFile),
                                ),
                                (
                                  label: 'Link',
                                  icon: Icons.link,
                                  run: busy
                                      ? null
                                      : () => showClassroomEditor(
                                          ctx,
                                          c,
                                          ClassroomKind.material,
                                        ),
                                ),
                                (
                                  label: 'OneDrive',
                                  icon: drive.connected
                                      ? Icons.cloud_done_outlined
                                      : Icons.cloud_outlined,
                                  run: busy
                                      ? null
                                      : () => action(
                                          () => drive.connected
                                              ? browseOneDrive(ctx, c, drive)
                                              : connectOneDrive(ctx, drive),
                                          showProgress: false,
                                        ),
                                ),
                              ];
                          return Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final item in actions)
                                SizedBox(
                                  width:
                                      (constraints.maxWidth -
                                          (columns - 1) * 6) /
                                      columns,
                                  child: TextButton(
                                    onPressed: item.run,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(item.icon, size: 24),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.label,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    if (searching || query.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextField(
                          controller: search,
                          autofocus: searching,
                          decoration: InputDecoration(
                            labelText: 'Dateien, Themen, Schüler suchen',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              tooltip: 'Suche leeren',
                              onPressed: () => setState(() {
                                search.clear();
                                query = '';
                                searching = false;
                              }),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                          onChanged: (v) => setState(() => query = v),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (widget.externalView == null)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final item in const [
                            ('files', 'Dateien'),
                            ('prepared', 'Bereitgelegt'),
                            ('packages', 'Pakete'),
                            ('plans', 'Planungen'),
                          ])
                            ChoiceChip(
                              showCheckmark: false,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              labelPadding: EdgeInsets.zero,
                              label: Text(item.$2),
                              selected: view == item.$1,
                              onSelected: (_) => setState(() {
                                view = item.$1;
                                selecting = false;
                                selection.clear();
                              }),
                            ),
                        ],
                      ),
                    if (busy && progress) const LinearProgressIndicator(),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                          ),
                        ),
                      ),
                    if (view == 'prepared') ...[
                      PreparedMaterialsTile(
                        controller: c,
                        date: dateOnly(DateTime.now()),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => showPreparedMaterials(ctx, c),
                        icon: const Icon(Icons.date_range_outlined),
                        label: const Text('Tag wählen / vorbereiten'),
                      ),
                      for (final d
                          in (c.classroom
                              .where(
                                (d) =>
                                    !d.deleted &&
                                    d.kind == ClassroomKind.preparation &&
                                    d.strings('materialIds').isNotEmpty &&
                                    d.text('date') != dateOnly(DateTime.now()),
                              )
                              .toList()
                            ..sort(
                              (a, b) =>
                                  b.text('date').compareTo(a.text('date')),
                            )))
                        PreparedMaterialsTile(
                          controller: c,
                          date: d.text('date'),
                        ),
                    ] else ...[
                      if (view == 'files') ...[
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            FilterChip(
                              label: const Text('Favoriten'),
                              avatar: const Icon(Icons.star_border, size: 18),
                              selected: favorites,
                              onSelected: (v) => setState(() => favorites = v),
                            ),
                            FilterChip(
                              label: const Text('Papierkorb'),
                              selected: trash,
                              onSelected: (v) => setState(() {
                                trash = v;
                                selection.clear();
                                selecting = false;
                              }),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => filters = !filters),
                              icon: const Icon(Icons.tune),
                              label: Text(
                                typeFilter != 'all' ||
                                        subjectFilter.isNotEmpty ||
                                        formatFilter != 'all'
                                    ? 'Filter aktiv'
                                    : 'Filter',
                              ),
                            ),
                          ],
                        ),
                        if (filters)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    for (final item in const [
                                      ('all', 'Alle Formate'),
                                      ('pdf', 'PDF'),
                                      ('docx', 'DOCX'),
                                      ('jpg', 'Fotos'),
                                      ('link', 'Links'),
                                    ])
                                      ChoiceChip(
                                        key: ValueKey(
                                          'material-format-${item.$1}',
                                        ),
                                        label: Text(item.$2),
                                        selected: formatFilter == item.$1,
                                        onSelected: (_) => setState(
                                          () => formatFilter = item.$1,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  key: ValueKey('type-$typeFilter'),
                                  initialValue: typeFilter,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Dokumentart',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'all',
                                      child: Text('Alle Dokumentarten'),
                                    ),
                                    for (final e in materialTypes.entries)
                                      DropdownMenuItem(
                                        value: e.key,
                                        child: Text(e.value),
                                      ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => typeFilter = v!),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  key: ValueKey('subject-$subjectFilter'),
                                  initialValue: subjectFilter,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Fach',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: '',
                                      child: Text('Alle Fächer'),
                                    ),
                                    for (final s in {
                                      ...subjects,
                                      if (subjectFilter.isNotEmpty)
                                        subjectFilter,
                                    })
                                      DropdownMenuItem(
                                        value: s,
                                        child: Text(s),
                                      ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => subjectFilter = v!),
                                ),
                              ],
                            ),
                          ),
                        materialBrowserToolbar(ctx, documents.length),
                        if (selecting)
                          TextButton(
                            onPressed: () => setState(
                              () =>
                                  selection.addAll(documents.map((d) => d.id)),
                            ),
                            child: const Text('Alle angezeigten auswählen'),
                          ),
                      ] else
                        Wrap(
                          spacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('Papierkorb'),
                              selected: trash,
                              onSelected: (v) => setState(() => trash = v),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      if (documents.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Column(
                            children: [
                              Icon(
                                trash
                                    ? Icons.delete_outline
                                    : Icons.folder_open_outlined,
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                trash
                                    ? 'Der Papierkorb ist leer.'
                                    : 'Keine passenden Materialien.',
                                textAlign: TextAlign.center,
                              ),
                              if (query.isNotEmpty ||
                                  favorites ||
                                  typeFilter != 'all' ||
                                  subjectFilter.isNotEmpty ||
                                  formatFilter != 'all')
                                TextButton(
                                  onPressed: () => setState(() {
                                    query = '';
                                    search.clear();
                                    favorites = false;
                                    typeFilter = 'all';
                                    subjectFilter = '';
                                    formatFilter = 'all';
                                  }),
                                  child: const Text(
                                    'Suche und Filter zurücksetzen',
                                  ),
                                )
                              else if (view == 'files' && !trash) ...[
                                const SizedBox(height: 6),
                                const Text(
                                  'Scannen, Dateien hinzufügen oder OneDrive öffnen.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (kind == ClassroomKind.material)
                        ...materialFiles(
                          ctx,
                          documents,
                          constraints.maxWidth - 32,
                        )
                      else
                        for (final d in documents)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            leading: Icon(
                              kind == ClassroomKind.plan
                                  ? Icons.event_note_outlined
                                  : Icons.folder_copy_outlined,
                            ),
                            title: Text(d.title),
                            subtitle: Text(
                              [
                                if (kind == ClassroomKind.plan)
                                  planStatuses[d.text('status', 'planned')]!,
                                d.text('subject'),
                                '${resolveMaterials(c.classroom, d.strings('materialIds')).length} Dateien',
                              ].where((s) => s.isNotEmpty).join(' · '),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => showMaterialCollection(ctx, c, d),
                          ),
                    ],
                    const SizedBox(height: 20),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Ablage & Sicherung',
                        style: Theme.of(ctx).textTheme.titleSmall,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (drive.connected) ...[
                          const Chip(
                            label: Text('OneDrive verbunden'),
                            avatar: Icon(Icons.cloud_done_outlined, size: 18),
                          ),
                          TextButton.icon(
                            onPressed: busy
                                ? null
                                : () => action(
                                    () => browseOneDrive(ctx, c, drive),
                                  ),
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Ordner wählen'),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => action(drive.disconnect),
                            child: const Text('Trennen'),
                          ),
                        ],
                      ],
                    ),
                    for (final f in c.classroom.where(
                      (d) => !d.deleted && d.kind == ClassroomKind.folder,
                    ))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(f.title),
                        onTap: busy
                            ? null
                            : () => action(
                                () => browseOneDrive(ctx, c, drive, folder: f),
                              ),
                        trailing: Wrap(
                          children: [
                            IconButton(
                              tooltip: 'Ordner einlesen / aktualisieren',
                              onPressed: busy
                                  ? null
                                  : () => action(
                                      () => reviewOneDriveFolder(
                                        ctx,
                                        c,
                                        drive,
                                        f,
                                      ),
                                    ),
                              icon: const Icon(Icons.sync),
                            ),
                            IconButton(
                              tooltip: 'Ordnerverknüpfung entfernen',
                              onPressed: busy
                                  ? null
                                  : () => action(
                                      () => c.saveClassroom(
                                        f.patch({'deleted': true}),
                                      ),
                                    ),
                              icon: const Icon(Icons.link_off),
                            ),
                          ],
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: busy || !materialDeviceAvailable
                              ? null
                              : () => action(exportBundle),
                          icon: const Icon(Icons.enhanced_encryption_outlined),
                          label: const Text('Materialsicherung erstellen'),
                        ),
                        TextButton.icon(
                          onPressed: busy || !materialDeviceAvailable
                              ? null
                              : () => action(importBundle),
                          icon: const Icon(Icons.restore),
                          label: const Text('Materialsicherung öffnen'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (selecting) selectionBar(ctx),
            ],
          );
        },
      ),
    );
  }
}
