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
    this.draftCounts = const {},
  });
  final Pupil pupil;
  final VoidCallback onOpen;
  final ValueChanged<FlexSymbol> onShortcut;
  final Map<FlexSymbol, int> counts, draftCounts;
  final Set<FlexSymbol> due;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = Theme.of(context).colorScheme;
    final color = theme.cardTheme.color ?? scheme.surfaceContainerLow;
    final appearance = theme.extension<FlexSurfaces>()?.appearance;
    final palette = theme.extension<FlexSurfaces>()?.palette;
    final headerColor = theme.extension<FlexSurfaces>()?.header;
    final headerInk = legibleOn(
      Color.alphaBlend(
        headerColor ?? Colors.transparent,
        Color.alphaBlend(color, palette?.backdrop ?? scheme.surface),
      ),
    );
    final foreground =
        theme.extension<FlexSurfaces>()?.palette?.cardInk ??
        legibleOn(Color.alphaBlend(color, scheme.surface));
    final order =
        (appearance?.shortcutOrder ??
                FlexSymbol.values.map((e) => e.name).toList())
            .map((name) => FlexSymbol.values.byName(name))
            .toList();
    const labels = ['Ziele', 'Sozial', 'Arbeit', 'HÜ', 'Orga'];
    Widget shortcut(FlexSymbol symbol, {int flex = 1}) {
      final openCount = counts[symbol] ?? 0;
      final count = openCount + (draftCounts[symbol] ?? 0);
      final drafts = draftCounts[symbol] ?? 0;
      final label = labels[symbol.index];
      return Expanded(
        flex: flex,
        child: Semantics(
          button: true,
          label:
              '$label für ${pupil.name} öffnen, $openCount offen, $drafts Entwürfe',
          child: InkWell(
            key: ValueKey('shortcut-${pupil.id}-${symbol.name}'),
            onTap: () => onShortcut(symbol),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: EdgeInsets.symmetric(
                vertical: appearance?.compact == true ? 3 : 5,
                horizontal: 2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 64,
                    height: 42,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: FlexIcon(symbol, size: 32, color: foreground),
                        ),
                        if (count > 0)
                          Positioned(
                            right: 5,
                            top: 0,
                            child: Tooltip(
                              message:
                                  '$openCount offene Einträge · $drafts Entwürfe',
                              child: Container(
                                key: ValueKey(
                                  'count-${pupil.id}-${symbol.name}',
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 17,
                                  minHeight: 17,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: due.contains(symbol)
                                      ? const Color(0xffe9d399)
                                      : scheme.primary,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  count > 99 ? '99+' : '$count',
                                  textAlign: TextAlign.center,
                                  textScaler: TextScaler.noScaling,
                                  style: TextStyle(
                                    fontSize: 10,
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
                  ),

                  const SizedBox(height: 2),
                  Text(
                    label,
                    textAlign: TextAlign.center,
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
      borderRadius: BorderRadius.circular(appearance?.cardRadius ?? 22),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appearance?.cardRadius ?? 22),
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
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: EdgeInsets.fromLTRB(
                      22,
                      appearance?.compact == true ? 3 : 6,
                      18,
                      appearance?.compact == true ? 3 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: headerColor,
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
                              fontSize: 20,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -.3,
                              color: headerInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right, size: 20, color: headerInk),
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
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final symbol in order.take(3)) shortcut(symbol),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          for (final symbol in order.skip(3))
                            shortcut(symbol, flex: 2),
                          const Spacer(),
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
