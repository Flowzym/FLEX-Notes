import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flex_notizbuch/ui/backup_dialog.dart';
import 'package:flex_notizbuch/ui/pupil_editor.dart';
import 'package:flex_notizbuch/ui/draft_buffer.dart' show saveBytesFile;
import 'package:flex_notizbuch/ui/material_thumbnail.dart';
import 'package:flex_notizbuch/ui/material_library.dart'
    show
        browseOneDrive,
        connectOneDrive,
        cacheMaterial,
        showMaterialAssignments;
import 'package:flex_notizbuch/services/onedrive.dart';
import 'package:flex_notizbuch/domain/drive_rules.dart' show isDriveRule;
import 'package:flex_notizbuch/services/docx_preview.dart';
import '../domain/core.dart';
import '../domain/week_folder.dart';
import '../domain/desk_organization.dart';
import '../data/week_pdf.dart';
import '../application/editor_session.dart';
import '../application/workspace_controller.dart';
import 'design.dart';
part 'desk.dart';
part 'week.dart';
part 'commands.dart';
part 'entry_editor.dart';
part 'calendar.dart';
part 'materials.dart';
part 'organization.dart';
part 'data_page.dart';

const sectionIcons = [
  Icons.space_dashboard_outlined,
  Icons.date_range_outlined,
  Icons.people_outline,
  Icons.calendar_month_outlined,
  Icons.view_week_outlined,
  Icons.folder_open_outlined,
  Icons.fact_check_outlined,
  Icons.tune_outlined,
];
const entryIcons = [
  Icons.people_outline,
  Icons.description_outlined,
  Icons.track_changes_outlined,
  Icons.school_outlined,
  Icons.sticky_note_2_outlined,
  Icons.checklist_outlined,
  Icons.event_outlined,
  Icons.assignment_turned_in_outlined,
  Icons.view_week_outlined,
  Icons.school_outlined,
];

class DesktopWorkspace extends StatefulWidget {
  const DesktopWorkspace({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<DesktopWorkspace> createState() => _DesktopWorkspaceState();
}

class _DesktopWorkspaceState extends State<DesktopWorkspace>
    with WidgetsBindingObserver, WindowListener {
  WorkspaceController get c => widget.controller;
  void redraw(VoidCallback action) {
    if (mounted) setState(action);
  }

  @override
  void onWindowClose() async {
    try {
      await c.editor?.flush();
      await c.repository.close();
      await windowManager.destroy();
    } catch (_) {
      if (mounted) {
        message(
          "Die Eingabe konnte nicht gesichert werden. Bitte speichern, bevor du FLEX schließt.",
        );
      }
    }
  }

  final drive = OneDriveClient(useNativeAuthentication: false);
  final calendarScroll = ScrollController(initialScrollOffset: 7 * 56);
  bool driveLoaded = false;
  String calendarView = 'Woche', orgaStatus = 'Alle', orgaKind = 'Alle Arten';
  String materialScope = 'Alle', materialSort = 'Zuletzt geändert';
  bool weekends = false, favoritesOnly = false;
  String journalFilter = 'Alle';
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      windowManager.addListener(this);
    }
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      drive
          .load()
          .then((_) {
            if (mounted) setState(() => driveLoaded = true);
          })
          .catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      windowManager.removeListener(this);
    }
    calendarScroll.dispose();
    drive.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(c.editor?.flush().catchError((Object _) {}) ?? Future.value());
    }
  }

  Future<void> run(Future<void> Function() action, {String? success}) async {
    try {
      await action();
      if (mounted && success != null) message(success);
    } catch (e) {
      if (mounted) {
        message(
          e is DomainError
              ? e.message
              : 'Die Aktion konnte nicht abgeschlossen werden. Deine Eingaben bleiben erhalten.',
        );
      }
    }
  }

  void message(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      width: 500,
    ),
  );
  Future<void> addPupil() => editPupil();

  Future<void> editPupil({Pupil? pupil, DialogDraft? draft}) async {
    final before = c.pupils.map((p) => p.id).toSet();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          PupilEditor(controller: c.notebook, pupil: pupil, draft: draft),
    );
    if (!mounted) return;
    final created = c.pupils.where((p) => !before.contains(p.id)).singleOrNull;
    if (created != null) c.selectPupil(created.id);
  }

  Future<bool> confirm(
    String title,
    String text, {
    String action = 'Bestätigen',
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
  Widget addMenu({bool wide = true}) => MenuAnchor(
    builder: (ctx, controller, child) => FilledButton.icon(
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
      icon: const Icon(Icons.add, size: 18),
      label: Text(wide ? 'Neuer Eintrag' : 'Neu'),
    ),
    menuChildren: [
      for (final kind in EntryKind.values)
        MenuItemButton(
          leadingIcon: Icon(entryIcons[kind.index], size: 18),
          onPressed: () => run(() => c.start(kind)),
          child: Text(kind.label),
        ),
      const Divider(),
      MenuItemButton(
        leadingIcon: const Icon(Icons.person_add_alt, size: 18),
        onPressed: addPupil,
        child: const Text('Schüler hinzufügen'),
      ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.file_upload_outlined, size: 18),
        onPressed: () => run(importLocal),
        child: const Text('Dateien importieren'),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            commandPalette,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            commandPalette,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            run(() => c.start(EntryKind.note)),
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
            run(c.commitEditor, success: 'Eintrag gespeichert'),
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () =>
            run(c.commitEditor, success: 'Eintrag gespeichert'),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: LayoutBuilder(
            builder: (context, box) {
              final narrow = box.maxWidth < 1200,
                  inspector = c.editor != null || c.material != null;
              return Row(
                children: [
                  sidebar(narrow),
                  Expanded(
                    child: Column(
                      children: [
                        header(narrow),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!inspector || box.maxWidth >= 1000)
                                Expanded(child: mainContent()),
                              if (inspector ||
                                  box.maxWidth >= 1380 &&
                                      c.section == WorkspaceSection.desk)
                                Container(
                                  width: box.maxWidth < 1000
                                      ? box.maxWidth - (narrow ? 76 : 220)
                                      : 390,
                                  decoration: const BoxDecoration(
                                    color: white,
                                    border: Border(
                                      left: BorderSide(color: line),
                                    ),
                                  ),
                                  child: Material(
                                    color: white,
                                    child: c.editor != null
                                        ? EntryEditor(
                                            key: ValueKey(c.editor!.draftId),
                                            session: c.editor!,
                                            workspace: c,
                                            onSave: () => run(
                                              c.commitEditor,
                                              success: 'Eintrag gespeichert',
                                            ),
                                            onPark: () => run(c.parkEditor),
                                            onTrash: () async {
                                              if (await confirm(
                                                'Eintrag in den Papierkorb?',
                                                'Der Eintrag kann anschließend unter Daten & Einstellungen wiederhergestellt werden.',
                                                action: 'Verschieben',
                                              )) {
                                                c.editor?.patch({
                                                  'deleted': true,
                                                });
                                                await run(
                                                  c.commitEditor,
                                                  success:
                                                      'In den Papierkorb verschoben',
                                                );
                                              }
                                            },
                                            onDiscard: () async {
                                              if (await confirm(
                                                'Entwurf verwerfen?',
                                                'Diese ungespeicherten Änderungen werden entfernt.',
                                                action: 'Verwerfen',
                                              )) {
                                                await run(c.discardEditor);
                                              }
                                            },
                                          )
                                        : c.material != null
                                        ? materialInspector(c.material!)
                                        : todayInspector(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
  Widget sidebar(bool compact) => Container(
    width: compact ? 76 : 220,
    decoration: const BoxDecoration(
      color: Color(0xffedeFe7),
      border: Border(right: BorderSide(color: line)),
    ),
    padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: compact ? 2 : 12, bottom: 4),
          child: Text(
            compact ? 'F.' : 'FLEX.',
            style: const TextStyle(
              fontSize: compactFont,
              letterSpacing: -1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (!compact)
          const Padding(
            padding: EdgeInsets.only(left: 12, bottom: 28),
            child: Text(
              'DESKTOP',
              style: TextStyle(fontSize: 9, letterSpacing: 2.6, color: muted),
            ),
          ),
        if (compact) const SizedBox(height: 30),
        for (final section in WorkspaceSection.values.where(
          (s) => s != WorkspaceSection.data,
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Tooltip(
              message: compact ? section.label : '',
              child: Material(
                color: c.section == section
                    ? const Color(0xffdce3d1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => c.navigate(section),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: compact
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        Icon(
                          sectionIcons[section.index],
                          size: 21,
                          color: c.section == section ? olive : muted,
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              section.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: c.section == section
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: c.section == section ? ink : muted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
        if (c.demo && !compact)
          const Padding(padding: EdgeInsets.all(10), child: Pill('DEMODATEN')),
        Tooltip(
          message: 'Entwürfe',
          child: compact
              ? IconButton(
                  onPressed: showDrafts,
                  icon: Badge(
                    label: Text('${c.draftCount}'),
                    isLabelVisible: c.draftCount > 0,
                    child: const Icon(Icons.edit_note),
                  ),
                )
              : TextButton(
                  onPressed: showDrafts,
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note, size: 20),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Entwürfe · ${c.draftCount}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const Divider(height: 24),
        Tooltip(
          message: 'Daten & Einstellungen',
          child: compact
              ? IconButton(
                  onPressed: () => c.navigate(WorkspaceSection.data),
                  icon: const Icon(Icons.tune),
                )
              : TextButton(
                  onPressed: () => c.navigate(WorkspaceSection.data),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, size: 20),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'Daten & Einstellungen',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        if (!compact)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 16, 0, 0),
            child: Row(
              children: [
                Icon(Icons.circle, size: 6, color: olive),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Lokal gespeichert',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
  static const compactFont = 30.0;
  Widget header(bool compact) => Container(
    height: 76,
    padding: const EdgeInsets.symmetric(horizontal: 26),
    decoration: const BoxDecoration(
      color: white,
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        Text(
          'FLEX-Klasse',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('/', style: TextStyle(color: line)),
        ),
        Expanded(
          child: Text(
            c.section.label,
            style: const TextStyle(color: muted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        OutlinedButton.icon(
          onPressed: commandPalette,
          icon: const Icon(Icons.search, size: 18),
          label: Text(
            compact ? 'Suchen' : 'Suchen oder Aktion …     Strg K',
            style: const TextStyle(fontSize: 11),
          ),
        ),
        const SizedBox(width: 12),
        addMenu(wide: !compact),
      ],
    ),
  );
  Widget mainContent() => switch (c.section) {
    WorkspaceSection.desk => desk(),
    WorkspaceSection.week => weekDesk(),
    WorkspaceSection.journal => journal(),
    WorkspaceSection.calendar => calendar(),
    WorkspaceSection.planning => planning(),
    WorkspaceSection.materials => materials(),
    WorkspaceSection.organization => organization(),
    WorkspaceSection.data => dataPage(),
  };
  Future<void> commandPalette() async {
    final target = await showDialog<Object>(
      context: context,
      builder: (_) => _DesktopCommands(c),
    );
    if (!mounted || target == null) return;
    await run(() async {
      if (target is WorkspaceSection) {
        c.navigate(target);
      } else if (target is EntryKind) {
        await c.start(target);
      } else if (target is Pupil) {
        await c.parkEditor();
        c.materialId = null;
        c.selectPupil(target.id);
        c.navigate(WorkspaceSection.journal);
      } else {
        await c.edit(target);
        if (target is ClassroomDocument &&
            target.kind == ClassroomKind.material) {
          c.navigate(WorkspaceSection.materials);
        }
      }
    });
  }

  Future<void> showDrafts() async {
    await run(() async {
      await c.editor?.flush();
      await c.notebook.reload();
    });
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gesicherte Entwürfe'),
        content: SizedBox(
          width: 580,
          height: 400,
          child: ListView(
            children: [
              if (c.draftCount == 0)
                const QuietEmpty(
                  'Keine offenen Entwürfe',
                  'Deine Eingaben sind vollständig gespeichert.',
                ),
              for (final d in c.notebook.schoolDrafts)
                ListTile(
                  title: Text(
                    '${d.record.kind.label} · ${c.name(d.record.pupilId)}',
                  ),
                  subtitle: Text(
                    d.record.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    run(() => c.edit(d));
                  },
                ),
              for (final d in c.notebook.drafts)
                ListTile(
                  title: Text(
                    d.entry.title.isEmpty
                        ? 'Unbenannter Eintrag'
                        : d.entry.title,
                  ),
                  subtitle: Text(c.name(d.entry.pupilId)),
                  onTap: () {
                    Navigator.pop(ctx);
                    run(() => c.edit(d));
                  },
                ),
              for (final d in c.notebook.dialogDrafts)
                ListTile(
                  title: Text(
                    (d.data['title'] ?? d.data['name'] ?? 'Entwurf') as String,
                  ),
                  subtitle: Text(d.type == 'pupil' ? 'Schülerprofil' : d.type),
                  onTap: () {
                    Navigator.pop(ctx);
                    run(
                      () => d.type == 'pupil' ? editPupil(draft: d) : c.edit(d),
                    );
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }
}
