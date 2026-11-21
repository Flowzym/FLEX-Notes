# FLEX 0.32.0+83 für Android

- [ARM64 herunterladen](FLEX-0.32.0%2B83-arm64.apk) · für die meisten aktuellen Android-Handys
- [ARMv7 herunterladen](FLEX-0.32.0%2B83-armv7.apk) · für ältere 32-Bit-Geräte
- [Prüfsummen und Quellcommit](release-manifest.json)
- [Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/)

Materialien lassen sich direkt an der Materialkarte, in den Details und aus der
Schülerübersicht zuordnen. Einsatzdaten sind optional und pro Schüler unabhängig;
mehrere Materialien können gemeinsam zugeordnet werden. Ein Schülerfilter und
wirksame Suche in „Bereitgelegt“ helfen beim Wiederfinden. Persönlich geplante
Einsätze erscheinen dort auch ohne zusätzliche Klassen-Tagesvorbereitung.
Materialdetails und Vorschauen sind neu geordnet.

Als Update über FLEX Build 62–82 installieren, **nicht vorher deinstallieren**.
App-Kennung, permanentes Zertifikat und Schema 8 bleiben unverändert. Bestehende
Zuordnungen, Einsatzdaten, Materialien, Schüler und Einträge bleiben erhalten.
Die native Microsoft-Anmeldung aus Build 82 ist unverändert.

[Materialprüfung und Bedienung](../../../docs/rebuild/MATERIAL-BUILD-83.md).

## Prüfstand

- Vollständige Flutter-Suite: **673 erfolgreich**, keine fehlgeschlagenen Tests.
- 45 Materialtests auf dem abschließenden Stand erfolgreich, darunter zehn neue
  Regressionstests für individuelle Zuordnung, Daten, Filter, Suche und Konflikte.
- 11 SQLite-Tests, Analyse und Formatprüfung erfolgreich.
- Browser: zwei Schüler mit verschiedenen Einsatzdaten; Speichern, erneutes
  Öffnen und vollständiges Neuladen; Foto öffnen; Papierkorb und Wiederherstellung
  mit erhaltenen Zuordnungen; Darstellung bei 320/390 Pixeln ohne JavaScriptfehler.
- Android- und Web-Releasebuilds erfolgreich; private Webvorschau aktualisiert.
- Beide APKs geprüft: Version/App-Kennung, permanentes Zertifikat, v1/v2/v3-Signatur,
  MSAL-Konfiguration/Rückleitung, SQLCipher, 16-KB-Ausrichtung, keine privaten
  Signierdaten und keine DWARF-Sektionen in libapp.so. Symbole/R8-Zuordnung separat.

Die Browserprüfung verwendet ausschließlich synthetische Daten. Installation,
Dateiauswahl, Kamera, Teilen an andere Android-Apps und echter OneDrive-Zugriff
wurden in dieser Runde nicht auf einem physischen Gerät geprüft.

[ARM64-Prüfung](verification-arm64.json) · [ARMv7-Prüfung](verification-armv7.json) ·
[Testnachweis](validation.json)
