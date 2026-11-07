import 'merge_dialog.dart';
import 'device_settings.dart';
import 'observation_tone_colors.dart';
import '../domain/observation_catalog.dart';
import 'option_bar.dart';
import 'maintenance_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'flex_icons.dart';
import 'school_workspace.dart';
import 'surfaces.dart';
import '../application/notebook_controller.dart';
import 'common.dart';
import 'flex_modal.dart';
import 'backup_dialog.dart';
import 'appearance_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.layout,
    this.dataOnly = false,
    this.includeDataTab = true,
  });
  final NotebookController controller;
  final SettingsLayoutState layout;
  final bool dataOnly, includeDataTab;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  bool _busy = false;
  NotebookController get c => widget.controller;
  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await guarded(context, action);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _export() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackupDialog(controller: c, export: true),
    );
  }

  Future<void> _import({required bool legacy}) async {
    if (!legacy) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => BackupDialog(controller: c, export: false),
      );
      return;
    }

    final text = TextEditingController();
    String? message;
    var working = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => FlexModal(
          title: Text(
            legacy
                ? 'HTML-Sicherung vormerken'
                : 'Flutter-Sicherung wiederherstellen',
          ),
          content: SizedBox(
            width: 700,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  legacy
                      ? 'Die originale JSON-Sicherung wird unverändert aufbewahrt. Die Übernahme aller Fachbereiche ist noch offen; hier werden keine Altdaten aktiviert oder überschrieben.'
                      : 'Nur in einem leeren Arbeitsbereich. Bei Fehlern wird die gesamte Übernahme zurückgerollt.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: text,
                  minLines: 6,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Inhalt der JSON-Sicherung',
                  ),
                ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(message!),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: working ? null : () => Navigator.pop(context),
              child: const Text('Schließen'),
            ),
            FilledButton(
              onPressed: working
                  ? null
                  : () async {
                      update(() => working = true);
                      try {
                        if (legacy) {
                          final report = await c.repository.inspectLegacy(
                            text.text,
                          );
                          await c.repository.stageLegacy(text.text);
                          update(
                            () => message =
                                'Unverändert vorgemerkt: ${report.pupils} Schüler, ${report.entries} Einträge, ${report.classTasks} Klassen-Vorgänge, ${report.drafts} Entwürfe. Noch nicht migriert.',
                          );
                        } else {
                          await c.repository.restoreBackup(text.text);
                          update(
                            () => message = 'Vollsicherung wiederhergestellt.',
                          );
                        }
                        await c.reload();
                      } catch (e) {
                        update(() => message = friendlyError(e));
                      }
                      update(() => working = false);
                    },
              child: Text(legacy ? 'Prüfen und vormerken' : 'Wiederherstellen'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    text.dispose();
  }

  final _tabFocus = List.generate(3, (_) => FocusNode());
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) c.flushAppearance();
  }

  @override
  void dispose() {
    c.flushAppearance();
    WidgetsBinding.instance.removeObserver(this);
    for (final node in _tabFocus) {
      node.dispose();
    }
    super.dispose();
  }

  void tab(int value, {bool focus = false}) {
    c.flushAppearance();
    setState(() => widget.layout.tab = value);
    if (focus) _tabFocus[value].requestFocus();
  }

  void move(String name, int delta) {
    final order = [...c.appearance.shortcutOrder];
    final from = order.indexOf(name), to = order.indexOf(name) + delta;
    if (to < 0 || to >= order.length) return;
    order[from] = order[to];
    order[to] = name;
    c.previewAppearance({'shortcutOrder': order});
  }

  Widget interaction() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (c.services != null) DeviceSettings(controller: c, backups: false),
      FlexCard(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Standard für Beobachtungen',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              OptionBar(
                options: observationTones,
                colors: observationToneColors,
                minButtonHeight: 34,
                fontSize: 14,
                value: c.appearance.defaultObservationTone,
                keyPrefix: 'default-tone',
                onChanged: (value) =>
                    c.previewAppearance({'defaultObservationTone': value}),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text('Karten-Shortcuts', style: Theme.of(context).textTheme.titleLarge),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => c.previewAppearance({
            'shortcutOrder': ['goal', 'social', 'work', 'homework', 'orga'],
          }),
          child: const Text('Zurücksetzen'),
        ),
      ),
      const SizedBox(height: 16),
      for (final name in c.appearance.shortcutOrder)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Text('${c.appearance.shortcutOrder.indexOf(name) + 1}'),
              const SizedBox(width: 10),
              FlexIcon(FlexSymbol.values.byName(name)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  const {
                    'goal': 'Ziele',
                    'social': 'Sozialverhalten',
                    'work': 'Arbeitsverhalten',
                    'homework': 'Hausübung',
                    'orga': 'Organisatorisches',
                  }[name]!,
                ),
              ),
              IconButton(
                key: ValueKey('shortcut-up-$name'),
                tooltip: '$name nach vorne',
                onPressed: name == c.appearance.shortcutOrder.first
                    ? null
                    : () => move(name, -1),
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                key: ValueKey('shortcut-down-$name'),
                tooltip: '$name nach hinten',
                onPressed: name == c.appearance.shortcutOrder.last
                    ? null
                    : () => move(name, 1),
                icon: const Icon(Icons.arrow_downward),
              ),
            ],
          ),
        ),
    ],
  );
  Widget data() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (c.services != null) DeviceSettings(controller: c, backups: true),
      FlexCard(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sichern & wiederherstellen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _action(_export),
                    icon: const Icon(Icons.download),
                    label: const Text('Exportieren'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _action(() => _import(legacy: false)),
                    icon: const Icon(Icons.upload),
                    label: const Text('Sicherung importieren'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _action(() => showImportArchives(context, c)),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Importarchiv'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _action(() => _import(legacy: true)),
                    child: const Text('HTML-Sicherung vormerken'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      FlexCard(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Papierkorb', style: Theme.of(context).textTheme.titleLarge),
              Text(
                '${c.trashedEntries.length + c.records.where((r) => r.deleted).length} gelöschte Einträge',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => FlexModal(
                      title: const Text('Papierkorb'),
                      onClose: () => Navigator.pop(ctx),
                      scrollable: false,
                      content: SizedBox(
                        height: MediaQuery.sizeOf(ctx).height * .65,
                        child: SchoolTools(controller: c, mode: 'trash'),
                      ),
                    ),
                  ),
                  child: const Text('Papierkorb öffnen'),
                ),
              ),
            ],
          ),
        ),
      ),
      FlexCard(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            key: const PageStorageKey('settings-maintenance'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Speicherpflege',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => MaintenanceDialog(controller: c),
                  ),
                  child: const Text('Speicherpflege öffnen'),
                ),
              ),
            ],
          ),
        ),
      ),
      if (c.stagedLegacyCount > 0)
        Text('${c.stagedLegacyCount} HTML-Sicherungen vorgemerkt'),
    ],
  );
  int get tabCount => widget.includeDataTab ? 3 : 2;
  Widget tabButton(int i) => Focus(
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      final key = event.logicalKey;
      final next = key == LogicalKeyboardKey.arrowRight
          ? (i + 1) % tabCount
          : key == LogicalKeyboardKey.arrowLeft
          ? (i + tabCount - 1) % tabCount
          : key == LogicalKeyboardKey.home
          ? 0
          : key == LogicalKeyboardKey.end
          ? tabCount - 1
          : null;
      if (next == null) return KeyEventResult.ignored;
      tab(next, focus: true);
      return KeyEventResult.handled;
    },
    child: Semantics(
      selected: widget.layout.tab == i,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: TextButton(
          key: ValueKey('settings-tab-$i'),
          focusNode: _tabFocus[i],
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
            textStyle: const TextStyle(
              fontFamily: 'FlexSans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            backgroundColor: widget.layout.tab == i
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            foregroundColor: widget.layout.tab == i
                ? legibleOn(Theme.of(context).colorScheme.primary)
                : Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => tab(i),
          child: Text(
            ['Darstellung', 'Bedienung', 'Daten'][i],
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
  Widget tabs() => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: LayoutBuilder(
        builder: (context, constraints) => Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).extension<FlexSurfaces>()?.palette?.workspace,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child:
              constraints.maxWidth < 500 &&
                  MediaQuery.textScalerOf(context).scale(1) > 1.5
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (var i = 0; i < tabCount; i++) tabButton(i)],
                )
              : Row(
                  children: [
                    for (var i = 0; i < tabCount; i++)
                      Expanded(child: tabButton(i)),
                  ],
                ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1180),
      child: ListView(
        key: const PageStorageKey('settings'),
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 14 : 24,
        ),
        children: [
          Text(
            widget.dataOnly ? 'Daten' : 'Einstellungen',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 18),
          if (!widget.dataOnly) tabs(),
          const SizedBox(height: 18),
          if (widget.dataOnly)
            data()
          else if (widget.layout.tab == 0)
            AppearanceSettings(controller: c, layout: widget.layout)
          else if (widget.layout.tab == 1)
            interaction()
          else
            data(),
          const Divider(height: 28),
          if (!widget.dataOnly)
            Semantics(
              liveRegion: true,
              child: Text(
                c.appearanceError ??
                    (c.appearanceSaving ? 'Wird gespeichert …' : 'Gespeichert'),
              ),
            ),
        ],
      ),
    ),
  );
}
