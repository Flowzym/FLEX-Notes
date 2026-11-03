import 'compact_switch.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import 'common.dart';
import 'flex_modal.dart';
import 'pupil_card.dart';
import 'surfaces.dart';

class SettingsLayoutState {
  int tab = 0;
  bool? previewOpen;
}

/// The native decoder validates the signature and dimensions before full decoding.
Future<String> prepareAppearanceImage(Uint8List bytes) async {
  if (bytes.length > 12 * 1024 * 1024) {
    throw const DomainError('Bitte ein Bild bis 12 MB wählen.');
  }
  final png =
      bytes.length >= 8 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71;
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255;
  final webp =
      bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
  if (!png && !jpeg && !webp) {
    throw const DomainError(
      'Bitte eine gültige JPEG-, PNG- oder WebP-Datei wählen.',
    );
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? original, output;
  ui.Picture? picture;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width * descriptor.height > 48000000) {
      throw const DomainError(
        'Das Bild ist zu groß. Bitte eine kleinere Fassung wählen.',
      );
    }
    final longest = descriptor.width > descriptor.height
        ? descriptor.width
        : descriptor.height;
    final scale = longest > 1600 ? 1600 / longest : 1.0;
    final width = (descriptor.width * scale).round().clamp(1, 1600);
    final height = (descriptor.height * scale).round().clamp(1, 1600);
    codec = await descriptor.instantiateCodec(
      targetWidth: width,
      targetHeight: height,
    );
    original = (await codec.getNextFrame()).image;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xff203a2d), BlendMode.src);
    canvas.drawImage(original, Offset.zero, Paint());
    picture = recorder.endRecording();
    output = await picture.toImage(width, height);
    final data = (await output.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    if (data.length > 5000000) {
      throw const DomainError(
        'Das Bild benötigt zu viel Speicher. Bitte eine kleinere Datei wählen.',
      );
    }
    return base64Encode(data);
  } finally {
    output?.dispose();
    picture?.dispose();
    original?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

const appearanceSwatches = <int, String>{
  0xff303e2b: 'Oliv',
  0xffdce5d7: 'Salbei',
  0xfff2ede2: 'Sand',
  0xfff7f7f5: 'Hell',
  0xff324d60: 'Blau',
  0xff55445d: 'Pflaume',
  0xff23262b: 'Graphit',
};

class AppearanceColorField extends StatefulWidget {
  const AppearanceColorField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.background = false,
  });
  final int value;
  final String label;
  final ValueChanged<int> onChanged;
  final bool background;
  @override
  State<AppearanceColorField> createState() => _AppearanceColorFieldState();
}

class _AppearanceColorFieldState extends State<AppearanceColorField> {
  late final TextEditingController text;
  final scroll = ScrollController(keepScrollOffset: false);
  String? error;
  String hex(int color) =>
      '#${(color & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  @override
  void initState() {
    super.initState();
    text = TextEditingController(text: hex(widget.value));
  }

  @override
  void didUpdateWidget(covariant AppearanceColorField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      text.text = hex(widget.value);
      error = null;
    }
  }

  @override
  void dispose() {
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  void input(String value) {
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value.trim())) {
      setState(
        () => error =
            'Bitte einen gültigen HEX-Farbwert eingeben, z. B. #303E2B.',
      );
      return;
    }
    setState(() => error = null);
    widget.onChanged(
      0xff000000 | int.parse(value.trim().substring(1), radix: 16),
    );
  }

  Future<void> picker() async {
    var color = HSVColor.fromColor(Color(widget.value));
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => FlexModal(
          title: Text(widget.label),
          onClose: () => Navigator.pop(ctx),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 52, color: color.toColor()),
              for (final property in [
                'Farbton',
                'Sättigung',
                'Helligkeit',
              ]) ...[
                Text(property),
                Slider(
                  value: property == 'Farbton'
                      ? color.hue / 360
                      : property == 'Sättigung'
                      ? color.saturation
                      : color.value,
                  onChanged: (value) => update(
                    () => color = property == 'Farbton'
                        ? color.withHue(value * 360)
                        : property == 'Sättigung'
                        ? color.withSaturation(value)
                        : color.withValue(value),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, color.toColor().toARGB32()),
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: '${widget.label} wählen',
            button: true,
            child: InkWell(
              onTap: picker,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Color(widget.value),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: ValueKey('hex-${widget.label}'),
              scrollController: scroll,
              controller: text,
              maxLength: 7,
              decoration: InputDecoration(
                labelText: 'Eigene Farbe',
                counterText: '',
                errorText: error,
                errorMaxLines: 6,
              ),
              onChanged: input,
              onSubmitted: input,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final swatch in appearanceSwatches.entries)
            Semantics(
              selected:
                  widget.value ==
                  (widget.background && swatch.key == 0xff303e2b
                      ? 0xff4f6038
                      : swatch.key),
              child: Tooltip(
                message: swatch.value,
                child: InkWell(
                  key: ValueKey('swatch-${widget.label}-${swatch.value}'),
                  onTap: () => widget.onChanged(
                    widget.background && swatch.key == 0xff303e2b
                        ? 0xff4f6038
                        : swatch.key,
                  ),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(
                        widget.background && swatch.key == 0xff303e2b
                            ? 0xff4f6038
                            : swatch.key,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: widget.value == swatch.key
                        ? Icon(Icons.check, color: legibleOn(Color(swatch.key)))
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

class AppearanceSettings extends StatefulWidget {
  const AppearanceSettings({
    super.key,
    required this.controller,
    required this.layout,
  });
  final NotebookController controller;
  final SettingsLayoutState layout;
  @override
  State<AppearanceSettings> createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<AppearanceSettings> {
  NotebookController get c => widget.controller;
  Appearance get a => c.appearance;
  bool imageBusy = false;
  final previewScroll = ScrollController(keepScrollOffset: false);
  @override
  void dispose() {
    previewScroll.dispose();
    super.dispose();
  }

  void change(Json values) => c.previewAppearance(values);
  Future<void> chooseImage(bool mobile) async {
    if (imageBusy) return;
    setState(() => imageBusy = true);
    await guarded(context, () async {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Bilder',
            extensions: ['png', 'jpg', 'jpeg', 'webp'],
            mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
          ),
        ],
      );
      if (file == null || !mounted) return;
      if (await file.length() > 12 * 1024 * 1024) {
        throw const DomainError('Bitte ein Bild bis 12 MB wählen.');
      }
      final collected = BytesBuilder();
      await for (final chunk in file.openRead()) {
        if (collected.length + chunk.length > 12 * 1024 * 1024) {
          throw const DomainError('Bitte ein Bild bis 12 MB wählen.');
        }
        collected.add(chunk);
      }
      final data = await prepareAppearanceImage(collected.takeBytes());
      if (!mounted) return;
      change({
        mobile ? 'mobileImage' : 'desktopImage': data,
        mobile ? 'mobileImageName' : 'desktopImageName': file.name.length > 120
            ? file.name.substring(0, 120)
            : file.name,
        'imageEnabled': true,
        'defaultTexture': false,
        'backgroundOpacity': 1.0,
      });
      await c.flushAppearance();
    });
    if (mounted) setState(() => imageBusy = false);
  }

  Widget range(
    String key,
    String label, {
    bool transparency = false,
    double max = 1,
    int divisions = 100,
    bool enabled = true,
  }) {
    final stored = (a.toJson()[key] as num).toDouble();
    final value = transparency ? 1 - stored : stored;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$label · ${(value * 100).round()} %'),
        Slider(
          key: ValueKey('setting-$key'),
          value: value,
          min: 0,
          max: max,
          divisions: divisions,
          semanticFormatterCallback: (v) => '${(v * 100).round()} Prozent',
          onChanged: enabled
              ? (v) => change({key: transparency ? 1 - v : v})
              : null,
          onChangeEnd: enabled ? (_) => c.flushAppearance() : null,
        ),
      ],
    );
  }

  Widget measure(
    String key,
    String label, {
    double min = 0,
    double max = 32,
    int divisions = 32,
    bool percent = false,
  }) {
    final value = (a.toJson()[key] as num).toDouble();
    String format(double v) =>
        percent ? '${(v * 100).round()} %' : '${v.round()} px';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$label · ${format(value)}'),
        Slider(
          key: ValueKey('setting-$key'),
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          semanticFormatterCallback: format,
          onChanged: (v) => change({key: v}),
          onChangeEnd: (_) => c.flushAppearance(),
        ),
      ],
    );
  }

  Widget color(
    String key,
    String label, {
    bool automatic = true,
    bool background = false,
  }) {
    final stored = a.toJson()[key] as int;
    final palette = Theme.of(context).extension<FlexSurfaces>()!.palette!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppearanceColorField(
          key: ValueKey('color-$key'),
          value: stored == 0 ? palette.panel.toARGB32() : stored,
          label: label,
          background: background,
          onChanged: (v) => change({
            key: v,
            if (key == 'backgroundColor') 'defaultTexture': false,
          }),
        ),
        if (automatic)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => change({key: 0}),
              child: Text(
                ['workspaceColor', 'cardColor'].contains(key)
                    ? 'Farbe dem Hintergrund anpassen'
                    : 'Farbe automatisch anpassen',
              ),
            ),
          ),
      ],
    );
  }

  Widget section(String title, List<Widget> children, {VoidCallback? reset}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (reset != null)
                  TextButton(
                    onPressed: reset,
                    child: const Text('Zurücksetzen'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );
  Widget group(String key, String title, List<Widget> children) => Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      key: PageStorageKey('settings-$key'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
  Widget surface(
    String title,
    String colorKey,
    String opacityKey,
    double opacity,
  ) => section(title, [
    range(opacityKey, 'Transparenz', transparency: true),
    color(colorKey, title),
  ], reset: () => change({colorKey: 0, opacityKey: opacity}));
  Widget picture(bool mobile) {
    final key = mobile ? 'mobileImage' : 'desktopImage';
    final fitKey = mobile ? 'mobileFit' : 'desktopFit';
    final exists = (a.toJson()[key] as String).isNotEmpty;
    return section(mobile ? 'Mobilhintergrund' : 'Desktophintergrund', [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: imageBusy ? null : () => chooseImage(mobile),
            child: Text(exists ? 'Anderes Bild wählen' : 'Bild wählen'),
          ),
          TextButton(
            onPressed: !exists || imageBusy
                ? null
                : () => change({
                    key: '',
                    mobile ? 'mobileImageName' : 'desktopImageName': '',
                  }),
            child: Text(mobile ? 'Mobiles Bild entfernen' : 'Bild entfernen'),
          ),
        ],
      ),
      Text(
        exists
            ? (mobile ? a.mobileImageName : a.desktopImageName).isEmpty
                  ? 'Eigenes Bild'
                  : mobile
                  ? a.mobileImageName
                  : a.desktopImageName
            : 'Noch kein Bild gewählt. JPEG, PNG oder WebP, maximal 12 MB.',
      ),
      const SizedBox(height: 8),
      if (a.hasImage)
        SizedBox(
          height: 140,
          child: FlexBackground(
            appearance: a.patch({'imageEnabled': true}),
            previewWidth: mobile ? 390 : 1100,
            child: const SizedBox.expand(),
          ),
        ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final fit in const {
            'cover': 'Fläche füllen / Filled',
            'contain': 'Einpassen / Scaled',
            'fill': 'Strecken / Stretched',
            'none': 'Originalgröße',
            'tile': 'Kacheln',
          }.entries)
            transparentChip(
              ChoiceChip(
                label: Text(fit.value),
                selected: a.toJson()[fitKey] == fit.key,
                onSelected: (_) => change({fitKey: fit.key}),
              ),
            ),
          if (['fitWidth', 'fitHeight'].contains(a.toJson()[fitKey]))
            transparentChip(
              Chip(
                label: Text(
                  a.toJson()[fitKey] == 'fitWidth' ? 'Breite' : 'Höhe',
                ),
              ),
            ),
        ],
      ),
    ]);
  }

  Widget preview(bool wide) => Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      key: const PageStorageKey('settings-preview'),
      initiallyExpanded: widget.layout.previewOpen ?? wide,
      onExpansionChanged: (open) => widget.layout.previewOpen = open,
      title: const Text('Live-Vorschau'),
      childrenPadding: const EdgeInsets.all(12),
      children: [
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: FlexBackground(
            appearance: a,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Builder(
                    builder: (context) {
                      final p = Theme.of(
                        context,
                      ).extension<FlexSurfaces>()!.palette!;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        color: p.workspace,
                        child: Text(
                          'Übersicht · Schüler · …',
                          style: TextStyle(color: p.workspaceInk),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  PupilCard(
                    counts: const {},
                    due: const {},
                    pupil: const Pupil(
                      id: 'settings-preview',
                      name: 'Schülername',
                    ),
                    onOpen: () {},
                    onShortcut: (_) {},
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final p = Theme.of(
                        context,
                      ).extension<FlexSurfaces>()!.palette!;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(a.modalRadius),
                        child: FlexBackground(
                          appearance: a,
                          child: ColoredBox(
                            color: p.modal,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  color: p.header,
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    'Beobachtung',
                                    style: TextStyle(
                                      color: legibleOn(
                                        Color.alphaBlend(
                                          p.header,
                                          p.modalPerceived,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Was ist passiert?',
                                        style: TextStyle(color: p.modalInk),
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: transparentChip(
                                          ActionChip(
                                            label: const Text('Hilft anderen'),
                                            onPressed: () {},
                                          ),
                                        ),
                                      ),
                                      TextField(
                                        scrollController: previewScroll,
                                        decoration: const InputDecoration(
                                          hintText: 'Beobachtung …',
                                        ),
                                        maxLines: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  color: p.footer,
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    'Eintrag speichern',
                                    style: TextStyle(
                                      color: legibleOn(
                                        Color.alphaBlend(
                                          p.footer,
                                          p.modalPerceived,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 960;
      final controls = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section(
            'Größe & Schrift',
            [
              measure(
                'uiScale',
                'App-Skalierung',
                min: .8,
                max: 1.2,
                divisions: 8,
                percent: true,
              ),
              measure(
                'textScale',
                'Schriftgröße',
                min: .8,
                max: 1.6,
                divisions: 16,
                percent: true,
              ),
              CompactSwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kompakte Abstände'),
                value: a.compact,
                onChanged: (v) => change({'compact': v}),
              ),
            ],
            reset: () =>
                change({'uiScale': 1.0, 'textScale': 1.0, 'compact': false}),
          ),
          section('Stilvorlagen', [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in const {
                  'calm': 'Ruhig',
                  'image-soft': 'Bild dezent',
                  'image-clear': 'Bild klar',
                }.entries)
                  TextButton(
                    onPressed: preset.key != 'calm' && !a.hasImage
                        ? null
                        : () => c
                              .saveAppearance(a.preset(preset.key))
                              .catchError((Object _) {}),
                    child: Text(preset.value),
                  ),
              ],
            ),
            CompactSwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lesbarkeitsschutz'),
              value: a.readabilityProtection,
              onChanged: (v) => change({'readabilityProtection': v}),
            ),
          ]),
          CompactSwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Alle Flächen gemeinsam einstellen'),
            value: a.coupleSurfaces,
            onChanged: (v) => change({'coupleSurfaces': v}),
          ),
          group('background', 'Hintergrund', [
            section(
              'Hintergrund',
              [
                color(
                  'backgroundColor',
                  'Hintergrund',
                  automatic: false,
                  background: true,
                ),
              ],
              reset: () => change({
                'backgroundColor': 0xff4f6038,
                'defaultTexture': false,
              }),
            ),
            CompactSwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bild verwenden'),
              value: a.imageEnabled && (a.hasImage || a.defaultTexture),
              onChanged: a.hasImage || a.defaultTexture
                  ? (v) => change({'imageEnabled': v})
                  : null,
            ),
            picture(false),
            picture(true),
            range('backgroundOpacity', 'Bilddeckkraft', enabled: a.hasImage),
            range(
              'backgroundDim',
              'Abdunklung',
              max: .8,
              divisions: 16,
              enabled: a.hasImage,
            ),
            color('backgroundTint', 'Bildtönung', automatic: false),
            range(
              'backgroundTintStrength',
              'Stärke der Tönung',
              max: .8,
              divisions: 80,
              enabled: a.hasImage,
            ),
            TextButton(
              onPressed: () => change({
                'backgroundTint': 0xff203a2d,
                'backgroundTintStrength': .25,
              }),
              child: const Text('Tönung zurücksetzen'),
            ),
          ]),
          group('surfaces', 'Hauptansicht', [
            surface('Kopfbereich', 'workspaceColor', 'workspaceOpacity', .12),
            surface('Schülerkarten', 'cardColor', 'cardOpacity', .28),
            section('Akzentfarbe', [
              color('accent', 'Akzentfarbe', automatic: false),
            ]),
            Text('Kartenrundung · ${a.cardRadius.round()}'),
            Slider(
              key: const ValueKey('setting-cardRadius'),
              value: a.cardRadius,
              max: 32,
              divisions: 32,
              onChanged: (v) => change({'cardRadius': v}),
              onChangeEnd: (_) => c.flushAppearance(),
            ),
            CompactSwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Gelasio für Überschriften'),
              value: a.serifHeaders,
              onChanged: (v) => change({'serifHeaders': v}),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final mode in const {
                  'dark': 'Wald · dunkel',
                  'light': 'Papier · hell',
                  'system': 'Wie das System',
                }.entries)
                  transparentChip(
                    ChoiceChip(
                      label: Text(mode.value),
                      selected: a.mode == mode.key,
                      onSelected: (_) => change({'mode': mode.key}),
                    ),
                  ),
              ],
            ),
          ]),
          group('controls', 'Buttons & Eingabefelder', [
            measure('buttonRadius', 'Buttonrundung'),
            measure('fieldRadius', 'Feldrundung'),
            surface('Buttons', 'buttonColor', 'buttonOpacity', .20),
            surface('Eingabefelder', 'fieldColor', 'fieldOpacity', .22),
          ]),
          group('dialogs', 'Dialoge', [
            measure('modalRadius', 'Dialogrundung'),
            surface(
              'Dialoghintergrund',
              'modalColor',
              'modalOpacity',
              a.imageActive ? 0 : 1,
            ),
            section(
              'Dialogfenster',
              [
                color('dialogColor', 'Dialogkopf und -fuß'),
                range('headerOpacity', 'Kopfzeile', transparency: true),
                range('footerOpacity', 'Fußzeile', transparency: true),
              ],
              reset: () => change({
                'dialogColor': 0,
                'headerOpacity': .18,
                'footerOpacity': .18,
              }),
            ),
          ]),
          TextButton(
            onPressed: () async {
              if (await confirmFlex(
                context,
                'Darstellung zurücksetzen?',
                'Farben, Bilder und Schrift werden zurückgesetzt. Bedienungseinstellungen, Schüler, Einträge und Entwürfe bleiben erhalten.',
                accept: 'Zurücksetzen',
              )) {
                await c
                    .saveAppearance(
                      const Appearance().patch({
                        'shortcutOrder': a.shortcutOrder,
                        'defaultObservationTone': a.defaultObservationTone,
                      }),
                    )
                    .catchError((Object _) {});
              }
            },
            child: const Text('Darstellung zurücksetzen'),
          ),
        ],
      );
      return wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 16, child: controls),
                const SizedBox(width: 24),
                Expanded(flex: 10, child: preview(true)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [controls, preview(false)],
            );
    },
  );
}
