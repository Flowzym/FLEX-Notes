import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import 'common.dart';
import 'draft_buffer.dart';
import 'flex_modal.dart';

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
  late OrgaEntry entry;
  late String draftId;
  late TextEditingController note, reminder;
  final itemText = TextEditingController();
  final itemFocus = FocusNode();
  String itemId = newId(), status = '';
  int draftRevision = 0;
  bool busy = false,
      dirty = false,
      canPop = false,
      reminderOpen = false,
      listOpen = false;
  String? error;
  Timer? debounce;
  Future<void> pending = Future.value();
  NotebookController get c => widget.controller;
  bool get isClass => entry.pupilId == null;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    entry = widget.entry;
    if (entry.revision == 0 && widget.draftId == null && isClass) {
      entry = entry.copyWith(isTask: true);
    }
    draftId = widget.draftId ?? newId();
    draftRevision =
        c.drafts.where((d) => d.id == draftId).firstOrNull?.editRevision ?? 0;
    note = TextEditingController(
      text: entry.body.isEmpty
          ? entry.title
          : entry.body.startsWith(entry.title)
          ? entry.body
          : '${entry.title}\n${entry.body}',
    );
    reminder = TextEditingController(text: entry.reminderText);
    reminderOpen = entry.reminderAtUtc != null;
    listOpen = entry.items.isNotEmpty;
  }

  OrgaEntry get value {
    final text = note.text.trim();
    final first = text.split('\n').first;
    return entry.copyWith(
      title: first.substring(0, first.length.clamp(0, 160)),
      body: note.text,
      reminderText: reminder.text,
      items: [
        ...entry.items,
        if (itemText.text.trim().isNotEmpty)
          CheckItem(id: itemId, text: itemText.text.trim()),
      ],
    );
  }

  void change([OrgaEntry? next]) {
    setState(() {
      if (next != null) entry = next;
      dirty = true;
      status = 'Entwurf wird gesichert …';
    });
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), persist);
  }

  Future<bool> persist() async {
    if (!dirty && draftRevision == 0) return true;
    final snapshot = value;
    pending = pending.catchError((Object _) {}).then((_) async {
      final saved = await c.repository.saveDraft(
        EditDraft(
          id: draftId,
          entry: snapshot,
          updatedAtUtc: utcNow(),
          editRevision: draftRevision,
        ),
      );
      draftRevision = saved.editRevision;
    });
    try {
      await pending;
      if (mounted) setState(() => status = 'Entwurf gesichert');
      return true;
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !busy) {
      debounce?.cancel();
      persist();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debounce?.cancel();
    note.dispose();
    reminder.dispose();
    itemText.dispose();
    itemFocus.dispose();
    super.dispose();
  }

  Future<void> pop() async {
    if (!mounted) return;
    setState(() => canPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> close() async {
    if (busy) return;
    setState(() => busy = true);
    debounce?.cancel();
    try {
      if (await persist()) {
        await c.reload();
        await pop();
      } else if (mounted &&
          await unsavedDraft(context, c.repository, {
            'type': 'orga',
            'draftId': draftId,
            'editRevision': draftRevision,
            'entry': value.toJson(),
          }) &&
          mounted) {
        await c.repository.discardDraft(draftId);
        await pop();
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> save({bool next = false}) async {
    if (busy) return;
    debounce?.cancel();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await pending.catchError((Object _) {});
      if (note.text.trim().isEmpty) {
        throw const DomainError('Bitte eine Notiz eingeben.');
      }
      if (reminderOpen && entry.reminderAtUtc == null) {
        throw const DomainError('Bitte ein Datum für die Erinnerung wählen.');
      }
      final saved = value.copyWith(
        dueDate: entry.isTask ? entry.dueDate : null,
        done: entry.isTask && entry.done,
      );
      saved.validate();
      await c.saveEntry(saved, draftId: draftId, draftRevision: draftRevision);
      if (next && !isClass && mounted) {
        final active = c.pupils.where((p) => !p.archived).toList();
        final index = active.indexWhere((p) => p.id == entry.pupilId);
        final owner = index >= 0 && index + 1 < active.length
            ? active[index + 1].id
            : entry.pupilId;
        final candidates = c.drafts
            .where((d) => d.entry.pupilId == owner && d.entry.revision == 0)
            .toList();
        final draft = candidates.length == 1 ? candidates.single : null;
        setState(() {
          entry =
              draft?.entry ??
              OrgaEntry.empty(pupilId: owner).copyWith(
                observedOn: entry.observedOn,
                observedTime: entry.observedTime,
              );
          draftId = draft?.id ?? newId();
          draftRevision = draft?.editRevision ?? 0;
          note.text = entry.body.isEmpty ? entry.title : entry.body;
          reminder.text = entry.reminderText;
          itemText.clear();
          itemId = newId();
          dirty = false;
          reminderOpen = entry.reminderAtUtc != null;
          listOpen = entry.items.isNotEmpty;
          status = owner == saved.pupilId
              ? 'Gespeichert. Letzter Schüler erreicht.'
              : candidates.length > 1
              ? '${candidates.length} vorhandene Entwürfe bleiben unter „Gesicherte Entwürfe“ verfügbar.'
              : draft == null
              ? ''
              : 'Entwurf fortgesetzt';
        });
      } else {
        await pop();
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  void addItem() {
    if (itemText.text.trim().isEmpty) return;
    final next = value;
    itemText.clear();
    itemId = newId();
    change(next);
  }

  void insertPrefix(String prefix) {
    final cursor = note.selection.isValid
        ? note.selection.start
        : note.text.length;
    final start = note.text.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0) + 1;
    note.value = TextEditingValue(
      text: note.text.replaceRange(start, start, prefix),
      selection: TextSelection.collapsed(offset: cursor + prefix.length),
    );
    change();
  }

  Future<void> date({bool due = false, bool remind = false}) async {
    final initial = remind && entry.reminderAtUtc != null
        ? DateTime.parse(entry.reminderAtUtc!).toLocal()
        : null;
    final selected = await pickFlexDate(
      context,
      date: due
          ? entry.dueDate ?? ''
          : remind
          ? initial == null
                ? ''
                : dateOnly(initial)
          : entry.observedOn,
      time: remind
          ? initial == null || !entry.reminderHasTime
                ? ''
                : '${initial.hour.toString().padLeft(2, '0')}:${initial.minute.toString().padLeft(2, '0')}'
          : entry.observedTime,
      allowTime: !due,
      title: due ? 'Datum wählen' : 'Datum & Uhrzeit',
    );
    if (selected == null || !mounted) return;
    if (due) {
      change(entry.copyWith(dueDate: selected.$1.isEmpty ? null : selected.$1));
    } else if (remind) {
      if (selected.$1.isEmpty) {
        change(
          entry.copyWith(
            reminderAtUtc: null,
            reminderState: ReminderState.none,
          ),
        );
        return;
      }
      final local = DateTime.parse(
        '${selected.$1}T${selected.$2.isEmpty ? '00:00' : selected.$2}:00',
      );
      if (selected.$2.isNotEmpty &&
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}' !=
              selected.$2) {
        setState(
          () => error =
              'Diese Ortszeit existiert wegen der Zeitumstellung nicht.',
        );
        return;
      }
      change(
        entry.copyWith(
          reminderAtUtc: local.toUtc().toIso8601String(),
          reminderHasTime: selected.$2.isNotEmpty,
          reminderZone: local.timeZoneName,
          reminderState: entry.done
              ? ReminderState.cancelled
              : ReminderState.planned,
        ),
      );
    } else {
      change(
        entry.copyWith(observedOn: selected.$1, observedTime: selected.$2),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: canPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
      child: Focus(
        autofocus: true,
        child: FlexModal(
          key: ValueKey(draftId),
          title: isClass
              ? const Text('Klassen-Orga')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.owner(entry),
                      style: const TextStyle(
                        fontFamily: 'FlexSans',
                        fontSize: 15,
                      ),
                    ),
                    const Text('Orga'),
                  ],
                ),
          accentColor: isClass
              ? null
              : Color(c.pupils.firstWhere((p) => p.id == entry.pupilId).color),
          onClose: busy ? null : close,
          content: AbsorbPointer(
            absorbing: busy,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(status, style: const TextStyle(fontSize: 12)),
                  ),
                const Text('Notiz oder Aufgabe'),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => listOpen = true);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) itemFocus.requestFocus();
                        });
                      },
                      child: const Text('☐ Checkliste'),
                    ),
                    TextButton(
                      onPressed: () => insertPrefix('• '),
                      child: const Text('• Aufzählung'),
                    ),
                    TextButton(
                      onPressed: () => insertPrefix('1. '),
                      child: const Text('1. Nummerierung'),
                    ),
                  ],
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          key: const ValueKey('orga-note'),
                          controller: note,
                          autofocus: true,
                          minLines: 4,
                          maxLines: 12,
                          maxLength: 12000,
                          decoration: const InputDecoration(
                            hintText: 'Notiz …',
                            counterText: '',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                          ),
                          onChanged: (_) => change(),
                        ),
                        for (final item in entry.items)
                          Row(
                            key: ValueKey(item.id),
                            children: [
                              Checkbox(
                                value: item.checked,
                                onChanged: (v) => change(
                                  entry.copyWith(
                                    items: entry.items
                                        .map(
                                          (i) => i.id == item.id
                                              ? i.copyWith(checked: v)
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
                                  onChanged: (v) => change(
                                    entry.copyWith(
                                      items: entry.items
                                          .map(
                                            (i) => i.id == item.id
                                                ? i.copyWith(text: v)
                                                : i,
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Listenpunkt entfernen',
                                onPressed: () => change(
                                  entry.copyWith(
                                    items: entry.items
                                        .where((i) => i.id != item.id)
                                        .toList(),
                                  ),
                                ),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        if (listOpen)
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: itemText,
                                  focusNode: itemFocus,
                                  decoration: const InputDecoration(
                                    labelText: 'Neuer Listenpunkt',
                                  ),
                                  onChanged: (_) => change(),
                                  onSubmitted: (_) => addItem(),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Listenpunkt hinzufügen',
                                onPressed: addItem,
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Als Aufgabe'),
                  value: entry.isTask,
                  onChanged: (v) =>
                      change(entry.copyWith(isTask: v, done: v && entry.done)),
                ),
                if (entry.isTask) ...[
                  TextButton.icon(
                    onPressed: () => date(due: true),
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      'Termin · optional: ${displayDate(entry.dueDate)}',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aufgabe erledigt'),
                    value: entry.done,
                    onChanged: (v) =>
                        change(v ? entry.complete() : entry.reopen()),
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Erinnern'),
                  value: reminderOpen,
                  onChanged: (v) => setState(() => reminderOpen = v),
                ),
                if (reminderOpen) ...[
                  TextButton.icon(
                    onPressed: entry.done ? null : () => date(remind: true),
                    icon: const Icon(Icons.calendar_month),
                    label: Text('Erinnern am: ${displayReminder(entry)}'),
                  ),
                  TextField(
                    controller: reminder,
                    decoration: const InputDecoration(
                      labelText: 'Erinnerungstext · optional',
                      hintText: 'Wie Notiz …',
                    ),
                    onChanged: (_) => change(),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Erinnerung quittiert'),
                    value: entry.reminderState == ReminderState.acknowledged,
                    onChanged: entry.reminderAtUtc == null || entry.done
                        ? null
                        : (v) => change(
                            entry.copyWith(
                              reminderState: v
                                  ? ReminderState.acknowledged
                                  : ReminderState.planned,
                            ),
                          ),
                  ),
                  const Text('Anzeige in der App'),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            if (!isClass) ...[
              TextButton.icon(
                onPressed: busy ? null : date,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  'Beobachtet am ${displayDate(entry.observedOn)} ${entry.observedTime}',
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Später ergänzen'),
                  value: entry.needsCompletion,
                  onChanged: busy
                      ? null
                      : (v) => change(entry.copyWith(needsCompletion: v)),
                ),
              ),
              TextButton(
                onPressed: busy ? null : () => save(next: true),
                child: const Text('Speichern & weiter'),
              ),
            ],
            FilledButton(
              onPressed: busy ? null : save,
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    ),
  );
}
