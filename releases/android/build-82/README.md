# FLEX 0.31.0+82 für Android

- [ARM64 herunterladen](FLEX-0.31.0%2B82-arm64.apk) · für die meisten aktuellen Android-Handys
- [ARMv7 herunterladen](FLEX-0.31.0%2B82-armv7.apk) · für ältere 32-Bit-Geräte
- [Prüfsummen und Quellcommit](release-manifest.json)
- [Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/)

**Material → OneDrive** öffnet jetzt Microsofts native MSAL-Anmeldung. Die
Entra-Registrierung ist hinterlegt; auf Android entfällt die Eingabe eines Codes.
FLEX fordert delegiertes `Files.Read` an und verändert keine OneDrive-Dateien.
MSAL verwaltet die Sitzung und erneuert Zugriffstokens. Bei widerrufener
Zustimmung kann man sich erneut anmelden; Trennen bleibt erreichbar.

Als Update über FLEX Build 62–81 installieren, **nicht vorher deinstallieren**.
Paketname, permanenter Signierschlüssel und Schema 8 bleiben unverändert.
Schüler, Einträge, Entwürfe und vorhandene Materialien bleiben erhalten.
Die frühere Android-Anmeldesitzung wird durch MSAL ersetzt: bitte einmal neu
bei Microsoft anmelden. Im Browser bleibt die Anmeldung per Microsoft-Code.

[Einrichtung, Berechtigungen und Geräteabnahme](../../../docs/rebuild/ONEDRIVE-SETUP.md).

## Prüfstand

- 12 neue Flutter-Tests für native Anmeldung, Kanal, Kontobindung, Abbruch,
  Token-Erneuerung und Abmelden während laufender Anfragen erfolgreich.
- Vollständiger Flutter-Lauf: 662 erfolgreich; ein veralteter Navigationstest
  erwartete noch die frühere Wischreihenfolge. Korrigiert und die gesamte
  betroffene Datei erneut geprüft: 10 erfolgreich. App-Navigation unverändert.
- 10 native JVM-Tests, 11 SQLite-Tests, Analyse und Formatkontrolle erfolgreich.
- Android- und Web-Releasebuilds erfolgreich. Web-Anmeldedialog mit simuliertem
  Microsoft-Server bei 320/390 Pixeln geprüft, keine JavaScriptfehler.
- Beide endgültigen APKs: Version, App-Kennung, permanentes Zertifikat,
  v1/v2/v3-Signatur, MSAL-Konfiguration/Rückleitung, SQLCipher, 16-KB-Ausrichtung
  und fehlende private Signierdaten geprüft. Debugsymbole und R8-Zuordnung separat.

MSAL bringt Android-Credential-/Passkey-Bibliotheken mit. Der CameraX-Scanner
bleibt unabhängig von ML Kit. Nimbus' optionale Kryptografieklassen sind
vollständig aufgelöst; keine pauschale Unterdrückung fehlender R8-Klassen.

**Offen:** Installation und echte Anmeldung mit dem eigenen Microsoft-Konto
auf Android, tatsächlicher Ordner-/Dateizugriff und Wiederanmeldung nach Neustart.
Die Tests verwenden simulierte Konten und bestätigen keinen echten Kontozugriff.

[ARM64-Prüfung](verification-arm64.json) · [ARMv7-Prüfung](verification-armv7.json) ·
[Testnachweis](validation.json)
