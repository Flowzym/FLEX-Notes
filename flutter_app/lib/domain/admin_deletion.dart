class AdminTarget {
  const AdminTarget(this.kind, this.id);
  const AdminTarget.all() : kind = 'all', id = '';
  final String kind, id;
}

class AdminDeletionPreview {
  const AdminDeletionPreview(
    this.target,
    this.title,
    this.fingerprint,
    this.removed,
    this.unlinked,
  );
  final AdminTarget target;
  final String title, fingerprint;
  final Map<String, int> removed;
  final int unlinked;
}
