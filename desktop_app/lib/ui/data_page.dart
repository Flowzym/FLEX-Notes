part of 'workspace.dart';

extension _DataViews on _DesktopWorkspaceState {
  Widget dataPage() => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      const SectionHeading(
        'Dein Arbeitsplatz',
        subtitle: 'Daten übernehmen, sichern und den Desktop einrichten.',
      ),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sicherungen & Datenaustausch',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
            const SizedBox(height: 8),
            const Text(
              'Übernimm eine vollständige FLEX-Sicherung mit Schülern, Einträgen und Dateien. Beim Import werden Unterschiede vor dem Zusammenführen angezeigt.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => backup(true),
                  icon: const Icon(Icons.lock_outline, size: 17),
                  label: const Text('Sicherung erstellen'),
                ),
                OutlinedButton.icon(
                  onPressed: () => backup(false),
                  icon: const Icon(Icons.file_download_outlined, size: 17),
                  label: const Text('Sicherung importieren'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Android und Desktop speichern unabhängig. Ein automatischer Geräteabgleich ist nicht eingerichtet.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OneDrive',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              drive.connected
                  ? 'Verbunden · Dateien verknüpfen und offline bereitlegen.'
                  : 'Für Materialien aus deinem Microsoft-Konto.',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => run(openDrive),
                  icon: const Icon(Icons.cloud_outlined, size: 17),
                  label: Text(
                    drive.connected ? 'OneDrive öffnen' : 'OneDrive verbinden',
                  ),
                ),
                if (drive.connected)
                  TextButton(
                    onPressed: () => run(() async {
                      await drive.disconnect();
                      if (mounted) redraw(() {});
                    }),
                    child: const Text('Abmelden'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Windows verwendet die Microsoft-Anmeldung mit Anmeldecode. Dafür muss die Entra-Registrierung öffentliche Clientflows erlauben.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tastatur & Bedienung',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
            const SizedBox(height: 12),
            for (final pair in [
              ('Strg K', 'Globale Suche und Bereichswechsel'),
              ('Strg N', 'Neue Notiz im Editor öffnen'),
              ('Strg Eingabe', 'Aktuellen Eintrag speichern'),
              ('Tab / Umschalt Tab', 'Zum nächsten / vorherigen Bedienelement'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    SizedBox(width: 150, child: Pill(pair.$1)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        pair.$2,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Termine mit der Maus verschieben. Den unteren Rand eines Termins ziehen, um seine Dauer zu ändern.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Papierkorb',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gelöschte Einträge und Materialien bleiben wiederherstellbar.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: showTrash,
              icon: const Icon(Icons.delete_outline, size: 17),
              label: const Text('Papierkorb öffnen'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FLEX Desktop · 1.0',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
            const SizedBox(height: 8),
            const Text(
              'Eigenständiger Windows-Arbeitsplatz mit gemeinsamem FLEX-Datenformat. Deine Arbeitsdaten werden lokal auf diesem Gerät gespeichert.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'FLEX Desktop',
                applicationVersion: '1.0.0',
              ),
              child: const Text('Open-Source-Lizenzen'),
            ),
          ],
        ),
      ),
    ],
  );
  Future<void> backup(bool export) async {
    await run(() async {
      await c.editor?.flush();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => BackupDialog(
          controller: c.notebook,
          files: c.files,
          export: export,
        ),
      );
      await c.notebook.reload();
    });
  }

  Future<void> showTrash() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AnimatedBuilder(
        animation: c,
        builder: (ctx, _) => AlertDialog(
          title: const Text('Papierkorb'),
          content: SizedBox(
            width: 600,
            height: 430,
            child: ListView(
              children: [
                for (final e in c.notebook.currentSnapshot.entries.where(
                  (e) => e.deleted,
                ))
                  ListTile(
                    title: Text(e.title),
                    subtitle: const Text('Organisation'),
                    trailing: IconButton(
                      tooltip: 'Wiederherstellen',
                      onPressed: () => run(
                        () => c.notebook.saveEntry(e.copyWith(deleted: false)),
                      ),
                      icon: const Icon(Icons.restore),
                    ),
                  ),
                for (final r in c.notebook.currentSnapshot.records.where(
                  (r) => r.deleted,
                ))
                  ListTile(
                    title: Text(r.title.isEmpty ? r.kind.label : r.title),
                    subtitle: Text(c.name(r.pupilId)),
                    trailing: IconButton(
                      tooltip: 'Wiederherstellen',
                      onPressed: () => run(
                        () =>
                            c.notebook.saveRecord(r.patch({'deleted': false})),
                      ),
                      icon: const Icon(Icons.restore),
                    ),
                  ),
                for (final d in c.notebook.currentSnapshot.classroom.where(
                  (d) => d.deleted,
                ))
                  ListTile(
                    title: Text(d.title),
                    subtitle: Text(d.label),
                    trailing: IconButton(
                      tooltip: 'Wiederherstellen',
                      onPressed: () => run(
                        () => c.notebook.saveClassroom(
                          d.patch({'deleted': false}),
                        ),
                      ),
                      icon: const Icon(Icons.restore),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Schließen'),
            ),
          ],
        ),
      ),
    );
  }
}
