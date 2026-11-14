import 'package:flutter/material.dart';
import 'flex_modal.dart';

Future<void> showPrivacyDetails(BuildContext context) => showDialog<void>(
  context: context,
  builder: (ctx) => FlexModal(
    title: const Text('Datenschutz & Speicher'),
    onClose: () => Navigator.pop(ctx),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final section in const [
          (
            'Auf diesem Gerät',
            'Einträge und Dateien werden lokal gespeichert. Die Android-App verschlüsselt ihre Datenbank und gespeicherte Dokumente mit einem Geräteschlüssel. Die Webvorschau nutzt den lokalen Browserspeicher ohne diese zusätzliche Verschlüsselung.',
          ),
          (
            'Sicherung & Gerätewechsel',
            'Nur eine vollständige Sicherung enthält auch Dateien und Scanentwürfe. Verschlüsselte Sicherungen lassen sich mit ihrem Passwort auf einem anderen Gerät öffnen. Ohne Sicherung können Daten beim Löschen der App oder beim Verlust des Geräteschlüssels nicht wiederhergestellt werden.',
          ),
          (
            'Kamera & Scanner',
            'Die Live-Randerkennung verwendet den Google-Dokumentenscanner über Google Play-Dienste. Die Bildverarbeitung erfolgt auf dem Gerät; die Dienste können Diagnose- und Nutzungsdaten nach Googles Bedingungen verarbeiten. Die einfache Fotoaufnahme ist ebenfalls verfügbar.',
          ),
          (
            'OneDrive & Teilen',
            'OneDrive wird erst nach Anmeldung verwendet und greift lesend auf die ausgewählten Materialien zu. Beim Öffnen oder Teilen erhält die gewählte andere App eine lesbare Kopie. Bereits weitergegebene Kopien kann FLEX nicht zurückholen.',
          ),
          (
            'Schwärzen & Versionen',
            'Schwärzungen werden fest in die neue Seite eingerechnet. Frühere Versionen, andere Kopien, offene Entwürfe und bereits erstellte Sicherungen können ungeschwärzte Inhalte enthalten. Beim Ersetzen bietet FLEX das Entfernen der früheren Versionen dieses Dokuments an.',
          ),
        ]) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 5),
            child: Text(section.$1, style: Theme.of(ctx).textTheme.titleSmall),
          ),
          Text(section.$2),
        ],
      ],
    ),
  ),
);
