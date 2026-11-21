import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/admin_deletion.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import '../domain/repository.dart';
import '../services/material_storage.dart';
import 'common.dart';
import 'material_versions.dart';
import '../domain/material_versions.dart';
import 'maintenance_dialog.dart';
import 'retention_dialog.dart';

Future<void> openAdminArea(BuildContext context, NotebookController c) =>
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => AdminArea(controller: c)));

class AdminArea extends StatefulWidget {
  const AdminArea({super.key, required this.controller});
  final NotebookController controller;
  @override
  State<AdminArea> createState() => _AdminAreaState();
}

class _AdminAreaState extends State<AdminArea> {
  NotebookController get c => widget.controller;
  late Future<NotebookSnapshot> data = c.repository.snapshot();
  String group = 'Schüler', query = '';
  bool busy = false;
  Future<void> erase(AdminTarget target) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await guarded(context, () async {
        if (c.syncingMaterials) await c.syncMaterials();
        final preview = await c.repository.previewAdminDeletion(target);
        if (!mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => _DeletionConfirmation(preview),
        );
        if (ok != true) return;
        await c.repository.deleteAdminSelection(preview);
        await c.reload();
        setStateIfMounted();
        try {
          await c.repository.removeUnreferencedFiles(
            const LocalMaterialFiles().remove,
          );
        } catch (_) {
          throw const DomainError(
            'Einträge gelöscht. Ausstehende lokale Dateien werden beim nächsten Start erneut bereinigt.',
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${preview.title} · dauerhaft gelöscht')),
          );
        }
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void setStateIfMounted() {
    if (mounted) setState(() => data = c.repository.snapshot());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admin-Bereich')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: FutureBuilder<NotebookSnapshot>(
          future: data,
          builder: (ctx, snap) {
            if (snap.hasError) {
              return Center(child: Text(friendlyError(snap.error!)));
            }
            final s = snap.data;
            if (s == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final names = {for (final p in s.pupils) p.id: p.name};
            final rows =
                <({AdminTarget target, String name, String detail})>[
                  if (group == 'Schüler')
                    for (final p in s.pupils)
                      (
                        target: AdminTarget('pupil', p.id),
                        name: p.name,
                        detail: p.deleted
                            ? 'Papierkorb'
                            : p.archived
                            ? 'Archiviert'
                            : 'Aktiv',
                      ),
                  if (group == 'Einträge') ...[
                    for (final e in s.entries)
                      (
                        target: AdminTarget('orga', e.id),
                        name: e.title,
                        detail: [
                          e.deleted
                              ? 'Papierkorb'
                              : e.isAppointment
                              ? 'Termin'
                              : e.isTask
                              ? 'Aufgabe'
                              : 'Notiz',
                          names[e.pupilId] ?? 'Klasse',
                        ].join(' · '),
                      ),
                    for (final r in s.records)
                      (
                        target: AdminTarget('school', r.id),
                        name: r.title.isNotEmpty
                            ? r.title
                            : r.body.isNotEmpty
                            ? r.body
                            : r.kind.label,
                        detail: [
                          r.kind.label,
                          names[r.pupilId] ?? '',
                          r.observedOn,
                          if (r.deleted) 'Papierkorb',
                        ].join(' · '),
                      ),
                  ],
                  if (group == 'Materialien' || group == 'Klassendaten')
                    for (final d in s.classroom.where(
                      (v) => group == 'Materialien'
                          ? v.kind == ClassroomKind.material
                          : v.kind != ClassroomKind.material,
                    ))
                      (
                        target: AdminTarget('document', d.id),
                        name: d.title,
                        detail: [
                          d.label,
                          if (d.deleted) 'Papierkorb',
                        ].join(' · '),
                      ),
                ]..removeWhere(
                  (r) => !('${r.name} ${r.detail}').toLowerCase().contains(
                    query.trim().toLowerCase(),
                  ),
                );
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  sliver: SliverList.list(
                    children: [
                      Text(
                        'Daten einzeln löschen',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Wähle einen Datensatz, um die betroffenen Einträge und lokalen Dateien vor dem Löschen zu prüfen.',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final label in [
                            'Schüler',
                            'Einträge',
                            'Materialien',
                            'Klassendaten',
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: label == group,
                              onSelected: busy
                                  ? null
                                  : (_) => setState(() => group = label),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'Name oder Eintrag suchen',
                        ),
                        onChanged: (v) => setState(() => query = v),
                      ),
                      if (rows.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Keine passenden Daten.'),
                        ),
                    ],
                  ),
                ),
                SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    final material = group == 'Materialien'
                        ? s.classroom
                              .where(
                                (d) =>
                                    d.id == r.target.id &&
                                    materialVersions(d.toJson()).isNotEmpty,
                              )
                              .firstOrNull
                        : null;
                    return ListTile(
                      key: ValueKey('admin-${r.target.kind}-${r.target.id}'),
                      title: Text(
                        r.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(r.detail),
                      trailing: material == null
                          ? const Icon(Icons.chevron_right)
                          : IconButton(
                              tooltip: 'Dokumentversionen verwalten',
                              icon: const Icon(Icons.history),
                              onPressed: busy
                                  ? null
                                  : () async {
                                      await showMaterialVersions(
                                        context,
                                        c,
                                        material,
                                        allowDeletion: true,
                                      );
                                      setStateIfMounted();
                                    },
                            ),
                      enabled: !busy,
                      onTap: () => erase(r.target),
                    );
                  },
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                  sliver: SliverList.list(
                    children: [
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.auto_delete_outlined),
                        title: const Text('Aufbewahrung & Löschprüfung'),
                        enabled: !busy,
                        onTap: () async {
                          await showRetentionReview(context, c);
                          setStateIfMounted();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_sweep_outlined),
                        title: const Text('Papierkorb endgültig leeren'),
                        enabled: !busy,
                        onTap: () async {
                          await showDialog<void>(
                            context: context,
                            builder: (_) => MaintenanceDialog(
                              controller: c,
                              emptyTrash: true,
                            ),
                          );
                          setStateIfMounted();
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: Icon(
                          Icons.delete_forever_outlined,
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                        title: const Text('Gesamtes lokales Notizbuch löschen'),
                        subtitle: const Text(
                          'Alle Schüler, Einträge, Entwürfe, lokalen Unterlagen und Schuljahresarchive auf diesem Gerät.',
                        ),
                        enabled: !busy,
                        onTap: () => erase(const AdminTarget.all()),
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
  );
}

class _DeletionConfirmation extends StatefulWidget {
  const _DeletionConfirmation(this.p);
  final AdminDeletionPreview p;
  @override
  State<_DeletionConfirmation> createState() => _DeletionConfirmationState();
}

class _DeletionConfirmationState extends State<_DeletionConfirmation> {
  String word = '';
  @override
  Widget build(BuildContext context) {
    final p = widget.p, all = p.target.kind == 'all';
    return AlertDialog(
      title: Text(
        all ? 'Gesamtes Notizbuch löschen?' : '„${p.title}“ endgültig löschen?',
      ),
      content: SizedBox(
        width: 440,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final e in p.removed.entries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.key),
                trailing: Text('${e.value}'),
              ),
            if (p.unlinked > 0)
              Text(
                '${p.unlinked} weitere Datensätze verlieren eine Zuordnung.',
              ),
            const SizedBox(height: 10),
            const Text(
              'Diese Löschung ist endgültig. Die Auswahl gilt für dieses Gerät. Separat gespeicherte Sicherungen und OneDrive-Originale liegen außerhalb des lokalen Notizbuchs.',
            ),
            if (all)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Zur Bestätigung LÖSCHEN eingeben',
                  ),
                  onChanged: (v) => setState(() => word = v),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: all && word != 'LÖSCHEN'
              ? null
              : () => Navigator.pop(context, true),
          child: const Text('Endgültig löschen'),
        ),
      ],
    );
  }
}
