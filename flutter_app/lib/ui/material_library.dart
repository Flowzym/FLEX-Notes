import 'incoming_shares.dart';
import 'quick_add.dart';
import '../domain/drive_rules.dart';
import '../domain/planning_import.dart';
import 'onedrive_setup.dart';
import 'material_versions.dart';
import '../domain/material_versions.dart';
import '../services/scan_store.dart';
import 'share_documents.dart';
import 'material_tags.dart';
import 'pupil_planning_review.dart';
import 'pupil_editor.dart';
import '../domain/material_tags.dart';
import 'detail_flow.dart';
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
import '../services/onedrive_native.dart' show OneDriveSignInRequired;
import '../services/material_sharing.dart' show materialMime;
import 'backup_dialog.dart';
import 'classroom_editor.dart';
import 'common.dart';
import 'draft_buffer.dart';
import 'flex_modal.dart';
import 'material_pdf.dart';
import '../services/material_index.dart';
import 'material_docx.dart';

part 'material_workspace_views.dart';
part 'prepared_offline.dart';
part 'pupil_materials.dart';
part 'material_index_review.dart';
part 'material_browser.dart';

part 'material_actions.dart';
part 'material_selection.dart';
part 'material_library_filters.dart';
part 'material_assignments.dart';
part 'drive_explorer.dart';
part 'drive_sources.dart';
part 'planning_material_views.dart';
part 'drive_pupil_folders.dart';

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
  String view = 'files';
  String get sort => c.appearance.materialSort;
  bool get grid => c.appearance.materialGrid;
  final search = TextEditingController();
  final fileSearch = TextEditingController();
  final trashSearch = TextEditingController();
  bool fileTrash = false, collectionTrash = false;
  bool get trash => view == 'files' ? fileTrash : collectionTrash;
  TextEditingController get currentSearch => view != 'files'
      ? search
      : fileTrash
      ? trashSearch
      : fileSearch;
  String get query => currentSearch.text.trim();
  var fileFilter = _LibraryFilter(), trashFilter = _LibraryFilter();
  _LibraryFilter get filter => fileTrash ? trashFilter : fileFilter;
  final selection = <String>{};
  bool busy = false, searching = false, selecting = false;
  bool progress = false;
  String? error;
  void updateLibrary(VoidCallback work) => setState(work);
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    view = widget.externalView ?? view;
    fileTrash = widget.initialTrash;
    c.addListener(pruneSelection);
    drive.load().catchError((Object e) {
      if (mounted) setState(() => error = friendlyError(e));
    });
  }

  @override
  void didUpdateWidget(covariant MaterialLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != c) {
      oldWidget.controller.removeListener(pruneSelection);
      c.addListener(pruneSelection);
    }
    if (widget.externalView != null &&
        widget.externalView != oldWidget.externalView) {
      changeView(widget.externalView!);
    }
  }

  void changeView(String value) {
    view = value;
    collectionTrash = false;
    selecting = false;
    selection.clear();
  }

  void openFileTrash(bool value) {
    setState(() {
      fileTrash = value;
      selecting = false;
      selection.clear();
    });
  }

  Iterable<ClassroomDocument> folderContents(
    ClassroomKind kind,
    bool deleted,
  ) => c.classroom.where(
    (d) =>
        d.kind == kind &&
        d.deleted == deleted &&
        (d.map('flow')['pupilId'] as String? ?? '').isEmpty,
  );

  bool matchesSearch(ClassroomDocument d) =>
      query.isEmpty || materialMatches(d, query, pupils: c.pupils);

  void pruneSelection() {
    if (!selecting || selection.isEmpty) return;
    selection.retainAll(
      folderContents(ClassroomKind.material, false)
          .where(
            (d) =>
                selection.contains(d.id) &&
                filter.matches(d) &&
                matchesSearch(d),
          )
          .map((d) => d.id)
          .toSet(),
    );
  }

  void changeFilters(VoidCallback change) => setState(() {
    change();
    pruneSelection();
  });

  void replaceFilter(_LibraryFilter value) {
    if (fileTrash) {
      trashFilter = value;
    } else {
      fileFilter = value;
    }
  }

  @override
  void dispose() {
    c.removeListener(pruneSelection);
    drive.dispose();
    search.dispose();
    fileSearch.dispose();
    trashSearch.dispose();
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

  Future<void> importFile() => importMaterialFile(context, c);

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
      for (final key in materialFileKeys(d.toJson())) {
        data[key] = await files.read(key);
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
        final mapping = <String, String>{};
        for (final oldKey in materialFileKeys(doc.toJson())) {
          final key = newId();
          written.add(key);
          await files.write(key, bundle.files[oldKey]!);
          mapping[oldKey] = key;
        }
        final next = doc.patch({
          'localKey': mapping[doc.text('localKey')] ?? doc.text('localKey'),
          'versions': [
            for (final v in materialVersions(doc.toJson()))
              {...v, 'localKey': mapping[v['localKey']]!},
          ],
        });
        final old = before[doc.id];
        documents.add(
          next.patch({
            if (next.map('planning').isNotEmpty) ...{
              'planningDecisions': next
                  .strings('planningDecisions')
                  .where(knownPupils.contains)
                  .toList(),
              'planningAutoDates': next
                  .strings('planningAutoDates')
                  .where(knownPupils.contains)
                  .toList(),
            },
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
    final materials = resolveMaterials(c.classroom, selection);
    final saved = await showMaterialAssignments(context, c, materials);
    if (!saved) return;
    if (mounted) {
      setState(() {
        selection.clear();
        selecting = false;
      });
    }
  }

  Future<void> tagSelection() async {
    final documents = c.classroom
        .where((d) => selection.contains(d.id))
        .toList();
    final choice = await chooseMaterialTags(
      context,
      c,
      count: documents.length,
    );
    if (choice == null) return;
    await c.saveClassroomBatch([
      for (final d in documents)
        d.patch({
          'tags': changeMaterialTags(d.strings('tags'), choice.$2, choice.$1),
        }),
    ]);
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

  Future<void> addSelectionToPackage(List<String> ids) async {
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
        fields: {'materialIds': ids},
      );
    } else {
      final p = c.classroom.firstWhere((d) => d.id == result);
      await c.saveClassroom(
        p.patch({
          'materialIds': {...p.strings('materialIds'), ...ids}.toList(),
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (layoutContext, constraints) => AnimatedBuilder(
        animation: Listenable.merge([c, drive]),
        builder: (ctx, _) {
          if (view == 'drive') {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              children: [
                if (widget.externalView == null)
                  TextButton(
                    onPressed: () => setState(() => changeView('files')),
                    child: const Text('Zur Bibliothek'),
                  ),
                _DriveSources(c, drive, (work) => action(work)),
                if (busy && ModalRoute.isCurrentOf(ctx) == true)
                  const LinearProgressIndicator(),
                if (error != null) Text(error!),
              ],
            );
          }
          final kind = view == 'packages'
              ? ClassroomKind.materialSet
              : view == 'plans'
              ? ClassroomKind.plan
              : ClassroomKind.material;
          final scope = folderContents(kind, trash);
          final documents =
              scope
                  .where(
                    (d) =>
                        (view != 'files' || filter.matches(d)) &&
                        matchesSearch(d),
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
          final cloudPlans = view == 'plans'
              ? c.classroom
                    .where(
                      (d) =>
                          d.kind == ClassroomKind.material &&
                          d.deleted == trash &&
                          {'dayPlan', 'weekPlan'}.contains(teachingUse(d)) &&
                          materialMatches(d, query, pupils: c.pupils),
                    )
                    .toList()
              : <ClassroomDocument>[];
          final today = dateOnly(DateTime.now());
          final preparedDays = view != 'prepared'
              ? <String, List<ClassroomDocument>>{}
              : preparedMaterialsByDay(
                  c.classroom,
                  query: query,
                  pupils: c.pupils,
                );
          final upcoming =
              preparedDays.keys.where((d) => d.compareTo(today) > 0).toList()
                ..sort();
          final past =
              preparedDays.keys.where((d) => d.compareTo(today) < 0).toList()
                ..sort((a, b) => b.compareTo(a));
          return Column(
            children: [
              Expanded(
                child: ListView(
                  key: const PageStorageKey('materials-library'),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    view == 'files' ? 4 : 16,
                    16,
                    96,
                  ),
                  children: [
                    ActionHeading(
                      leading: view == 'files' && trash
                          ? Row(
                              children: [
                                IconButton(
                                  tooltip: 'Zur Bibliothek',
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () => openFileTrash(false),
                                ),
                                Expanded(
                                  child: Text(
                                    'Papierkorb',
                                    style: Theme.of(
                                      ctx,
                                    ).textTheme.headlineSmall,
                                  ),
                                ),
                              ],
                            )
                          : Text(switch (view) {
                              'prepared' => 'Bereitgelegt',
                              'packages' => 'Pakete',
                              'plans' => 'Planungen',
                              _ => 'Bibliothek',
                            }, style: Theme.of(ctx).textTheme.headlineSmall),
                      actions: [
                        if (view == 'files' && !trash) ...[
                          addMaterialMenu(ctx),
                          libraryOptions(ctx),
                        ],
                        if (view != 'files')
                          IconButton(
                            tooltip: 'Materialien suchen',
                            isSelected: searching,
                            icon: const Icon(Icons.search),
                            onPressed: () =>
                                setState(() => searching = !searching),
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
                      IncomingFilesButton(controller: c),
                    if (view != 'files' && (searching || query.isNotEmpty))
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
                                searching = false;
                              }),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    if (view != 'files') const SizedBox(height: 8),
                    if (widget.externalView == null)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final item in const [
                            ('files', 'Bibliothek'),
                            ('prepared', 'Bereitgelegt'),
                            ('drive', 'OneDrive'),
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
                              onSelected: (_) =>
                                  setState(() => changeView(item.$1)),
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
                    if (view == 'prepared' ||
                        view == 'packages' ||
                        view == 'plans')
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PopupMenuButton<String>(
                          tooltip: 'Unterricht planen',
                          onSelected: (v) => setState(() => changeView(v)),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'packages',
                              child: Text('Pakete'),
                            ),
                            PopupMenuItem(
                              value: 'plans',
                              child: Text('Planungen'),
                            ),
                            PopupMenuItem(
                              value: 'prepared',
                              child: Text('Zur Tagesplanung'),
                            ),
                          ],
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Unterricht planen ▾'),
                          ),
                        ),
                      ),
                    if (view == 'prepared') ...[
                      _PlanningWeeks(c, query),
                      OutlinedButton.icon(
                        onPressed: () => showPreparedMaterials(ctx, c),
                        icon: const Icon(Icons.date_range_outlined),
                        label: const Text('Tag wählen / vorbereiten'),
                      ),
                      if (query.trim().isEmpty ||
                          preparedDays.containsKey(today))
                        PreparedMaterialsTile(
                          controller: c,
                          date: today,
                          query: query,
                        ),
                      if (upcoming.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Nächste Einsätze',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      for (final date in upcoming)
                        PreparedMaterialsTile(
                          controller: c,
                          date: date,
                          query: query,
                        ),
                      if (past.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Frühere Einsätze',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      for (final date in past)
                        PreparedMaterialsTile(
                          controller: c,
                          date: date,
                          query: query,
                        ),
                      if (query.trim().isNotEmpty &&
                          preparedDays.isEmpty &&
                          !c.classroom.any(
                            (d) =>
                                !d.deleted &&
                                teachingWeek(d).isNotEmpty &&
                                materialMatches(d, query, pupils: c.pupils),
                          ))
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'Keine passenden Materialien bereitgelegt oder geplant.',
                          ),
                        ),
                    ] else ...[
                      if (view == 'files') ...[
                        librarySearchBar(ctx),
                        if (!trash && !selecting) _PlanningInbox(c),
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
                              onSelected: (v) =>
                                  setState(() => collectionTrash = v),
                            ),
                          ],
                        ),
                      if (view != 'files') const SizedBox(height: 8),
                      if (cloudPlans.isNotEmpty)
                        ExpansionTile(
                          key: const PageStorageKey('planning-source-files'),
                          tilePadding: EdgeInsets.zero,
                          title: const Text(
                            'Tages- und Wochenpläne aus OneDrive',
                          ),
                          subtitle: Text('${cloudPlans.length} Dateien'),
                          children: [_PlanningFiles(c, '', cloudPlans)],
                        ),
                      if (documents.isEmpty && cloudPlans.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Column(
                            children: [
                              Icon(
                                trash
                                    ? Icons.delete_outline
                                    : Icons.folder_open_outlined,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                query.isNotEmpty ||
                                        view == 'files' && filter.isActive
                                    ? 'Keine Materialien gefunden.'
                                    : trash
                                    ? 'Der Papierkorb ist leer.'
                                    : view == 'files'
                                    ? 'Deine Bibliothek ist noch leer.'
                                    : 'Keine passenden Materialien.',
                                textAlign: TextAlign.center,
                              ),
                              if (query.isNotEmpty ||
                                  view == 'files' && filter.isActive)
                                TextButton(
                                  onPressed: () => changeFilters(() {
                                    currentSearch.clear();
                                    if (view == 'files') {
                                      replaceFilter(_LibraryFilter());
                                    }
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

Future<void> importMaterialFile(
  BuildContext context,
  NotebookController c, {
  String? pupilId,
}) async {
  final files = const LocalMaterialFiles();
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Dokumente und Fotos',
        extensions: ['docx', 'pdf', 'jpg', 'jpeg', 'png'],
        mimeTypes: [
          'application/pdf',
          'image/jpeg',
          'image/png',
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
  final data = bytes.takeBytes(), ext = cloudExtension(file.name);
  validateMaterialBytes(data, ext);
  final key = newId();
  await files.write(key, data);
  late final ClassroomDocument imported;
  try {
    imported = await c.repository.saveClassroomDocument(
      ClassroomDocument.create(ClassroomKind.material, file.name, {
        if (pupilId != null) 'pupilIds': [pupilId],
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
  if (context.mounted) await showMaterialDetails(context, c, imported);
}
