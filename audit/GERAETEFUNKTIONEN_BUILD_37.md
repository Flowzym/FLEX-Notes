# Sicherungen, Erinnerungen, Zusammenführen, PDF und App-Sperre – Build 37

Stand: 4. November 2026, `0.16.0-rebuild.17+37`, Branch `fix/dialog-reference-audit`.
Umsetzung der ausgewählten Empfehlungen **1, 2, 3, 5 und 6**. Keine Vorlagen und keine Änderung am SQL-Schema 7.

## Funktionen und Datenverhalten

- **Automatische Sicherungen:** Android-Dokumentordner mit dauerhaftem Zugriff, Passwort ab zwölf
  Zeichen, täglich/wöchentlich, 7/14/30 Dateien. Vorhandener AES-256-GCM-/PBKDF2-SHA256-Codec
  (310.000 Iterationen, zufälliges Salt/Nonce). Android WorkManager arbeitet auch ohne offene UI;
  eine fällige Sicherung wird zusätzlich bei Nutzung der App angestoßen. Erfolg wird erst nach
  erneutem Lesen und SHA-256-Vergleich gespeichert. Bei Fehlern bleiben vorherige Sicherungen erhalten.
  Aufbewahrung entfernt nur Dateien dieser Einrichtung, auch wenn mehrere Geräte denselben Ordner nutzen.
  Letzter Erfolg/Fehler, sofortige Sicherung, Ordnerliste und Import sind sichtbar.
- **Android-Erinnerungen:** Termine, offene Aufgaben/Hausübungen, aktive Zielüberprüfungen sowie explizite
  Orga-Erinnerungen. Ohne Uhrzeit gilt die einstellbare Tageszeit. Abgeschlossene, gelöschte, archivierte,
  bestätigte oder abgebrochene Erinnerungen werden nicht neu eingeplant. Stabile IDs verhindern doppelte
  Alarme; Änderungen/Ausschalten gleichen die Android-Liste ab. Boot-/Update-Receiver stellen geplante
  Alarme wieder her. Allgemeine Benachrichtigung ohne Schülerdaten; Antippen öffnet den betreffenden
  Eintrag nach der App-Entsperrung. Exakte Alarme sind optional, sonst inexactAllowWhileIdle.
- **Zusammenführen:** erst strenge Importprüfung und schreibfreie Vorschau, dann atomare Übernahme.
  Gleiche stabile IDs erkennen vorhandene Einträge; gleiche Inhalte werden übersprungen. Gleichnamige
  Schüler mit anderen IDs erfordern ausdrückliche Zuordnung oder getrennte Übernahme. Keine automatische
  Gleichsetzung verschiedener Beobachtungen nur wegen gleichen Texts. Pro abweichendem Feld bleibt
  zunächst der lokale Wert ausgewählt. Listen sind jeweils ein Feld. Ungültige Feldkombinationen und
  inzwischen geänderte Arbeitsstände verhindern den gesamten Import. Schüler, Einträge, Entwürfe,
  Zielbezüge, gemeinsame Situationen, Checklisten, Terminmetadaten und Katalogauswahl werden berücksichtigt.
  Neue Datensätze behalten ihren Verlauf. Abweichende Verlaufszweige und Gruppenaktionen bleiben in der
  vollständigen Originalfassung im **Importarchiv** erhalten und können wieder verschlüsselt exportiert
  werden. Es gibt keine stille Übernahme fremder Geräte-Operationszähler. Ergebnis muss weiterhin
  innerhalb des bestehenden 20-MB-Sicherungslimits exportierbar sein, sonst vollständiger Rollback.
- **PDF:** vorhandene Gesprächsvorbereitung mit Zeitraum, Bereichsauswahl und einzelnen Einträgen;
  zusätzliche Namen bleiben optional. Eingebettete Schriften, A4, Seitenzahlen und Umbruch langer Notizen.
  Änderungen an Auswahl/Zeitraum/Bereichen verwerfen die alte Vorschau. PDF und Text verwenden dieselbe
  zusammengestellte Fassung, einschließlich Orga-Termindatum/Uhrzeit. Export über Androids Dateidialog.
- **App-Sperre:** PIN mit 6–12 Ziffern und optionaler biometrischer Bestätigung. Gesalzener PIN-Hash
  mit PBKDF2-SHA256 (210.000 Iterationen), persistente Fehlversuchsbegrenzung mit Wartezeit nach fünf
  Fehlversuchen. Alte PIN für Änderung/Ausschalten. Sperre bei Verlassen/Neustart, gesperrte Navigation,
  Erhalt offener Editoren und FLAG_SECURE für Vorschau/Screenshots. Abbruch oder Speicherfehler entsperrt
  nicht; ein Hintergrundwechsel während der Entsperrung wird berücksichtigt. Kein automatisches
  Löschen beschädigter Secure-Storage-Schlüssel. **Keine Verschlüsselung der lokalen Datenbank.**

Passwörter, PIN-Konfiguration und Android-Berechtigungen liegen gerätespezifisch außerhalb der
exportierten Fachdaten. Nach Neuinstallation/Gerätewechsel werden die Gerätefunktionen neu eingerichtet.
FLEX-Sicherungen bleiben manuell mit dem Sicherungspasswort lesbar. Android-Systembackup und
System-Geräteübertragung sind deaktiviert, um Daten und gerätegebundene Schlüssel nicht getrennt zu kopieren.

## Implementierung

`services/` trennt Sicherung, Sperre, Erinnerungsplanung und Plattformadapter. Der Controller gibt
konsistente Snapshots an die Dienste; Plattformfehler verhindern keine fachlichen Speicherungen.
Die Hintergrundsicherung verwendet dieselbe Datenbanköffnung und denselben Export wie die UI.
Das interne Android-Plugin `packages/flex_device` stellt SAF-Zugriff auch im Hintergrund-Engine bereit.
Eine native prozessweite Sperre serialisiert Sicherungen/Einstellungsänderungen über Flutter-Engines.
Kryptographische Ableitungen und Sicherungsverschlüsselung laufen außerhalb des UI-Isolates.

Die Importprüfung verwendet die bestehende Restore-Validierung innerhalb eines immer zurückgerollten
verschachtelten SQLite-Transactions. Die Übernahme prüft den unveränderten Tabellenstand erneut und
validiert JSON-Verknüpfungen sowie SQLite-Fremdschlüssel vor dem Commit. Originaldateien werden ohne
komprimierte, potentiell unbeschränkt expandierende Daten in das Importarchiv übernommen.
Der bisherige separate Konfliktdialog für lokale konkurrierende Bearbeitungen bleibt eine Fassungswahl;
feldweise Auswahl ist Teil des neuen Sicherungsimports.

## Prüfung

- `flutter analyze --no-pub`: ohne Befunde.
- Vollständige Flutter-Testsuite: **264 bestanden**, davon 24 neue Tests gegenüber Build 36.
  Abschließende PDF-Umbruchkorrektur zusätzlich gezielt nachgeprüft.
  [Prüfprotokoll](evidence/build-37-checks.txt).
- Neue Tests: verschlüsselte Sicherung/Lesekontrolle/Rotation/Fehler, Scheduler-Ausfall, Wiederherstellung;
  PIN-Neustart/alte PIN/Fehlversuchsgrenze/Speicherfehler/Hintergrundrennen; Erhalt offener Editoren und
  Zurück-Navigation unter Sperre; Erinnerungsplanung/Abgleich/Berechtigungsablehnung; atomarer Import,
  Dubletten, erneuter Import, Entwürfe, Schülerzuordnung, Feldwahl, veraltete Vorschau, beschädigte Quelldaten,
  Katalog-Ausschluss bei vollständigem Originalarchiv; PDF und Export unveränderter Binärdaten.
- Neue Einstellungsdialoge als Widgets auf 390 Pixeln mit normaler und doppelter Schriftgröße geprüft.
- Unabhängige PDF-Prüfung mit `pdfinfo`/`pdftotext`: mehrseitiges A4-Langdokument, Umlaute, Notizen und nächste Schritte.
- Android-Releasebuild: Universal-APK, API 24–36, ARM64/ARMv7/x86_64; Paketkennung, Testsignatur,
  Manifest-Receiver/Berechtigungen, native Registrierung und 16-KB-Ausrichtung geprüft.

Keine Browsertests und keine physische Android-Abnahme. Noch erforderlich sind insbesondere tatsächliche
Benachrichtigungen/Backups nach Prozessende und Geräte-Neustart, Doze/OEM-Energiesparen, persistenter
Zugriff auf lokale/Cloud-Dokumentanbieter, Biometrie und Updateinstallation mit realem Datenbestand.
WorkManager meldet einen Hinweis zur künftig nötigen Migration seines Kotlin-Gradle-Plugins;
der Build mit den hier festgehaltenen SDK-/Abhängigkeitsversionen funktioniert.

[Installation und Einrichtung](../flutter_app/ANDROID-TEST.md) · [APK Build 37](../releases/android/build-37/README.md)
