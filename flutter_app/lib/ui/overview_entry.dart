import 'package:flutter/material.dart';
import 'flex_icons.dart';
import 'surfaces.dart';

/// Read-only summary. Status changes belong to the entry's detail dialog.
class OverviewEntry extends StatelessWidget {
  const OverviewEntry({
    super.key,
    required this.id,
    required this.title,
    required this.meta,
    required this.summary,
    required this.status,
    required this.order,
    required this.symbol,
    required this.onOpen,
    required this.onEdit,
  });
  final String id, title, meta, summary, status, order;
  final FlexSymbol symbol;
  final VoidCallback onOpen, onEdit;
  @override
  Widget build(BuildContext context) => FlexCard(
    builder: (context) => InkWell(
      key: ValueKey('overview-open-$id'),
      onTap: onOpen,
      borderRadius: BorderRadius.circular(
        Theme.of(context).extension<FlexSurfaces>()?.appearance?.cardRadius ??
            22,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: FlexIcon(
                symbol,
                size: 23,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (summary.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  if (status.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Column(
              children: [
                IconButton(
                  tooltip: 'Bearbeiten',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 19),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
