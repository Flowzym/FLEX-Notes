import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import 'surfaces.dart';

/// Shared shell for entry editors, secondary dialogs and confirmations.
class FlexModal extends StatelessWidget {
  const FlexModal({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.onClose,
    this.scrollable = true,
  });
  final Widget title, content;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final bool scrollable;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surfaces = Theme.of(context).extension<FlexSurfaces>();
    final headerForeground = legibleOn(
      Color.alphaBlend(
        surfaces?.header ?? scheme.surfaceContainerHigh,
        scheme.surface,
      ),
    );
    final footerForeground = legibleOn(
      Color.alphaBlend(
        surfaces?.footer ?? scheme.surfaceContainerHigh,
        scheme.surface,
      ),
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 440;
            final header = Container(
              color: surfaces?.header ?? scheme.surfaceContainerHigh,
              padding: EdgeInsets.fromLTRB(
                20,
                compact ? 4 : 12,
                8,
                compact ? 4 : 12,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: headerForeground),
                child: Row(
                  children: [
                    Expanded(
                      child: DefaultTextStyle(
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: headerForeground,
                        ),
                        child: title,
                      ),
                    ),
                    if (onClose != null)
                      IconButton(
                        tooltip: 'Schließen und Eingaben sichern',
                        onPressed: onClose,
                        color: headerForeground,
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                ),
              ),
            );
            final footer = Container(
              width: double.infinity,
              color: surfaces?.footer ?? scheme.surfaceContainerHigh,
              padding: EdgeInsets.all(compact ? 8 : 16),
              child: Theme(
                data: Theme.of(context).copyWith(
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: footerForeground,
                    ),
                  ),
                  outlinedButtonTheme: OutlinedButtonThemeData(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: footerForeground,
                    ),
                  ),
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: footerForeground),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
                  ),
                ),
              ),
            );
            final body = Padding(
              padding: EdgeInsets.all(compact ? 12 : 20),
              child: content,
            );
            if (constraints.maxHeight < 230) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [header, body, footer],
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                header,
                Flexible(
                  child: scrollable ? SingleChildScrollView(child: body) : body,
                ),
                if (actions.isNotEmpty) footer,
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<bool> confirmFlex(
  BuildContext context,
  String title,
  String message, {
  String accept = 'Bestätigen',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => FlexModal(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(accept),
          ),
        ],
      ),
    ) ??
    false;

Future<(String, String)?> pickFlexDate(
  BuildContext context, {
  required String date,
  String time = '',
  bool allowTime = true,
  bool requireTime = false,
  String title = 'Datum und Uhrzeit',
}) async {
  var selected = DateTime.tryParse(date) ?? DateTime.now();
  var withTime = requireTime || time.isNotEmpty;
  final initial = time.isEmpty ? '09:00' : time;
  var hour = initial.split(':').first, minute = initial.split(':').last;
  String? error;
  return showDialog<(String, String)>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => FlexModal(
        title: Text(title),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: math.min(320, MediaQuery.sizeOf(context).height * .5),
                child: CalendarDatePicker(
                  initialDate: selected,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2200),
                  onDateChanged: (d) => update(() => selected = d),
                ),
              ),
              if (allowTime) ...[
                if (!requireTime)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Uhrzeit hinzufügen'),
                    value: withTime,
                    onChanged: (v) => update(() => withTime = v),
                  ),
                if (withTime)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: hour,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stunde',
                          ),
                          onChanged: (v) => hour = v,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(':'),
                      ),
                      Expanded(
                        child: TextFormField(
                          initialValue: minute,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Minute',
                          ),
                          onChanged: (v) => minute = v,
                        ),
                      ),
                    ],
                  ),
              ],
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final value = withTime && allowTime
                  ? '${hour.padLeft(2, '0')}:${minute.padLeft(2, '0')}'
                  : '';
              if (!validTime(value)) {
                update(() => error = 'Bitte eine gültige Uhrzeit eingeben.');
                return;
              }
              Navigator.pop(context, (dateOnly(selected), value));
            },
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    ),
  );
}
