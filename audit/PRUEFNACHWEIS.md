# Lokale Prüfung des Dialogaudits

> Nachtrag rebuild.7: Automatische Entwurfsfortsetzung ist durch die spätere ausdrückliche Nutzervorgabe aufgehoben. Aktueller Stand und Prüfnachweise: [UI_UX_PRUEFUNG.md](UI_UX_PRUEFUNG.md).

Arbeitsstand **0.16.0-rebuild.5+25**, Flutter **3.47.9**, Dart **3.13.7**. Die maßgeblichen aktuellen Ergebnisse sind `evidence/flutter-analyze.log` und `evidence/flutter-tests.log`; frühere Diagnoseprotokolle sind Zwischenläufe.

## Ausgeführte Prüfungen

| Prüfung | Ergebnis / Aussage |
| --- | --- |
| `flutter analyze --no-pub` | Keine Befunde im abschließenden Lauf |
| `flutter test --no-pub --reporter expanded` | **81 Tests bestanden**; vorhandene Tests plus neue Referenz-/Persistenz-/Fehlerfälle |
| Direkte Dialogmatrix | **37 Zustände × 3 Ansichtsvarianten = 111 PNGs** aus Flutter `RenderRepaintBoundary.toImage`; tatsächliches Engine-Rendering mit geladenen Schriftdateien |
| Weitere vorhandene Renderingtests | **10 zusätzliche PNGs**, darunter Schülerkarten, HÜ, Kommentar und Beobachtungs-/Kalenderansichten; insgesamt 121 PNGs im Ausgabeordner |
| HTML-Quelleninspektion | 65 Zustände, 21 eindeutige benannte Dialoge plus temporärer Passwortdialog in beiden Modi; Node/jsdom ohne CSS-Layout/Browser |
| Referenzintegrität | SHA-256-Prüfung aller Dateien des Referenzmanifests und ursprünglicher Recovery-Archive bestanden |
| Reviewbarkeit | Quelle-zu-Quelle-Patch gegen das hochgeladene ZIP; getrennte Hashlisten für aktiven Prüfquellstand und Renderings |

Die Testprotokolle enthalten die Drift-Diagnose zu mehreren Datenbankinstanzen. Die betreffenden Tests öffnen absichtlich getrennte Speicher-/Dateidatenbanken für Wiederherstellung und Wiederöffnung; sie verwenden nicht gleichzeitig denselben QueryExecutor. Die Diagnose wird nicht als bestandener Test verschwiegen oder mit einem Testfehler verwechselt.

## Ansichtsvarianten und Zustände

| Variante | Logische Pixel | Schriftfaktor | Tastatur-Inset |
| --- | --- | --- | --- |
| Breit | 1440 × 1000 | 1,0 | 0 |
| Schmal | 320 × 700 | 1,0 | 0 |
| Große Schrift und Tastatur | 320 × 700 | 2,0 | 280 |

Das Tastatur-Inset simuliert den vom Betriebssystem belegten Bereich. Die PNGs zeichnen **keine echte Bildschirmtastatur**. Sichtbare Dialogfläche, Außenabstand, Rundung, Überläufe und Erreichbarkeit der Speicheraktionen werden mit diesem verkleinerten Bereich geprüft. Große Inhalte dürfen scrollen. Ein Foto der Anfangsposition zeigt deshalb nicht immer gleichzeitig Kopf, Eingabefeld und Fuß.

Die Matrix umfasst Sozial leer/befüllt/fehlerhaft, Arbeit leer, Ziel neu/bearbeiten/überprüfen, HÜ neu/bearbeiten/Kommentar/Notiz, Orga Schüler/Klasse/befüllt, Schüler neu/bearbeiten/fehlerhaft, Katalog, Gruppe, gemeinsame Situation, Verlauf, Gespräch, Kalender mit/ohne Uhrzeit, Sicherung, Passwort Export/Import, Importprüfung, Pflege/Fehler, Entwürfe leer/befüllt, Klassen-Orga leer, Papierkorb leer, Konflikte leer/befüllt und ungesicherten Entwurf. `renderings/manifest.jsonl` nennt jede Datei und ihre genauen Parameter.

Leere, befüllte und fehlerhafte Zustände werden damit abgedeckt; dies ist **keine vollständige Kreuzkombination aller Dialoge mit allen möglichen Fehlern, Datenständen und Plattformen**.

## Bedienungs- und Persistenznachweise

Die Tests prüfen Auswirkungen auf gespeicherte Daten, nicht ausschließlich vorhandene Texte:

- Beobachtungsauswahl wandert in den gemeinsamen Eingaberahmen; Vorschlag und Stern verschwinden dort; Favorit bleibt unabhängig. Zeitpunkt wechseln und Unterstützung einklappen erhalten freien Text und gespeicherte Werte.
- Arbeitsauftrag allein ist gültig. Freier Text mit Trennzeichen bleibt freier Text; Auftragstags sind separat gespeichert.
- Speichern & weiter: Commit-Fehler hält Schüler/Eingabe fest; nächster aktiver Schüler und passender Entwurf werden fortgesetzt; letzter Schüler bleibt aktiv mit neuer Eintrags-ID.
- HÜ: vier direkte Stände, identischer Stand als No-op, Doppelklickschutz, Speicherfehler/Retry, unabhängige Teilaufgaben, aufgabenbezogener Kommentar mit Fokus und Modus nach Wiederöffnung.
- Kommentar beginnen, Aufgabenstand extern ändern, aktuelle Fassung ausdrücklich übernehmen, Kommentar speichern: neuer Aufgabenstand bleibt erhalten.
- Zieltermin und nächste Überprüfung getrennt; Abschluss entfernt nächste Frist, erzeugt Prüfung und lässt Zieltermin unverändert.
- Generische Entwürfe werden tatsächlich gezählt; ausgewählter Schülerentwurf wird fortgesetzt, der andere bleibt erhalten. Fehlgeschlagenes Schließen zeigt D12; Weiterbearbeiten erhält die Eingabe; auch ein Fehler beim Verwerfen bleibt sichtbar und erhält den Editor; erfolgreicher erneuter Versuch sichert den Entwurf ohne Schülerveröffentlichung.
- Orga-/allgemeine Entwurfsrevisionen weisen konkurrierende alte Schreibversuche ab. Gruppenvorgänge sind atomar, idempotent, je Schüler eigenständig und nur vor Einzeländerungen rücknehmbar.
- Reale SQLite-Datei schließen und erneut öffnen, zusätzlich vollständiger Backup-Rundlauf: Auftrag/Freitext, Schülerentwurf und Erinnerung ohne Uhrzeit gegenüber **00:00** bleiben erhalten.
- Katalog-Neueingaben beider Tonlisten werden beim Speichern berücksichtigt; fallunabhängige Duplikate führen zum Rollback beider Listen. Abgeschaltete Katalogübernahme im echten Restore erhält lokale Kataloge.
- Kalender mit Schaltjahr, Monats-/Jahreswechsel, Pfeiltasten über Monatsgrenze, Mitternacht, Entfernen und unverändertem Ergebnis bei Abbruch.
- Bereinigung blockiert nach Änderung des zuvor exportierten Snapshots; gelöschte Einträge, Verweise und frühere Fassungen werden konsistent bereinigt.
- Lesbarer Verlauf filtert Orga/Fachdatensätze und zeigt tatsächliche historische Inhalte. Konfliktentscheidung erhält beide Alternativen und erzeugt eine neue Revision.
- Die Sozial-Fehlermeldung wird nach erfolglosem Speichern in die sichtbare Dialogfläche gescrollt; die Matrix prüft ihre Lage.

Testquellen: [dialog_reference_test.dart](../flutter_app/test/dialog_reference_test.dart), [rebuild_ui_test.dart](../flutter_app/test/rebuild_ui_test.dart), [handover_ui_test.dart](../flutter_app/test/handover_ui_test.dart), bestehende Modell-/Datenbank-/Kryptografietests unter `flutter_app/test/`.

## Tatsächliche Sichtprüfung

Die abschließende Bildstichprobe mit SHA-256 und die zusätzlich während der Korrekturen geöffneten Ansichten stehen in [visual-review.json](evidence/visual-review.json). Geprüft wurden ausgewählte direkte PNGs, keine Browserbilder und nicht pauschal alle 121 Dateien.

Dabei sichtbar überprüft: runde Originalfarbpalette, vollständiger Monatsname bei 320 Pixel, gemeinsamer Tag-/Freitextrahmen, durchgehende Vorschlag-/Sternflächen, Kopf-/Fußfarben, Titel-/Labelhierarchie, Zusatzangaben, Ziel-/HÜ-Speichertexte, kleine Dialoge, schmale Konfliktspalten, sichtbare Fehlermeldungen und Scrollverhalten bei großer Schrift/Tastatur. Gefundene Probleme – abgeschnittener Monatsname, ausufernde HEX-Farbchips, fehlende Lesbarkeit des Verlaufs, abweichende Detailbreiten und unsichtbare Sozial-Fehlermeldung – wurden korrigiert und neu gerendert.

Die Grafikdarstellung wurde gegen dokumentierte CSS-Werte, Elementreihenfolge und spätere Nutzervorgaben geprüft. **Kein vollständiger visueller Pixelvergleich mit gerendertem Original-HTML oder dem kompilierten Webpreview.** Deshalb keine Behauptung „originalgetreu“; konkrete Restabweichungen siehe [Abgleich](FLUTTER_ABGLEICH.md).

## Reproduktion

Im vollständigen Quellenpaket:

```sh
cd flutter_app
flutter pub get
flutter analyze --no-pub
FLEX_RENDER_DIR="$PWD/../audit/renderings" flutter test --no-pub --reporter expanded
```

Die Variable weist die Tests an, ihre Renderings zu speichern. Unter PowerShell vor `flutter test` beispielsweise `$env:FLEX_RENDER_DIR = (Join-Path (Get-Location) '../audit/renderings')` setzen.

In dieser Umgebung wurden `XDG_CONFIG_HOME=/workspace/.runtime`, `PUB_CACHE=/workspace/.pub-cache`, `ANALYZER_STATE_LOCATION_OVERRIDE=/workspace/.runtime/analyzer` und `DASH__SUPPRESS_ANALYTICS=true` verwendet. Der Testprozess benötigt einen lokalen VM-Service-Socket; dessen Freigabe ist **kein Browserzugriff**.

Originalintegrität und Patch im Repository-Wurzelverzeichnis:

```sh
sha256sum -c recovery/SHA256SUMS
python3 audit/tools/compare-recovered.py /pfad/zur/unveraenderten/FLEX-Notes-Extraktion
```

Das Referenzmanifest wird aus `audit/` mit `sha256sum -c evidence/reference-SHA256SUMS` geprüft. Die Source-Hashliste in `evidence/tested-source-SHA256SUMS` gilt relativ zur Repository-Wurzel. Die Bildhashliste gilt relativ zu `audit/renderings/`.

Nicht ausgeführt: Browsertests, Geräte-/OS-Dateidialogtests, Android-/Windows-Releasebuild, vollständige HTML-Datenmigration, Web-Deployment oder Veröffentlichung. Es wurden ausschließlich synthetische Testdaten benutzt.
