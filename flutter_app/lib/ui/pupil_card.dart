import 'package:flutter/material.dart';
import '../domain/models.dart';
import 'flex_icons.dart';
import 'surfaces.dart';

class PupilCard extends StatelessWidget {
  const PupilCard({
    super.key,
    required this.pupil,
    required this.onOpen,
    required this.onShortcut,
    required this.counts,
    required this.due,
  });
  final Pupil pupil;
  final VoidCallback onOpen;
  final ValueChanged<FlexSymbol> onShortcut;
  final Map<FlexSymbol, int> counts;
  final Set<FlexSymbol> due;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = Theme.of(context).colorScheme;
    final color = theme.cardTheme.color ?? scheme.surfaceContainerLow;
    final foreground = legibleOn(Color.alphaBlend(color, scheme.surface));
    const labels = ['Ziele', 'Sozial', 'Arbeit', 'HÜ', 'Orga'];
    Widget shortcut(FlexSymbol symbol) {
      final count = counts[symbol] ?? 0;
      final label = labels[symbol.index];
      return Expanded(
        child: Semantics(
          button: true,
          label:
              '$label für ${pupil.name} öffnen${count == 0 ? '' : ', $count offen'}',
          child: InkWell(
            key: ValueKey('shortcut-${pupil.id}-${symbol.name}'),
            onTap: () => onShortcut(symbol),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      FlexIcon(symbol, size: 26, color: foreground),
                      if (count > 0)
                        Positioned(
                          right: -9,
                          top: -7,
                          child: Tooltip(
                            message: '$count offene Einträge',
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 17,
                                minHeight: 17,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              decoration: BoxDecoration(
                                color: due.contains(symbol)
                                    ? const Color(0xffe9d399)
                                    : scheme.primary,
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: scheme.surface,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                count > 99 ? '99+' : '$count',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'FlexSans',
                                  fontSize: 10,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                  color: due.contains(symbol)
                                      ? const Color(0xff3b321b)
                                      : scheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: Color(pupil.color)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  key: ValueKey('pupil-open-${pupil.id}'),
                  onTap: onOpen,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.fromLTRB(22, 10, 18, 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            pupil.name,
                            style: TextStyle(
                              fontFamily: 'FlexSerif',
                              fontSize: 22,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -.3,
                              color: foreground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right, size: 20, color: foreground),
                      ],
                    ),
                  ),
                ),
                if (pupil.archived)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Archiviert'),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          shortcut(FlexSymbol.goal),
                          shortcut(FlexSymbol.social),
                          shortcut(FlexSymbol.work),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          shortcut(FlexSymbol.homework),
                          shortcut(FlexSymbol.orga),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
