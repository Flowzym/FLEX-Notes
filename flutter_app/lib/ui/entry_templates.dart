import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/entry_template.dart';
import '../domain/models.dart';
import '../platform/backup_transfer.dart';
import 'common.dart';
import 'flex_modal.dart';

class EntryTemplateButton extends StatelessWidget {
  const EntryTemplateButton({
    super.key,
    required this.controller,
    required this.kind,
    required this.capture,
    required this.apply,
    this.enabled = true,
  });
  final NotebookController controller;
  final String kind;
  final EntryTemplate Function(String name) capture;
  final ValueChanged<EntryTemplate> apply;
  final bool enabled;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Eintragsvorlagen',
    icon: const Icon(Icons.library_add_outlined, size: 20),
    onPressed: !enabled
        ? null
        : () => guarded(context, () async {
            final templates = (await controller.repository.entryTemplates())
                .where((t) => t.kind == kind)
                .toList();
            if (!context.mounted) return;
            final selected = await showDialog<EntryTemplate>(
              context: context,
              builder: (ctx) => FlexModal(
                title: Text('Vorlagen · ${templateKinds[kind]}'),
                maxWidth: 620,
                onClose: () => Navigator.pop(ctx),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (templates.isEmpty)
                      const Text('Noch keine Vorlage für diesen Bereich.'),
                    for (final template in templates)
                      ExpansionTile(
                        title: Text(template.name),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(template.preview),
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.pop(ctx, template),
                            icon: const Icon(Icons.add),
                            label: const Text('Eingaben ergänzen'),
                          ),
                        ],
                      ),
                  ],
                ),
                actions: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Aktuelle Eingaben als Vorlage'),
                    onPressed: () async {
                      final name = await templateName(ctx);
                      if (name == null || !ctx.mounted) return;
                      final ok = await guarded(
                        ctx,
                        () => controller.repository.saveEntryTemplate(
                          capture(name),
                        ),
                      );
                      if (ok && ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            );
            if (selected != null && context.mounted) apply(selected);
          }),
  );
}

Future<String?> templateName(
  BuildContext context, {
  String initial = '',
}) async {
  final field = TextEditingController(text: initial);
  final value = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Vorlage benennen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: field,
            maxLength: 100,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const Text(
            'Die Vorlage enthält Texte und Auswahlfelder. Namen oder persönliche Angaben in eigenen Texten bitte vorher entfernen.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Abbrechen'),
        ),
        ValueListenableBuilder(
          valueListenable: field,
          builder: (_, value, _) => FilledButton(
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.pop(ctx, value.text.trim()),
            child: const Text('Speichern'),
          ),
        ),
      ],
    ),
  );
  field.dispose();
  return value;
}

Future<void> showEntryTemplateManager(
  BuildContext context,
  NotebookController c,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _TemplateManager(controller: c),
  );
}

class _TemplateManager extends StatefulWidget {
  const _TemplateManager({required this.controller});
  final NotebookController controller;
  @override
  State<_TemplateManager> createState() => _TemplateManagerState();
}

class _TemplateManagerState extends State<_TemplateManager> {
  late Future<List<EntryTemplate>> loading = widget.controller.repository
      .entryTemplates();
  void refresh() =>
      setState(() => loading = widget.controller.repository.entryTemplates());
  @override
  Widget build(BuildContext context) => FlexModal(
    title: const Text('Eintragsvorlagen'),
    onClose: () => Navigator.pop(context),
    content: FutureBuilder(
      future: loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Vorlagen konnten nicht geladen werden.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Text(
            'Neue Vorlagen im jeweiligen Eintragsformular über „Eintragsvorlagen“ speichern.',
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final template in snapshot.data!)
              ExpansionTile(
                title: Text(template.name),
                subtitle: Text(templateKinds[template.kind]!),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(template.preview),
                  ),
                  Wrap(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Umbenennen'),
                        onPressed: () async {
                          final name = await templateName(
                            context,
                            initial: template.name,
                          );
                          if (name == null || !context.mounted) return;
                          await guarded(
                            context,
                            () =>
                                widget.controller.repository.saveEntryTemplate(
                                  EntryTemplate.fromJson({
                                    ...template.toJson(),
                                    'name': name,
                                  }),
                                ),
                          );
                          if (mounted) refresh();
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Löschen'),
                        onPressed: () async {
                          if (!await confirmFlex(
                                context,
                                'Vorlage löschen?',
                                template.name,
                                accept: 'Löschen',
                              ) ||
                              !context.mounted) {
                            return;
                          }
                          await guarded(
                            context,
                            () => widget.controller.repository
                                .deleteEntryTemplate(template.id),
                          );
                          if (mounted) refresh();
                        },
                      ),
                    ],
                  ),
                ],
              ),
          ],
        );
      },
    ),
  );
}

Future<void> showCatalogTransfer(
  BuildContext context,
  NotebookController c, {
  bool importing = false,
}) async {
  final CatalogBundle bundle;
  if (importing) {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'FLEX-Kataloge',
          extensions: ['json'],
          mimeTypes: ['application/json'],
        ),
      ],
    );
    if (file == null) return;
    if (await file.length() > 1000000) {
      throw const DomainError('Die Katalogdatei ist zu groß (höchstens 1 MB).');
    }
    bundle = CatalogBundle.decode(await file.readAsString());
  } else {
    bundle = await c.repository.exportCatalogs();
  }
  if (!context.mounted) return;
  bool replace = false, busy = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => FlexModal(
        title: Text(importing ? 'Kataloge übernehmen' : 'Kataloge exportieren'),
        onClose: busy ? null : () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Beobachtungslisten und Favoriten, ohne Einträge, Schülerzuordnungen oder Anhänge. Eigene Texte vor dem Teilen prüfen.',
            ),
            if (importing)
              SwitchListTile(
                title: const Text('Vorhandene Listen ersetzen'),
                subtitle: Text(
                  replace
                      ? 'Nur die enthaltenen Bereiche werden ersetzt.'
                      : 'Neue Texte ergänzen; bestehende bleiben erhalten.',
                ),
                value: replace,
                onChanged: busy ? null : (v) => update(() => replace = v),
              ),
            for (final item in bundle.catalogs.entries)
              ExpansionTile(
                title: Text(
                  '${item.key.startsWith('social') ? 'Sozial' : 'Arbeit'} · ${const {'positive': 'Positiv', 'neutral': 'Neutral', 'negative': 'Negativ'}[item.key.split('-').last]}',
                ),
                subtitle: Text(
                  '${item.value.options.length} Texte · ${item.value.favorites.length} Favoriten',
                ),
                children: [
                  for (final text in item.value.options)
                    ListTile(
                      dense: true,
                      title: Text(text),
                      trailing: item.value.favorites.contains(text)
                          ? const Icon(Icons.star_outline, size: 18)
                          : null,
                    ),
                ],
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    update(() => busy = true);
                    final ok = await guarded(ctx, () async {
                      if (importing) {
                        await c.repository.importCatalogs(
                          bundle,
                          replace: replace,
                        );
                      } else {
                        final saved = await saveBackupStream(
                          'FLEX-Beobachtungskataloge.json',
                          Stream.value(utf8.encode(bundle.encode())),
                        );
                        if (!saved) {
                          throw const DomainError('Speichern abgebrochen.');
                        }
                      }
                    });
                    if (!ctx.mounted) return;
                    if (ok) {
                      Navigator.pop(ctx);
                    } else {
                      update(() => busy = false);
                    }
                  },
            child: Text(
              importing
                  ? (replace ? 'Listen ersetzen' : 'Listen ergänzen')
                  : 'Datei speichern',
            ),
          ),
        ],
      ),
    ),
  );
}
