import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import 'common.dart';
import 'flex_modal.dart';

class AppearanceSettings extends StatefulWidget {
  const AppearanceSettings({super.key, required this.controller});
  final NotebookController controller;
  @override
  State<AppearanceSettings> createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<AppearanceSettings> {
  bool busy = false;
  Appearance get a => widget.controller.appearance;
  Future<void> save(Json change) async {
    if (busy) return;
    setState(() => busy = true);
    await guarded(
      context,
      () => widget.controller.saveAppearance(a.patch(change)),
    );
    if (mounted) setState(() => busy = false);
  }

  Future<void> color(String key, String title) async {
    final controller = TextEditingController(
      text: (a.toJson()[key] as int)
          .toRadixString(16)
          .padLeft(8, '0')
          .substring(2),
    );
    String? error;
    final value = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => FlexModal(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in [
                    0xff303e2b,
                    0xffdae9a6,
                    0xfff5f2e8,
                    0xff426574,
                    0xff9dc9d3,
                    0xff614761,
                    0xffc4ade0,
                    0xffc17f59,
                  ])
                    ActionChip(
                      label: const Text('●'),
                      backgroundColor: Color(c),
                      onPressed: () => Navigator.pop(context, c),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Eigene Farbe · RRGGBB',
                  prefixText: '#',
                ),
              ),
              if (error != null) Text(error!),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 0),
              child: const Text('Automatisch'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(text)) {
                  update(
                    () => error = 'Bitte sechs Hexadezimalzeichen eingeben.',
                  );
                  return;
                }
                Navigator.pop(context, 0xff000000 | int.parse(text, radix: 16));
              },
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (value != null && mounted) {
      await save({
        key: value,
        if (a.coupleSurfaces) ...{
          'dialogColor': value,
          'cardColor': value,
          'buttonColor': value,
        },
      });
    }
  }

  Future<void> image(String key) async {
    if (busy) return;
    await guarded(context, () async {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Bilder',
            extensions: ['png', 'jpg', 'jpeg'],
            mimeTypes: ['image/png', 'image/jpeg'],
          ),
        ],
      );
      if (file == null) return;
      if (await file.length() > 5000000) {
        throw const DomainError('Bitte ein Bild bis 5 MB wählen.');
      }
      final data = BytesBuilder();
      await for (final chunk in file.openRead()) {
        if (data.length + chunk.length > 5000000) {
          throw const DomainError('Das Bild überschreitet 5 MB.');
        }
        data.add(chunk);
      }
      final bytes = data.takeBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final valid = frame.image.width <= 4096 && frame.image.height <= 4096;
      frame.image.dispose();
      codec.dispose();
      if (!valid) {
        throw const DomainError(
          'Bitte ein Bild mit höchstens 4096 × 4096 Pixeln wählen.',
        );
      }
      await save({key: base64Encode(bytes)});
    });
  }

  Widget opacity(String key, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '$label · ${((a.toJson()[key] as double) * 100).round()} % Deckkraft',
      ),
      Wrap(
        spacing: 8,
        children: [
          for (final value in [.25, .5, .75, 1.0])
            ChoiceChip(
              label: Text('${(value * 100).round()} %'),
              selected: a.toJson()[key] == value,
              onSelected: busy ? null : (_) => save({key: value}),
            ),
        ],
      ),
    ],
  );
  Widget picture(bool mobile) {
    final key = mobile ? 'mobileImage' : 'desktopImage',
        fitKey = mobile ? 'mobileFit' : 'desktopFit';
    final hasImage = (a.toJson()[key] as String).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          mobile ? 'Mobilhintergrund' : 'Desktophintergrund',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: busy ? null : () => image(key),
              icon: const Icon(Icons.image),
              label: Text(hasImage ? 'Bild ersetzen' : 'Bild wählen'),
            ),
            if (hasImage)
              TextButton(
                onPressed: busy ? null : () => save({key: ''}),
                child: const Text('Eigenes Bild entfernen'),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final fit in const {
              'cover': 'Füllen',
              'contain': 'Einpassen',
              'fitWidth': 'Breite',
              'fitHeight': 'Höhe',
              'fill': 'Strecken',
            }.entries)
              ChoiceChip(
                label: Text(fit.value),
                selected: a.toJson()[fitKey] == fit.key,
                onSelected: busy ? null : (_) => save({fitKey: fit.key}),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(height: 32),
      Text(
        'Flächen und Dialoge',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Flächenfarben koppeln'),
        value: a.coupleSurfaces,
        onChanged: busy ? null : (v) => save({'coupleSurfaces': v}),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in const {
            'dialogColor': 'Dialogleistenfarbe',
            'cardColor': 'Kartenfarbe',
            'buttonColor': 'Buttonfarbe',
          }.entries)
            OutlinedButton(
              onPressed: busy ? null : () => color(entry.key, entry.value),
              child: Text(entry.value),
            ),
        ],
      ),
      const SizedBox(height: 12),
      opacity('headerOpacity', 'Dialogkopf'),
      opacity('footerOpacity', 'Dialogfuß'),
      opacity('cardOpacity', 'Karten'),
      opacity('buttonOpacity', 'Buttons'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Gelasio für Überschriften'),
        value: a.serifHeaders,
        onChanged: busy ? null : (v) => save({'serifHeaders': v}),
      ),
      const Divider(height: 32),
      Text('Hintergrundbilder', style: Theme.of(context).textTheme.titleLarge),
      const Text(
        'Im dunklen Modus erscheint ohne eigenes Bild die dunkle Textur. '
        'Eigene Bilder ersetzen sie für Desktop und Mobil getrennt.',
      ),
      const SizedBox(height: 16),
      picture(false),
      picture(true),
      opacity('backgroundOpacity', 'Eigene Hintergrundbilder'),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: busy
              ? null
              : () async {
                  if (await confirmFlex(
                    context,
                    'Darstellung zurücksetzen?',
                    'Farben und Bilder werden auf die Vorgaben zurückgesetzt. Einträge bleiben erhalten.',
                    accept: 'Zurücksetzen',
                  )) {
                    await save(const Appearance().toJson());
                  }
                },
          child: const Text('Darstellung zurücksetzen'),
        ),
      ),
    ],
  );
}
