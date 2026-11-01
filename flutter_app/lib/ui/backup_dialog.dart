import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../security/backup_codec.dart';
import 'common.dart';
import 'flex_modal.dart';

Future<String> _encodeMessage(Map<String, String> input) =>
    BackupCodec.encrypt(input['text']!, input['password']!);
Future<String> _decodeMessage(Map<String, String> input) =>
    BackupCodec.decrypt(input['text']!, input['password']!);

class BackupDialog extends StatefulWidget {
  const BackupDialog({
    super.key,
    required this.controller,
    required this.export,
  });
  final NotebookController controller;
  final bool export;
  @override
  State<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<BackupDialog> {
  final password = TextEditingController(),
      confirmation = TextEditingController(),
      input = TextEditingController();
  bool encrypt = true, busy = false;
  String? message;
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    input.dispose();
    super.dispose();
  }

  Future<void> action(Future<void> Function() callback) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await callback();
    } catch (e) {
      if (mounted) setState(() => message = friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<String> output() async {
    final plain = await widget.controller.repository.exportBackup();
    if (!encrypt) return plain;
    if (password.text != confirmation.text) {
      throw const DomainError('Die Passwörter stimmen nicht überein.');
    }
    return compute(_encodeMessage, {'text': plain, 'password': password.text});
  }

  Future<void> saveFile() async {
    final text = await output();
    final name = 'FLEX-Sicherung-${dateOnly(DateTime.now())}.json';
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(text)),
      name: name,
      mimeType: 'application/json',
    );
    if (kIsWeb) {
      await file.saveTo(name);
    } else {
      final location = await getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON', extensions: ['json']),
        ],
      );
      if (location == null) return;
      await file.saveTo(location.path);
    }
    if (mounted) setState(() => message = 'Sicherungsdatei wurde ausgegeben.');
  }

  Future<void> chooseFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'JSON',
          extensions: ['json'],
          mimeTypes: ['application/json'],
        ),
      ],
    );
    if (file == null) return;
    if (await file.length() > BackupCodec.maxEnvelopeBytes) {
      throw const DomainError('Die Datei überschreitet 28 MB.');
    }
    final bytes = BytesBuilder();
    await for (final chunk in file.openRead()) {
      if (bytes.length + chunk.length > BackupCodec.maxEnvelopeBytes) {
        throw const DomainError('Die Datei überschreitet 28 MB.');
      }
      bytes.add(chunk);
    }
    input.text = utf8.decode(bytes.takeBytes());
  }

  Future<void> restore() async {
    if (utf8.encode(input.text).length > BackupCodec.maxEnvelopeBytes) {
      throw const DomainError('Die Datei überschreitet 28 MB.');
    }
    final text = BackupCodec.isEncrypted(input.text)
        ? await compute(_decodeMessage, {
            'text': input.text,
            'password': password.text,
          })
        : input.text;
    await widget.controller.repository.restoreBackup(text);
    await widget.controller.reload();
    if (mounted) {
      setState(() => message = 'Vollsicherung vollständig wiederhergestellt.');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: FlexModal(
      title: Text(
        widget.export
            ? 'Vollsicherung exportieren'
            : 'Vollsicherung wiederherstellen',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.export) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mit Passwort verschlüsseln'),
              value: encrypt,
              onChanged: busy ? null : (v) => setState(() => encrypt = v),
            ),
            if (encrypt) ...[
              TextField(
                controller: password,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Passwort · mindestens 12 Zeichen',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmation,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Passwort wiederholen',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bewahre das Passwort getrennt auf. Ohne Passwort kann die Sicherung nicht wiederhergestellt werden.',
              ),
            ],
          ] else ...[
            const Text(
              'Wiederherstellung in einen leeren Arbeitsbereich. Unterstützt werden Sicherungen dieser Rekonstruktion und Flutter 0.1.0. Andere neuere Flutter-Datenformate benötigen eine gesonderte Migration.',
            ),
            TextButton.icon(
              onPressed: busy ? null : () => action(chooseFile),
              icon: const Icon(Icons.folder_open),
              label: const Text('Sicherungsdatei wählen'),
            ),
            TextField(
              controller: input,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'JSON-Sicherung'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Passwort bei verschlüsselter Sicherung',
              ),
            ),
          ],
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(message!),
            ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Schließen'),
        ),
        if (widget.export) ...[
          TextButton(
            onPressed: busy
                ? null
                : () => action(() async {
                    final text = await output();
                    await Clipboard.setData(ClipboardData(text: text));
                    if (mounted) setState(() => message = 'Sicherung kopiert.');
                  }),
            child: const Text('Kopieren'),
          ),
          FilledButton(
            onPressed: busy ? null : () => action(saveFile),
            child: const Text('Datei speichern'),
          ),
        ] else
          FilledButton(
            onPressed: busy ? null : () => action(restore),
            child: const Text('Wiederherstellen'),
          ),
      ],
    ),
  );
}
