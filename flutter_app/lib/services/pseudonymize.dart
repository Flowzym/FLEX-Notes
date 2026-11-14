/// Applies one replacement pass, so generated aliases cannot be replaced again.
/// Known full names and their unambiguous name parts share an alias. Ambiguous
/// first names become simply “Person”. The lookup is never included in exports.
String pseudonymizeReport(String text, Iterable<String> names) {
  final aliases = <String, String>{};
  var index = 0;
  for (final name
      in names.map((n) => n.trim()).where((n) => n.isNotEmpty).toSet()) {
    final alias = 'Person ${++index}';
    final parts = name.split(RegExp(r'\s+'));
    for (final key in {
      name.toLowerCase(),
      if (parts.length > 1)
        ...parts.where((p) => p.runes.length >= 3).map((p) => p.toLowerCase()),
    }) {
      aliases[key] = aliases.containsKey(key) && aliases[key] != alias
          ? 'Person'
          : alias;
    }
  }
  if (aliases.isEmpty) return text;
  final keys = aliases.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final pattern = RegExp(
    '(^|[^\\p{L}\\p{N}_])(${keys.map(RegExp.escape).join('|')})(?=\$|[^\\p{L}\\p{N}_])',
    unicode: true,
    caseSensitive: false,
  );
  return text.replaceAllMapped(
    pattern,
    (m) => '${m[1]}${aliases[m[2]!.toLowerCase()]}',
  );
}
