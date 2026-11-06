part of 'material_library.dart';

Future<void> reviewOneDriveFolder(
  BuildContext context,
  NotebookController c,
  OneDriveClient drive,
  ClassroomDocument folder,
) => showDialog<void>(
  context: context,
  builder: (_) => _FolderReview(controller: c, drive: drive, folder: folder),
);

class _FolderReview extends StatefulWidget {
  const _FolderReview({
    required this.controller,
    required this.drive,
    required this.folder,
  });
  final NotebookController controller;
  final OneDriveClient drive;
  final ClassroomDocument folder;
  @override
  State<_FolderReview> createState() => _FolderReviewState();
}

class _FolderReviewState extends State<_FolderReview> {
  List<ClassroomDocument>? documents;
  final selected = <String>{};
  String? error;
  int folders = 0, files = 0;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    scan();
  }

  Future<void> scan() async {
    try {
      final result = await scanMaterialFolder(
        widget.drive,
        widget.folder,
        widget.controller.classroom,
        cancelled: () => !mounted,
        progress: (a, b) {
          if (mounted) {
            setState(() {
              folders = a;
              files = b;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() {
        documents = result;
        selected.addAll(result.where((d) => d.revision == 0).map((d) => d.id));
      });
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
  }

  Future<void> correct(ClassroomDocument d) async {
    var patch = <String, dynamic>{};
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => FlexModal(
          title: const Text('Angaben prüfen'),
          onClose: () => Navigator.pop(ctx),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: d.title,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Bezeichnung'),
                onChanged: (v) => patch['title'] = v,
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: d.text('subject'),
                decoration: const InputDecoration(labelText: 'Fach · optional'),
                onChanged: (v) => patch['subject'] = v,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: d.text('documentType', 'other'),
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Dokumentart'),
                items: [
                  for (final e in materialTypes.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => patch['documentType'] = v,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: d.text('audience', 'all'),
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Für wen'),
                items: [
                  for (final e in materialAudiences.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => patch['audience'] = v,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.people_outline),
                label: Text(
                  'Schüler · ${(patch['pupilIds'] as List? ?? d.strings('pupilIds')).length}',
                ),
                onPressed: () async {
                  final ids = await chooseMaterialPupils(
                    ctx,
                    widget.controller,
                    List<String>.from(
                      patch['pupilIds'] as List? ?? d.strings('pupilIds'),
                    ),
                  );
                  if (ids != null) {
                    update(() => patch = {...patch, 'pupilIds': ids});
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => guarded(ctx, () async {
                d.patch(patch);
                Navigator.pop(ctx, true);
              }),
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && mounted) {
      setState(() {
        documents = [
          for (final value in documents!)
            if (value.id == d.id) d.patch(patch) else value,
        ];
        selected.add(d.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: FlexModal(
      title: const Text('Ordner einlesen'),
      onClose: saving ? null : () => Navigator.pop(context),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.folder.title),
          if (error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
          if (documents == null && error == null) ...[
            const LinearProgressIndicator(),
            Text('$folders Ordner · $files Dateien'),
          ],
          if (documents != null) ...[
            const Text(
              'Neue Dateien sind ausgewählt. Angaben lassen sich vor dem Übernehmen korrigieren. Vorhandene Dateien nur auswählen, wenn ihre Quellenangaben aktualisiert werden sollen.',
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () => setState(
                      () => selected.addAll(
                        documents!.where((d) => !d.deleted).map((d) => d.id),
                      ),
                    ),
              child: const Text('Alle aktiven auswählen'),
            ),
            if (documents!.isEmpty)
              const Text('Keine DOCX- oder PDF-Dateien gefunden.'),
            for (final d in documents!)
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(d.id),
                      onChanged: saving
                          ? null
                          : (v) => setState(() {
                              if (v == true) {
                                selected.add(d.id);
                              } else {
                                selected.remove(d.id);
                              }
                            }),
                      title: Text(d.title),
                      subtitle: Text(
                        '${d.deleted
                            ? 'Im Papierkorb'
                            : d.revision == 0
                            ? 'Neu'
                            : 'Vorhanden'} · ${materialTypes[d.text('documentType', 'other')]}\n${d.text('sourcePath')}',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Angaben korrigieren',
                    onPressed: saving ? null : () => correct(d),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: saving || selected.isEmpty
              ? null
              : () async {
                  setState(() => saving = true);
                  final ok = await guarded(context, () async {
                    await widget.controller.repository.saveClassroomDocuments(
                      documents!.where((d) => selected.contains(d.id)).toList(),
                    );
                    await widget.controller.reload();
                  });
                  if (context.mounted) {
                    if (ok) {
                      Navigator.pop(context);
                    } else {
                      setState(() => saving = false);
                    }
                  }
                },
          child: Text('${selected.length} übernehmen'),
        ),
      ],
    ),
  );
}
