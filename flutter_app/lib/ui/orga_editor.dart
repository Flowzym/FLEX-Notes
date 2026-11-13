import 'compact_switch.dart';
import 'document_attachments.dart';
import 'option_bar.dart';
import 'option_swipe.dart';
import 'draft_actions.dart';
import 'symbol_button.dart';
import 'surfaces.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/drafts.dart';
import 'common.dart';
import 'draft_buffer.dart';
import 'flex_modal.dart';
import 'orga_list_editing.dart';
import 'entry_navigation.dart';
import 'person_assignment.dart';
import 'classroom_editor.dart';
import '../domain/classroom.dart';

class OrgaEditor extends StatefulWidget {
  const OrgaEditor({
    super.key,
    required this.controller,
    required this.entry,
    this.draftId,
    this.defaultToClassTask = true,
  });
  final NotebookController controller;
  final OrgaEntry entry;
  final String? draftId;
  final bool defaultToClassTask;
  @override
  State<OrgaEditor> createState() => _OrgaEditorState();
}

class _OrgaEditorState extends State<OrgaEditor> with WidgetsBindingObserver {
  late OrgaEntry entry;
  late OrgaTypeDraft typeDraft;
  Json? returnInitial;
  DialogDraft? returnDraft;
  bool returnOpen = false;
  late String draftId;
  late TextEditingController note, reminder;
  final itemText = TextEditingController();
  final itemFocus = FocusNode();
  final noteFocus = FocusNode();
  final itemNodes = <String, FocusNode>{};
  final itemControllers = <String, TextEditingController>{};
  String itemId = newId(), status = '';
  int draftRevision = 0, editGeneration = 0;
  late String baseline;
  bool busy = false,
      dirty = false,
      canPop = false,
      reminderOpen = false,
      listOpen = false;
  String? error;
  final errorAnchor = GlobalKey();
  void revealError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = errorAnchor.currentContext;
      if (mounted && target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: .5,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  Timer? debounce;
  Future<void> pending = Future.value();
  NotebookController get c => widget.controller;
  bool get isClass =>
      entry.pupilId == null && entry.otherParticipants.trim().isEmpty;
  Map<String, String> get kinds => {
    'note': 'Notiz',
    'task': 'Aufgabe',
    'appointment': 'Termin',
    if (entry.revision == 0) 'return': 'Rücklauf',
  };
  String get kind => entry.isAppointment
      ? 'appointment'
      : entry.isTask
      ? 'task'
      : 'note';

  void selectKind(String next) {
    if (next == 'return') {
      openReturn();
      return;
    }
    if (next == kind) return;
    change(typeDraft.select(entry, next), false);
  }

  Future<void> openReturn() async {
    if (busy || returnOpen) return;
    setState(() => busy = true);
    debounce?.cancel();
    try {
      if (!await persist() || !mounted) return;
      final current = value;
      returnInitial ??= {
        ...classroomInitial(ClassroomKind.returnList, c),
        'title': current.title,
        'note': current.body == current.title ? '' : current.body,
        'dueDate': current.dueDate ?? current.appointmentDate ?? '',
        'otherParticipants': current.otherParticipants,
        if (current.pupilId != null)
          'participants': [
            for (final pupil in c.pupils.where((p) => p.id == current.pupilId))
              {
                'pupilId': pupil.id,
                'name': pupil.name,
                'status': 'open',
                'note': '',
                'paid': 0,
              },
          ],
      };
      setState(() => returnOpen = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget returnEditor() => classroomEditor(
    c,
    ClassroomKind.returnList,
    fields: returnInitial,
    draft: returnDraft,
    entryOwner: 'FLEX-Klasse',
    navigation: (content, navigate) {
      void select(String next) {
        if (next == 'return') return;
        navigate((draft) {
          setState(() {
            returnDraft = draft;
            returnOpen = false;
          });
          selectKind(next);
        });
      }

      return OptionSwipe(
        key: const ValueKey('orga-kind-swipe'),
        onChanged: (previous) {
          if (previous) select('appointment');
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OptionBar(
              key: const ValueKey('orga-kind-bar'),
              minButtonHeight: 38,
              fontSize: 12,
              horizontalPadding: 2,
              keyPrefix: 'orga-kind',
              options: kinds,
              value: 'return',
              onChanged: select,
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      );
    },
  );

  void swipeKind(bool previous) {
    final options = kinds.keys.toList();
    selectKind(
      options[(options.indexOf(kind) + (previous ? -1 : 1)).clamp(
        0,
        options.length - 1,
      )],
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    entry = widget.entry;
    if (entry.revision == 0 &&
        widget.defaultToClassTask &&
        widget.draftId == null &&
        isClass &&
        !entry.isAppointment) {
      entry = entry.copyWith(isTask: true);
    }
    draftId = widget.draftId ?? newId();
    draftRevision =
        c.drafts.where((d) => d.id == draftId).firstOrNull?.editRevision ?? 0;
    note = TextEditingController(
      text: entry.body.isEmpty
          ? entry.title
          : entry.body.startsWith(entry.title) ||
                OrgaLine.parse(entry.body.split('\n').first).text == entry.title
          ? entry.body
          : '${entry.title}\n${entry.body}',
    );
    reminder = TextEditingController(text: entry.reminderText);
    reminderOpen = entry.reminderAtUtc != null;
    listOpen = entry.items.isNotEmpty;
    final draft = c.drafts.where((d) => d.id == draftId).firstOrNull;
    typeDraft = (draft?.typeDraft ?? const OrgaTypeDraft()).remember(entry);
    final original =
        c.entries.where((e) => e.id == entry.id).firstOrNull ??
        OrgaEntry.empty(
          pupilId: entry.pupilId,
        ).copyWith(observedOn: entry.observedOn, isTask: isClass);
    baseline =
        draft?.baseline ?? signature(widget.draftId == null ? value : original);
    dirty = draft != null && signature(value, typeDraft) == baseline;
  }

  String signature(OrgaEntry value, [OrgaTypeDraft? types]) => draftSignature({
    ...value.toJson(),
    'body': meaningfulOrgaText(value.body),
    'orgaTypeDraft': types?.toJson(excluding: value),
  });

  OrgaEntry get value {
    final first = OrgaLine.parse(
      note.text.trimLeft().split('\n').first,
    ).text.trim();
    final result = entry.copyWith(
      title: first.substring(0, first.length.clamp(0, 160)),
      body: note.text,
      reminderText: reminder.text,
    );
    return itemText.text.trim().isEmpty
        ? result
        : result.withTaskItems([
            ...entry.items,
            CheckItem(id: itemId, text: itemText.text.trim()),
          ]);
  }

  void change([OrgaEntry? next, bool rememberType = true]) {
    if (busy) return;
    setState(() {
      error = null;
      final candidate = next;
      if (candidate != null) {
        final listChanged =
            candidate.items.length != entry.items.length ||
            candidate.items.indexed.any(
              (e) =>
                  e.$2.id != entry.items[e.$1].id ||
                  e.$2.checked != entry.items[e.$1].checked,
            );
        final updated = listChanged
            ? candidate.withTaskItems(candidate.items)
            : candidate;
        if (rememberType) typeDraft = typeDraft.remember(updated);
        entry = updated;
      }
      dirty = true;
      editGeneration++;
      status = 'Entwurf wird gesichert …';
    });
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), persist);
  }

  bool get hasDraftAttachments {
    final scope = orgaDraftScanContext(c, draftId, value);
    return c.classroom.any(scope.matchesMaterial) ||
        c.dialogDrafts.any(scope.matchesDraft);
  }

  Future<bool> persist({bool force = false}) async {
    final snapshot = value, types = typeDraft, generation = editGeneration;
    if (dirty || force || draftRevision > 0) {
      pending = pending.catchError((Object _) {}).then((_) async {
        if (!force &&
            signature(snapshot, types) == baseline &&
            !hasDraftAttachments) {
          if (draftRevision > 0) {
            await c.repository.discardDraft(
              draftId,
              expectedRevision: draftRevision,
            );
            draftRevision = 0;
          }
        } else if (dirty || force && draftRevision == 0) {
          final saved = await c.repository.saveDraft(
            EditDraft(
              id: draftId,
              entry: snapshot,
              updatedAtUtc: utcNow(),
              editRevision: draftRevision,
              baseline: baseline,
              typeDraft: types,
            ),
          );
          draftRevision = saved.editRevision;
        }
        if (generation == editGeneration) dirty = false;
        await c.reload();
      });
    }
    try {
      await pending;
      if (mounted) {
        setState(
          () => status = dirty
              ? 'Entwurf wird gesichert …'
              : draftRevision > 0
              ? 'Entwurf gesichert'
              : '',
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          error = friendlyError(e);
          status = 'Entwurf nicht gesichert';
        });
      }
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
    noteFocus.dispose();
    for (final node in itemNodes.values) {
      node.dispose();
    }
    for (final controller in itemControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> navigateEntry(Future<void> Function() open) async {
    if (busy) return;
    setState(() => busy = true);
    debounce?.cancel();
    try {
      if (await persist() && mounted) {
        await open();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pop() async {
    if (!mounted) return;
    setState(() => canPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> deleteDraft() async {
    if (busy) return;
    setState(() => busy = true);
    debounce?.cancel();
    try {
      if (!await confirmEditorDraftDeletion(context) || !mounted) return;
      await pending.catchError((Object _) {});
      if (draftRevision > 0) {
        await c.repository.discardDraft(
          draftId,
          expectedRevision: draftRevision,
        );
      }
      dirty = false;
      draftRevision = 0;
      status = '';
      await c.reload();
      if (mounted) await pop();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => busy = false);
        if (dirty && !canPop) {
          debounce = Timer(const Duration(milliseconds: 400), persist);
        }
      }
    }
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
            'orgaTypeDraft': typeDraft.toJson(),
          }) &&
          mounted) {
        await c.repository.discardDraft(
          draftId,
          expectedRevision: draftRevision,
        );
        await pop();
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> save() async {
    if (busy) return;
    debounce?.cancel();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await pending.catchError((Object _) {});
      if (note.text.trim().isEmpty) {
        throw DomainError(
          entry.isAppointment
              ? 'Bitte den Termin benennen.'
              : entry.isTask
              ? 'Bitte eine Aufgabe eingeben.'
              : 'Bitte eine Notiz eingeben.',
        );
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
      if (!mounted) return;
      await pop();
    } catch (e) {
      if (mounted) {
        setState(() => error = friendlyError(e));
        revealError();
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> openAttachments({bool scan = false}) async {
    if (busy) return;
    setState(() => busy = true);
    debounce?.cancel();
    try {
      if (!await persist(force: true) || !mounted) return;
      final scope = orgaDraftScanContext(c, draftId, value);
      if (scan) {
        await scanAndShow(context, c, scope);
      } else {
        await showContextDocuments(
          context,
          c,
          scope,
          additionalScopes: [orgaScanContext(c, value)],
        );
      }
      if (mounted) await persist();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void addItem({bool fromEnter = false}) {
    if (itemText.text.trim().isEmpty) {
      if (!fromEnter) return;
      setState(() => listOpen = false);
      noteFocus.requestFocus();
      return;
    }
    final next = value;
    itemText.clear();
    itemId = newId();
    change(next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) itemFocus.requestFocus();
    });
  }

  void nextItem(String id) {
    final index = entry.items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    if (entry.items[index].text.trim().isEmpty) {
      change(
        entry.copyWith(
          items: entry.items.where((item) => item.id != id).toList(),
        ),
      );
      setState(() => listOpen = false);
      noteFocus.requestFocus();
      return;
    }
    final controller = itemControllers[id]!;
    final selection = controller.selection.isValid
        ? controller.selection
        : TextSelection.collapsed(offset: controller.text.length);
    final before = controller.text.substring(0, selection.start),
        after = controller.text.substring(selection.end);
    controller.value = TextEditingValue(
      text: before,
      selection: TextSelection.collapsed(offset: before.length),
    );
    final nextId = newId(), items = [...entry.items];
    items[index] = items[index].copyWith(text: before);
    items.insert(index + 1, CheckItem(id: nextId, text: after));
    change(entry.copyWith(items: items));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) itemNodes[nextId]?.requestFocus();
    });
  }

  void applyList(TextEditingValue result) {
    if (result.text.length > 12000) return;
    note.value = result;
    noteFocus.requestFocus();
    change();
  }

  void insertPrefix(String prefix) => applyList(
    styleOrgaLines(note.value, prefix == '1. ' ? 'number' : 'bullet'),
  );

  Future<void> date({
    bool due = false,
    bool remind = false,
    bool appointment = false,
  }) async {
    final initial = remind && entry.reminderAtUtc != null
        ? DateTime.parse(entry.reminderAtUtc!).toLocal()
        : null;
    final selected = await pickFlexDate(
      context,
      date: appointment
          ? entry.appointmentDate ?? dateOnly(DateTime.now())
          : due
          ? entry.dueDate ?? ''
          : remind
          ? initial == null
                ? ''
                : dateOnly(initial)
          : entry.observedOn,
      time: appointment
          ? entry.appointmentTime
          : remind
          ? initial == null || !entry.reminderHasTime
                ? ''
                : '${initial.hour.toString().padLeft(2, '0')}:${initial.minute.toString().padLeft(2, '0')}'
          : entry.observedTime,
      allowTime: !due,
      allowDateClear: !appointment,
      title: appointment
          ? 'Termin'
          : due
          ? 'Datum wählen'
          : 'Datum & Uhrzeit',
    );
    if (selected == null || !mounted) return;
    if (appointment) {
      if (selected.$1.isEmpty) return;
      change(
        entry.copyWith(
          appointmentDate: selected.$1,
          appointmentTime: selected.$2,
        ),
      );
    } else if (due) {
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
  Widget build(BuildContext context) =>
      returnOpen ? returnEditor() : orgaEditor();

  Widget orgaEditor() => PopScope(
    canPop: canPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
      child: Focus(
        autofocus: true,
        child: FlexModal(
          closeLabel: 'Schließen und Entwurf sichern',
          key: ValueKey(draftId),
          title: Text(isClass ? 'Klassen-Orga' : 'Orga'),
          headerContent: EntryPageHeader(
            owner: isClass ? 'FLEX-Klasse' : c.owner(entry),
            title: isClass ? 'Klassen-Orga' : 'Orga',
            onClose: busy ? null : close,
            titleActions: [
              if (dirty || draftRevision > 0)
                EditorDraftDeleteButton(onPressed: busy ? null : deleteDraft),
            ],
            actions: [
              AnimatedBuilder(
                animation: c,
                builder: (_, _) => EntryHeaderButton(
                  key: const ValueKey('entry-drafts'),
                  label: 'Entwürfe',
                  icon: Icons.edit_note,
                  count: entryDraftCount(
                    c,
                    pupilId: entry.pupilId,
                    exclude: draftId,
                  ),
                  onPressed: busy
                      ? null
                      : () => navigateEntry(
                          () => showEntryDrafts(
                            context,
                            c,
                            pupilId: entry.pupilId,
                            exclude: draftId,
                          ),
                        ),
                ),
              ),
            ],
          ),
          onClose: busy ? null : close,
          content: AbsorbPointer(
            absorbing: busy,
            child: OptionSwipe(
              key: const ValueKey('orga-kind-swipe'),
              onChanged: swipeKind,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (status.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(status, style: const TextStyle(fontSize: 12)),
                    ),
                  OptionBar(
                    key: const ValueKey('orga-kind-bar'),
                    minButtonHeight: 38,
                    fontSize: kinds.length > 3 ? 12 : 14,
                    horizontalPadding: kinds.length > 3 ? 2 : 6,
                    keyPrefix: 'orga-kind',
                    options: kinds,
                    value: kind,
                    onChanged: selectKind,
                  ),
                  const SizedBox(height: 12),
                  PersonAssignmentField(
                    pupils: c.pupils,
                    selected: {if (entry.pupilId != null) entry.pupilId!},
                    locked: {
                      if (entry.revision > 0 && entry.pupilId != null)
                        entry.pupilId!,
                    },
                    multiple: false,
                    canChangePupils: entry.revision == 0,
                    otherNames: entry.otherParticipants,
                    onChanged: (ids, names) => change(
                      entry.copyWith(
                        pupilId: ids.firstOrNull,
                        otherParticipants: names,
                      ),
                    ),
                  ),
                  if (entry.isAppointment)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton.icon(
                        key: const ValueKey('orga-appointment-date'),
                        onPressed: () => date(appointment: true),
                        icon: const Icon(Icons.event_outlined),
                        label: Text(
                          '${displayDate(entry.appointmentDate)} · ${entry.appointmentTime.isEmpty ? 'Ganztägig' : entry.appointmentTime}',
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.isAppointment
                              ? 'Termin und Notizen'
                              : entry.isTask
                              ? 'Aufgabe'
                              : 'Notiz',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          FlexSymbolButton(
                            key: const ValueKey('orga-list-check'),
                            label: entry.isTask
                                ? 'Unteraufgaben'
                                : 'Checkliste',
                            icon: Icons.checklist,
                            onPressed: () {
                              setState(() => listOpen = true);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) itemFocus.requestFocus();
                              });
                            },
                          ),
                          FlexSymbolButton(
                            key: const ValueKey('orga-list-bullet'),
                            label: 'Aufzählung',
                            icon: Icons.format_list_bulleted,
                            onPressed: () => insertPrefix('• '),
                          ),
                          FlexSymbolButton(
                            key: const ValueKey('orga-list-number'),
                            label: 'Nummerierung',
                            icon: Icons.format_list_numbered,
                            onPressed: () => insertPrefix('1. '),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DecoratedBox(
                    key: const ValueKey('orga-text-editor'),
                    decoration: BoxDecoration(
                      color: Theme.of(context).inputDecorationTheme.fillColor,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(
                        FlexDesign.fieldRadius,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Focus(
                            onKeyEvent: (_, event) {
                              final keyboard = HardwareKeyboard.instance;
                              if (event is KeyDownEvent &&
                                  (event.logicalKey ==
                                          LogicalKeyboardKey.enter ||
                                      event.logicalKey ==
                                          LogicalKeyboardKey.numpadEnter) &&
                                  !keyboard.isControlPressed &&
                                  !keyboard.isAltPressed &&
                                  !keyboard.isMetaPressed) {
                                if (keyboard.isShiftPressed &&
                                    note.selection.isValid &&
                                    note.value.composing.isCollapsed) {
                                  final start = note.selection.start,
                                      end = note.selection.end;
                                  applyList(
                                    TextEditingValue(
                                      text: note.text.replaceRange(
                                        start,
                                        end,
                                        '\n',
                                      ),
                                      selection: TextSelection.collapsed(
                                        offset: start + 1,
                                      ),
                                    ),
                                  );
                                  return KeyEventResult.handled;
                                }
                                final result = continueOrgaLine(note.value);
                                if (result != null) {
                                  applyList(result);
                                  return KeyEventResult.handled;
                                }
                              }
                              return KeyEventResult.ignored;
                            },
                            child: TextField(
                              key: const ValueKey('orga-note'),
                              focusNode: noteFocus,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              inputFormatters: [OrgaListFormatter()],
                              controller: note,
                              autofocus: true,
                              minLines: 4,
                              maxLines: 12,
                              maxLength: 12000,
                              decoration: InputDecoration(
                                hintText: entry.isAppointment
                                    ? 'Termin …'
                                    : entry.isTask
                                    ? 'Aufgabe …'
                                    : 'Notiz …',
                                counterText: '',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                              ),
                              onChanged: (_) => change(),
                            ),
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
                                    key: ValueKey('orga-item-${item.id}'),
                                    focusNode: itemNodes.putIfAbsent(
                                      item.id,
                                      () => FocusNode(),
                                    ),
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) => nextItem(item.id),
                                    controller: itemControllers.putIfAbsent(
                                      item.id,
                                      () => TextEditingController(
                                        text: item.text,
                                      ),
                                    ),
                                    decoration: InputDecoration(
                                      labelText: entry.isTask
                                          ? 'Unteraufgabe'
                                          : 'Listenpunkt',
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
                                  tooltip: entry.isTask
                                      ? 'Unteraufgabe entfernen'
                                      : 'Listenpunkt entfernen',
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
                          if (listOpen || entry.isTask)
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    key: const ValueKey('orga-new-item'),
                                    textInputAction: TextInputAction.next,
                                    controller: itemText,
                                    focusNode: itemFocus,
                                    decoration: InputDecoration(
                                      labelText: entry.isTask
                                          ? 'Neue Unteraufgabe'
                                          : 'Neuer Listenpunkt',
                                    ),
                                    onChanged: (_) => change(),
                                    onSubmitted: (_) =>
                                        addItem(fromEnter: true),
                                  ),
                                ),
                                IconButton(
                                  tooltip: entry.isTask
                                      ? 'Unteraufgabe hinzufügen'
                                      : 'Listenpunkt hinzufügen',
                                  onPressed: addItem,
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (entry.isTask) ...[
                    OutlinedButton.icon(
                      onPressed: () => date(due: true),
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        'Fällig am · optional: ${displayDate(entry.dueDate)}',
                      ),
                    ),
                    CompactSwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline),
                      title: const Text(
                        'Aufgabe erledigt',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      value: entry.done,
                      onChanged: (v) =>
                          change(v ? entry.complete() : entry.reopen()),
                    ),
                  ],
                  CompactSwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_none_outlined),
                    title: const Text(
                      'Erinnern',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    value: reminderOpen,
                    onChanged: (v) {
                      setState(() => reminderOpen = v);
                      if (!v) {
                        change(
                          entry.copyWith(
                            reminderAtUtc: null,
                            reminderState: ReminderState.none,
                          ),
                        );
                      }
                    },
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
                    CompactSwitchListTile(
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
                  const SizedBox(height: 12),
                  DocumentAttachmentSection(
                    controller: c,
                    scope: orgaDraftScanContext(c, draftId, value),
                    additionalScopes: [orgaScanContext(c, value)],
                    onScan: () => openAttachments(scan: true),
                    onDocuments: () => openAttachments(),
                  ),
                  if (error != null)
                    Padding(
                      key: errorAnchor,
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
          ),
          footerContent: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                child: CompactSwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Später ergänzen'),
                  value: entry.needsCompletion,
                  onChanged: busy
                      ? null
                      : (v) => change(entry.copyWith(needsCompletion: v)),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('cancel-editor'),
                      onPressed: busy ? null : close,
                      child: const Text('Abbrechen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : save,
                      child: const Text('Speichern'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
