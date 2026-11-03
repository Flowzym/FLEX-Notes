import 'compact_switch.dart';
import 'draft_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/drafts.dart';
import 'common.dart';
import 'draft_buffer.dart';
import 'flex_modal.dart';

const pupilPalette = [
  0xff53747e,
  0xff756582,
  0xff49765a,
  0xffb87943,
  0xffac5d72,
  0xff487f85,
  0xff8a7845,
  0xff6478a6,
  0xff8c6553,
  0xff73834c,
];

class PupilEditor extends StatefulWidget {
  const PupilEditor({
    super.key,
    required this.controller,
    this.pupil,
    this.draft,
  });
  final NotebookController controller;
  final Pupil? pupil;
  final DialogDraft? draft;
  @override
  State<PupilEditor> createState() => _PupilEditorState();
}

class _PupilEditorState extends State<PupilEditor> with WidgetsBindingObserver {
  late Pupil pupil;
  late DraftBuffer buffer;
  late TextEditingController name, colorText;
  bool busy = false, canPop = false, customColor = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pupil = widget.draft == null
        ? widget.pupil ??
              Pupil(
                id: newId(),
                name: '',
                color:
                    pupilPalette
                        .where(
                          (v) => !widget.controller.pupils.any(
                            (p) => p.color == v,
                          ),
                        )
                        .firstOrNull ??
                    pupilPalette.first,
              )
        : Pupil.fromJson(widget.draft!.data);
    name = TextEditingController(text: pupil.name);
    colorText = TextEditingController(text: hex(pupil.color));
    buffer = DraftBuffer(
      widget.controller.repository,
      type: 'pupil',
      ownerId: pupil.id,
      data: pupil.toJson(),
      baseline: draftSignature(
        (widget.pupil ??
                widget.controller.pupils
                    .where((p) => p.id == pupil.id)
                    .firstOrNull ??
                pupil.copyWith(name: ''))
            .toJson(),
      ),
      onPersisted: widget.controller.reload,
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
      initial: widget.draft,
    );
  }

  String hex(int color) =>
      '#${(color & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  void change(Pupil value) {
    if (busy) return;
    setState(() => pupil = value);
    buffer.change(value.toJson());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !busy) {
      buffer.flush().catchError((Object e) {
        buffer.error = e;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    buffer.dispose();
    name.dispose();
    colorText.dispose();
    super.dispose();
  }

  Future<void> pop() async {
    setState(() => canPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> deleteDraft() async {
    if (busy) return;
    setState(() => busy = true);
    buffer.timer?.cancel();
    try {
      if (!await confirmEditorDraftDeletion(context) || !mounted) {
        await buffer.flush();
        return;
      }
      await buffer.discard();
      await widget.controller.reload();
      if (mounted) await pop();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> close() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await buffer.flush();
      if (mounted) await pop();
    } catch (e) {
      if (mounted &&
          await unsavedDraft(context, widget.controller.repository, {
            'type': 'dialog',
            'draft': buffer.draft.toJson(),
          }) &&
          mounted) {
        try {
          await widget.controller.repository.discardDialogDraft(
            buffer.draft.id,
            buffer.draft.revision,
          );
          await pop();
        } catch (discardError) {
          if (mounted) setState(() => error = friendlyError(discardError));
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (customColor &&
          !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(colorText.text)) {
        throw const DomainError('Bitte eine gültige HEX-Farbe eingeben.');
      }
      pupil.validate();
      await buffer.flush();
      await widget.controller.repository.savePupilDialog(pupil, buffer.draft);
      await widget.controller.reload();
      if (mounted) await pop();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
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
          maxWidth: 430,
          title: Text(
            pupil.revision == 0 ? 'Schüler hinzufügen' : 'Schüler verwalten',
          ),
          headerActions: [
            if (buffer.hasContent || buffer.draft.revision > 0)
              EditorDraftDeleteButton(onPressed: busy ? null : deleteDraft),
          ],
          onClose: busy ? null : close,
          content: AbsorbPointer(
            absorbing: busy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Name …',
                  ),
                  onChanged: (v) => change(pupil.copyWith(name: v)),
                ),
                const Text('Farbe'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final color in pupilPalette)
                      Tooltip(
                        message: hex(color),
                        child: Semantics(
                          label: 'Farbe ${hex(color)}',
                          selected: pupil.color == color,
                          button: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              colorText.text = hex(color);
                              change(pupil.copyWith(color: color));
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Color(color),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: pupil.color == color
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: pupil.color == color
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() => customColor = !customColor),
                  child: const Text('Eigene Farbe wählen'),
                ),
                if (customColor)
                  TextField(
                    controller: colorText,
                    decoration: const InputDecoration(labelText: 'HEX-Farbe'),
                    onChanged: (v) {
                      if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v)) {
                        change(
                          pupil.copyWith(
                            color: int.parse('ff${v.substring(1)}', radix: 16),
                          ),
                        );
                      }
                    },
                  ),
                if (pupil.revision > 0) ...[
                  CompactSwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Schüler archivieren'),
                    value: pupil.archived,
                    onChanged: (v) => change(pupil.copyWith(archived: v)),
                  ),
                  const Text(
                    'Alle Einträge bleiben erhalten. Archivierte Schüler findest du im Menü unter „Archiv“.',
                  ),
                  if (pupil.archived)
                    Text(
                      '${widget.controller.records.where((r) => r.pupilId == pupil.id && r.pending).length + widget.controller.entries.where((e) => e.pupilId == pupil.id && e.pending).length} offene Vorgänge bleiben erhalten.',
                    ),
                ],
                DraftStatus(buffer: buffer),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(pupil.revision == 0 ? 'Hinzufügen' : 'Speichern'),
            ),
          ],
        ),
      ),
    ),
  );
}
