import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';
import '../services/incoming_shares.dart';
import 'classroom_editor.dart';
import 'common.dart';
import 'flex_modal.dart';
import 'material_thumbnail.dart';

Future<void> showIncomingShares(
  BuildContext context,
  NotebookController controller,
  IncomingShares incoming,
) async {
  if (incoming.presenting) return;
  incoming.presenting = true;
  try {
    await incoming.refresh();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _IncomingDialog(controller: controller, incoming: incoming),
    );
  } finally {
    incoming.presenting = false;
  }
}

class IncomingFilesButton extends StatelessWidget {
  const IncomingFilesButton({super.key, required this.controller});
  final NotebookController controller;
  @override
  Widget build(BuildContext context) {
    final incoming = controller.services?.incoming;
    if (incoming == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: incoming,
      builder: (context, _) => incoming.items.isEmpty && incoming.error == null
          ? const SizedBox.shrink()
          : Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    showIncomingShares(context, controller, incoming),
                icon: const Icon(Icons.move_to_inbox_outlined),
                label: Text('Geteilte Dateien · ${incoming.items.length}'),
              ),
            ),
    );
  }
}

class _IncomingDialog extends StatefulWidget {
  const _IncomingDialog({required this.controller, required this.incoming});
  final NotebookController controller;
  final IncomingShares incoming;
  @override
  State<_IncomingDialog> createState() => _IncomingDialogState();
}

class _IncomingDialogState extends State<_IncomingDialog> {
  late final items = List<SharedDocument>.of(widget.incoming.items);
  late final selected = items.map((d) => d.id).toSet();
  late final names = {
    for (final d in items) d.id: TextEditingController(text: d.name),
  };
  late final files = widget.incoming.previewFiles;
  List<String> pupils = [], lessons = [];
  String category = 'other';
  String? date, error;
  bool busy = false;
  @override
  void dispose() {
    for (final name in names.values) {
      name.dispose();
    }
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
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: FlexModal(
      maxWidth: 560,
      title: const Text('Geteilte Dateien'),
      onClose: busy ? null : () => Navigator.pop(context),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.incoming.error != null) ...[
            Text(widget.incoming.error!),
            TextButton(
              onPressed: busy ? null : () => action(widget.incoming.clearError),
              child: const Text('Hinweis schließen'),
            ),
          ],
          if (items.isEmpty) const Text('Keine Dateien im Eingang.'),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Checkbox(
                    value: selected.contains(item.id),
                    onChanged: busy
                        ? null
                        : (value) => setState(() {
                            value!
                                ? selected.add(item.id)
                                : selected.remove(item.id);
                          }),
                  ),
                  MaterialThumbnail(
                    material: item.preview(),
                    files: files,
                    width: 40,
                    height: 52,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: names[item.id],
                      enabled: !busy,
                      maxLength: 150,
                      decoration: InputDecoration(
                        labelText: 'Dateiname',
                        counterText: '',
                        helperText:
                            '${item.extension.toUpperCase()} · ${(item.size / 1000000).toStringAsFixed(1)} MB',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kategorie'),
              items: [
                for (final e in materialTypes.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: busy
                  ? null
                  : (value) => setState(() => category = value!),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.people_outline),
              title: const Text('Schüler zuordnen'),
              subtitle: Text(
                pupils.isEmpty ? 'FLEX-Klasse' : '${pupils.length} ausgewählt',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: busy
                  ? null
                  : () async {
                      final result = await chooseMaterialPupils(
                        context,
                        widget.controller,
                        pupils,
                      );
                      if (result != null && mounted) {
                        setState(() => pupils = result);
                      }
                    },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Unterricht zuordnen'),
              subtitle: Text(
                lessons.isEmpty ? 'Optional' : '${lessons.length} ausgewählt',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: busy
                  ? null
                  : () async {
                      final result = await choosePlanLessons(
                        context,
                        widget.controller,
                        lessons,
                      );
                      if (result != null && mounted) {
                        setState(() => lessons = result);
                      }
                    },
            ),
            if (pupils.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Für die Schüler geplant am'),
                subtitle: Text(
                  date == null ? 'Ohne Datum' : displayDate(date!),
                ),
                trailing: date == null
                    ? const Icon(Icons.event_outlined)
                    : IconButton(
                        tooltip: 'Datum entfernen',
                        icon: const Icon(Icons.close),
                        onPressed: busy
                            ? null
                            : () => setState(() => date = null),
                      ),
                onTap: busy
                    ? null
                    : () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date == null
                              ? now
                              : DateTime.parse(date!),
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 3),
                        );
                        if (picked != null && mounted) {
                          setState(() => date = dateOnly(picked));
                        }
                      },
              ),
          ],
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
      actions: [
        if (selected.isNotEmpty)
          TextButton(
            onPressed: busy
                ? null
                : () => action(() async {
                    final discard = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Aus Eingang entfernen?'),
                        content: const Text(
                          'Die ausgewählten Dateien werden nicht in FLEX übernommen. Die Originale in der anderen App bleiben erhalten.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Abbrechen'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Entfernen'),
                          ),
                        ],
                      ),
                    );
                    if (discard != true) return;
                    await widget.incoming.discard(selected.toList());
                    if (context.mounted) Navigator.pop(context);
                  }),
            child: const Text('Entfernen'),
          ),
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Später'),
        ),
        FilledButton(
          onPressed: busy || selected.isEmpty
              ? null
              : () => action(() async {
                  try {
                    await widget.incoming.accept(
                      widget.controller.repository,
                      selected,
                      names: {
                        for (final e in names.entries) e.key: e.value.text,
                      },
                      pupils: pupils,
                      lessons: lessons,
                      category: category,
                      date: pupils.isEmpty ? null : date,
                    );
                  } finally {
                    await widget.controller.reload();
                  }
                  if (context.mounted) Navigator.pop(context);
                }),
          child: const Text('Übernehmen'),
        ),
      ],
    ),
  );
}
