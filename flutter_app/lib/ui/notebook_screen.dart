import 'detail_flow.dart';
import 'material_thumbnail.dart';
import 'general_orga_page.dart';
import 'scanner_library.dart';
import 'document_attachments.dart';
import '../domain/document_scanner.dart';
import '../services/material_storage.dart';
import '../services/scan_store.dart';
import 'collapsible_search.dart';
import 'draft_actions.dart';
import 'pupil_workspace.dart';
import 'conflict_dialog.dart';
import 'maintenance_dialog.dart';
import 'pupil_editor.dart';
import 'dialog_workflows.dart';
import 'surfaces.dart';
import 'overview_entry.dart';
import 'app_navigation.dart';
import 'pupil_card.dart';

import 'package:flutter/material.dart';

import '../application/notebook_controller.dart';
import '../domain/models.dart';
import 'common.dart';
import 'orga_editor.dart';
import 'settings.dart';
import 'appearance_settings.dart';
import '../domain/school.dart';
import 'flex_icons.dart';
import 'flex_modal.dart';
import 'school_workspace.dart';
import '../domain/classroom.dart';
import '../domain/material_workspace.dart';
import '../domain/calendar.dart';
import 'classroom_editor.dart';
import 'calendar_page.dart';
import 'timetable.dart';
import 'material_library.dart';
import 'return_lists.dart';
import 'repeat_editor.dart';
import 'reminder_actions.dart';

class NotebookScreen extends StatefulWidget {
  const NotebookScreen({super.key, required this.controller});
  final NotebookController controller;
  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  NotebookController get c => widget.controller;
  int _primary = 0, _destination = 1, _materialView = 0, _moreView = 0;
  int _calendarView = 0, _orgaView = 0;
  final _calendarPages = PageController();
  final _visited = <int>{1};
  final _dataLayout = SettingsLayoutState()..tab = 2;
  DateTime? _calendarShortcutDate, _timetableShortcutDate;
  int _calendarShortcutRevision = 0, _timetableShortcutRevision = 0;
  String? _overviewSection;
  final _pages = PageController();
  final _settingsLayout = SettingsLayoutState();
  VoidCallback? _refreshPupilDialog;
  void _changeView(VoidCallback action) {
    if (!mounted) return;
    c.flushAppearance();
    setState(action);
    _refreshPupilDialog?.call();
  }

  String _pupilQuery = '', _entryQuery = '', _filter = 'all';
  final _expandedSections = <String>{};
  final _pupilSearch = TextEditingController();
  final _entrySearch = TextEditingController();
  @override
  void initState() {
    super.initState();
    c.services?.reminders.addListener(_notification);
    c.services?.lock.addListener(_notification);
    _notification();
  }

  bool _openingNotification = false;
  void _notification() {
    final services = c.services;
    if (services == null ||
        services.lock.locked ||
        services.reminders.pendingTarget == null ||
        _openingNotification) {
      return;
    }
    _openingNotification = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || services.lock.locked) {
        _openingNotification = false;
        return;
      }
      final target = services.reminders.pendingTarget!;
      services.reminders.consumeTarget();
      try {
        await c.reload();
        if (!mounted) return;
        final id = target.substring(target.indexOf(':') + 1);
        if (target.startsWith('orga:')) {
          final entry = c.entries.where((e) => e.id == id).firstOrNull;
          if (entry != null) {
            await _editor(entry);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dieser Eintrag ist nicht mehr verfügbar.'),
              ),
            );
          }
        } else if (target.startsWith('return:')) {
          await showReturnDetail(context, c, id);
        } else if (target.startsWith('lesson:')) {
          final date = target.split(':').last;
          if (validDate(date)) {
            final item = calendarItems(
              c.currentSnapshot,
              dateOnly(schoolDay(date).subtract(const Duration(days: 365))),
              dateOnly(schoolDay(date).add(const Duration(days: 365))),
            ).where((e) => e.id == target).firstOrNull;
            if (item != null && mounted) {
              await showCalendarItem(context, c, item);
            }
          }
        } else if (target.startsWith('school:')) {
          final record = c.records
              .where((r) => r.id == id && !r.deleted)
              .firstOrNull;
          if (record != null) {
            await editSchool(context, c, record);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dieser Eintrag ist nicht mehr verfügbar.'),
              ),
            );
          }
        }
      } finally {
        _openingNotification = false;
        _notification();
      }
    });
  }

  @override
  void dispose() {
    c.services?.reminders.removeListener(_notification);
    c.services?.lock.removeListener(_notification);
    _pages.dispose();
    _calendarPages.dispose();
    _pupilSearch.dispose();
    _entrySearch.dispose();
    super.dispose();
  }

  final _busyIds = <String>{};
  void _sectionTo(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    _changeView(() {
      _destination = index;
      _visited.add(index);
    });
  }

  void _main(int index) {
    _sectionTo(1);
    _changeView(() => _primary = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pages.hasClients) {
        _pages.animateToPage(
          index,
          duration: const Duration(milliseconds: 120),
          curve: Curves.linear,
        );
      }
    });
  }

  void _calendarTo(int index) {
    _sectionTo(0);
    _changeView(() => _calendarView = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _calendarPages.hasClients) {
        _calendarPages.animateToPage(
          index,
          duration: const Duration(milliseconds: 120),
          curve: Curves.linear,
        );
      }
    });
  }

  void _calendarShortcut(bool timetable, DateTime date) {
    if (timetable) {
      _timetableShortcutDate = date;
      _timetableShortcutRevision++;
    } else {
      _calendarShortcutDate = date;
      _calendarShortcutRevision++;
    }
    _calendarTo(timetable ? 1 : 0);
  }

  Widget _generalOrga(String kind) => GeneralOrgaPage(
    key: ValueKey('general-$kind-page'),
    controller: c,
    kind: kind,
    onEdit: (entry) => _editor(entry, defaultToClassTask: false),
    entryBuilder: _entryCard,
    onEditDraft: (draft) => _editor(draft.entry, draftId: draft.id),
  );

  Future<void> _editor(
    OrgaEntry entry, {
    String? draftId,
    bool defaultToClassTask = true,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OrgaEditor(
        controller: c,
        entry: entry,
        draftId: draftId,
        defaultToClassTask: defaultToClassTask,
      ),
    );
    if (mounted) await guarded(context, c.reload);
  }

  Future<void> _mutate(OrgaEntry value) async {
    if (_busyIds.contains(value.id)) return;
    _changeView(() => _busyIds.add(value.id));
    await guarded(context, () => c.saveEntry(value));
    if (mounted) _changeView(() => _busyIds.remove(value.id));
  }

  Future<void> _pupilEditor([Pupil? pupil, DialogDraft? draft]) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PupilEditor(controller: c, pupil: pupil, draft: draft),
    );
    await c.reload();
  }

  Future<void> _classOrga() async {
    var filter = 'all', query = '';
    final search = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AnimatedBuilder(
          animation: c,
          builder: (ctx, _) {
            final values = c.entries
                .where(
                  (e) =>
                      e.pupilId == null &&
                      '${e.title} ${e.body}'.toLowerCase().contains(
                        query.toLowerCase(),
                      ) &&
                      (filter == 'all' ||
                          (filter == 'appointments'
                              ? e.isAppointment
                              : e.isTask &&
                                    (filter == 'done' ? e.done : !e.done))),
                )
                .toList();
            return FlexModal(
              maxWidth: 1000,
              title: const Text('Klassen-Orga'),
              headerActions: [
                TextButton.icon(
                  onPressed: () => showReturnLists(ctx, c),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Rückläufe'),
                ),
              ],
              onClose: () => Navigator.pop(ctx),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CollapsibleSearch(
                    controller: search,
                    fieldKey: const ValueKey('class-orga-search'),
                    buttonKey: const ValueKey('class-orga-search-button'),
                    label: 'Einträge durchsuchen',
                    onChanged: (value) => update(() => query = value),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in const {
                        'all': 'Alle',
                        'appointments': 'Termine',
                        'open': 'Offen',
                        'done': 'Erledigt',
                      }.entries)
                        transparentChip(
                          ChoiceChip(
                            label: Text(option.value),
                            selected: filter == option.key,
                            onSelected: (_) =>
                                update(() => filter = option.key),
                          ),
                        ),
                    ],
                  ),
                  if (values.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Keine Einträge.'),
                    ),
                  for (final e in values)
                    FlexCard(
                      child: InkWell(
                        onTap: () => _editor(e),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                e.isAppointment
                                    ? 'Termin'
                                    : e.isTask
                                    ? e.done
                                          ? 'Aufgabe erledigt'
                                          : 'Aufgabe offen'
                                    : 'Notiz',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                e.body.isEmpty ? e.title : e.body,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (e.isAppointment)
                                Text(
                                  'Termin: ${displayDate(e.appointmentDate)} ${e.appointmentTime}',
                                ),
                              if (e.dueDate != null)
                                Text('Termin: ${displayDate(e.dueDate)}'),
                              if (e.reminderState == ReminderState.planned)
                                Text('Erinnern am: ${displayReminder(e)}'),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                OutlinedButton.icon(
                  key: const ValueKey('class-add-appointment'),
                  onPressed: () => _editor(
                    OrgaEntry.empty().copyWith(
                      appointmentDate: dateOnly(DateTime.now()),
                    ),
                  ),
                  icon: const Icon(Icons.event_outlined),
                  label: const Text('Termin anlegen'),
                ),
                FilledButton(
                  onPressed: () => _editor(OrgaEntry.empty()),
                  child: const Text('Eintrag hinzufügen'),
                ),
              ],
            );
          },
        ),
      ),
    );
    search.dispose();
  }

  Future<void> _auxDialog(String type) async {
    if (type == 'class') {
      await _classOrga();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AnimatedBuilder(
        animation: c,
        builder: (ctx, _) => FlexModal(
          title: Text(
            type == 'drafts'
                ? 'Gesicherte Entwürfe'
                : type == 'class'
                ? 'Klassen-Orga'
                : 'Papierkorb',
          ),
          maxWidth: type == 'class' ? 1000 : 760,
          actions: type == 'trash'
              ? [
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: ctx,
                      builder: (_) =>
                          MaintenanceDialog(controller: c, emptyTrash: true),
                    ),
                    child: const Text('Papierkorb endgültig leeren'),
                  ),
                ]
              : const [],
          onClose: () => Navigator.pop(ctx),
          scrollable: false,
          content: SizedBox(
            height:
                type == 'drafts' && c.draftCount == 0 ||
                    type == 'trash' &&
                        c.trashedEntries.isEmpty &&
                        !c.records.any((r) => r.deleted)
                ? 140
                : MediaQuery.sizeOf(ctx).height * .7,
            child: type == 'drafts'
                ? _drafts()
                : type == 'trash'
                ? SchoolTools(controller: c, mode: 'trash')
                : _entries(
                    c.entries.where((e) => e.pupilId == null).toList(),
                    scope: 'class',
                    orga: true,
                    pupil: null,
                  ),
          ),
        ),
      ),
    );
  }

  static const _morePages = {
    0: 'Weitere',
    1: 'Archiv',
    2: 'Papierkorb',
    3: 'Daten',
    4: 'Einstellungen',
    5: 'Scanner',
  };
  static const _materialPages = {
    0: 'Dateien',
    1: 'Bereitgelegt',
    2: 'Pakete',
    3: 'Planungen',
  };
  static const _materialViews = ['files', 'prepared', 'packages', 'plans'];
  Widget _placeholder(String title, IconData icon) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Dieser Bereich wird noch gestaltet.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
  Widget _moreHome() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      for (final item in <(String, IconData, VoidCallback)>[
        (
          'Scans & Fotos',
          Icons.document_scanner_outlined,
          () => _changeView(() => _moreView = 5),
        ),
        (
          'Entwürfe (${c.draftCount})',
          Icons.edit_note,
          () => _auxDialog('drafts'),
        ),
        ('Klassen-Orga', Icons.assignment_outlined, _classOrga),
        (
          'Rückläufe',
          Icons.fact_check_outlined,
          () => showReturnLists(context, c),
        ),
        (
          'Für mehrere erfassen',
          Icons.group_add_outlined,
          () => showBulk(context, c),
        ),
        (
          'Gruppenerfassungen',
          Icons.groups_outlined,
          () => showDialog<void>(
            context: context,
            builder: (ctx) => FlexModal(
              title: const Text('Gruppenerfassungen'),
              onClose: () => Navigator.pop(ctx),
              scrollable: false,
              content: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * .65,
                child: SchoolTools(controller: c, mode: 'groups'),
              ),
            ),
          ),
        ),
        (
          'Änderungskonflikte',
          Icons.compare_arrows,
          () => showDialog<void>(
            context: context,
            builder: (_) => ConflictDialog(controller: c),
          ),
        ),
        (
          'Material-Papierkorb',
          Icons.delete_sweep_outlined,
          () => showDialog<void>(
            context: context,
            builder: (ctx) => FlexModal(
              title: const Text('Material-Papierkorb'),
              maxWidth: 1000,
              onClose: () => Navigator.pop(ctx),
              scrollable: false,
              content: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * .7,
                child: MaterialLibraryPage(
                  controller: c,
                  externalView: 'files',
                  initialTrash: true,
                ),
              ),
            ),
          ),
        ),
      ])
        Card(
          child: ListTile(
            leading: Icon(item.$2),
            title: Text(item.$1),
            trailing: const Icon(Icons.chevron_right),
            onTap: item.$3,
          ),
        ),
    ],
  );
  Widget _moreBody() => switch (_moreView) {
    5 => ScannerLibrary(
      key: const ValueKey('scanner-library-page'),
      controller: c,
    ),
    1 => _pupils(archived: true),
    2 => Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) =>
                  MaintenanceDialog(controller: c, emptyTrash: true),
            ),
            child: const Text('Papierkorb endgültig leeren'),
          ),
        ),
        Expanded(
          child: SchoolTools(controller: c, mode: 'trash'),
        ),
      ],
    ),
    3 => SettingsPage(
      key: const ValueKey('data-page'),
      controller: c,
      layout: _dataLayout,
      dataOnly: true,
    ),
    4 => SettingsPage(
      key: const ValueKey('settings-page'),
      controller: c,
      layout: _settingsLayout,
      includeDataTab: false,
    ),
    _ => _moreHome(),
  };
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _destination == 1 && _primary == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _main(0);
    },
    child: Scaffold(
      bottomNavigationBar: FlexBottomNavigation(
        selected: _destination,
        onSelected: _sectionTo,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (c.appearanceError != null)
              MaterialBanner(
                content: Text(c.appearanceError!),
                actions: [
                  TextButton(
                    onPressed: () {
                      _sectionTo(4);
                      _changeView(() => _moreView = 4);
                    },
                    child: const Text('Einstellungen'),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'FLEX.',
                  key: const ValueKey('app-wordmark'),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: .5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .55),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: FlexPagePills(
                keyPrefix: _destination == 1 ? 'page' : 'context-$_destination',
                selected: switch (_destination) {
                  0 => _calendarView,
                  1 => _primary,
                  2 => _orgaView,
                  3 => _materialView,
                  4 => _moreView,
                  _ => 0,
                },
                pages: switch (_destination) {
                  0 => calendarPages,
                  1 => livePages,
                  2 => const {0: 'Orga', 1: 'Rückläufe', 2: 'Notizen'},
                  3 => _materialPages,
                  _ => _morePages,
                },
                onSelected: (index) {
                  if (_destination == 0) {
                    _calendarTo(index);
                  } else if (_destination == 2) {
                    _changeView(() => _orgaView = index);
                  } else if (_destination == 1) {
                    _main(index);
                  } else if (_destination == 3) {
                    _changeView(() => _materialView = index);
                  } else if (_destination == 4) {
                    _changeView(() => _moreView = index);
                  }
                },
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: IndexedStack(
                    index: _destination,
                    children: [
                      if (_visited.contains(0))
                        PageView(
                          physics: const FlexPageScrollPhysics(
                            parent: ClampingScrollPhysics(),
                          ),
                          key: const ValueKey('calendar-pages'),
                          controller: _calendarPages,
                          onPageChanged: (index) =>
                              _changeView(() => _calendarView = index),
                          children: [
                            CalendarPage(
                              key: const ValueKey('main-calendar'),
                              controller: c,
                              shortcutDate: _calendarShortcutDate,
                              shortcutRevision: _calendarShortcutRevision,
                              onSwitchSection: _calendarShortcut,
                            ),
                            CalendarPage(
                              key: const ValueKey('main-timetable'),
                              controller: c,
                              initialTimetable: true,
                              shortcutDate: _timetableShortcutDate,
                              shortcutRevision: _timetableShortcutRevision,
                              onSwitchSection: _calendarShortcut,
                            ),
                            _generalOrga('task'),
                          ],
                        )
                      else
                        const SizedBox(),
                      PageView(
                        physics: const FlexPageScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                        key: const ValueKey('main-pages'),
                        controller: _pages,
                        onPageChanged: (index) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          _changeView(() => _primary = index);
                        },
                        children: [
                          _overview(),
                          _pupils(),
                          _placeholder('Ablauf', Icons.route_outlined),
                        ],
                      ),
                      if (_visited.contains(2))
                        IndexedStack(
                          index: _orgaView,
                          children: [
                            _generalOrga('all'),
                            ReturnLists(controller: c),
                            _generalOrga('note'),
                          ],
                        )
                      else
                        const SizedBox(),
                      if (_visited.contains(3))
                        MaterialLibraryPage(
                          controller: c,
                          externalView: _materialViews[_materialView],
                        )
                      else
                        const SizedBox(),
                      if (_visited.contains(4))
                        _moreBody()
                      else
                        const SizedBox(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _pupilDrafts(Pupil pupil) => showDialog<void>(
    context: context,
    builder: (ctx) => AnimatedBuilder(
      animation: c,
      builder: (_, _) => FlexModal(
        title: Text('Entwürfe · ${pupil.name}'),
        onClose: () => Navigator.pop(ctx),
        scrollable: false,
        content: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .65,
          child: _drafts(pupilId: pupil.id),
        ),
      ),
    ),
  );

  Future<void> _openPupil(Pupil pupil, {FlexSymbol? symbol}) async {
    try {
      await showFlexDetail<void>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (modalContext, refresh) {
            _refreshPupilDialog = () {
              if (modalContext.mounted) refresh(() {});
            };
            return AnimatedBuilder(
              animation: c,
              builder: (_, _) {
                final current =
                    c.pupils.where((p) => p.id == pupil.id).firstOrNull ??
                    pupil;
                return PupilWorkspaceDialog(
                  controller: c,
                  pupil: current,
                  initialArea: symbol,
                  entryCard: _entryCard,
                  editPupil: () => _pupilEditor(current),
                  newOrga: () => _editor(OrgaEntry.empty(pupilId: current.id)),
                  newAppointment: () => _editor(
                    OrgaEntry.empty(
                      pupilId: current.id,
                    ).copyWith(appointmentDate: dateOnly(DateTime.now())),
                  ),
                  showDrafts: () => _pupilDrafts(current),
                  draftCount:
                      FlexSymbol.values.fold(
                        0,
                        (sum, s) => sum + _pupilDraftCount(current.id, s),
                      ) +
                      c.dialogDrafts
                          .where(
                            (d) => d.type == 'pupil' && d.ownerId == current.id,
                          )
                          .length,
                );
              },
            );
          },
        ),
      );
    } finally {
      _refreshPupilDialog = null;
    }
  }

  Widget _overview() {
    final today = dateOnly(DateTime.now());
    final prepared = resolveMaterials(
      c.classroom,
      preparationFor(c.classroom, today).strings('materialIds'),
    );
    final records = c.records.where((r) => !r.deleted).toList();
    final pendingRecords = records.where((r) => r.pending).toList();
    final pendingOrga = c.upcoming(c.entries);
    final completeRecords = records
        .where((r) => !r.pending && r.needsCompletion)
        .toList();
    final completeOrga = c.entries
        .where((e) => !e.pending && e.needsCompletion)
        .toList();
    final recentRecords = records
        .where((r) => !r.pending && !r.needsCompletion)
        .toList();
    final recentOrga = c.entries
        .where((e) => !e.pending && !e.needsCompletion)
        .toList();
    final counts = {
      'pending': pendingRecords.length + pendingOrga.length,
      'complete': completeRecords.length + completeOrga.length,
      'recent': recentRecords.length + recentOrga.length,
    };
    final selected =
        _overviewSection ??
        (counts['pending']! > 0
            ? 'pending'
            : counts['complete']! > 0
            ? 'complete'
            : 'recent');
    final width = MediaQuery.sizeOf(context).width;
    return ListView(
      key: const PageStorageKey('overview'),
      padding: EdgeInsets.fromLTRB(
        width > 960
            ? (width.clamp(0, 1400) - 920) / 2
            : width <= 360
            ? 12
            : 24,
        14,
        width > 960
            ? (width.clamp(0, 1400) - 920) / 2
            : width <= 360
            ? 12
            : 24,
        32,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Überblick',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontFamily: 'FlexSans'),
              ),
            ),
            IconButton(
              tooltip: 'Klassen-Orga anlegen',
              style: IconButton.styleFrom(backgroundColor: Colors.transparent),
              onPressed: () => _editor(OrgaEntry.empty()),
              icon: const Icon(Icons.post_add),
            ),
            IconButton(
              key: const ValueKey('overview-add-appointment'),
              tooltip: 'Termin anlegen',
              style: IconButton.styleFrom(backgroundColor: Colors.transparent),
              onPressed: () =>
                  _editor(OrgaEntry.empty().copyWith(appointmentDate: today)),
              icon: const Icon(Icons.event_available_outlined),
            ),
            IconButton(
              tooltip: 'Rückläufe',
              style: IconButton.styleFrom(backgroundColor: Colors.transparent),
              onPressed: () => showReturnLists(context, c),
              icon: const Icon(Icons.fact_check_outlined),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(displayDate(today), style: Theme.of(context).textTheme.bodySmall),
        if (prepared.isNotEmpty ||
            suggestedMaterials(c.classroom, today).isNotEmpty)
          PreparedMaterialsTile(controller: c, date: today),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final section in const [
              ('pending', 'Anstehend', Icons.schedule_outlined),
              ('complete', 'Ergänzen', Icons.edit_note_outlined),
              ('recent', 'Zuletzt', Icons.history),
            ])
              Semantics(
                selected: selected == section.$1,
                button: true,
                child: Material(
                  color: selected == section.$1
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .15)
                      : Colors.transparent,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: selected == section.$1
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: InkWell(
                    key: ValueKey('overview-section-${section.$1}'),
                    customBorder: const StadiumBorder(),
                    onTap: () => setState(() => _overviewSection = section.$1),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              section.$2,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${counts[section.$1]}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (c.draftCount > 0)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('overview-drafts'),
              onPressed: () => _auxDialog('drafts'),
              icon: const Icon(Icons.edit_note, size: 18),
              label: Text(
                '${c.draftCount} ${c.draftCount == 1 ? 'Entwurf' : 'Entwürfe'}',
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (selected == 'pending')
          _combinedSection(
            'Anstehend',
            pendingOrga,
            pendingRecords,
            'Gerade stehen keine Aufgaben, Hausübungen, Ziele oder Termine an.',
            upcoming: true,
          )
        else if (selected == 'complete')
          _combinedSection(
            'Noch ergänzen',
            completeOrga,
            completeRecords,
            'Alle Einträge sind ergänzt.',
          )
        else
          _combinedSection(
            'Zuletzt dokumentiert',
            recentOrga,
            recentRecords,
            'Noch keine weiteren Einträge.',
          ),
      ],
    );
  }

  Future<void> _overviewDetails({SchoolRecord? record, OrgaEntry? entry}) =>
      showFlexDetail<void>(
        context: context,
        builder: (ctx) => AnimatedBuilder(
          animation: c,
          builder: (_, _) {
            final school = record == null
                ? null
                : c.records
                      .where((r) => r.id == record.id && !r.deleted)
                      .firstOrNull;
            final orga = entry == null
                ? null
                : c.entries.where((e) => e.id == entry.id).firstOrNull;
            return FlexModal(
              title: Text(school?.kind.label ?? 'Orga'),
              onClose: () => Navigator.pop(ctx),
              content: school != null
                  ? SchoolRecordCard(
                      key: ValueKey(school.id),
                      controller: c,
                      record: school,
                      standalone: true,
                    )
                  : orga != null
                  ? _entryCard(orga)
                  : const Text('Dieser Eintrag wurde entfernt.'),
            );
          },
        ),
      );

  Widget _combinedSection(
    String title,
    List<OrgaEntry> orga,
    List<SchoolRecord> records,
    String empty, {
    bool upcoming = false,
  }) {
    final items = <OverviewEntry>[
      for (final e in orga)
        OverviewEntry(
          id: e.id,
          title: e.title,
          meta:
              '${c.owner(e)} · ${e.isAppointment
                  ? 'Termin'
                  : e.isTask
                  ? 'Aufgabe'
                  : 'Notiz'}',
          summary: e.body.trim() == e.title.trim() ? '' : e.body,
          status: [
            if (e.isAppointment)
              '${displayDate(e.appointmentDate)} · ${e.appointmentTime.isEmpty ? 'Ganztägig' : e.appointmentTime}',
            if (e.items.isNotEmpty)
              '${e.items.where((i) => i.checked).length} von ${e.items.length} Listenpunkten erledigt',
            if (e.isTask) e.done ? 'Erledigt' : 'Offen',
            if (e.dueDate != null) 'Fällig ${displayDate(e.dueDate)}',
            if (e.reminderState == ReminderState.planned)
              'Erinnerung ${displayReminder(e)}',
            if (e.needsCompletion) 'Noch ergänzen',
          ].join(' · '),
          order: upcoming
              ? ([
                      if (e.appointmentDate != null)
                        '${e.appointmentDate} ${e.appointmentTime}',
                      if (e.dueDate != null) e.dueDate!,
                      if (e.reminderState == ReminderState.planned)
                        e.reminderAtUtc!,
                    ].toList()..sort()).firstOrNull ??
                    '9999'
              : '${e.observedOn} ${e.observedTime}',
          symbol: FlexSymbol.orga,
          onOpen: () => _overviewDetails(entry: e),
          onEdit: () => _editor(e),
        ),
      for (final r in records)
        OverviewEntry(
          id: r.id,
          title: r.kind == SchoolKind.homework
              ? (r.subject.isEmpty ? 'Hausübung' : 'Hausübung · ${r.subject}')
              : r.title.isNotEmpty
              ? r.title
              : r.kind.label,
          meta:
              '${c.pupils.where((p) => p.id == r.pupilId).firstOrNull?.name ?? 'Schüler'} · ${displayDate(r.observedOn)}',
          summary: r.kind == SchoolKind.homework
              ? r.tasks.map((t) => t.text).join(' · ')
              : [
                  r.body,
                  ...r.positive.map((v) => '+ $v'),
                  ...r.neutral.map((v) => '• $v'),
                  ...r.negative.map((v) => '− $v'),
                ].where((v) => v.isNotEmpty).join(' · '),
          status: [
            if (r.kind == SchoolKind.homework)
              '${r.tasks.where((t) => r.taskState(t) == TaskState.complete).length} von ${r.tasks.length} Aufgaben vollständig',
            if (r.kind == SchoolKind.goal)
              r.goalStatus == 'active'
                  ? 'In Arbeit'
                  : r.goalStatus == 'achieved'
                  ? 'Ziel erreicht'
                  : 'Beendet',
            if (r.dueDate != null) 'Termin ${displayDate(r.dueDate)}',
            if (r.kind == SchoolKind.goal && r.nextReviewDate != null)
              'Überprüfen ${displayDate(r.nextReviewDate)}',
            if (r.needsCompletion) 'Noch ergänzen',
          ].join(' · '),
          order: upcoming
              ? (r.kind == SchoolKind.goal
                        ? r.nextReviewDate ?? r.dueDate
                        : r.dueDate) ??
                    '9999'
              : '${r.observedOn} ${r.observedTime}',
          symbol: FlexSymbol.values.byName(r.kind.name),
          onOpen: () => _overviewDetails(record: r),
          onEdit: () => editSchool(context, c, r),
        ),
    ]..sort((a, b) => upcoming ? a.order.compareTo(b.order) : b.order.compareTo(a.order));
    if (upcoming && items.isNotEmpty) {
      final today = dateOnly(DateTime.now());
      String group(OverviewEntry item) {
        final day = item.order.length >= 10
            ? item.order.substring(0, 10)
            : item.order;
        return day.compareTo(today) < 0
            ? 'Überfällig'
            : day == today
            ? 'Heute'
            : 'Danach';
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final label in ['Überfällig', 'Heute', 'Danach'])
            if (items.any((item) => group(item) == label)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 6),
                child: Text(
                  '$label · ${items.where((item) => group(item) == label).length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: label == 'Überfällig'
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              ),
              ...items.where((item) => group(item) == label),
            ],
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${items.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(empty),
            ),
          ...items.take(
            _expandedSections.contains('overview-$title') ? items.length : 5,
          ),
          if (items.length > 5)
            TextButton(
              key: const ValueKey('overview-show-more'),
              onPressed: () => setState(() {
                final key = 'overview-$title';
                if (!_expandedSections.remove(key)) _expandedSections.add(key);
              }),
              child: Text(
                _expandedSections.contains('overview-$title')
                    ? 'Weniger anzeigen'
                    : 'Alle ${items.length} anzeigen',
              ),
            ),
        ],
      ),
    );
  }

  Widget _pupils({bool archived = false}) {
    final all = c.pupils.where((p) => p.archived == archived).toList();
    final pupils = all
        .where((p) => p.name.toLowerCase().contains(_pupilQuery.toLowerCase()))
        .toList();
    final width = MediaQuery.sizeOf(context).width;
    final gutter = width <= 360
        ? 12.0
        : width <= 700
        ? 16.0
        : 40.0;
    return ListView(
      key: PageStorageKey('pupils-$archived'),
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 40),
      children: [
        CollapsibleSearch(
          controller: _pupilSearch,
          fieldKey: ValueKey('search-$archived'),
          buttonKey: const ValueKey('toggle-pupil-search'),
          label: 'Schüler suchen',
          iconOnly: true,
          leading: Text(
            archived ? 'Archiv' : 'Notizen',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          actions: [
            if (!archived)
              FlexCircleButton(
                tooltip: 'Neuer Schüler',
                onPressed: () => _pupilEditor(),
                icon: const Icon(Icons.person_add_alt_1_outlined),
              ),
          ],
          onChanged: (value) => _changeView(() => _pupilQuery = value),
        ),
        const SizedBox(height: 10),
        if (pupils.isEmpty)
          EmptyState(
            archived
                ? 'Keine passenden archivierten Schüler.'
                : 'Noch keine passenden Schüler.',
            icon: Icons.people,
          ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                for (final pupil in pupils)
                  PupilCard(
                    key: ValueKey('pupil-card-${pupil.id}'),
                    pupil: pupil,
                    onOpen: () => _openPupil(pupil),
                    onShortcut: (symbol) => _entryShortcut(pupil, symbol),
                    counts: _shortcutCounts(pupil),
                    draftCounts: {
                      for (final symbol in FlexSymbol.values)
                        symbol: _pupilDraftCount(pupil.id, symbol),
                    },
                    due: _dueShortcuts(pupil),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _entryShortcut(Pupil pupil, FlexSymbol symbol) async {
    if (pupil.archived) {
      await _openPupil(pupil, symbol: symbol);
      return;
    }
    if (symbol == FlexSymbol.orga) {
      await _editor(OrgaEntry.empty(pupilId: pupil.id));
      return;
    }
    final kind = switch (symbol) {
      FlexSymbol.goal => SchoolKind.goal,
      FlexSymbol.social => SchoolKind.social,
      FlexSymbol.work => SchoolKind.work,
      _ => SchoolKind.homework,
    };
    await editSchool(context, c, SchoolRecord.empty(kind, pupil.id));
  }

  int _pupilDraftCount(String pupilId, FlexSymbol symbol) =>
      c.schoolDrafts
          .where(
            (d) =>
                d.record.kind.name == symbol.name &&
                (d.record.pupilId == pupilId || d.recipients.contains(pupilId)),
          )
          .length +
      (symbol == FlexSymbol.orga
          ? c.drafts.where((d) => d.entry.pupilId == pupilId).length
          : 0) +
      c.dialogDrafts
          .where(
            (d) =>
                d.type == 'bulk' &&
                d.data['kind'] == symbol.name &&
                (d.data['recipients'] as List).contains(pupilId),
          )
          .length;

  Map<FlexSymbol, int> _shortcutCounts(Pupil pupil) {
    final records = c.records.where((r) => r.pupilId == pupil.id && !r.deleted);
    return {
      FlexSymbol.goal: records
          .where((r) => r.kind == SchoolKind.goal && r.pending)
          .length,
      FlexSymbol.social: records
          .where((r) => r.kind == SchoolKind.social && r.needsCompletion)
          .length,
      FlexSymbol.work: records
          .where((r) => r.kind == SchoolKind.work && r.needsCompletion)
          .length,
      FlexSymbol.homework: records
          .where((r) => r.kind == SchoolKind.homework && r.pending)
          .length,
      FlexSymbol.orga: c.entries
          .where((e) => e.pupilId == pupil.id && e.isTask && !e.done)
          .length,
    };
  }

  Set<FlexSymbol> _dueShortcuts(Pupil pupil) {
    final today = dateOnly(DateTime.now());
    return {
      if (c.records.any(
        (r) =>
            r.pupilId == pupil.id &&
            !r.deleted &&
            r.kind == SchoolKind.homework &&
            r.pending &&
            r.dueDate != null &&
            r.dueDate!.compareTo(today) <= 0,
      ))
        FlexSymbol.homework,
      if (c.entries.any(
        (e) =>
            e.pupilId == pupil.id &&
            e.isTask &&
            !e.done &&
            e.dueDate != null &&
            e.dueDate!.compareTo(today) <= 0,
      ))
        FlexSymbol.orga,
    };
  }

  Widget _entries(
    List<OrgaEntry> entries, {
    required String scope,
    required bool orga,
    required Pupil? pupil,
  }) {
    final visible = entries
        .where(
          (e) =>
              '${e.title} ${e.body} ${e.items.map((i) => i.text).join(' ')}'
                  .toLowerCase()
                  .contains(_entryQuery.toLowerCase()) &&
              (_filter == 'all' ||
                  (_filter == 'appointments'
                      ? e.isAppointment
                      : (e.isTask && e.done == (_filter == 'done')))),
        )
        .toList();
    return ListView(
      key: PageStorageKey('entries-$scope-$orga'),
      padding: EdgeInsets.all(pupil == null ? 24 : 0),
      children: [
        if (pupil == null)
          Text('Klassen-Orga', style: Theme.of(context).textTheme.titleLarge),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => scanAndShow(
              context,
              c,
              const ScanContext(title: 'Klassen-Orga', category: 'form'),
            ),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Scannen'),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _editor(OrgaEntry.empty(pupilId: pupil?.id)),
              icon: const Icon(Icons.add),
              label: const Text('Orga anlegen'),
            ),
            TextButton.icon(
              key: const ValueKey('orga-add-appointment'),
              onPressed: () => _editor(
                OrgaEntry.empty(
                  pupilId: pupil?.id,
                ).copyWith(appointmentDate: dateOnly(DateTime.now())),
              ),
              icon: const Icon(Icons.event_outlined),
              label: const Text('Termin anlegen'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        CollapsibleSearch(
          controller: _entrySearch,
          fieldKey: ValueKey('entry-query-$scope'),
          buttonKey: ValueKey('entry-search-$scope'),
          label: 'Einträge durchsuchen',
          onChanged: (value) => _changeView(() => _entryQuery = value),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final f in {
              'all': 'Alle',
              'appointments': 'Termine',
              'open': 'Offene Aufgaben',
              'done': 'Erledigte Aufgaben',
            }.entries)
              transparentChip(
                FilterChip(
                  label: Text(f.value),
                  selected: _filter == f.key,
                  onSelected: (_) => _changeView(() => _filter = f.key),
                ),
              ),
          ],
        ),
        if (pupil != null && !orga)
          for (final r in c.records.where(
            (r) =>
                r.pupilId == pupil.id &&
                !r.deleted &&
                r.searchText.toLowerCase().contains(_entryQuery.toLowerCase()),
          ))
            SchoolRecordCard(controller: c, record: r),
        if (orga || _entryQuery.isNotEmpty || _filter != 'all')
          _section(
            '$scope-list',
            'Orga',
            visible,
            empty: 'Keine passenden Orga-Einträge.',
          )
        else ...[
          _section(
            '$scope-pending',
            'Anstehend',
            c.upcoming(visible),
            empty: 'Keine offenen Aufgaben oder Erinnerungen.',
          ),
          _section(
            '$scope-docs',
            'Noch ergänzen',
            visible.where((e) => e.needsCompletion && !e.pending).toList(),
            empty: 'Keine Dokumentation nachzutragen.',
          ),
          _section(
            '$scope-recent',
            'Zuletzt',
            visible.where((e) => !e.pending && !e.needsCompletion).toList(),
            empty: 'Noch keine abgeschlossenen Vorgänge oder Notizen.',
          ),
        ],
      ],
    );
  }

  Widget _section(
    String key,
    String title,
    List<OrgaEntry> entries, {
    required String empty,
  }) {
    final expanded = _expandedSections.contains(key);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$title · ${entries.length}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(empty),
            ),
          ...entries.take(expanded ? entries.length : 4).map(_entryCard),
          if (entries.length > 4)
            TextButton(
              onPressed: () => _changeView(() {
                if (expanded) {
                  _expandedSections.remove(key);
                } else {
                  _expandedSections.add(key);
                }
              }),
              child: Text(
                expanded
                    ? 'Weniger anzeigen'
                    : '${entries.length - 4} weitere anzeigen',
              ),
            ),
        ],
      ),
    );
  }

  Widget _entryCard(OrgaEntry e) {
    final busy = _busyIds.contains(e.id);
    return FlexCard(
      builder: (context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (ctx, constraints) {
                final leading = e.isTask
                    ? IconButton(
                        tooltip: e.done ? 'Wieder öffnen' : 'Erledigen',
                        onPressed: busy
                            ? null
                            : () => _mutate(e.done ? e.reopen() : e.complete()),
                        icon: Icon(
                          e.done
                              ? Icons.task_alt
                              : Icons.check_box_outline_blank,
                        ),
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : Icon(
                        e.isAppointment ? Icons.event_outlined : Icons.notes,
                        color: Theme.of(context).colorScheme.primary,
                      );
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${c.owner(e)} · ${e.isAppointment
                          ? 'Termin'
                          : e.isTask
                          ? (e.done ? 'Aufgabe erledigt' : 'Aufgabe offen')
                          : 'Notiz'}',
                    ),
                  ],
                );
                final edit = IconButton(
                  tooltip: 'Bearbeiten',
                  onPressed: () => _editor(e),
                  icon: const Icon(Icons.edit),
                );
                if (constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(ctx).scale(14) > 21) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [leading, const Spacer(), edit]),
                      heading,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leading,
                    const SizedBox(width: 8),
                    Expanded(child: heading),
                    edit,
                  ],
                );
              },
            ),
            if (e.body.trim().isNotEmpty && e.body.trim() != e.title.trim())
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  e.body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            for (final item in e.items.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item.checked
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.text)),
                  ],
                ),
              ),
            if (e.items.isNotEmpty)
              Text(
                '${e.items.where((i) => i.checked).length} / ${e.items.length} Listenpunkte',
              ),
            if (e.isAppointment)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '${displayDate(e.appointmentDate)} · ${e.appointmentTime.isEmpty ? 'Ganztägig' : e.appointmentTime}',
                ),
              ),
            if (e.dueDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Fällig: ${displayDate(e.dueDate)}${!e.done && e.dueDate!.compareTo(dateOnly(DateTime.now())) < 0 ? ' · überfällig' : ''}',
                ),
              ),
            if (e.reminderAtUtc != null)
              Text(
                'Erinnerung: ${displayReminder(e)} · ${switch (e.reminderState) {
                  ReminderState.planned => 'aktiv',
                  ReminderState.acknowledged => 'quittiert',
                  ReminderState.cancelled => 'beendet',
                  ReminderState.none => '',
                }}',
              ),
            if (e.needsCompletion)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Dokumentation noch ergänzen'),
              ),
            DocumentAttachmentSection(
              controller: c,
              scope: orgaScanContext(c, e),
              readOnly: e.deleted,
              compact: true,
              actions: [
                if ((e.isTask || e.isAppointment) && !e.done)
                  IconButton(
                    tooltip: 'Wiederholung',
                    onPressed: busy
                        ? null
                        : () => showOrgaRepeat(context, c, e),
                    icon: const Icon(Icons.repeat),
                  ),
                if (e.pending)
                  IconButton(
                    tooltip: 'Erinnerung verschieben',
                    onPressed: busy
                        ? null
                        : () => showReminderActions(
                            context,
                            c,
                            'orga:${e.id}',
                            e.title,
                          ),
                    icon: const Icon(Icons.snooze),
                  ),
                if (e.reminderState == ReminderState.planned)
                  IconButton(
                    tooltip: 'Erinnerung quittieren',
                    onPressed: busy ? null : () => _mutate(e.acknowledge()),
                    icon: const Icon(Icons.notifications_off_outlined),
                  ),
                IconButton(
                  tooltip: 'Papierkorb',
                  onPressed: busy
                      ? null
                      : () async {
                          if (await confirmFlex(
                            context,
                            'Orga in den Papierkorb?',
                            'Geplante Erinnerungen werden beendet. Der Eintrag bleibt wiederherstellbar.',
                            accept: 'In den Papierkorb',
                          )) {
                            await _mutate(
                              e.copyWith(
                                deleted: true,
                                reminderState:
                                    e.reminderState == ReminderState.planned
                                    ? ReminderState.cancelled
                                    : e.reminderState,
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
                IconButton(
                  tooltip: 'Änderungen',
                  onPressed: () => _history(e),
                  icon: const Icon(Icons.history),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _history(OrgaEntry entry) => showJournal(context, c, entry.id);

  Widget _drafts({String? pupilId, FlexSymbol? symbol}) {
    String pupilName(String? id) => id == null
        ? 'Klasse'
        : c.pupils.where((p) => p.id == id).firstOrNull?.name ??
              'Unbekannte Zuordnung';
    final rows =
        <
            ({
              String id,
              String title,
              String preview,
              String time,
              VoidCallback open,
              Future<void> Function() discard,
            })
          >[
            for (final d in c.dialogDrafts.where(
              (d) =>
                  pupilId == null ||
                  (d.type == 'scan' &&
                      (d.data['pupilIds'] as List).contains(pupilId)) ||
                  (d.type == 'pupil' &&
                      symbol == null &&
                      d.ownerId == pupilId) ||
                  d.type == 'bulk' &&
                      (symbol == null || d.data['kind'] == symbol.name) &&
                      (d.data['recipients'] as List).contains(pupilId),
            ))
              (
                id: 'dialog-${d.id}',
                title: d.type == 'scan'
                    ? 'Scan · ${d.data['title']}'
                    : d.type == 'pupil'
                    ? 'Schüler · ${d.data['name']}'
                    : d.type == 'classroom'
                    ? 'FLEX-Klasse · ${d.data['title'] ?? 'Entwurf'}'
                    : d.type == 'context'
                    ? 'Gemeinsame Situation'
                    : d.type == 'catalog'
                    ? '${d.ownerId == 'social' ? 'Sozialverhalten' : 'Arbeitsverhalten'} · Auswahl'
                    : 'Gemeinsam · ${const {'social': 'Sozialverhalten', 'work': 'Arbeitsverhalten', 'homework': 'Hausübung', 'orga': 'Orga'}[d.data['kind']]} · ${(d.data['recipients'] as List? ?? []).map((id) => pupilName(id as String)).join(', ')}',
                preview:
                    '${d.data['text'] ?? d.data['context'] ?? d.data['body'] ?? ''}',
                time: d.updatedAtUtc,
                open: () {
                  if (d.type == 'scan') {
                    scanAndShow(context, c, const ScanContext(), draft: d);
                  } else if (d.type == 'classroom' &&
                      (d.data['kind'] == 'timetable' ||
                          d.data['_timetableEditor'] == true)) {
                    guarded(context, () => resumeTimetableDraft(context, c, d));
                  } else if (d.type == 'classroom') {
                    showClassroomEditor(
                      context,
                      c,
                      ClassroomKind.values.byName(d.data['kind'] as String),
                      draft: d,
                    );
                  } else if (d.type == 'pupil') {
                    _pupilEditor(null, d);
                  } else if (d.type == 'catalog') {
                    showCatalog(context, c, d.ownerId, draft: d);
                  } else if (d.type == 'context') {
                    showSituation(context, c, d.ownerId, draft: d);
                  } else {
                    showBulk(context, c, draft: d);
                  }
                },
                discard: () => d.type == 'scan'
                    ? discardScan(c.repository, const LocalMaterialFiles(), d)
                    : c.repository.discardDialogDraft(d.id, d.revision),
              ),
            for (final d in c.schoolDrafts.where(
              (d) =>
                  pupilId == null ||
                  (symbol == null || d.record.kind.name == symbol.name) &&
                      (d.record.pupilId == pupilId ||
                          d.recipients.contains(pupilId)),
            ))
              (
                id: 'school-${d.id}',
                title:
                    '${pupilName(d.record.pupilId)} · ${d.record.kind.label}${d.mode == 'comment'
                        ? ' · Kommentar'
                        : d.mode == 'review'
                        ? ' · Überprüfung'
                        : ''}',
                preview: d.mode == 'comment'
                    ? d.record.feedback
                              .where((f) => f.id == d.feedbackId)
                              .firstOrNull
                              ?.note ??
                          ''
                    : d.mode == 'review'
                    ? d.record.reviews
                              .where((r) => r.id == d.feedbackId)
                              .firstOrNull
                              ?.note ??
                          d.record.title
                    : [
                        d.record.title,
                        d.record.subject,
                        d.record.body,
                        ...d.record.positive,
                        ...d.record.neutral,
                        ...d.record.negative,
                        ...d.record.tasks.map((t) => t.text),
                      ].where((v) => v.isNotEmpty).join(' · '),
                time: d.updatedAtUtc,
                open: () => editSchool(context, c, d.record, draft: d),
                discard: () => c.repository.discardSchoolDraft(
                  d.id,
                  expectedRevision: d.editRevision,
                ),
              ),
            for (final d in c.drafts.where(
              (d) =>
                  pupilId == null ||
                  (symbol == null || symbol == FlexSymbol.orga) &&
                      d.entry.pupilId == pupilId,
            ))
              (
                id: 'orga-${d.id}',
                title: '${pupilName(d.entry.pupilId)} · Orga',
                preview: d.entry.body.isEmpty ? d.entry.title : d.entry.body,
                time: d.updatedAtUtc,
                open: () => _editor(d.entry, draftId: d.id),
                discard: () => c.repository.discardDraft(
                  d.id,
                  expectedRevision: d.editRevision,
                ),
              ),
          ]
          ..sort((a, b) => b.time.compareTo(a.time));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (rows.isEmpty) const EmptyState('Keine gesicherten Entwürfe.'),
        for (final row in rows)
          FlexCard(
            key: ValueKey('draft-row-${row.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (row.id.startsWith('dialog-'))
                        for (final draft in c.dialogDrafts.where(
                          (d) => 'dialog-${d.id}' == row.id && d.type == 'scan',
                        )) ...[
                          ScanDraftThumbnail(draft: draft),
                          const SizedBox(width: 12),
                        ],
                      Expanded(
                        child: Text(
                          row.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (row.preview.isNotEmpty)
                    Text(
                      row.preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    displayDate(row.time),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: row.open,
                        child: const Text('Fortsetzen'),
                      ),
                      DraftDeleteButton(
                        onDelete: () async {
                          await row.discard();
                          await c.reload();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (rows.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Entwürfe sind noch keine veröffentlichten Einträge. Sie bleiben nach einem Neustart verfügbar.',
            ),
          ),
      ],
    );
  }
}
