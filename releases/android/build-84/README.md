# FLEX 0.33.0+84 für Android

- [ARM64 herunterladen](FLEX-0.33.0%2B84-arm64.apk) · aktuelle Android-Handys
- [ARMv7 herunterladen](FLEX-0.33.0%2B84-armv7.apk) · ältere 32-Bit-Geräte
- [Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/)
- [Integrationsprüfung, Korrekturen und offene UX-Punkte](../../../docs/rebuild/INTEGRATION-SCANNER-BUILD-84.md)

Rückläufe erscheinen beim zugeordneten Schüler, in Aufgaben, Verlauf und
Entwürfen. Individuelle Statusanzeigen, Zähler, Suche und gemeinsame Anhänge
sind verbunden. Speicherfehler bleiben sichtbar und verlieren keine Eingaben.
Lokal bearbeitete OneDrive-Dateien werden beim erneuten Einlesen nicht mehr
mit dem Cloud-Original überschrieben. Offlinekopien öffnen ohne Netzwerkwarten.

Die eigene Dokumentkamera hat Live-Kantenanzeige, eine stabilisierte automatische
Aufnahme, Dokument-/Fotomodus, Serienaufnahme, Kameralicht und eine Vorschau der
letzten Aufnahme. Filtervorschauen, Zuschnitt, Sortieren, Ersetzen, Schwärzen und
Tags bleiben im anschließenden Editor erreichbar.

Als Update über FLEX Build 62–83 installieren, **nicht vorher deinstallieren**.
App-Kennung, permanentes Zertifikat und Schema 8 bleiben unverändert.
Die native Kamera steht in der Android-App zur Verfügung; die Webvorschau
unterstützt Import, Bearbeitung und Verwaltung.

## Prüfnachweise

- Vollständige Flutter-Suite: **687 erfolgreich**, keine fehlgeschlagenen Tests.
  Nach der letzten Korrektur an gemeinsamen Rücklauf-Vorschaubildern: sämtliche
  **10 Rücklauf-Regressionsprüfungen** auf dem endgültigen Quellstand erfolgreich.
- **16 native Android-Tests**, darunter Live-Kanten, geringer Kontrast,
  Auslösestabilität, Doppelaufnahmeschutz, Geometrie und verschlüsselte Dateien.
- **11 SQLite-Prüfungen**; Analyse, Formatkontrolle und Diff-Prüfung erfolgreich.
- Gefüllte Seiten/Editoren in 320/390/768/1280 Pixeln, große Schrift,
  Tastatur und Hell/Dunkel in den UI-Prüfungen durchlaufen.
- Browser mit separaten Testdaten: Rücklauf anlegen, eigener Status, Schüler-
  und Aufgabenansicht, PDF importieren/filtern/taggen/speichern, Vorschaubilder
  und PDF nach vollständigem Neuladen erhalten. Keine JavaScriptfehler.
- Simulierte Microsoft-Antworten: Dateiauswahl öffnet direkt nach Anmeldung;
  Ordnernavigation, Verknüpfung und Ordnermerken geprüft. Keine echte Anmeldung.
- Beide endgültigen APKs geprüft: Paketkennung/Version, permanentes Zertifikat,
  v1/v2/v3-Signatur, MSAL-Rückleitung, SQLCipher, ZIP-Integrität und 16-KB-
  Ausrichtung. Keine privaten Signierdaten oder DWARF-Sektionen in `libapp.so`;
  Debugsymbole und R8-Zuordnung separat aufbewahrt.
- Webvorschau erfolgreich unter derselben privaten Adresse aktualisiert.

[Prüfergebnisse](validation.json) · [Prüfsummen und Quellcommit](release-manifest.json) ·
[ARM64-Prüfung](verification-arm64.json) · [ARMv7-Prüfung](verification-armv7.json) ·
[Logs und Bildschirmnachweise](../../../docs/rebuild/evidence/build-84/).

Eine physische Android-Abnahme, echte OneDrive-Anmeldung und Tests der
Live-Kamera unter unterschiedlichen Lichtbedingungen stehen noch aus.
Die bestehenden Build-Warnungen zweier externer Kotlin-Plugins und die Grenzen
des signierten GitHub-Releaseprozesses sind im Integrationsreview dokumentiert.
