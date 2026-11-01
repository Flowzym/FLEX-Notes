part of 'flex_modal.dart';

class _FlexDatePicker extends StatefulWidget {
  const _FlexDatePicker({
    required this.date,
    required this.time,
    required this.allowTime,
    required this.requireTime,
    required this.title,
  });
  final String date, time, title;
  final bool allowTime, requireTime;
  @override
  State<_FlexDatePicker> createState() => _FlexDatePickerState();
}

class _FlexDatePickerState extends State<_FlexDatePicker> {
  late DateTime selected, visible;
  late bool withTime;
  late int hour, minute;
  final dayFocus = <String, FocusNode>{};
  @override
  void dispose() {
    for (final node in dayFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void moveDay(int offset) {
    final next = selected.add(Duration(days: offset));
    if (next.year < 1900 || next.year > 2200) return;
    setState(() {
      selected = next;
      visible = DateTime(next.year, next.month);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) dayFocus[dateOnly(next)]?.requestFocus();
    });
  }

  static const months = [
    'Jänner',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];
  @override
  void initState() {
    super.initState();
    selected = DateTime.tryParse(widget.date) ?? DateTime.now();
    if (selected.year < 1900 || selected.year > 2200) selected = DateTime.now();
    visible = DateTime(selected.year, selected.month);
    withTime = widget.requireTime || widget.time.isNotEmpty;
    final now = DateTime.now();
    final parts = widget.time.split(':');
    hour = widget.time.isEmpty
        ? (widget.requireTime ? 9 : now.hour)
        : int.tryParse(parts.first) ?? 9;
    minute = widget.time.isEmpty
        ? (widget.requireTime ? 0 : now.minute)
        : int.tryParse(parts.last) ?? 0;
    hour = hour.clamp(0, 23);
    minute = minute.clamp(0, 59);
  }

  void month(int value) =>
      setState(() => visible = DateTime(visible.year, value));
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = DateUtils.getDaysInMonth(visible.year, visible.month);
    final offset = visible.weekday - 1;
    final rows = (days + offset + 6) ~/ 7;
    return FlexModal(
      maxWidth: 430,
      appearance:
          Theme.of(context).extension<FlexSurfaces>()?.appearance ??
          const Appearance(),
      title: Text(
        widget.title,
        style: const TextStyle(
          fontFamily: 'FlexSerif',
          fontSize: 22,
          fontWeight: FontWeight.w500,
        ),
      ),
      onClose: () => Navigator.pop(context),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Vorheriger Monat',
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                onPressed: visible.year == 1900 && visible.month == 1
                    ? null
                    : () => month(visible.month - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                flex: 3,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    key: const ValueKey('calendar-month'),
                    value: visible.month,
                    isExpanded: true,
                    items: [
                      for (var i = 1; i <= 12; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            months[i - 1],
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) month(v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 2,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    key: const ValueKey('calendar-year'),
                    value: visible.year,
                    isExpanded: true,
                    menuMaxHeight: 320,
                    items: [
                      for (var i = 1900; i <= 2200; i++)
                        DropdownMenuItem(value: i, child: Text('$i')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => visible = DateTime(v, visible.month));
                      }
                    },
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Nächster Monat',
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                onPressed: visible.year == 2200 && visible.month == 12
                    ? null
                    : () => month(visible.month + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final day in ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'])
                Expanded(
                  child: Center(
                    child: Text(day, style: const TextStyle(fontSize: 12)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var week = 0; week < rows; week++)
            Row(
              children: [
                for (var weekday = 0; weekday < 7; weekday++)
                  Expanded(
                    child: SizedBox(
                      height:
                          44 *
                          MediaQuery.textScalerOf(
                            context,
                          ).scale(1).clamp(1, 1.5),
                      child: Builder(
                        builder: (context) {
                          final day = week * 7 + weekday - offset + 1;
                          if (day < 1 || day > days) return const SizedBox();
                          final date = DateTime(
                            visible.year,
                            visible.month,
                            day,
                          );
                          final active = DateUtils.isSameDay(date, selected);
                          return Padding(
                            padding: const EdgeInsets.all(2),
                            child: TextButton(
                              key: ValueKey('calendar-day-${dateOnly(date)}'),
                              focusNode: dayFocus.putIfAbsent(
                                dateOnly(date),
                                () => FocusNode(
                                  onKeyEvent: (_, event) {
                                    if (event is! KeyDownEvent) {
                                      return KeyEventResult.ignored;
                                    }
                                    final offset = {
                                      LogicalKeyboardKey.arrowLeft: -1,
                                      LogicalKeyboardKey.arrowRight: 1,
                                      LogicalKeyboardKey.arrowUp: -7,
                                      LogicalKeyboardKey.arrowDown: 7,
                                    }[event.logicalKey];
                                    if (offset == null) {
                                      return KeyEventResult.ignored;
                                    }
                                    selected = date;
                                    moveDay(offset);
                                    return KeyEventResult.handled;
                                  },
                                ),
                              ),
                              onPressed: () {
                                setState(() => selected = date);
                                dayFocus[dateOnly(date)]?.requestFocus();
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                backgroundColor: active
                                    ? scheme.primary
                                    : Colors.transparent,
                                foregroundColor: active
                                    ? legibleOn(scheme.primary)
                                    : scheme.onSurface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text('$day'),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          if (widget.allowTime) ...[
            const SizedBox(height: 18),
            if (!withTime)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => withTime = true),
                  icon: const Icon(Icons.schedule),
                  label: const Text('Uhrzeit hinzufügen'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                    backgroundColor: scheme.onSurface.withValues(alpha: .07),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const ValueKey('calendar-hour'),
                      initialValue: hour,
                      isExpanded: true,
                      menuMaxHeight: 280,
                      decoration: const InputDecoration(labelText: 'Stunde'),
                      items: [
                        for (var i = 0; i < 24; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(i.toString().padLeft(2, '0')),
                          ),
                      ],
                      onChanged: (v) => setState(() => hour = v!),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(':'),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const ValueKey('calendar-minute'),
                      initialValue: minute,
                      isExpanded: true,
                      menuMaxHeight: 280,
                      decoration: const InputDecoration(labelText: 'Minute'),
                      items: [
                        for (var i = 0; i < 60; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(i.toString().padLeft(2, '0')),
                          ),
                      ],
                      onChanged: (v) => setState(() => minute = v!),
                    ),
                  ),
                  if (!widget.requireTime)
                    IconButton(
                      tooltip: 'Uhrzeit entfernen',
                      onPressed: () => setState(() => withTime = false),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
          ],
        ],
      ),
      footerContent: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: () => setState(() {
              selected = DateTime.now();
              visible = DateTime(selected.year, selected.month);
            }),
            child: const Text('Heute'),
          ),
          if (!widget.requireTime)
            TextButton(
              onPressed: () => Navigator.pop(context, ('', '')),
              child: const Text('Datum entfernen'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              dateOnly(selected),
              widget.allowTime && withTime
                  ? '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'
                  : '',
            )),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            ),
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
  }
}
