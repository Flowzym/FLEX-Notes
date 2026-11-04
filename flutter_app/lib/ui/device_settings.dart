import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../services/automatic_backup.dart';
import 'backup_dialog.dart';
import 'common.dart';
import 'compact_switch.dart';
import 'flex_modal.dart';
import 'surfaces.dart';

class DeviceSettings extends StatelessWidget {
  const DeviceSettings({
    super.key,
    required this.controller,
    required this.backups,
  });
  final NotebookController controller;
  final bool backups;
  @override
  Widget build(BuildContext context) {
    final services = controller.services!;
    final backup = services.backup,
        lock = services.lock,
        reminders = services.reminders;
    return AnimatedBuilder(
      animation: Listenable.merge([backup, lock, reminders]),
      builder: (context, _) => Column(
        children: [
          if (backups)
            _card(context, 'Automatische Sicherungen', [
              Text(
                backup.enabled
                    ? 'Aktiv · ${backup.intervalHours == 24 ? 'täglich' : 'wöchentlich'} · ${backup.keep} Sicherungen'
                    : 'Ausgeschaltet',
              ),
              if (backup.folderName.isNotEmpty)
                Text('Ordner: ${backup.folderName}'),
              Text(
                'Letzte erfolgreiche Sicherung: ${backup.lastSuccess == null ? 'noch keine' : _stamp(backup.lastSuccess!)}',
              ),
              if (backup.lastFailure != null || backup.error != null)
                Text(backup.error ?? backup.lastFailure!),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: backup.busy
                        ? null
                        : () => _configureBackup(context, backup),
                    icon: const Icon(Icons.folder_outlined),
                    label: Text(
                      backup.enabled ? 'Einrichtung ändern' : 'Einrichten',
                    ),
                  ),
                  if (backup.enabled) ...[
                    OutlinedButton(
                      onPressed: backup.busy
                          ? null
                          : () =>
                                guarded(context, () => backup.run(force: true)),
                      child: Text(backup.busy ? 'Sichert …' : 'Jetzt sichern'),
                    ),
                    TextButton(
                      onPressed: backup.busy
                          ? null
                          : () => guarded(context, backup.disable),
                      child: const Text('Ausschalten'),
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: () =>
                        guarded(context, () => _restore(context, controller)),
                    icon: const Icon(Icons.restore),
                    label: const Text('Sicherungen öffnen'),
                  ),
                ],
              ),
            ])
          else ...[
            _card(context, 'Android-Erinnerungen', [
              CompactSwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Benachrichtigungen'),
                value: reminders.enabled,
                onChanged: (value) => guarded(
                  context,
                  () => reminders.configure({'enabled': value}),
                ),
              ),
              for (final option in const {
                'appointments': 'Termine',
                'tasks': 'Aufgaben und Hausübungen',
                'goals': 'Zielüberprüfungen',
              }.entries)
                CompactSwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(option.value),
                  value: reminders.settings[option.key] != false,
                  onChanged: (value) => guarded(
                    context,
                    () => reminders.configure({option.key: value}),
                  ),
                ),
              TextButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text(
                  'Ohne Uhrzeit: ${(reminders.settings['hour'] ?? 9).toString().padLeft(2, '0')}:${(reminders.settings['minute'] ?? 0).toString().padLeft(2, '0')}',
                ),
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: reminders.settings['hour'] as int? ?? 9,
                      minute: reminders.settings['minute'] as int? ?? 0,
                    ),
                  );
                  if (time != null && context.mounted) {
                    await guarded(
                      context,
                      () => reminders.configure({
                        'hour': time.hour,
                        'minute': time.minute,
                      }),
                    );
                  }
                },
              ),
              Text(
                '${reminders.count} Erinnerungen geplant · ${reminders.exact ? 'zeitgenau' : 'Android bestimmt den Zustellzeitpunkt'}',
              ),
              if (!reminders.exact)
                TextButton(
                  onPressed: () => guarded(context, reminders.requestExact),
                  child: const Text('Zeitgenaue Erinnerungen erlauben'),
                ),
              if (reminders.error != null) Text(reminders.error!),
            ]),
            _card(context, 'App-Sperre', [
              Text(
                lock.enabled
                    ? 'PIN aktiv${lock.biometrics ? ' · Biometrie aktiv' : ''}'
                    : 'Ausgeschaltet',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _configureLock(context, controller),
                    icon: const Icon(Icons.lock_outline),
                    label: Text(
                      lock.enabled ? 'PIN / Biometrie ändern' : 'Einrichten',
                    ),
                  ),
                  if (lock.enabled) ...[
                    TextButton(
                      onPressed: lock.lock,
                      child: const Text('Jetzt sperren'),
                    ),
                    TextButton(
                      onPressed: () =>
                          _configureLock(context, controller, disable: true),
                      child: const Text('Ausschalten'),
                    ),
                  ],
                ],
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

Widget _card(BuildContext context, String title, List<Widget> children) =>
    FlexCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
String _stamp(DateTime time) {
  final t = time.toLocal();
  return '${displayDate(dateOnly(t))} · ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

Future<void> _configureBackup(
  BuildContext context,
  AutomaticBackup backup,
) async {
  final password = TextEditingController(), repeat = TextEditingController();
  Map<String, dynamic>? folder;
  var hours = backup.intervalHours, retention = backup.keep, busy = false;
  String? error;
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => PopScope(
          canPop: !busy,
          child: FlexModal(
            title: const Text('Verschlüsselte Sicherungen'),
            onClose: busy ? null : () => Navigator.pop(ctx),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: Text(
                    folder?['name'] as String? ?? 'Sicherungsordner wählen',
                  ),
                  onPressed: busy
                      ? null
                      : () async {
                          await guarded(ctx, () async {
                            final chosen = await backup.files.chooseDirectory();
                            if (ctx.mounted && chosen != null) {
                              update(() => folder = chosen);
                            }
                          });
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Sicherungspasswort · mindestens 12 Zeichen',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: repeat,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Passwort wiederholen',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Passwort sicher aufbewahren: Es wird nach einem Gerätewechsel zur Wiederherstellung benötigt. Android kann Sicherungen im Energiesparmodus verzögern.',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final h in [24, 168])
                      ChoiceChip(
                        label: Text(h == 24 ? 'Täglich' : 'Wöchentlich'),
                        selected: h == hours,
                        onSelected: busy
                            ? null
                            : (_) => update(() => hours = h),
                      ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final n in [7, 14, 30])
                      ChoiceChip(
                        label: Text('$n behalten'),
                        selected: retention == n,
                        onSelected: busy
                            ? null
                            : (_) => update(() => retention = n),
                      ),
                  ],
                ),
                if (error != null) Text(error!),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (folder == null) {
                          update(() => error = 'Bitte einen Ordner wählen.');
                          return;
                        }
                        if (password.text != repeat.text) {
                          update(
                            () =>
                                error = 'Die Passwörter stimmen nicht überein.',
                          );
                          return;
                        }
                        update(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          await backup.configure(
                            folder: folder!,
                            password: password.text,
                            hours: hours,
                            retention: retention,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            update(() => error = friendlyError(e));
                          }
                        }
                        if (ctx.mounted) update(() => busy = false);
                      },
                child: Text(busy ? 'Sichert …' : 'Einrichten und sichern'),
              ),
            ],
          ),
        ),
      ),
    );
  } finally {
    password.dispose();
    repeat.dispose();
  }
}

Future<void> _restore(BuildContext context, NotebookController c) async {
  final backup = c.services!.backup;
  final files = await backup.available();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => FlexModal(
      title: const Text('Automatische Sicherungen'),
      onClose: () => Navigator.pop(ctx),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (files.isEmpty)
            const Text(
              'In diesem Ordner liegen noch keine automatischen Sicherungen. Nach einem Gerätewechsel bitte „Sicherung importieren“ verwenden.',
            ),
          for (final file in files)
            ListTile(
              title: Text(file['name'] as String),
              subtitle: Text(
                '${((file['size'] as num? ?? 0) / 1024).round()} KB',
              ),
              trailing: const Icon(Icons.restore),
              onTap: () => guarded(ctx, () async {
                String text;
                try {
                  text = await backup.open(file['uri'] as String);
                } catch (_) {
                  if (!ctx.mounted) return;
                  final password = await backupPassword(ctx, opening: true);
                  if (password == null) return;
                  text = await backup.open(
                    file['uri'] as String,
                    password: password,
                  );
                }
                if (ctx.mounted) await showImportReview(ctx, c, text);
              }),
            ),
        ],
      ),
    ),
  );
}

Future<void> _configureLock(
  BuildContext context,
  NotebookController c, {
  bool disable = false,
}) async {
  final lock = c.services!.lock;
  final current = TextEditingController(),
      pin = TextEditingController(),
      repeat = TextEditingController();
  var biometrics = lock.biometrics, busy = false;
  String? error;
  Widget field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      maxLength: 12,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, counterText: ''),
    ),
  );
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => PopScope(
          canPop: !busy,
          child: FlexModal(
            title: Text(
              disable ? 'App-Sperre ausschalten' : 'App-Sperre einrichten',
            ),
            onClose: busy ? null : () => Navigator.pop(ctx),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (lock.enabled) field(current, 'Bisherige PIN'),
                if (!disable) ...[
                  field(pin, 'Neue PIN · 6 bis 12 Ziffern'),
                  field(repeat, 'PIN wiederholen'),
                  CompactSwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Biometrie zusätzlich erlauben'),
                    value: biometrics,
                    onChanged: busy
                        ? null
                        : (v) => update(() => biometrics = v),
                  ),
                  const Text(
                    'Die App sperrt beim Verlassen. Ohne PIN oder aktivierte Biometrie ist kein Zugriff möglich. Bewahre eine verschlüsselte Sicherung samt Passwort auf. Die App-Sperre verschlüsselt die Datenbank nicht.',
                  ),
                ],
                if (error != null) Text(error!),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!disable && pin.text != repeat.text) {
                          update(
                            () => error = 'Die PINs stimmen nicht überein.',
                          );
                          return;
                        }
                        update(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          if (disable) {
                            await lock.disable(current.text);
                          } else {
                            await lock.configure(
                              pin.text,
                              useBiometrics: biometrics,
                              currentPin: current.text,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            update(() => error = friendlyError(e));
                          }
                        }
                        if (ctx.mounted) update(() => busy = false);
                      },
                child: Text(disable ? 'Ausschalten' : 'Sperre speichern'),
              ),
            ],
          ),
        ),
      ),
    );
  } finally {
    current.dispose();
    pin.dispose();
    repeat.dispose();
  }
}
