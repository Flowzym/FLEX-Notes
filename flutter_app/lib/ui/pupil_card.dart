import 'package:flutter/material.dart';
import '../domain/models.dart';
import 'flex_icons.dart';
import 'surfaces.dart';

/// A pupil is an open row: name and all five recording actions stay visible.
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
    final order =
        (theme.extension<FlexSurfaces>()?.appearance.shortcutOrder ??
                FlexSymbol.values.map((e) => e.name).toList())
            .map(FlexSymbol.values.byName);
    const labels = ['Ziele', 'Sozial', 'Arbeit', 'HÜ', 'Orga'];
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: scheme.outlineVariant, width: .8),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: InkWell(
                  key: ValueKey('pupil-open-${pupil.id}'),
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 25,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            pupil.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (pupil.archived)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text('Archiviert'),
                          ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: scheme.onSurface,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final symbol in order)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final open = counts[symbol] ?? 0;
                          final drafts = draftCounts[symbol] ?? 0;
                          final count = open + drafts;
                          final label = labels[symbol.index];
                          return Semantics(
                            button: true,
                            label:
                                '$label für ${pupil.name} öffnen, $open offen, $drafts Entwürfe${due.contains(symbol) ? ', fällig' : ''}',
                            excludeSemantics: true,
                            child: InkWell(
                              key: ValueKey(
                                'shortcut-${pupil.id}-${symbol.name}',
                              ),
                              onTap: () => onShortcut(symbol),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 0,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      height: 30,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Align(
                                            alignment: Alignment.topCenter,
                                            child: FlexIcon(
                                              symbol,
                                              size: 27,
                                              color: scheme.primary,
                                            ),
                                          ),
                                          if (count > 0)
                                            Positioned(
                                              right: 0,
                                              bottom: -1,
                                              child: Container(
                                                key: ValueKey(
                                                  'count-${pupil.id}-${symbol.name}',
                                                ),
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 16,
                                                      minHeight: 16,
                                                    ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: due.contains(symbol)
                                                      ? const Color(0xffe3d6b4)
                                                      : scheme.primaryContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(99),
                                                  border: Border.all(
                                                    color: scheme.surface,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Text(
                                                  count > 99 ? '99+' : '$count',
                                                  textAlign: TextAlign.center,
                                                  textScaler:
                                                      TextScaler.noScaling,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    height: 1.2,
                                                    fontWeight: FontWeight.w600,
                                                    color: due.contains(symbol)
                                                        ? const Color(
                                                            0xff52442b,
                                                          )
                                                        : scheme
                                                              .onPrimaryContainer,
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
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: 12,
                                            height: 1.25,
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
            ],
          ),
        ),
      ),
    );
  }
}
