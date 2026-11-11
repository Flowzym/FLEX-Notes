import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/onedrive.dart';
import 'common.dart';
import 'flex_modal.dart';

Future<bool> setupOneDrive(BuildContext context, OneDriveClient drive) async {
  final id = TextEditingController(text: drive.clientId);
  var busy = false;
  String? error;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => PopScope(
        canPop: !busy,
        child: FlexModal(
          title: const Text('OneDrive einrichten'),
          maxWidth: 560,
          onClose: busy ? null : () => Navigator.pop(ctx, false),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Privates Microsoft-Konto'),
              const SizedBox(height: 12),
              const Text(
                'FLEX benötigt eine eigene Appregistrierung bei Microsoft. Die öffentliche Client-ID verbindet diese Installation mit deiner Registrierung.',
              ),
              const SizedBox(height: 12),
              const Text(
                '1. App „FLEX“ registrieren; persönliche Microsoft-Konten zulassen.\n2. Unter Authentifizierung öffentliche Clientflows aktivieren.\n3. Microsoft Graph: delegierte Berechtigung Files.Read.\n4. Die Anwendungs-/Client-ID hier einfügen.',
              ),
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => launchUrl(
                        Uri.parse(
                          'https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Microsoft-Appregistrierungen öffnen'),
              ),
              const Text(
                'Die Registrierung setzt ein Microsoft-Entra-Verzeichnis und entsprechende Rechte voraus. Ein privates OneDrive-Konto allein ersetzt diese Registrierung nicht. Kein Client-Geheimnis anlegen oder hier eingeben.',
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('onedrive-client-id'),
                controller: id,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Anwendungs-/Client-ID',
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx, false),
              child: const Text('Später'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      update(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await drive.configure(id.text);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          update(() {
                            busy = false;
                            error = friendlyError(e);
                          });
                        }
                      }
                    },
              child: const Text('Speichern & verbinden'),
            ),
          ],
        ),
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 250));
  id.dispose();
  return result == true;
}
