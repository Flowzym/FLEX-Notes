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
    this.maxWidth = 640,
  });
  final Widget title, content;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final bool scrollable;
  final double maxWidth;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mobile = MediaQuery.sizeOf(context).width <= 700;
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
      insetPadding: EdgeInsets.all(mobile ? 10 : 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        key: const ValueKey('flex-modal-frame'),
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 440;
            final header = Container(
              color: surfaces?.header ?? scheme.surfaceContainerHigh,
              padding: EdgeInsets.fromLTRB(
                mobile ? 12 : 20,
                compact
                    ? 4
                    : mobile
                    ? 9
                    : 14,
                mobile ? 8 : 14,
                compact
                    ? 4
                    : mobile
                    ? 9
                    : 14,
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
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 16 : 24,
                vertical: compact
                    ? 8
                    : mobile
                    ? 11
                    : 12,
              ),
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
                  style: TextStyle(
                    color: footerForeground,
                    fontSize: 11,
                    height: 1.3,
                  ),
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
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 16 : 24,
                vertical: compact ? 12 : 22,
              ),
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
  final initial = time.isEmpty && requireTime ? '09:00' : time;
  final hour = TextEditingController(
    text: initial.isEmpty ? '' : initial.split(':').first,
  );
  final minute = TextEditingController(
    text: initial.isEmpty ? '' : initial.split(':').last,
  );
  String? error;
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => FlexModal(
        maxWidth: 430,
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 300,
              child: CalendarDatePicker(
                initialDate: selected,
                firstDate: DateTime(1900),
                lastDate: DateTime(2200),
                onDateChanged: (d) => update(() => selected = d),
              ),
            ),
            if (allowTime) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(requireTime ? 'Uhrzeit' : 'Uhrzeit · optional'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: hour,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stunde',
                        hintText: 'hh',
                      ),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.all(8), child: Text(':')),
                  Expanded(
                    child: TextFormField(
                      controller: minute,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minute',
                        hintText: 'mm',
                      ),
                    ),
                  ),
                ],
              ),
              if (!requireTime)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      hour.clear();
                      minute.clear();
                      update(() => error = null);
                    },
                    child: const Text('Ohne Uhrzeit'),
                  ),
                ),
            ],
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final empty =
                  hour.text.trim().isEmpty && minute.text.trim().isEmpty;
              final value = !allowTime || empty
                  ? ''
                  : '${hour.text.trim().padLeft(2, '0')}:${minute.text.trim().padLeft(2, '0')}';
              if ((requireTime && value.isEmpty) || !validTime(value)) {
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
  await Future<void>.delayed(const Duration(milliseconds: 250));
  hour.dispose();
  minute.dispose();
  return result;
}
