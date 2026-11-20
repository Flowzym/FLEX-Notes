import 'compact_switch.dart';
import 'draft_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/classroom.dart';
import '../domain/planning_import.dart';
import 'pupil_planning_review.dart';
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
    this.initialMaterialCode,
    this.initialSchoolYear,
  });
  final String? initialMaterialCode, initialSchoolYear;
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
  late final TextEditingController code, aliases;
  late String year;
  ClassroomDocument? originalProfile;
  late int profileRevision;
  Json get draftData => {
    ...pupil.toJson(),
    if (profileChanged)
      '_materialEdit': {
        'year': year,
        'code': code.text,
        'aliases': aliases.text,
        'revision': profileRevision,
      },
  };
  List<String> get fileAliases => aliases.text
      .split(',')
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toList();
  bool get profileChanged =>
      code.text.trim().toUpperCase() != (originalProfile?.text('code') ?? '') ||
      fileAliases.join(',') !=
          (originalProfile?.strings('aliases') ?? []).join(',');
  void loadYear(String value) {
    year = value;
    originalProfile = pupilProfile(widget.controller.classroom, pupil.id, year);
    profileRevision = originalProfile?.revision ?? 0;
    code.text = originalProfile?.text('code') ?? '';
    aliases.text = (originalProfile?.strings('aliases') ?? []).join(', ');
  }

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
    code = TextEditingController();
    aliases = TextEditingController();
    final edit = widget.draft?.data['_materialEdit'] as Map?;
    loadYear(
      edit?['year'] as String? ??
          widget.initialSchoolYear ??
          yearOfDay(DateTime.now()),
    );
    if (widget.initialMaterialCode != null &&
        widget.draft == null &&
        pupil.revision == 0) {
      code.text = widget.initialMaterialCode!;
    }
    if (edit != null) {
      code.text = edit['code'] as String;
      aliases.text = edit['aliases'] as String;
      profileRevision = edit['revision'] as int;
    }
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
    buffer.change(draftData);
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
    code.dispose();
    aliases.dispose();
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
      final c = widget.controller;
      ClassroomDocument? profile;
      List<ClassroomDocument> updates = [];
      if (profileChanged) {
        if ((pupilProfile(c.classroom, pupil.id, year)?.revision ?? 0) !=
            profileRevision) {
          throw const StaleRevision();
        }
        profile = buildMaterialProfile(
          c.classroom,
          pupil.id,
          year,
          code.text.trim().toUpperCase(),
          fileAliases,
        );
        final roster = PlanningRoster(
          [
            for (final d in c.classroom)
              if (d.id != profile.id) d,
            profile,
          ],
          [
            for (final p in c.pupils)
              if (p.id != pupil.id) p,
            pupil,
          ],
        );
        final matches = c.classroom
            .where(
              (d) =>
                  d.kind == ClassroomKind.material &&
                  roster.match(d).owners.contains(pupil.id),
            )
            .toList();
        if (matches.isNotEmpty) {
          if (!mounted) return;
          final picked = await reviewPupilBacklog(
            context,
            pupil.id,
            pupil.name,
            matches,
          );
          if (picked == null) {
            if (mounted) setState(() => busy = false);
            return;
          }
          updates = picked;
        }
      }
      await c.repository.savePupilDialog(
        pupil,
        buffer.draft,
        materialProfile: profile,
        materialUpdates: updates,
      );
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
                TextField(
                  key: const ValueKey('pupil-material-code'),
                  controller: code,
                  maxLength: 12,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Materialkürzel · optional',
                    counterText: '',
                    helperText: 'Z. B. MI für MI01.pdf · Schuljahr $year',
                  ),
                  onChanged: (_) => change(pupil),
                ),
                if (code.text.isEmpty &&
                    suggestMaterialCode(
                      pupil.name,
                      widget.controller.classroom,
                      pupil.id,
                      year,
                    ).isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        code.text = suggestMaterialCode(
                          pupil.name,
                          widget.controller.classroom,
                          pupil.id,
                          year,
                        );
                        change(pupil);
                      },
                      child: Text(
                        'Kürzel ${suggestMaterialCode(pupil.name, widget.controller.classroom, pupil.id, year)} übernehmen',
                      ),
                    ),
                  ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Schuljahr und Dateinamen'),
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: year,
                      decoration: const InputDecoration(labelText: 'Schuljahr'),
                      items: [
                        for (final y in ({
                          year,
                          for (final i in [-1, 0, 1])
                            schoolYearLabel(
                              int.parse(
                                    yearOfDay(DateTime.now()).substring(0, 4),
                                  ) +
                                  i,
                            ),
                          for (final d in widget.controller.classroom)
                            if (d.kind == ClassroomKind.materialProfile)
                              d.text('schoolYear')
                            else if (d.kind == ClassroomKind.material &&
                                (d.map('planning')['year'] as String? ?? '')
                                    .isNotEmpty)
                              d.map('planning')['year'] as String,
                        }.toList()..sort()).reversed)
                          DropdownMenuItem(value: y, child: Text(y)),
                      ],
                      onChanged: profileChanged
                          ? null
                          : (v) {
                              if (v != null) {
                                loadYear(v);
                                change(pupil);
                              }
                            },
                    ),
                    TextField(
                      controller: aliases,
                      decoration: const InputDecoration(
                        labelText: 'Weitere Namen in Dateinamen',
                        helperText: 'Mehrere Schreibweisen mit Komma trennen.',
                      ),
                      onChanged: (_) => change(pupil),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
