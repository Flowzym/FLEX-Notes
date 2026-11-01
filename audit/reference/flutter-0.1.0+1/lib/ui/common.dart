import 'package:flutter/material.dart';
import '../domain/models.dart';

String friendlyError(Object e) => e is DomainError ? e.message : 'Speichern oder Laden fehlgeschlagen. Deine Eingaben bleiben erhalten. Bitte Speicherplatz und Berechtigungen prüfen.';
Future<bool> guarded(BuildContext context, Future<void> Function() action) async {
  try { await action(); return true; } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e)), duration: const Duration(seconds: 8)));
    return false;
  }
}
String displayDate(String? value) {
  if (value == null) return 'Ohne Termin';
  if (value.length == 10) return '${value.substring(8,10)}.${value.substring(5,7)}.${value.substring(0,4)}';
  final d = DateTime.parse(value).toLocal();
  return '${displayDate(dateOnly(d))} · ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}
class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key, this.icon = Icons.notes_rounded});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16), child: Column(children: [Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 12), Text(text, textAlign: TextAlign.center)]));
}
