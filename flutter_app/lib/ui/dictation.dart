import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/dictation.dart';

class DictationButton extends StatelessWidget {
  const DictationButton({
    super.key,
    required this.controller,
    required this.onChanged,
    this.maxLength = 12000,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int maxLength;
  @override
  Widget build(BuildContext context) => supportsDictation
      ? IconButton(
          tooltip: 'Diktieren',
          icon: const Icon(Icons.mic_none, size: 21),
          onPressed: () async {
            final result = await showDialog<String>(
              context: context,
              builder: (_) => DictationDialog(port: deviceDictation),
            );
            if (result == null || !context.mounted) return;
            try {
              controller.value = insertDictation(
                controller.value,
                result,
                maxLength,
              );
              onChanged(controller.text);
            } on FormatException catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(e.message)));
            }
          },
        )
      : const SizedBox.shrink();
}

class DictationDialog extends StatefulWidget {
  const DictationDialog({super.key, required this.port});
  final DictationPort port;
  @override
  State<DictationDialog> createState() => _DictationDialogState();
}

class _DictationDialogState extends State<DictationDialog>
    with WidgetsBindingObserver {
  final preview = TextEditingController();
  StreamSubscription<DictationEvent>? subscription;
  bool active = false, cancelled = false;
  String language = 'de-DE',
      base = '',
      status = 'Der erkannte Text erscheint zuerst hier.';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    subscription = widget.port.events.listen((event) {
      if (!mounted || !active || cancelled) return;
      setState(() {
        switch (event.state) {
          case 'partial':
          case 'final':
            preview.text = [
              base,
              event.text,
            ].where((s) => s.isNotEmpty).join(' ');
            if (event.state == 'final') {
              active = false;
              status = 'Text prüfen und einfügen.';
            }
          case 'listening':
            status = 'Ich höre zu …';
          case 'processing':
            status = 'Text wird erkannt …';
          case 'error':
            active = false;
            status = event.text;
        }
      });
    });
  }

  Future<void> start() async {
    setState(() {
      active = true;
      cancelled = false;
      base = preview.text.trim();
      status = 'Mikrofon wird gestartet …';
    });
    try {
      await widget.port.start(language);
    } on PlatformException catch (e) {
      if (mounted && !cancelled) {
        setState(() {
          active = false;
          status = e.message ?? 'Lokales Diktat ist nicht verfügbar.';
        });
      }
    } catch (_) {
      if (mounted && !cancelled) {
        setState(() {
          active = false;
          status = 'Lokales Diktat ist nicht verfügbar.';
        });
      }
    }
  }

  Future<void> cancel() async {
    cancelled = true;
    if (mounted) {
      setState(() {
        active = false;
        status = 'Diktat angehalten.';
      });
    }
    try {
      await widget.port.cancel();
    } catch (_) {
      /* No transcription in error reports. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(cancel());
    }
  }

  @override
  void dispose() {
    cancelled = true;
    WidgetsBinding.instance.removeObserver(this);
    subscription?.cancel();
    unawaited(widget.port.cancel().catchError((_) {}));
    preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Diktieren'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'de-DE', label: Text('Deutsch')),
                ButtonSegment(value: 'en-GB', label: Text('English')),
              ],
              selected: {language},
              onSelectionChanged: active
                  ? null
                  : (v) => setState(() => language = v.first),
            ),
            const SizedBox(height: 12),
            Text(status, key: const ValueKey('dictation-status')),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('dictation-preview'),
              controller: preview,
              readOnly: active,
              minLines: 4,
              maxLines: 8,
              maxLength: 12000,
              decoration: const InputDecoration(labelText: 'Vorschau'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: Icon(active ? Icons.stop : Icons.mic_none),
              label: Text(active ? 'Anhalten' : 'Diktat starten'),
              onPressed: active
                  ? () async {
                      try {
                        await widget.port.stop();
                      } catch (_) {
                        await cancel();
                      }
                    }
                  : start,
            ),
            const Text(
              'Verarbeitung auf diesem Gerät.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      ValueListenableBuilder(
        valueListenable: preview,
        builder: (_, value, _) => FilledButton(
          onPressed: active || value.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, preview.text.trim()),
          child: const Text('Einfügen'),
        ),
      ),
    ],
  );
}

/// Controller-backed form field, so applying a template or dictation updates
/// both the visible input and its draft without recreating the form.
class DictationTextField extends StatefulWidget {
  const DictationTextField({
    super.key,
    required this.fieldKey,
    required this.value,
    required this.onChanged,
    required this.decoration,
    this.focusNode,
    this.autofocus = false,
    this.minLines = 1,
    this.maxLines = 8,
    this.maxLength = 12000,
    this.onSubmitted,
    this.textInputAction,
  });
  final Key fieldKey;
  final String value;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;
  final FocusNode? focusNode;
  final bool autofocus;
  final int minLines, maxLines, maxLength;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  @override
  State<DictationTextField> createState() => _DictationTextFieldState();
}

class _DictationTextFieldState extends State<DictationTextField> {
  late final controller = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(covariant DictationTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.text != widget.value) {
      controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    key: widget.fieldKey,
    controller: controller,
    focusNode: widget.focusNode,
    autofocus: widget.autofocus,
    minLines: widget.minLines,
    maxLines: widget.maxLines,
    maxLength: widget.maxLength,
    textInputAction: widget.textInputAction,
    onFieldSubmitted: widget.onSubmitted,
    onChanged: widget.onChanged,
    decoration: widget.decoration.copyWith(
      suffixIcon: supportsDictation
          ? DictationButton(
              controller: controller,
              onChanged: widget.onChanged,
              maxLength: widget.maxLength,
            )
          : null,
    ),
  );
}
