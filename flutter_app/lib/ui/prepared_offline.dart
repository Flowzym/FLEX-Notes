part of 'material_library.dart';

class PreparedOfflineStatus extends StatefulWidget {
  const PreparedOfflineStatus({
    super.key,
    required this.controller,
    required this.materials,
    this.details = false,
    this.files = const LocalMaterialFiles(),
  });
  final NotebookController controller;
  final List<ClassroomDocument> materials;
  final bool details;
  final MaterialFiles files;
  @override
  State<PreparedOfflineStatus> createState() => _PreparedOfflineStatusState();
}

class _PreparedOfflineStatusState extends State<PreparedOfflineStatus>
    with WidgetsBindingObserver {
  bool expanded = false, busy = false;
  late Future<Map<String, bool?>> availability = check();
  Future<Map<String, bool?>> check() async {
    final entries = await Future.wait(
      widget.materials.map((m) async {
        final key = m.text('localKey');
        try {
          return MapEntry<String, bool?>(
            m.id,
            key.isNotEmpty && await widget.files.exists(key),
          );
        } catch (_) {
          return MapEntry<String, bool?>(m.id, null);
        }
      }),
    );
    return Map.fromEntries(entries);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final updated = check();
      setState(() {
        availability = updated;
      });
    }
  }

  @override
  void didUpdateWidget(PreparedOfflineStatus old) {
    super.didUpdateWidget(old);
    List<(String, String, int)> signature(List<ClassroomDocument> docs) => [
      for (final m in docs) (m.id, m.text('localKey'), m.revision),
    ];
    if (old.files != widget.files ||
        !listEquals(signature(old.materials), signature(widget.materials))) {
      availability = check();
    }
  }

  Future<void> download(List<ClassroomDocument> docs) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await guarded(
        context,
        () =>
            cacheMaterials(context, widget.controller, docs, offerSignIn: true),
      );
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          availability = check();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, bool?>>(
    future: availability,
    builder: (ctx, snapshot) {
      if (snapshot.connectionState != ConnectionState.done ||
          !snapshot.hasData) {
        return const Text('Offlinekopien werden geprüft …');
      }
      final result = snapshot.data!;
      final ready = result.values.where((v) => v == true).length;
      final unknown = result.values.where((v) => v == null).length;
      final missing = widget.materials.where((m) => result[m.id] != true);
      bool downloadable(ClassroomDocument d) =>
          d.text('itemId').isNotEmpty &&
          {'pdf', 'docx', 'jpg', 'png'}.contains(d.text('extension'));
      final remote = missing.where(downloadable).toList();
      final summary =
          '$ready von ${result.length} auf diesem Gerät${unknown > 0 ? ' · $unknown ungeprüft' : ''}';
      if (!widget.details) {
        return Text(summary, style: Theme.of(ctx).textTheme.bodySmall);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              missing.isEmpty
                  ? Icons.offline_pin_outlined
                  : Icons.cloud_download_outlined,
            ),
            title: Text(summary),
            subtitle: missing.isEmpty ? null : Text('${missing.length} prüfen'),
            trailing: missing.isEmpty
                ? null
                : Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: missing.isEmpty
                ? null
                : () => setState(() => expanded = !expanded),
          ),
          if (expanded)
            for (final m in missing)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(m.title),
                subtitle: Text(
                  result[m.id] == null
                      ? 'Speicherprüfung fehlgeschlagen'
                      : downloadable(m)
                      ? 'In OneDrive verfügbar'
                      : m.text('url').isNotEmpty
                      ? 'Online-Link'
                      : 'Lokale Datei fehlt',
                ),
                onTap: busy
                    ? null
                    : () => showMaterialDetails(ctx, widget.controller, m),
                trailing: downloadable(m)
                    ? IconButton(
                        onPressed: busy ? null : () => download([m]),
                        tooltip: '${m.title} offline laden',
                        icon: const Icon(Icons.download_outlined),
                      )
                    : null,
              ),
          if (remote.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => download(remote),
                icon: const Icon(Icons.download_outlined),
                label: Text('Offline laden · ${remote.length}'),
              ),
            ),
          if (busy) const LinearProgressIndicator(),
        ],
      );
    },
  );
}
