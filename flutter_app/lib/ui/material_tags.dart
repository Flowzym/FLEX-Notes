import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/material_tags.dart';
import 'common.dart';
import 'flex_modal.dart';

Map<String, int> materialTagUsage(NotebookController c) {
  final names = <String, String>{};
  final counts = <String, int>{};
  void add(Iterable<String> tags) {
    for (final tag in normalizeMaterialTags(tags)) {
      final key = materialTagKey(tag);
      names.putIfAbsent(key, () => tag);
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }

  for (final d in c.classroom.where((d) => d.kind == ClassroomKind.material)) {
    add(d.strings('tags'));
  }
  for (final d in c.dialogDrafts.where(
    (d) => d.type == 'scan' || d.type == 'classroom',
  )) {
    add(List<String>.from(d.data['tags'] as List? ?? []));
  }
  final keys = names.keys.toList()..sort();
  return {for (final key in keys) names[key]!: counts[key]!};
}

/// A valid tag being typed is included in the draft immediately, so saving or
/// backgrounding cannot silently lose it. Enter/+ turns it into a chip.
class MaterialTagEditor extends StatefulWidget {
  const MaterialTagEditor({
    super.key,
    required this.values,
    required this.suggestions,
    required this.onChanged,
    this.enabled = true,
  });
  final List<String> values;
  final Iterable<String> suggestions;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;
  @override
  State<MaterialTagEditor> createState() => _MaterialTagEditorState();
}

class _MaterialTagEditorState extends State<MaterialTagEditor> {
  final input = TextEditingController();
  late List<String> selected = normalizeMaterialTags(widget.values);
  List<String> get current => normalizeMaterialTags([...selected, input.text]);
  @override
  void didUpdateWidget(MaterialTagEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(normalizeMaterialTags(widget.values), current)) {
      selected = normalizeMaterialTags(widget.values);
      input.clear();
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void commit([String? value]) {
    setState(() {
      selected = normalizeMaterialTags([...selected, value ?? input.text]);
      input.clear();
    });
    widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = normalizeMaterialTags(widget.suggestions)
        .where(
          (t) =>
              !current.map(materialTagKey).contains(materialTagKey(t)) &&
              materialTagKey(t).contains(materialTagKey(input.text)),
        )
        .take(8)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tags', style: TextStyle(fontWeight: FontWeight.w600)),
        if (selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tag in selected)
                  InputChip(
                    label: Text(tag),
                    onDeleted: !widget.enabled
                        ? null
                        : () {
                            setState(() => selected.remove(tag));
                            widget.onChanged(current);
                          },
                  ),
              ],
            ),
          ),
        TextField(
          controller: input,
          enabled: widget.enabled && selected.length < 30,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(',')),
            LengthLimitingTextInputFormatter(64),
          ],
          decoration: InputDecoration(
            labelText: 'Tag hinzufügen',
            prefixIcon: const Icon(Icons.sell_outlined),
            suffixIcon: IconButton(
              tooltip: 'Tag übernehmen',
              onPressed: !widget.enabled || input.text.trim().isEmpty
                  ? null
                  : commit,
              icon: const Icon(Icons.add),
            ),
          ),
          onChanged: (_) {
            setState(() {});
            widget.onChanged(current);
          },
          onSubmitted: (_) => commit(),
        ),
        if (widget.enabled && selected.length < 30 && suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tag in suggestions)
                  ActionChip(label: Text(tag), onPressed: () => commit(tag)),
              ],
            ),
          ),
      ],
    );
  }
}

Future<void> showMaterialTagManager(
  BuildContext context,
  NotebookController c,
) => showDialog<void>(
  context: context,
  builder: (ctx) => AnimatedBuilder(
    animation: c,
    builder: (ctx, _) {
      final usage = materialTagUsage(c);
      return FlexModal(
        title: const Text('Tags verwalten'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (usage.isEmpty)
              const Text(
                'Neue Tags kannst du direkt bei einer Datei oder einem Scan eingeben.',
              ),
            for (final entry in usage.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.key),
                subtitle: Text('${entry.value} Zuordnungen'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Tag ${entry.key} umbenennen',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        var value = entry.key;
                        final form = GlobalKey<FormState>();
                        final renamed = await showDialog<String>(
                          context: ctx,
                          builder: (dialog) => FlexModal(
                            title: const Text('Tag umbenennen'),
                            onClose: () => Navigator.pop(dialog),
                            content: Form(
                              key: form,
                              child: TextFormField(
                                initialValue: value,
                                autofocus: true,
                                maxLength: 64,
                                decoration: const InputDecoration(
                                  labelText: 'Tag',
                                ),
                                onChanged: (v) => value = v,
                                validator: (v) {
                                  try {
                                    checkedMaterialTag(v ?? '');
                                    return null;
                                  } catch (_) {
                                    return 'Bitte einen gültigen Tag ohne Komma eingeben.';
                                  }
                                },
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialog),
                                child: const Text('Abbrechen'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  if (form.currentState!.validate()) {
                                    Navigator.pop(dialog, value);
                                  }
                                },
                                child: const Text('Umbenennen'),
                              ),
                            ],
                          ),
                        );
                        if (renamed == null || !ctx.mounted) return;
                        await guarded(ctx, () async {
                          await c.repository.renameMaterialTag(
                            entry.key,
                            renamed,
                          );
                          await c.reload();
                        });
                      },
                    ),
                    IconButton(
                      tooltip: 'Tag ${entry.key} entfernen',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (!await confirmFlex(
                              ctx,
                              'Tag entfernen?',
                              '„${entry.key}“ wird bei Dateien und Entwürfen entfernt. Die Dateien bleiben erhalten.',
                              accept: 'Tag entfernen',
                            ) ||
                            !ctx.mounted) {
                          return;
                        }
                        await guarded(ctx, () async {
                          await c.repository.renameMaterialTag(entry.key, null);
                          await c.reload();
                        });
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  ),
);

Future<(TagChange, List<String>)?> chooseMaterialTags(
  BuildContext context,
  NotebookController c, {
  required int count,
}) {
  var mode = TagChange.add;
  var values = <String>[];
  return showDialog<(TagChange, List<String>)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => FlexModal(
        title: Text('Tags · $count Dateien'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              children: [
                for (final item in const {
                  TagChange.add: 'Ergänzen',
                  TagChange.remove: 'Entfernen',
                  TagChange.replace: 'Ersetzen',
                }.entries)
                  ChoiceChip(
                    label: Text(item.value),
                    selected: mode == item.key,
                    onSelected: (_) => update(() => mode = item.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            MaterialTagEditor(
              values: values,
              suggestions: materialTagUsage(c).keys,
              onChanged: (v) => update(() => values = v),
            ),
            if (mode == TagChange.replace)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Ersetzt alle bisherigen Tags der ausgewählten Dateien.',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: values.isEmpty
                ? null
                : () => Navigator.pop(ctx, (mode, values)),
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    ),
  );
}
