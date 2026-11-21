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
import 'package:flex_notizbuch/ui/material_layout_button.dart';
import 'package:flex_notizbuch/ui/material_library.dart'
    show
        browseOneDrive,
        connectOneDrive,
        cacheMaterial,
        showMaterialAssignments,
        AssignedMaterialsExplorer,
        showAssignedMaterials;
import 'package:flex_notizbuch/services/onedrive.dart';
import 'package:flex_notizbuch/domain/drive_rules.dart' show isDriveRule;
import 'package:flex_notizbuch/ui/material_docx.dart' show DocxPreview;
import '../domain/core.dart';
import '../domain/week_folder.dart';
import 'package:flex_notizbuch/domain/teaching_sheet.dart';
import 'package:flex_notizbuch/domain/planning_import.dart'
    show teachingDay, teachingUse, teachingWeek;
import 'package:flex_notizbuch/ui/lesson_flow_page.dart';
import 'package:flex_notizbuch/ui/teaching_review.dart';
import 'package:flex_notizbuch/ui/admin_page.dart';
import 'package:flex_notizbuch/ui/archived_pupils.dart';
import '../domain/desk_organization.dart';
import '../data/week_pdf.dart';
import '../application/editor_session.dart';
import '../application/workspace_controller.dart';
import 'package:flex_notizbuch/ui/school_workspace.dart'
    show editSchool, showHomeworkDetail, showJournal, SchoolRecordCard;
import 'package:flex_notizbuch/ui/homework_control.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flex_notizbuch/ui/classroom_editor.dart'
    show showClassroomEditor;
import 'package:flex_notizbuch/ui/return_lists.dart' show showReturnDetail;
import 'package:flex_notizbuch/ui/dialog_workflows.dart'
    show showBulk, showCatalog, showSituation;
import 'package:flex_notizbuch/ui/timetable.dart' show resumeTimetableDraft;
import 'package:flex_notizbuch/ui/calendar_page.dart' show showCalendarItem;
import 'package:flex_notizbuch/ui/scan_editor.dart' show showDocumentScanner;
import 'package:flex_notizbuch/ui/observation_tone_colors.dart';
import 'package:flex_notizbuch/ui/repeat_editor.dart' show showOrgaRepeat;
import 'package:flex_notizbuch/ui/reminder_actions.dart';
import 'package:flex_notizbuch/ui/flex_modal.dart';
import 'package:flex_notizbuch/ui/entry_templates.dart'
    show showEntryTemplateManager, showCatalogTransfer;
import 'package:flex_notizbuch/ui/option_bar.dart' show OptionBar;
import 'package:flex_notizbuch/domain/reminder_action.dart';
import 'design.dart';
part 'desk.dart';
part 'week.dart';
part 'teaching.dart';
part 'commands.dart';
part 'entry_editor.dart';
part 'full_editor.dart';
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
      if (Navigator.of(context).canPop()) {
        await Navigator.of(context).maybePop();
        return;
      }
      await c.editor?.flush();
      if (c.notebook.syncingMaterials) await c.notebook.syncMaterials();
      await c.settleReminders();
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

  bool handlingReminder = false;
  void onWindowsReminder() {
    final alerts = c.reminders;
    if (!mounted || handlingReminder || alerts?.pendingTarget == null) return;
    final action = ReminderAction.parse(alerts!.pendingTarget!);
    alerts.consumeTarget();
    if (action == null) return;
    handlingReminder = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        await run(() async {
          if (action.action != 'open') {
            final applied = await c.repository.applyReminderAction(
              action,
              DateTime.now(),
            );
            await c.notebook.reload();
            if (!applied && mounted) {
              message('Die Erinnerung wurde bereits geändert.');
            }
            return;
          }
          final parts = action.target.split(':'), id = parts[1];
          final item = switch (parts.first) {
            'orga' => c.notebook.entries.where((e) => e.id == id).firstOrNull,
            'school' =>
              c.notebook.records
                  .where((e) => e.id == id && !e.deleted)
                  .firstOrNull,
            'return' =>
              c.notebook.classroom
                  .where((e) => e.id == id && !e.deleted)
                  .firstOrNull,
            _ => null,
          };
          if (item != null) {
            await openDesktopValue(item);
            return;
          }
          if (parts.first == 'lesson' && validDate(parts.last)) {
            final matches = c
                .agenda(schoolDay(parts.last))
                .where((i) => i.id == action.target);
            if (matches.isNotEmpty) {
              await viewCalendarItem(matches.first);
              return;
            }
          }
          message('Der Eintrag ist inzwischen nicht mehr verfügbar.');
        });
      } finally {
        handlingReminder = false;
        if (mounted) onWindowsReminder();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
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
    c.reminders?.addListener(onWindowsReminder);
    unawaited(c.initializeReminders());
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
    c.reminders?.removeListener(onWindowsReminder);
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
  Widget addMenu({bool floating = true}) {
    final priority = switch (c.section) {
      WorkspaceSection.calendar || WorkspaceSection.week => [
        EntryKind.appointment,
        EntryKind.lesson,
        EntryKind.plan,
      ],
      WorkspaceSection.journal => [
        EntryKind.social,
        EntryKind.work,
        EntryKind.goal,
        EntryKind.homework,
      ],
      WorkspaceSection.organization => [
        EntryKind.task,
        EntryKind.returnList,
        EntryKind.note,
        EntryKind.appointment,
      ],
      WorkspaceSection.planning => [EntryKind.plan, EntryKind.lesson],
      _ => const [EntryKind.note, EntryKind.task, EntryKind.social],
    };
    Widget actionForKind(EntryKind kind) => MenuItemButton(
      leadingIcon: Icon(entryIcons[kind.index], size: 18),
      onPressed: () => run(() => newDesktopEntry(kind)),
      child: Text(kind.label),
    );
    final files = [
      MenuItemButton(
        leadingIcon: const Icon(Icons.file_upload_outlined),
        onPressed: () => run(importLocal),
        child: const Text('Dateien importieren'),
      ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.add_link),
        onPressed: () => run(addLink),
        child: const Text('Materiallink hinzufügen'),
      ),
    ];
    return MenuAnchor(
      style: MenuStyle(
        alignment: floating ? Alignment.topRight : Alignment.bottomRight,
      ),
      builder: (ctx, menu, _) {
        void toggle() => menu.isOpen ? menu.close() : menu.open();
        return floating
            ? FloatingActionButton(
                key: const ValueKey('desktop-add'),
                heroTag: null,
                tooltip: 'Hinzufügen',
                onPressed: toggle,
                child: const Icon(Icons.add),
              )
            : IconButton(
                tooltip: 'Hinzufügen',
                onPressed: toggle,
                icon: const Icon(Icons.add),
              );
      },
      menuChildren: [
        if (c.section == WorkspaceSection.materials) ...[
          ...files,
          const Divider(),
        ],
        for (final kind in priority) actionForKind(kind),
        SubmenuButton(
          leadingIcon: const Icon(Icons.library_add_outlined),
          menuChildren: [
            for (final kind in EntryKind.values.where(
              (k) => !priority.contains(k),
            ))
              actionForKind(kind),
          ],
          child: const Text('Weitere Eintragsarten'),
        ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(Icons.group_add_outlined),
          onPressed: () => run(() => showBulk(context, c.notebook)),
          child: const Text('Für mehrere erfassen'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.fact_check_outlined),
          onPressed: () => run(
            () => showHomeworkControl(
              context,
              c.notebook,
              dateOnly(c.date),
              pupilId: c.section == WorkspaceSection.journal
                  ? c.pupil?.id
                  : null,
            ),
          ),
          child: const Text('Hausübungen kontrollieren'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.document_scanner_outlined),
          onPressed: () => run(() async {
            await showDocumentScanner(context, c.notebook);
          }),
          child: const Text('Scan oder Bild hinzufügen'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_note),
          onPressed: () => run(() => c.start(EntryKind.note)),
          child: const Text('Schnellnotiz im Seitenbereich'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.person_add_alt, size: 18),
          onPressed: addPupil,
          child: const Text('Schüler hinzufügen'),
        ),
        if (c.section != WorkspaceSection.materials) ...files,
      ],
    );
  }

  Widget centralPage() => Stack(
    fit: StackFit.expand,
    children: [
      mainContent(),
      Positioned(
        right: 20,
        bottom: 20,
        child: SafeArea(top: false, left: false, child: addMenu()),
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
            run(() => newDesktopEntry(EntryKind.note)),
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
                                Expanded(child: centralPage()),
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
                                            onExpand: () =>
                                                run(expandQuickEditor),
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
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => c.navigate(section),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
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
    height: 56,
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
        if (MediaQuery.sizeOf(context).width < 1000 &&
            (c.editor != null || c.material != null))
          addMenu(floating: false),
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
        await newDesktopEntry(target);
      } else if (target is Pupil) {
        await c.parkEditor();
        c.materialId = null;
        c.selectPupil(target.id);
        c.navigate(WorkspaceSection.journal);
      } else {
        await openDesktopValue(target);
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
                    run(() => openDesktopValue(d));
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
                    run(() => openDesktopValue(d));
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
                    run(() => openDesktopValue(d));
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
