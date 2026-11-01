import 'maintenance_dialog.dart';
import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import 'common.dart';
import 'flex_modal.dart';
import 'backup_dialog.dart';
import 'appearance_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});
  final NotebookController controller;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('settings'),
    padding: const EdgeInsets.all(24),
    children: [
      Text('Darstellung', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        children: [
          for (final option in {
            'dark': 'Wald · dunkel',
            'light': 'Papier · hell',
            'system': 'Wie das System',
          }.entries)
            ChoiceChip(
              label: Text(option.value),
              selected: c.appearance.mode == option.key,
              onSelected: _busy
                  ? null
                  : (_) => _action(
                      () => c.saveAppearance(
                        c.appearance.copyWith(mode: option.key),
                      ),
                    ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      const Text('Akzentfarbe'),
      Wrap(
        spacing: 8,
        children: [
          for (final option in {
            0xffdae9a6: 'Linde',
            0xff9dc9d3: 'Blau',
            0xffe2bda0: 'Sand',
            0xffc4ade0: 'Flieder',
          }.entries)
            ChoiceChip(
              label: Text(option.value),
              avatar: Icon(Icons.circle, color: Color(option.key)),
              selected: c.appearance.accent == option.key,
              onSelected: _busy
                  ? null
                  : (_) => _action(
                      () => c.saveAppearance(
                        c.appearance.copyWith(accent: option.key),
                      ),
                    ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      const Text('Schriftgröße'),
      Wrap(
        spacing: 8,
        children: [
          for (final scale in [0.9, 1.0, 1.15, 1.3])
            ChoiceChip(
              label: Text('${(scale * 100).round()} %'),
              selected: c.appearance.textScale == scale,
              onSelected: _busy
                  ? null
                  : (_) => _action(
                      () => c.saveAppearance(
                        c.appearance.copyWith(textScale: scale),
                      ),
                    ),
            ),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Kompakte Abstände'),
        value: c.appearance.compact,
        onChanged: _busy
            ? null
            : (v) => _action(
                () => c.saveAppearance(c.appearance.copyWith(compact: v)),
              ),
      ),
      AppearanceSettings(controller: c),
      const Divider(height: 40),
      Text('Bedienung', style: Theme.of(context).textTheme.titleLarge),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.edit_note),
        title: Text('Entwurfsschutz'),
        subtitle: Text(
          'Orga-Änderungen werden nach kurzer Schreibpause gesichert. Zurück und Escape sichern vor dem Schließen. Erst Speichern übernimmt den Eintrag.',
        ),
      ),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.notifications),
        title: Text('Erinnerungen innerhalb der App'),
        subtitle: Text(
          'Native Benachrichtigungen und Synchronisation folgen später. Erledigen beendet die Erinnerung; Quittieren erledigt die Aufgabe nicht.',
        ),
      ),
      const Divider(height: 40),
      Text('Daten', style: Theme.of(context).textTheme.titleLarge),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Die Daten liegen lokal auf diesem Gerät bzw. im Speicher dieser Webadresse. Die Webvorschau nutzt einen eigenen Datenstand. Regelmäßige Vollsicherungen schützen vor gelöschten Browserdaten oder Geräteverlust.',
        ),
      ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => MaintenanceDialog(controller: c),
            ),
            child: const Text('Speicher pflegen'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _action(_export),
            icon: const Icon(Icons.download),
            label: const Text('Vollsicherung'),
          ),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _action(() => _import(legacy: false)),
            icon: const Icon(Icons.restore),
            label: const Text('Wiederherstellen'),
          ),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _action(() => _import(legacy: true)),
            icon: const Icon(Icons.inventory_2),
            label: const Text('HTML-Sicherung vormerken'),
          ),
        ],
      ),
      if (c.stagedLegacyCount > 0)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            '${c.stagedLegacyCount} unveränderte HTML-Sicherungen für die Migration vorgemerkt. Sie sind in der Flutter-Vollsicherung enthalten.',
          ),
        ),
      const SizedBox(height: 24),
      const Text(
        'Die lokale Datenbank ist noch nicht verschlüsselt. Diese erste Entwicklungsfassung ist für synthetische Testdaten vorgesehen.',
      ),
    ],
  );
}
