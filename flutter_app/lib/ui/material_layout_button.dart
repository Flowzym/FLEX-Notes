import 'package:flutter/material.dart';
import '../domain/models.dart';

class MaterialLayoutButton extends StatelessWidget {
  const MaterialLayoutButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final MaterialLayout value;
  final ValueChanged<MaterialLayout> onChanged;

  static const options = {
    MaterialLayout.list: ('Liste', Icons.view_list_outlined),
    MaterialLayout.compact: ('Kompaktliste', Icons.view_headline_outlined),
    MaterialLayout.grid: ('Kacheln', Icons.grid_view_outlined),
  };

  @override
  Widget build(BuildContext context) => PopupMenuButton<MaterialLayout>(
    tooltip: 'Materialansicht · ${options[value]!.$1}',
    icon: Icon(options[value]!.$2, size: 20),
    initialValue: value,
    onSelected: onChanged,
    itemBuilder: (_) => [
      for (final entry in options.entries)
        CheckedPopupMenuItem(
          value: entry.key,
          checked: entry.key == value,
          child: Row(
            children: [
              Icon(entry.value.$2, size: 18),
              const SizedBox(width: 10),
              Text(entry.value.$1),
            ],
          ),
        ),
    ],
  );
}
