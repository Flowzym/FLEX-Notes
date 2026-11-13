import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'flex_modal.dart';

class PersonAssignmentField extends StatelessWidget {
  const PersonAssignmentField({
    super.key,
    required this.pupils,
    required this.selected,
    required this.otherNames,
    required this.onChanged,
    this.multiple = true,
    this.locked = const {},
    this.canChangePupils = true,
    this.maxNameLength = 2000,
  });

  final List<Pupil> pupils;
  final Set<String> selected, locked;
  final String otherNames;
  final bool multiple, canChangePupils;
  final int? maxNameLength;
  final void Function(Set<String>, String) onChanged;

  @override
  Widget build(BuildContext context) {
    final names = [
      for (final pupil in pupils)
        if (selected.contains(pupil.id)) pupil.name,
      if (otherNames.trim().isNotEmpty) otherNames.trim(),
    ];
    return ListTile(
      key: const ValueKey('person-assignment'),
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 20,
      leading: const Icon(Icons.person_outline, size: 21),
      title: Text(names.isEmpty ? 'Schüler / Person zuordnen' : 'Zuordnung'),
      subtitle: names.isEmpty
          ? null
          : Text(
              names.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () async {
        final result = await _choosePeople(context);
        if (result != null && context.mounted) {
          onChanged(result.$1, result.$2);
        }
      },
    );
  }

  Future<(Set<String>, String)?> _choosePeople(BuildContext context) async {
    var ids = {...selected, ...locked};
    var query = '';
    var names = otherNames;
    return await showDialog<(Set<String>, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final visible = pupils
              .where(
                (p) =>
                    (canChangePupils || ids.contains(p.id)) &&
                    (!p.archived || ids.contains(p.id)) &&
                    p.name.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
          return FlexModal(
            maxWidth: 520,
            title: const Text('Schüler / Person zuordnen'),
            onClose: () => Navigator.pop(ctx),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canChangePupils)
                  TextField(
                    key: const ValueKey('person-assignment-search'),
                    decoration: const InputDecoration(
                      hintText: 'Schüler suchen',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => update(() => query = value),
                  ),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      !canChangePupils
                          ? 'Kein Schüler zugeordnet.'
                          : query.isNotEmpty
                          ? 'Keine passenden Schüler.'
                          : 'Keine Schüler verfügbar.',
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final pupil in visible)
                          CheckboxListTile(
                            key: ValueKey('person-assignment-${pupil.id}'),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(pupil.name),
                            secondary: locked.contains(pupil.id)
                                ? const Tooltip(
                                    message: 'Zugehöriger Schüler',
                                    child: Icon(Icons.lock_outline, size: 16),
                                  )
                                : null,
                            value: ids.contains(pupil.id),
                            onChanged:
                                !canChangePupils || locked.contains(pupil.id)
                                ? null
                                : (checked) => update(() {
                                    if (checked == true) {
                                      ids = multiple
                                          ? {...ids, pupil.id}
                                          : {pupil.id};
                                    } else {
                                      ids.remove(pupil.id);
                                    }
                                  }),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('person-assignment-names'),
                  initialValue: otherNames,
                  onChanged: (value) => names = value,
                  maxLength: maxNameLength,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Andere Person / weitere Namen',
                    hintText: 'Name eingeben',
                    counterText: '',
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
                key: const ValueKey('person-assignment-apply'),
                onPressed: () => Navigator.pop(ctx, (ids, names.trim())),
                child: const Text('Übernehmen'),
              ),
            ],
          );
        },
      ),
    );
  }
}
