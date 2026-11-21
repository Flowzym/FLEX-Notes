import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import '../domain/classroom.dart';
import 'common.dart';

Future<void> openArchivedPupils(BuildContext context, NotebookController c) =>
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => _ArchivedPupils(c)));

class _ArchivedPupils extends StatefulWidget {
  const _ArchivedPupils(this.c);
  final NotebookController c;
  @override
  State<_ArchivedPupils> createState() => _ArchivedPupilsState();
}

class _ArchivedPupilsState extends State<_ArchivedPupils> {
  String query = '';
  late var snapshot = widget.c.repository.snapshot();
  Future<void> restore(Pupil p) async {
    await guarded(context, () async {
      await widget.c.savePupil(p.copyWith(archived: false));
      if (mounted) setState(() => snapshot = widget.c.repository.snapshot());
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Archivierte Schüler')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: FutureBuilder(
          future: snapshot,
          builder: (ctx, state) {
            if (state.hasError) {
              return Center(child: Text(friendlyError(state.error!)));
            }
            final data = state.data;
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final pupils = data.pupils
                .where(
                  (p) =>
                      p.archived &&
                      !p.deleted &&
                      p.name.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Archivierte Schüler suchen',
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
                if (pupils.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Keine passenden archivierten Schüler.'),
                  ),
                for (final p in pupils)
                  ExpansionTile(
                    key: PageStorageKey(p.id),
                    title: Text(p.name),
                    leading: const Icon(Icons.person_outline),
                    children: [
                      for (final r in data.records.where(
                        (r) =>
                            !r.deleted &&
                            (r.pupilId == p.id ||
                                r.participantIds.contains(p.id)),
                      ))
                        ListTile(
                          title: Text(r.title.isEmpty ? r.kind.label : r.title),
                          subtitle: Text(
                            [
                              r.observedOn,
                              r.body,
                              ...r.positive,
                              ...r.neutral,
                              ...r.negative,
                              ...r.tasks.map((t) => t.text),
                            ].where((s) => s.isNotEmpty).join(' · '),
                          ),
                        ),
                      for (final e in data.entries.where(
                        (e) => !e.deleted && e.pupilId == p.id,
                      ))
                        ListTile(title: Text(e.title), subtitle: Text(e.body)),
                      for (final d in data.classroom.where(
                        (d) =>
                            !d.deleted &&
                            (d.kind == ClassroomKind.material &&
                                    d.strings('pupilIds').contains(p.id) ||
                                d.kind == ClassroomKind.returnList &&
                                    d
                                        .rows('participants')
                                        .any((r) => r['pupilId'] == p.id)),
                      ))
                        ListTile(title: Text(d.title), subtitle: Text(d.label)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => restore(p),
                          icon: const Icon(Icons.unarchive_outlined),
                          label: const Text('Wieder aktivieren'),
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
