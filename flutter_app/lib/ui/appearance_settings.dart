import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import 'option_bar.dart';
import 'surfaces.dart';

class SettingsLayoutState {
  int tab = 0;
}

/// The visual language is fixed. Only reading size and brightness are personal.
class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({
    super.key,
    required this.controller,
    required this.layout,
  });
  final NotebookController controller;
  final SettingsLayoutState layout;

  @override
  Widget build(BuildContext context) {
    final a = controller.appearance;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FlexCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ansicht', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                OptionBar(
                  keyPrefix: 'appearance-mode',
                  options: const {
                    'light': 'Hell',
                    'dark': 'Dunkel',
                    'system': 'System',
                  },
                  value: a.mode,
                  minButtonHeight: 40,
                  onChanged: (mode) =>
                      controller.previewAppearance({'mode': mode}),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FlexCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Schriftgröße',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text('${(a.textScale * 100).round()} %'),
                  ],
                ),
                Slider(
                  key: const ValueKey('appearance-text-scale'),
                  min: .8,
                  max: 1.6,
                  divisions: 8,
                  label: '${(a.textScale * 100).round()} %',
                  value: a.textScale,
                  onChanged: (value) =>
                      controller.previewAppearance({'textScale': value}),
                  onChangeEnd: (_) => controller.flushAppearance(),
                ),
                const Divider(height: 24),
                Text(
                  'Gut lesbar. Schnell notiert.',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Beobachtungen, Aufgaben und Termine für die FLEX-Klasse.',
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const ValueKey('appearance-reset-size'),
                    onPressed: a.textScale == 1
                        ? null
                        : () =>
                              controller.previewAppearance({'textScale': 1.0}),
                    child: const Text('Standardgröße'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
