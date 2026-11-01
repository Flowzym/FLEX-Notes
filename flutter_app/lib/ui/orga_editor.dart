import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import 'common.dart';
import 'flex_modal.dart';
import 'flex_icons.dart';

class OrgaEditor extends StatefulWidget {
  const OrgaEditor({
    super.key,
    required this.controller,
    required this.entry,
    this.draftId,
  });
  final NotebookController controller;
  final OrgaEntry entry;
  final String? draftId;
  @override
  State<OrgaEditor> createState() => _OrgaEditorState();
}

class _OrgaEditorState extends State<OrgaEditor> with WidgetsBindingObserver {
  late OrgaEntry _entry;
  late String _draftId;
  late TextEditingController _title, _body;
  final _itemText = TextEditingController();
  String _newItemId = newId();
  Timer? _debounce;
  Future<void> _pending = Future.value();
  bool _busy = false, _canPop = false, _dirty = false;
  String? _error;
  String _draftStatus = 'Änderungen werden als Entwurf gesichert.';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entry = widget.entry;
    _draftId = widget.draftId ?? newId();
    _title = TextEditingController(text: _entry.title);
    _body = TextEditingController(text: _entry.body);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _title.dispose();
    _body.dispose();
    _itemText.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_busy) {
      _debounce?.cancel();
      _writeDraft();
    }
  }

  OrgaEntry get _value => _entry.copyWith(
    title: _title.text,
    body: _body.text,
    items: [
      ..._entry.items,
      if (_itemText.text.trim().isNotEmpty)
        CheckItem(id: _newItemId, text: _itemText.text.trim()),
    ],
  );
  void _change([OrgaEntry? value]) {
    setState(() {
      if (value != null) _entry = value;
      _dirty = true;
      _draftStatus = 'Entwurf wird gesichert …';
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _writeDraft();
    });
  }

  Future<bool> _writeDraft() async {
    if (!_dirty && widget.draftId == null) return true;
    final draft = EditDraft(
      id: _draftId,
      entry: _value,
      updatedAtUtc: utcNow(),
    );
    _pending = _pending
        .catchError((Object _) {})
        .then((_) => widget.controller.repository.saveDraft(draft));
    try {
      await _pending;
      if (mounted) {
        setState(() {
          _error = null;
          _draftStatus = 'Entwurf auf diesem Gerät gesichert';
        });
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _draftStatus = 'Entwurf noch nicht gesichert';
        });
      }
      return false;
    }
  }

  Future<void> _pop() async {
    if (!mounted) return;
    setState(() => _canPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _close() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    _debounce?.cancel();
    try {
      if (await _writeDraft()) {
        await widget.controller.reload();
        await _pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _save() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    _debounce?.cancel();
    if (_itemText.text.trim().isNotEmpty) {
      _addItem();
      _debounce?.cancel();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _pending.catchError((Object _) {});
      final value = _value;
      value.validate();
      await widget.controller.saveEntry(value, draftId: _draftId);
      await _pop();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  void _addItem() {
    if (_itemText.text.trim().isEmpty) return;
    final next = _entry.copyWith(
      items: [
        ..._entry.items,
        CheckItem(id: _newItemId, text: _itemText.text.trim()),
      ],
    );
    _itemText.clear();
    _newItemId = newId();
    _change(next);
  }

  Future<void> _pickDue() async {
    final initial = _entry.dueDate == null
        ? DateTime.now()
        : DateTime.parse(_entry.dueDate!);
    final picked = await pickFlexDate(
      context,
      date: dateOnly(initial),
      allowTime: false,
    );
    if (picked != null && mounted) _change(_entry.copyWith(dueDate: picked.$1));
  }

  Future<void> _pickReminder() async {
    final initial = _entry.reminderAtUtc == null
        ? DateTime.now().add(const Duration(hours: 1))
        : DateTime.parse(_entry.reminderAtUtc!).toLocal();
    final picked = await pickFlexDate(
      context,
      date: dateOnly(initial),
      time:
          '${initial.hour.toString().padLeft(2, '0')}:${initial.minute.toString().padLeft(2, '0')}',
      requireTime: true,
    );
    if (picked == null || !mounted) return;
    final local = DateTime.parse('${picked.$1}T${picked.$2}:00');
    if (local.hour != int.parse(picked.$2.split(':')[0]) ||
        local.minute != int.parse(picked.$2.split(':')[1])) {
      setState(
        () =>
            _error = 'Diese Ortszeit existiert wegen der Zeitumstellung nicht.',
      );
      return;
    }
    _change(
      _entry.copyWith(
        reminderAtUtc: local.toUtc().toIso8601String(),
        reminderZone:
            '${local.timeZoneName} (${local.timeZoneOffset.inMinutes} min)',
        reminderState: ReminderState.planned,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _canPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _close();
    },
    child: CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Focus(
        autofocus: true,
        child: FlexModal(
          title: Row(
            children: [
              const FlexIcon(FlexSymbol.orga),
              const SizedBox(width: 12),
              Text(_entry.revision == 0 ? 'Orga anlegen' : 'Orga bearbeiten'),
            ],
          ),
          onClose: _busy ? null : _close,
          content: AbsorbPointer(
            absorbing: _busy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.controller.owner(_entry),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _title,
                  autofocus: true,
                  maxLength: 160,
                  decoration: const InputDecoration(labelText: 'Titel'),
                  onChanged: (_) => _change(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _body,
                  minLines: 4,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Notiz',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => _change(),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Als Aufgabe'),
                  subtitle: const Text(
                    'Notizen zählen nicht als offene Aufgaben.',
                  ),
                  value: _entry.isTask,
                  onChanged: (value) => _change(
                    _entry.copyWith(
                      isTask: value,
                      done: value && _entry.done,
                      dueDate: value ? _entry.dueDate : null,
                    ),
                  ),
                ),
                if (_entry.isTask) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aufgabentermin'),
                    subtitle: Text(displayDate(_entry.dueDate)),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Termin wählen',
                          onPressed: _pickDue,
                          icon: const Icon(Icons.calendar_month),
                        ),
                        if (_entry.dueDate != null)
                          IconButton(
                            tooltip: 'Termin entfernen',
                            onPressed: () =>
                                _change(_entry.copyWith(dueDate: null)),
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aufgabe erledigt'),
                    value: _entry.done,
                    onChanged: (value) => _change(
                      value == true ? _entry.complete() : _entry.reopen(),
                    ),
                  ),
                ],
                const Divider(height: 32),
                Text(
                  'Checkliste',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Listenpunkte und Aufgabenabschluss sind unabhängig.',
                  ),
                ),
                for (final item in _entry.items)
                  Row(
                    key: ValueKey(item.id),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: item.checked,
                        onChanged: (checked) => _change(
                          _entry.copyWith(
                            items: _entry.items
                                .map(
                                  (i) => i.id == item.id
                                      ? i.copyWith(checked: checked)
                                      : i,
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          initialValue: item.text,
                          decoration: const InputDecoration(
                            labelText: 'Listenpunkt',
                          ),
                          onChanged: (text) => _change(
                            _entry.copyWith(
                              items: _entry.items
                                  .map(
                                    (i) => i.id == item.id
                                        ? i.copyWith(text: text)
                                        : i,
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Listenpunkt entfernen',
                        onPressed: () => _change(
                          _entry.copyWith(
                            items: _entry.items
                                .where((i) => i.id != item.id)
                                .toList(),
                          ),
                        ),
                        icon: const Icon(Icons.remove_circle),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _itemText,
                        decoration: const InputDecoration(
                          labelText: 'Neuer Listenpunkt',
                        ),
                        onChanged: (_) => _change(),
                        onSubmitted: (_) => _addItem(),
                      ),
                    ),
                    IconButton(
                      onPressed: _addItem,
                      tooltip: 'Listenpunkt hinzufügen',
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const Divider(height: 32),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Erinnerung'),
                  subtitle: Text(
                    _entry.reminderAtUtc == null
                        ? 'Keine Erinnerung'
                        : '${displayDate(_entry.reminderAtUtc)}\n${_entry.reminderZone}\n${switch (_entry.reminderState) {
                            ReminderState.planned => 'Aktiv',
                            ReminderState.acknowledged => 'Quittiert',
                            ReminderState.cancelled => 'Beendet',
                            ReminderState.none => '',
                          }}',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Erinnerung setzen oder reaktivieren',
                        onPressed: _entry.done ? null : _pickReminder,
                        icon: const Icon(Icons.notification_add),
                      ),
                      if (_entry.reminderAtUtc != null)
                        IconButton(
                          tooltip: 'Erinnerung entfernen',
                          onPressed: () => _change(
                            _entry.copyWith(
                              reminderAtUtc: null,
                              reminderState: ReminderState.none,
                            ),
                          ),
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                ),
                const Text(
                  'Erinnerungen erscheinen vorerst innerhalb der App. Termin und Erinnerung sind unabhängig.',
                ),
                if (_entry.reminderState == ReminderState.planned)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _change(_entry.acknowledge()),
                      icon: const Icon(Icons.notifications_off),
                      label: const Text('Erinnerung quittieren'),
                    ),
                  ),
                const Divider(height: 32),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dokumentation noch ergänzen'),
                  value: _entry.needsCompletion,
                  onChanged: (value) =>
                      _change(_entry.copyWith(needsCompletion: value)),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final selected = await pickFlexDate(
                          context,
                          date: _entry.observedOn.isEmpty
                              ? dateOnly(DateTime.now())
                              : _entry.observedOn,
                          time: _entry.observedTime,
                        );
                        if (selected != null && mounted) {
                          _change(
                            _entry.copyWith(
                              observedOn: selected.$1,
                              observedTime: selected.$2,
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  'Beobachtet am ${displayDate(_entry.observedOn.isEmpty ? dateOnly(DateTime.now()) : _entry.observedOn)} ${_entry.observedTime}',
                ),
              ),
            ),
            Text(_draftStatus),
            OutlinedButton(
              onPressed: _busy ? null : _close,
              child: const Text('Als Entwurf schließen'),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_busy ? 'Speichern …' : 'Speichern'),
            ),
          ],
        ),
      ),
    ),
  );
}
