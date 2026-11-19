part of 'material_library.dart';

typedef _DriveFolder = ({
  String id,
  String drive,
  String name,
  String url,
  bool writable,
});

Future<void> browseOneDrive(
  BuildContext context,
  NotebookController c,
  OneDriveClient drive, {
  ClassroomDocument? folder,
  bool appFolder = false,
}) async {
  final account = (await drive.graph('/me/drive'))['id'] as String;
  if (folder != null &&
      folder.text('accountDrive').isNotEmpty &&
      folder.text('accountDrive') != account) {
    throw const DomainError(
      'Dieser Ordner gehört zu einem anderen OneDrive-Konto.',
    );
  }
  final root = folder == null
      ? await drive.graph(
          appFolder ? '/me/drive/special/approot' : '/me/drive/root',
        )
      : null;
  final rootId = appFolder
      ? (root?['id'] as String? ?? folder!.text('appRoot'))
      : '';
  if (appFolder && folder != null) {
    await drive.verifyAppFolder(
      folder.text('driveId'),
      folder.text('itemId'),
      rootId,
    );
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _DriveExplorer(
      c: c,
      client: drive,
      account: account,
      appRoot: rootId,
      first: (
        id: folder?.text('itemId') ?? root!['id'] as String,
        drive:
            folder?.text('driveId') ??
            (root?['parentReference'] as Map?)?['driveId'] as String? ??
            account,
        name: folder?.title ?? (appFolder ? 'FLEX-App-Ordner' : 'OneDrive'),
        url: folder?.text('url') ?? root?['webUrl'] as String? ?? '',
        writable: appFolder,
      ),
    ),
  );
}

class _DriveExplorer extends StatefulWidget {
  const _DriveExplorer({
    required this.c,
    required this.client,
    required this.account,
    required this.appRoot,
    required this.first,
  });
  final NotebookController c;
  final OneDriveClient client;
  final String account, appRoot;
  final _DriveFolder first;
  @override
  State<_DriveExplorer> createState() => _DriveExplorerState();
}

class _DriveExplorerState extends State<_DriveExplorer> {
  late final stack = [widget.first];
  late Future<List<Json>> listing = children();
  final selected = <String, ClassroomDocument>{};
  final search = TextEditingController();
  bool choosing = false, across = false, busy = false;
  String query = '', error = '';
  _DriveFolder get folder => stack.last;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<List<Json>> children() async {
    if (across) {
      final results = <String, Json>{};
      for (final rule in widget.c.classroom.where(
        (d) =>
            !d.deleted &&
            d.kind == ClassroomKind.folder &&
            (d.text('accountDrive') == widget.account ||
                d.text('accountDrive').isEmpty &&
                    d.text('driveId') == widget.account),
      )) {
        for (final d in await scanMaterialFolder(
          widget.client,
          rule,
          widget.c.classroom,
        )) {
          results[d.id] = {
            'id': d.text('itemId'),
            'name': d.text('remoteName'),
            'webUrl': d.text('url'),
            'size': d.number('size'),
            'eTag': d.text('remoteEtag'),
            'lastModifiedDateTime': d.text('remoteModifiedAt'),
            '_drive': d.text('driveId'),
            '_path': d.text('sourcePath'),
          };
        }
      }
      return results.values.toList();
    }
    final items = await widget.client.children(
      drive: folder.drive,
      folder: folder.id,
    );
    return [
      for (final item in items)
        if (item['remoteItem'] is Map)
          {
            ...Json.from(item['remoteItem'] as Map),
            'name': item['name'] ?? (item['remoteItem'] as Map)['name'],
            '_drive':
                ((item['remoteItem'] as Map)['parentReference']
                    as Map?)?['driveId'],
            '_shared': true,
          }
        else
          {...item, '_drive': folder.drive},
    ];
  }

  void changeFolder(VoidCallback change) {
    setState(() {
      change();
      across = false;
      query = '';
      search.clear();
      error = '';
      listing = children();
    });
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  ClassroomDocument material(Json item) => indexOneDriveFile(
    item['_drive'] as String,
    item,
    widget.c.classroom,
    restore: true,
    path: item['_path'] as String?,
  );
  Future<void> take(List<ClassroomDocument> items) async {
    final ok = await showMaterialAssignments(
      context,
      widget.c,
      items,
      importing: true,
    );
    if (mounted && ok) {
      setState(() {
        selected.clear();
        choosing = false;
      });
    }
  }

  Future<void> preview(Json item) async {
    final info = await widget.client.item(
      item['_drive'] as String,
      item['id'] as String,
    );
    final name = item['name'] as String, ext = cloudExtension(name);
    final url = (info['webUrl'] ?? item['webUrl'] ?? '') as String;
    if (info['@microsoft.graph.downloadUrl'] == null && url.isNotEmpty) {
      await _launchMaterial(url);
      return;
    }
    final bytes = await widget.client.download(info);
    validateMaterialBytes(bytes, ext);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => switch (ext) {
        'pdf' => MaterialPdf(
          fileKey: item['id'] as String,
          title: name,
          preview: bytes,
        ),
        'docx' => MaterialDocx(
          title: name,
          bytes: bytes,
          openOriginal: () => _launchMaterial(url),
        ),
        _ => FlexModal(
          title: Text(name),
          onClose: () => Navigator.pop(ctx),
          content: InteractiveViewer(maxScale: 5, child: Image.memory(bytes)),
        ),
      },
    );
  }

  @override
  Widget build(BuildContext context) => FlexModal(
    maxWidth: 740,
    title: const Text('OneDrive'),
    onClose: busy ? null : () => Navigator.pop(context),
    headerActions: [
      IconButton(
        tooltip: 'Mehrere Dateien auswählen',
        isSelected: choosing,
        icon: const Icon(Icons.checklist),
        onPressed: busy
            ? null
            : () => setState(() {
                choosing = !choosing;
                selected.clear();
              }),
      ),
    ],
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (i, f) in stack.indexed) ...[
              if (i > 0) const Icon(Icons.chevron_right, size: 16),
              TextButton(
                onPressed: busy || i == stack.length - 1
                    ? null
                    : () => changeFolder(
                        () => stack.removeRange(i + 1, stack.length),
                      ),
                child: Text(f.name),
              ),
            ],
          ],
        ),
        TextField(
          controller: search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: across
                ? 'Verknüpfte Ordner durchsuchen'
                : 'In diesem Ordner suchen',
          ),
          onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
        ),
        if (widget.c.classroom.any(
          (f) =>
              f.kind == ClassroomKind.folder &&
              !f.deleted &&
              f.text('driveId') == widget.account,
        ))
          FilterChip(
            label: const Text('Alle verknüpften Ordner'),
            selected: across,
            onSelected: busy
                ? null
                : (v) => setState(() {
                    across = v;
                    listing = children();
                  }),
          ),
        if (error.isNotEmpty)
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (busy && ModalRoute.isCurrentOf(context) == true)
          const LinearProgressIndicator(),
        FutureBuilder<List<Json>>(
          future: listing,
          builder: (ctx, s) {
            if (s.hasError) {
              return Column(
                children: [
                  Text(friendlyError(s.error!)),
                  TextButton(
                    onPressed: () => setState(() => listing = children()),
                    child: const Text('Erneut laden'),
                  ),
                ],
              );
            }
            if (!s.hasData || s.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            final matches =
                s.data!
                    .where(
                      (j) =>
                          j['id'] is String &&
                          j['_drive'] is String &&
                          (j['folder'] != null ||
                              cloudFileSupported(j['name'] as String? ?? '')) &&
                          (j['name'] as String).toLowerCase().contains(query),
                    )
                    .toList()
                  ..sort((a, b) {
                    final folders = (a['folder'] == null ? 1 : 0).compareTo(
                      b['folder'] == null ? 1 : 0,
                    );
                    return folders == 0
                        ? (a['name'] as String).toLowerCase().compareTo(
                            (b['name'] as String).toLowerCase(),
                          )
                        : folders;
                  });
            if (matches.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  query.isEmpty
                      ? 'Keine unterstützten Dateien oder Ordner.'
                      : 'Keine Treffer für „${search.text}“.',
                ),
              );
            }
            return Column(
              children: [
                for (final j in matches)
                  if (j['folder'] != null)
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(j['name'] as String),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: busy
                          ? null
                          : () => changeFolder(
                              () => stack.add((
                                id: j['id'] as String,
                                drive: j['_drive'] as String,
                                name: j['name'] as String,
                                url: j['webUrl'] as String? ?? '',
                                writable:
                                    folder.writable && j['_shared'] != true,
                              )),
                            ),
                    )
                  else
                    Builder(
                      builder: (ctx) {
                        final d = material(j);
                        final linked = widget.c.classroom.any(
                          (v) => v.id == d.id && !v.deleted,
                        );
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: MaterialThumbnail(
                            material: d,
                            width: 36,
                            height: 46,
                          ),
                          title: Text(
                            j['name'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            j['_path'] as String? ??
                                (linked
                                    ? 'Bereits in FLEX'
                                    : cloudExtension(
                                        j['name'] as String,
                                      ).toUpperCase()),
                          ),
                          onTap: busy
                              ? null
                              : choosing
                              ? () => setState(() {
                                  if (selected.containsKey(d.id)) {
                                    selected.remove(d.id);
                                  } else {
                                    selected[d.id] = d;
                                  }
                                })
                              : () => act(() => preview(j)),
                          trailing: choosing
                              ? Checkbox(
                                  value: selected.containsKey(d.id),
                                  onChanged: busy
                                      ? null
                                      : (v) => setState(() {
                                          if (v == true) {
                                            selected[d.id] = d;
                                          } else {
                                            selected.remove(d.id);
                                          }
                                        }),
                                )
                              : IconButton(
                                  tooltip: linked
                                      ? 'Zuordnung bearbeiten'
                                      : 'Übernehmen',
                                  icon: Icon(
                                    linked ? Icons.person_outline : Icons.add,
                                  ),
                                  onPressed: busy
                                      ? null
                                      : () => act(() => take([d])),
                                ),
                        );
                      },
                    ),
              ],
            );
          },
        ),
      ],
    ),
    actions: [
      if (choosing)
        FilledButton(
          onPressed: busy || selected.isEmpty
              ? null
              : () => act(() => take(selected.values.toList())),
          child: Text('${selected.length} übernehmen und zuordnen'),
        )
      else if (!across && folder.drive == widget.account) ...[
        if (folder.writable)
          IconButton(
            tooltip: 'Schülerordner einrichten',
            icon: const Icon(Icons.group_add_outlined),
            onPressed: busy
                ? null
                : () => act(() async {
                    await _setupPupilFolders(
                      context,
                      widget.c,
                      widget.client,
                      folder,
                      widget.appRoot,
                    );
                    if (mounted) setState(() => listing = children());
                  }),
          ),
        if (folder.writable)
          IconButton(
            tooltip: 'Unterordner anlegen',
            onPressed: busy
                ? null
                : () => act(() async {
                    final name = await _folderName(context);
                    if (name == null) return;
                    await widget.client.verifyAppFolder(
                      folder.drive,
                      folder.id,
                      widget.appRoot,
                    );
                    final item = await widget.client.createFolder(
                      folder.drive,
                      folder.id,
                      name,
                    );
                    if (mounted) {
                      changeFolder(
                        () => stack.add((
                          id: item['id'] as String,
                          drive: folder.drive,
                          name: name,
                          url: item['webUrl'] as String? ?? '',
                          writable: true,
                        )),
                      );
                    }
                  }),
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () => act(() async {
                  final saved = await _configureDriveFolder(
                    context,
                    widget.c,
                    widget.client,
                    folder,
                    widget.account,
                    widget.appRoot,
                  );
                  if (saved && context.mounted) Navigator.pop(context);
                }),
          icon: const Icon(Icons.link),
          label: const Text('Ordner verknüpfen'),
        ),
      ],
    ],
  );
}
