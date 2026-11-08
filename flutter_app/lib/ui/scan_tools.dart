import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/scan_images.dart';

/// Compact scanner tools retain readable labels and a full touch target.
class ScanTool extends StatelessWidget {
  const ScanTool({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(64, 56),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      backgroundColor: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      foregroundColor: selected
          ? Theme.of(context).colorScheme.onPrimaryContainer
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class ScanFilterStrip extends StatelessWidget {
  const ScanFilterStrip({
    super.key,
    required this.thumbnails,
    required this.selected,
    required this.onSelected,
  });
  final Map<String, Uint8List> thumbnails;
  final String selected;
  final ValueChanged<String>? onSelected;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 68 + MediaQuery.textScalerOf(context).scale(11) * 3,
    child: SingleChildScrollView(
      key: const ValueKey('scan-filter-strip'),
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final f in scanFilters.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Builder(
                builder: (context) {
                  final chosen = selected == f.key;
                  return SizedBox(
                    width: 74,
                    child: Semantics(
                      selected: chosen,
                      button: true,
                      child: InkWell(
                        key: ValueKey('scan-filter-${f.key}'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: onSelected == null
                            ? null
                            : () => onSelected!(f.key),
                        child: Column(
                          children: [
                            Container(
                              height: 60,
                              width: 62,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  width: chosen ? 3 : 1,
                                  color: chosen
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: thumbnails[f.key] == null
                                    ? const Icon(Icons.image_outlined)
                                    : Image.memory(
                                        thumbnails[f.key]!,
                                        fit: BoxFit.cover,
                                        excludeFromSemantics: true,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              f.value,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: chosen
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}
