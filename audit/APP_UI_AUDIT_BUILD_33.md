# App- und UI-Audit – Build 33

Stand: **0.16.0-rebuild.13+33**, 3. November 2026.

## Ergebnis und Änderungen

- Sozial und Arbeit: kompakte Auswahl **Positiv · Neutral · Negativ** mit horizontalem
  Wischen in dieser Reihenfolge. An den Enden bleibt die Auswahl stehen. Neutrale
  Beobachtungen besitzen eigene sachliche Tags, Favoriten und Freitext. Alle eigenen
  Katalogeinträge sind direkt im Formular sichtbar, ohne „Mehr anzeigen“.
- Standardauswahl unter **Einstellungen → Bedienung**; Appstandard Neutral. Ein
  Darstellungsreset erhält diese Bedienungseinstellung. Bestehende Beobachtungen
  und Entwürfe öffnen weiterhin mit ihren vorhandenen Auswahlen.
- Orga: Notiz, Aufgabe und Termin als obere Auswahlbuttons. Aufgaben zeigen Fälligkeit
  und Erledigt-Status, Termine Datum und optionale Uhrzeit. Notizen zeigen diese
  Felder nicht. „Beobachtet am“ wurde aus dem Orga-Formular entfernt; bestehende
  Datumsmetadaten und die Historie werden nicht gelöscht.
- Orga-Erinnerungen: Ausschalten entfernt nun den aktiven Erinnerungstermin und
  Status. Zuvor wurden lediglich die Eingabefelder eingeklappt. Validierungsfehler
  werden auch bei offener Tastatur sichtbar gescrollt.
- **Abbrechen** ersetzt „Speichern & weiter“. Es veröffentlicht keine Eingabe und
  sichert begonnene Änderungen als Entwurf. Entwürfe können weiterhin ausdrücklich
  gelöscht werden. Auch beim Bearbeiten bleibt der veröffentlichte Stand bis zum
  Speichern unverändert.
- Schülerseite: reine Suchlupe direkt neben dem Hinzufügen, aktive Filtermarkierung,
  direktes Leeren einer inaktiven Suche und unveränderter Filter bei Fokusverlust.
- Kompaktere Unterrichts-/Pausenbuttons. Kleinere Dreifachpille; bei sehr großer
  Systemschrift werden ihre drei Optionen ohne Abschneiden untereinander angeordnet.
- Einstellungen: erklärende Absätze entfernt, Darstellungsgruppen dauerhaft offen,
  Export/Import und Speicherpflege direkt erreichbar. Mobil folgen die Optionen vor
  der Vorschau. Keine vorhandene Einstellungsoption wurde entfernt.
- Symbolkontrast folgt nun der tatsächlichen Fläche auch bei heller Einstellung
  mit dunkler Hintergrundfarbe, einschließlich eigener gezeichneter Bereichssymbole.

## Daten und Kompatibilität

Die optionale JSON-Liste `neutral` wird in alten Datensätzen als leere Liste gelesen.
Neutrale Angaben werden in Einzel- und Gruppeneinträgen, Entwürfen, Revisionen,
Suchtexten, Karten, Verlauf und Gesprächsvorbereitung berücksichtigt. Alte
Katalogentwürfe ohne Neutral-Liste übernehmen den vorhandenen neutralen Katalog,
ohne dessen Anpassungen zu überschreiben. Alte Darstellungseinstellungen starten
mit Neutral als Standard. Es gibt keine SQL-Schemaänderung und keinen Datenreset.

Die Android-App behält `at.flowzym.flex_notizbuch.test` und dieselbe Testsignatur.
Build 33 über die vorhandene FLEX Test installieren; nicht deinstallieren. Die
Prüfung umfasst echte SQLite-Dateien mit Schließen/Öffnen und vollständige Sicherung
und Wiederherstellung. Ein physisches Android-Update wurde nicht ausgeführt.

## Prüfumfang

Der vollständige Flutter-Testbestand deckt Speicherung, Datenvalidierung,
Revisionskonflikte, Rücknahme/Papierkorb, Entwürfe und Löschrennen, Backup inklusive
Verschlüsselung, Schüler/Archiv, Ziele, Sozial/Arbeit, Hausübungsstatus, Gruppen,
Orga/Termine/Checklisten/Erinnerungen, Suche, Navigation, Kalender, Einstellungen,
Exportbrücke und Fokus bei Tastatur-/Skalierungswechseln ab.

17 zusätzliche Tests in `full_audit_test.dart` ergänzen unter anderem:

- alte Daten ohne Neutral, gültige/ungültige neue Tags und Standardwerte;
- Dateidatenbank-Neustart, vollständige Wiederherstellung, Kataloge und Favoriten;
- unabhängige neutrale Angaben in Gruppeneinträgen und alte Katalogentwürfe;
- drei Wischzustände mit Randverhalten, gemischte Tags und Freitext, stabile
  Eingabeverbindung bei Tastaturresize;
- konfigurierbaren Standard und dessen Erhalt beim Darstellungsreset;
- Orga-Typwechsel für Klasse und Schüler, passende Felder, Text- und Datenerhalt;
- deaktivierte Erinnerungen, sichtbare Fehler bei offener Tastatur und Korrektur;
- Suchlupe neben Hinzufügen, erhaltenen Filter und direktes Leeren;
- alle Optionen auch bei mehr als sechs Katalogeinträgen;
- direkte Renderings und erreichbare Regler/Datenaktionen mit 320, 390 und 1200 px,
  dunkler/heller Einstellung, 200 % Systemschrift und 120 % App-Skalierung.

Bestehende Tests der entfernten „Speichern & weiter“-Funktion prüfen jetzt
Abbrechen und Entwurfserhalt, einschließlich Speicherfehlern und unveränderten
Entwürfen anderer Schüler. Tests positiver Tags wählen Positiv ausdrücklich,
statt einen impliziten alten Standard vorauszusetzen.

Ergebnis: **218 Flutter-Tests bestanden**, darunter 17 neue Tests. Statische Analyse
ohne Befunde, 11 SQLite-Vertragstests und 3 lokale HTTP-Serverprüfungen bestanden.
Android- und Web-Releasebuild erfolgreich, einschließlich Wasm-Kompilierprüfung.
48 aktuelle Renderings wurden auf schmale/breite Ansichten, Textumbrüche,
Funktionsfelder, Kontrast, Tastaturplatz und erreichbare Optionen geprüft.

- [Vollständiger Flutter-Testlauf](evidence/app33-flutter-tests.log)
- [17 ergänzte Tests und Renderings](evidence/app33-focused-tests.log)
- [Statische Analyse](evidence/app33-analyze.log)
- [SQLite-Vertragstests](evidence/app33-schema-tests.log)
- [Lokale Vorschau-Servertests](evidence/app33-preview-server-tests.log)
- [Android-Releasebuild](evidence/app33-apk-build.log) · [Webbuild](evidence/app33-web-build.log)
- [APK-Verifikation](evidence/app33-apk-verification.json)
- [Quellprüfsummen](evidence/app33-source-sha256.txt)
- [Unveränderte Wiederherstellungsbasis](evidence/app33-recovery-checksums.log)
- [48 direkte Renderings](full-audit-renderings/README.md)

APK: **64625528 Bytes**, SHA-256 `53fee7ca590ccccf42a3beec81bf6601775b16d3692c7e83702b3901ba19545c`.
Paketkennung, Version, Start-Activity, Testzertifikat und die enthaltenen nativen
Bibliotheken sowie ZIP-/ELF-Ausrichtung für 16-KB-Seiten wurden geprüft.

## Grenzen

Die App bleibt der dokumentierte Flutter-Wiederaufbau. Ein Testlauf auf einem
angeschlossenen Android-Gerät, mit einer echten Android-Tastatur und einem realen
Dokumentanbieter steht noch aus. Flutter-Engine-Prüfungen simulieren Tastaturinsets
und kontrollieren Fokus und Eingabeverbindung; sie ersetzen diesen Gerätelauf nicht.
Der Webbuild und lokale HTTP-Tests prüfen Kompilierung und Auslieferung, keine
Browserinteraktion. Orga-Erinnerungen bleiben Anzeigen innerhalb der App.
Import-Zusammenführung und vollständige feldweise Konfliktauflösung bleiben die
bereits dokumentierten offenen Produktfunktionen. Es wurden keine externen Termine
oder Benachrichtigungen eingerichtet und keine Cloud-Vorschau veröffentlicht.
