import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/onedrive.dart';
import 'common.dart';
import 'flex_modal.dart';

Future<void> connectNativeOneDrive(
  BuildContext context,
  OneDriveClient drive,
) async {
  var started = false, busy = true;
  String? error;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) {
        Future<void> signIn() async {
          try {
            await drive.signInNative();
            if (ctx.mounted) Navigator.pop(ctx);
          } catch (e) {
            if (ctx.mounted) {
              update(() {
                busy = false;
                error = friendlyError(e);
              });
            }
          }
        }

        if (!started) {
          started = true;
          Future<void>(signIn);
        }
        return PopScope(
          canPop: !busy,
          child: FlexModal(
            maxWidth: 520,
            title: const Text('OneDrive verbinden'),
            onClose: busy ? null : () => Navigator.pop(ctx),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (busy) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Microsoft-Anmeldung wird geöffnet …'),
                ],
                if (error != null) Text(error!),
                const SizedBox(height: 12),
                Text(
                  drive.appFolderAccess
                      ? 'FLEX liest deine Materialien und legt fertige Scans in den von dir verbundenen Unterordnern des FLEX-App-Ordners ab.'
                      : 'FLEX liest die Materialien in den von dir geöffneten oder verknüpften OneDrive-Ordnern.',
                ),
              ],
            ),
            actions: busy
                ? const []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Schließen'),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        update(() {
                          busy = true;
                          error = null;
                        });
                        signIn();
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Erneut anmelden'),
                    ),
                  ],
          ),
        );
      },
    ),
  );
}

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
              const Text('Microsoft-Konto verbinden'),
              const SizedBox(height: 12),
              Text(
                drive.clientId.isEmpty
                    ? 'Die einmalige Microsoft-Appregistrierung fehlt noch. Mit ihrer öffentlichen Client-ID kann FLEX die Anmeldung anbieten.'
                    : 'Die öffentliche Client-ID verbindet FLEX mit deiner Microsoft-Appregistrierung.',
              ),
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Dateien lassen sich auch in OneDrive über „Teilen → FLEX“ übernehmen.',
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                '1. App „FLEX“ registrieren; persönliche Microsoft-Konten zulassen.\n2. Unter Authentifizierung öffentliche Clientflows aktivieren.\n3. Unter Microsoft Graph den delegierten Zugriff Files.Read aktivieren. Für die Scanablage zusätzlich Files.ReadWrite.AppFolder freigeben.\n4. Die Anwendungs-/Client-ID hier einfügen.',
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
                'Für die Registrierung ist ein Microsoft-Entra-Verzeichnis mit passenden Rechten nötig. FLEX benötigt keine kostenpflichtigen Azure-Rechendienste und aktiviert kein Testabo. Kein Client-Geheimnis anlegen oder hier eingeben.',
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
