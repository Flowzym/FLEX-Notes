# UI-/UX-Prüfung und Entwurfskorrektur · rebuild.7

Historischer Bericht für rebuild.7. Die späteren Änderungen an Badges, Zugängen und Flächen stehen im [aktuellen Abgleich](UEBERSICHT_ORGA_ABGLEICH.md).

Stand: **0.16.0-rebuild.7+27**, 02.11.2026. Bearbeitbare Grundlage ist der nachgereichte
Quellenfund, weitergeführt auf `fix/dialog-reference-audit`. Die jüngste Nutzervorgabe
ersetzt die frühere automatische Entwurfsfortsetzung ausdrücklich.

## Ergebnis der Korrekturen

| Anforderung / festgestellte Abweichung | Verhalten dieses Stands | Nachweis |
| --- | --- | --- |
| Shortcuts setzten passende Entwürfe automatisch fort | Alle fünf Schülerkarten-Shortcuts öffnen einen neuen Eintrag. Vorhandene Entwürfe bleiben getrennt; Öffnen nur über Badge/Entwurfsliste und „Fortsetzen“. Auch „Speichern & weiter“ beginnt beim nächsten Schüler leer. | `settings_test`, `handover_ui_test`, `draft_ux_test` |
| Bedienänderung allein erzeugte leeren Entwurf | Vergleich mit dem ursprünglichen Inhalt: Leerzeichen, leere Aufgabenzeilen, generierte IDs, Bereichswechsel im neuen Gruppenformular, Tonwechsel, aufgeklappte Abschnitte, Fokus und Katalog-Fehlermeldungen erzeugen keinen Inhalt. Eingaben, Tags, zusätzliche Empfänger und tatsächlich geänderte Termine zählen. | Neue Tests für alle vier Fachbereiche, Orga, Katalog und Gruppe |
| Vollständig geleerte Eingabe blieb als Entwurf stehen | Nach Rückkehr zum Ausgangsinhalt wird nur der eigene Entwurf entfernt. Auch bei bearbeiteten gespeicherten Einträgen bleibt die Originalfassung erhalten. | Automatisches Sichern → schließen → ausdrücklich fortsetzen → leeren; Bearbeitung zurücksetzen |
| Entwurfsvergleich ging beim Neustart verloren | Optionaler Ausgangsvergleich wird mit dem Entwurf gespeichert, ohne Änderung des SQL-Schemas. Bestehende Entwürfe bleiben lesbar; alte Entwürfe ohne diese Information werden konservativ behandelt und nicht pauschal bereinigt. | SQLite-Datei schließen/öffnen und Backup-Rücksicherung für alle drei Entwurfsspeicher |
| Sozial/Arbeit ohne sichtbare Entwurfsbadges | Eigene Entwurfszähler auf den jeweiligen Shortcuts, getrennt von offenen Vorgängen. Gruppeneinträge erscheinen bei den betreffenden Empfängern. Badge öffnet die gefilterte Liste. Bei großer Schrift steht es unter dem Symbol. | Tatsächliches Fortsetzen/Speichern, Mehrfachzählung und Prüfung überlappender Rechtecke |
| Löschen konnte neuere Entwurfsfassung entfernen | Versionsprüfung auch beim Verwerfen/automatischen Entfernen; veraltete Zugriffe werden abgewiesen. Schreibreihenfolge bleibt seriell. | Konkurrenzprüfung für Orga-, Fach- und Dialogentwürfe; verzögertes Sichern mit anschließendem Leeren; Fehler/Retry |
| HÜ bestand aus großen Einzelkapseln | Gemeinsame Aufgabenliste mit Nummern, eingerückten Teilaufgaben, Zeilentrennern, transparenten Eingaben und kompakten Zeilenaktionen. Derselbe Editor für Einzel- und Gruppen-HÜ. | HTML `.hw-task-editor`, `.hw-task-row`, `taskEditorRows`; direkte Renderings |
| Enter unmittelbar nach Eingabe ordnete neue Zeile falsch ein | Aufgabenidentität statt Vergleich eines veralteten Objekts; aktueller Text wird vor der nächsten Zeile bewahrt. Löschen einer Hauptaufgabe erhält den Text und die IDs verbleibender Teilaufgaben. | Echter Tippen/Enter-Ablauf, Unteraufgabe, Größenwechsel, Entfernen |
| Zu große Schrift/Leisten/aktive Tags | Schriftfaktor × 0,95 zusätzlich zur weiterhin wirksamen Nutzer-/Systemeinstellung; geringere Leistenabstände, kleinerer Titel, kompakter Datumsbereich. Ausgewählte Tags im Eingabefeld 12 px mit kleinerem Löschsymbol; gepolsterte Trefferfläche bleibt. | Schmal/breit, Schriftfaktor 2, Tastatur-Inset; Messung von HÜ-Kopf und -Fuß |
| Kalender bei großer Schrift unlesbar | Monat und Jahresnavigation stehen dann in zwei Zeilen; vollständige Monats- und Jahresangaben bleiben sichtbar. | Tatsächliche Textbreite ohne Ellipse, Monatswechsel und Übernehmen bei 320 px / Faktor 2 / Tastatur |
| Große doppelte Entwurfshinweise | Sozial/Arbeit zeigen einen kleinen Status im Fuß statt des zusätzlichen großen Banners. Allgemeine Dialoge melden auch fehlgeschlagenes automatisches Sichern sichtbar. | Direkte Ansichten und vorhandene Fehler-/Recovery-Tests |

Ausgangsvergleich bedeutet bei einer Bearbeitung „gegenüber der geöffneten Fassung geändert“.
Das Öffnen eines bestehenden Eintrags erzeugt deshalb ebenso wenig einen Entwurf wie ein leeres
Neuformular. „Später ergänzen“ ist eine fachliche Auswahl und darf einen Entwurf begründen.
Ein Bereichswechsel eines bestehenden Eintrags ist eine inhaltliche Änderung und wird gesichert.
Ein Entwurf ist weiterhin kein veröffentlichter Eintrag.

## Prüfumfang aller vorhandenen Bereiche

Das vollständige Referenzverzeichnis bleibt [DIALOGVERZEICHNIS.md](DIALOGVERZEICHNIS.md).
Es wurden keine zusätzlichen Originaldialoge erfunden. Diese Runde prüft die vorhandenen
Flutter-Abläufe und ihre gemeinsamen Komponenten; folgende Zuordnung benennt die Abdeckung
und verhindert, dass ein Rendering mit einem vollständig geprüften Fachablauf verwechselt wird.

| Bereich / Originaldialoge | Lokale Funktionsprüfung | Darstellungsprüfung / Grenzen |
| --- | --- | --- |
| Navigation, Karten, Suche, Übersicht / D01 | Direkte Shortcuts, Suche/Fokus, Reihenfolge, Badge-Klick getrennt vom Hauptbutton, archivierte Schüler | Direkte Kartenansichten; HTML-Gruppierung/Filter bleiben abweichend |
| Sozial/Arbeit, Bearbeiten / D01, D05 | Tags/Freitext, Favoriten, Auftrag, Zeitpunkte, optionale Angaben, Speichern, Weiter, Fehler, Entwürfe | Leer/befüllt/Fehler, eng/breit/große Schrift/Tastatur |
| HÜ / D01, D07, D08 | Haupt-/Teilaufgaben, Enter, Empfänger, atomare Speicherung, vier Stände, Doppelklickschutz, Kommentar/Fokus, Konfliktübernahme | Kompakte Liste; Kommentarmodus verändert Aufgabenstand nicht |
| Ziele / D01, D09 | Eingabe, Terminvorschläge, Kriterium, Überprüfung, Abschluss, nächster Termin separat, Entwurf | Neu/bearbeitet/Überprüfung in Dialogmatrix |
| Orga und Klassen-Orga / D01, D21, D22 | Notiz, Checkliste, Aufgabenstand, Erinnerung, Quittieren, Weiter, Entwurf | Schüler/Klasse/gefüllt; strukturierte Listen bleiben Flutter-Bedienung |
| Schüler / D02, D03 | Name/Farbe/Archiv, Validierung, Entwurf, explizites Fortsetzen | Neu/bearbeitet/Fehler; HEX statt nativer Farbauswahl |
| Katalog, Gruppe, gemeinsame Situation / D04, D06, D10 | Optionen/Favoriten, Duplikate und Grenzen, ungefüllte Änderungen, Transaktion/Rücknahme, Kontextrevision | Direkte Dialoge; geführte Kontext-/Katalogkonfliktlösung fehlt |
| Entwürfe/Recovery / D11, D12 | Neuerfassung trotz Altentwurf; drei Entwurfsspeicher; Konfliktschutz; Fehler, Weiterbearbeiten, erneuter Versuch | Leer/befüllt/Fehler; kein geführter Reimport des Notfall-JSON |
| Verlauf/Gespräch / D01, D13 | Filter und gespeicherte Inhalte einschließlich Orga; Gesprächsauswahl/Datumsgrenzen | Dialogmatrix; nicht jede historische Original-Textvorlage reproduziert |
| Kalender / D14 | Datum, Schaltjahr, Monats-/Jahreswechsel, Pfeiltasten, Abbruch, Entfernen, ohne Uhrzeit vs. 00:00 | Zusätzlicher Lesbarkeitstest für große Schrift |
| Sicherung/Passwort/Import / D15–D17 | Verschlüsselung, Passwortfehler, Validierung, Rollback, Katalogoption, vollständiger Backup-Rundlauf | Dateidialoge nicht auf Zielbetriebssystem ausgeführt; normale Import-Zusammenführung fehlt |
| Pflege/Papierkorb/Konflikte / D18–D20 | Löschschutz, Snapshotprüfung, Wiederherstellung, Revisionen, gesamte Fassung bewusst wählen | Leere/befüllte/fehlerhafte Ansichten; feldweise Konfliktauflösung fehlt |
| Einstellungen | Alle vorhandenen Tabs, sieben Deckkraftwerte, Kopplung, Farben, Schrift, Kartenreihenfolge, Bilder/Modi, Speicherung/Fehler | Settings-Renderingmatrix; Originalbilder teilweise nicht verfügbar |

## Ausgeführte Prüfungen

- **125 Flutter-Tests bestanden**, einschließlich **27 neuer Tests** dieser Runde.
  Maßgeblich: [ux-flutter-tests.log](evidence/ux-flutter-tests.log).
- `flutter analyze --no-pub`: keine Befunde, [Protokoll](evidence/ux-analyze.log).
- **11 SQLite-Schematests** bestanden; getrennt von Dart-/Repositorytests.
- **3 Vorschau-Servertests** über lokales HTTP bestanden; Inhalte, Header und Serververhalten,
  ohne Browserautomatisierung.
- Release-Webbuild erfolgreich mit lokalen Web-Ressourcen; [Buildprotokoll](evidence/ux-web-build.log).
- **144 direkte Flutter-PNGs**, darunter die 37 Dialogzustände in drei Varianten sowie
  Settings-, Karten- und ergänzende HÜ-/Beobachtungs-/Badge-/Kalenderansichten.
  [Renderings](ux-renderings/), [Dateiindex mit Prüfsummen](ux-renderings/render-index.json).

Die Dialogmatrix verwendet 1440 × 1000, 320 × 700 und 320 × 700 bei Schriftfaktor 2 mit
280 px Tastatur-Inset. Zusätzliche aktuelle Beispiele verwenden 320/390/1100 px und bis
260 px Inset. Der neue Basisfaktor 0,95 wird zusätzlich angewandt. Es handelt sich um echte
Flutter-Engine-Renderings mit geladenen Schriftdateien; die Bildschirmtastatur selbst ist
simuliert, nicht als Betriebssystemfenster gestartet. Überlange Dialoge scrollen einschließlich
Kopf/Fuß, damit Aktionen erreichbar bleiben. Einige Aufnahmen zeigen bewusst eine gescrollte
Fehler- oder Eingabeposition.

Die Dialogmatrix wurde in Kontaktübersichten gesichtet; HÜ, Sozial, Badges und Kalender
zusätzlich als Einzelbilder. Dabei wurden die Schriftzuordnung im Datumsbutton, das fehlende
Textpfeil-Glyph der Teilaufgabe und die Kalenderkürzung tatsächlich erkannt und korrigiert.
Das ersetzt weder Pixelvergleich jeder Originalansicht noch einen Nutzertest auf allen Geräten.
Zwischenläufe mit roten Tests bleiben als Diagnoseprotokolle erkennbar; maßgeblich ist der
abschließende grüne Lauf. Drift-Hinweise betreffen absichtlich getrennte Testdatenbanken.

## Verbleibende Grenzen

Keine Browsertests. Kein nativer Windows-/Android-Lauf, keine reale Bildschirmtastatur,
keine vollständige Prüfung von OS-Dateidialogen oder Browserpersistenz. Die Windows-Vorschau
enthält einen erfolgreich kompilierten lokalen Server; dessen Windows-Ausführung wurde hier
nicht behauptet. Die Tests verwenden ausschließlich synthetische Daten.

Die wesentlichen bereits dokumentierten Lücken bleiben: normale Import-Zusammenführung,
feldweise Konfliktauflösung und geführte Wiederherstellung des Notfall-JSON. Weitere
Referenzabweichungen stehen in [FLUTTER_ABGLEICH.md](FLUTTER_ABGLEICH.md) (A01–A07).
**Geprüfte Rekonstruktion mit konkreten Korrekturen; keine Freigabe als „originalgetreu“
und keine Behauptung, jede mögliche Daten-/Geräte-/Fehlerkombination sei getestet.**
