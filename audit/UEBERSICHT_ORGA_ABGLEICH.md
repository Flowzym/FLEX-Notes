# Übersicht, Flächen, Listen und Modalzugänge · rebuild.8

Historischer Bericht für rebuild.8; die nächsten Änderungen stehen im [aktuellen Prüfstand](SWIPE_DESIGN_ABGLEICH.md).

Stand: **0.16.0-rebuild.8+28**, 02.11.2026. Grundlage ist der erhaltene Quellenfund,
weitergeführt auf `fix/dialog-reference-audit`. Die späteren ausdrücklichen Nutzeränderungen
haben Vorrang vor HTML und älteren Berichten. Das [Dialogverzeichnis](DIALOGVERZEICHNIS.md)
und der [dialogweise Quellenabgleich](FLUTTER_ABGLEICH.md) bleiben die Referenzbasis.

## Konkrete Korrekturen

| Nutzervorgabe / vorherige Abweichung | Umsetzung und Bedienung |
| --- | --- |
| Karten und Eingabefelder waren standardmäßig grün | Automatische Flächenfarbe jetzt Schwarz; transparente Deckkraft für Karten 28 %, Felder 22 %. Individuell gesetzte Farben bleiben wirksam. |
| Kopf-/Fußbereiche und Buttons sollten weiß transparent sein | Kopf/Fuß 18 %, Buttons 20 %, Navigation 12 %, jeweils Weiß als automatische Farbe. Schülerkartenköpfe nutzen ebenfalls die Kopffläche. Ausgewählte Zustände behalten ihre Akzentfarbe. |
| Auswahlbuttons blieben trotz geändertem Farbwert grün | Flutter zeichnete unter durchscheinenden Chips eine undurchsichtige Material-Fläche. Diese Unterlage ist jetzt ausschließlich für Chips transparent; andere Menüs behalten ihren eigenen Hintergrund. |
| Übersicht enthielt vollständige Formulare mit Auswahl-/Abhakbuttons | Neue Zusammenfassungen für Anstehend, Noch ergänzen und Zuletzt dokumentiert: Schüler, Datum, Titel, Vorschautext, Fortschritt/Termin als Text. Keine Chips, Checkboxen oder Statusauswahl in der Übersicht. Karte öffnet Details, Stift öffnet Bearbeitung. Auf breiten Ansichten stehen anstehende und jüngste Einträge nebeneinander. |
| Positiv/Negativ waren zwei getrennte Flächen | Gemeinsame abgerundete Pille mit zwei gleich breiten Bereichen; Auswahl und Tastatur-/Semantikzustand bleiben erhalten. Ein bloßer Wechsel erzeugt weiterhin keinen Entwurf. |
| Sozial/Arbeit zeigten eigene Entwurfssymbole | Alle fünf Shortcuts haben denselben kleinen Zahlenbadge. Zahl = bisherige offene Vorgänge + passende Entwürfe, einschließlich Gruppenentwürfen für diesen Empfänger. Keine zusätzliche Stiftplakette. Tooltip/Semantik benennt die Zusammensetzung. |
| Entwürfe waren über einen separaten Kartenbadge erreichbar | Der Shortcut öffnet weiterhin einen neuen Eintrag. Im Kopf des Eintragsmodals öffnet das Entwurfssymbol die passende Liste; Fortsetzung ausschließlich mit „Fortsetzen“. Orga filtert Schüler-/Klassenentwürfe getrennt. Der aktuell geöffnete Entwurf wird nicht nochmals angeboten. |
| Aufgegebene HÜ sollten im Modalkopf erreichbar sein | Zusätzliches HÜ-Symbol mit Anzahl im Kopf des HÜ-Eintrags. Öffnet die bestehenden Hausübungen dieses Schülers, einschließlich abgeschlossener Einträge; Suche und „Nur offen“ sind verfügbar. Status, Kommentare und Bearbeitung bleiben dort erreichbar. |
| Navigation konnte eine noch nicht gesicherte Eingabe verlassen | Vor dem Öffnen beider Listen wird die aktuelle Eingabe gesichert. Verzögerte Schreibvorgänge werden abgewartet, doppelte Navigation wird gesperrt. Bei Schreibfehler bleibt der Editor mit Fehlermeldung offen. Nach Rückkehr ist die begonnene Eingabe unverändert vorhanden. Ein leeres Formular erzeugt dabei keinen Entwurf. |
| Orga-Nummerierung/Aufzählung reagierten nicht auf Enter | Hardware-Enter und IME-Zeilenumbruch setzen die Liste fort. Nummerierte Folgezeilen werden angepasst; Enter auf leerer Listenzeile beendet die Liste. Shift+Enter fügt einen normalen Zeilenumbruch ein. Mehrzeiliges Einfügen und laufende Texteingabe-Komposition werden nicht als Enter behandelt. |
| Orga-Toolbar stapelte Präfixe | Markierte ganze Zeilen werden formatiert, bestehende Präfixe ersetzt; derselbe Stil schaltet die Formatierung wieder aus. Cursor/Markierung und Fokus bleiben sinnvoll erhalten. Reine leere Listenmarker erzeugen keinen Entwurf. |
| Checklisten verloren beim Enter den Arbeitsfluss | Enter fügt den Listenpunkt hinzu und fokussiert die nächste Zeile. In bestehenden Punkten teilt Enter den Text an der Auswahl, erhält vorhandene IDs/Häkchen und erstellt einen neuen unmarkierten Punkt. Leere Zeile beendet die Eingabe. Leerer Plusbutton bleibt ohne Änderung. |
| Große Schrift zerlegte den Kopf der aufgegebenen HÜ unnötig | Schülername und Titel stehen getrennt. In schmalen Detailkarten bzw. bei großer Schrift stehen Aktionen oberhalb des Texts, damit Titel und Metadaten die gesamte Breite nutzen können. |

Die unveränderte alte Standardpalette wird beim Laden gezielt auf die neuen Standardwerte
umgestellt. Bereits individuell geänderte Farben/Deckkraftwerte oder gekoppelte Flächen werden
nicht pauschal zurückgesetzt. `surfaceDefaultsVersion` wird innerhalb der bestehenden
Einstellungen gespeichert; das SQL-Schema bleibt unverändert.

## Abgleich mit der Originalquelle

Die Orga-Bedienregeln stammen aus `orgListLine`, `styleOrgLines`, `renumberOrgTail`,
`continueOrgLine` und `attachOrgTools` in
[HTML-Referenz, Zeilen 2326–2349](reference/FLEX-Notizbuch-37.html).
Dart bildet Zeilenauswahl, Fortsetzung, leere Zeile, Folge-Nummerierung und Modifier-Regeln
nach. Die bestehende Flutter-Rekonstruktion speichert Checklisten weiter als strukturierte
Listenpunkte; die HTML-Quelle verwendet Textmarker mit interaktiver Vorschau. Diese Darstellung
und dieses Datenformat werden hier nicht als identisch bezeichnet. Vorhandene Checklisten
werden nicht stillschweigend in ein anderes Format konvertiert.

Neue Flächen, Übersicht, gemeinsame Pille und Modalzugänge folgen den späteren Nutzeränderungen.
Sie sind ausdrücklich keine Behauptung einer pixelgleichen HTML-Kopie.

## Ausgeführte Prüfungen

- **145 Flutter-Tests**, davon **20 neue Tests** in `overview_lists_test.dart`.
  [Gesamtlauf](evidence/overview-flutter-tests.log). Vorhandene Tests wurden nur dort auf die
  neue Bedienung umgestellt, wo die ausdrückliche Nutzervorgabe sie ersetzt: Detaildialog
  vor Statusänderung, Entwurfszugang über den Modalkopf und neue Standarddeckkraft.
- [Statische Analyse](evidence/overview-analyze.log) ohne Befunde.
- **11 Schematests** und **3 lokale Vorschau-Servertests** bestanden:
  [Schema](evidence/overview-schema-tests.log), [Server](evidence/overview-preview-server-tests.log).
- [Release-Webbuild](evidence/overview-web-build.log) mit lokalen Web-Ressourcen.
- **168 direkte Flutter-PNGs** im [aktuellen Renderingordner](overview-renderings/), mit
  [Dateiindex, Größen und Prüfsummen](overview-renderings/render-index.json).
  Darunter 24 neue Ansichten für Übersicht, Zahlenbadges, gemeinsame Pille, Orga mit
  Tastatur-Inset, HÜ-Kopf und aufgegebene HÜ. Die vorhandene Dialogmatrix und Settings-/UX-Ansichten
  wurden ebenfalls mit dem aktuellen Code erneut gerendert.

Die neuen Ansichten verwenden 320 × 700, 390 × 844, 1200 × 1000 und 320 × 800 bei
Systemschriftfaktor 2; Orga zusätzlich mit 240 px Tastatur-Inset. Die bestehende Matrix umfasst
auch leere, befüllte und fehlerhafte Dialogzustände, 1440 × 1000, 320 × 700 und große Schrift
mit 280 px Inset. Der Basisfaktor 0,95 bleibt zusätzlich wirksam. Überlange Dialoge scrollen;
Kopf und Fuß sind bei großer Schrift/Tastatur deshalb nicht in jeder Aufnahme gleichzeitig sichtbar.

Die neue Funktionsprüfung umfasst unter anderem: Zahlen statt Stiftbadge, neuer Eintrag trotz
Altentwurf, ausdrückliche Fortsetzung, Kategorien-/Empfängerfilter, Erhalt der aktuellen Eingabe,
Schreibfehler/Verzögerung beim Navigieren, Ändern aufgegebener HÜ und Rückkehr zur neuen HÜ,
Nummerierungswechsel, Cursor in Listenmitte, Shift+Enter, IME-Enter, mehrzeiliges Einfügen,
Checklistenfokus, Häkchen/IDs sowie Schließen, Fortsetzen und Speichern einer Orga-Liste.

Die neuen Layouts wurden als direkte Einzelbilder gesichtet, die übrige Matrix zusätzlich
in Kontaktübersichten. Tatsächlich dabei erkannt und korrigiert wurden die grüne Material-Unterlage
von Chips und die ungünstigen Umbrüche in HÜ-Kopf/Detailkarte bei großer Schrift. Diagnoseprotokolle
früherer Zwischenläufe stehen getrennt in `evidence/overview-diagnostics/`; maßgeblich ist der
abschließende Gesamtlauf.

## Grenzen

Keine Browsertests. Die Renderings stammen aus `flutter_test` mit echten Flutter-Schriftdateien
und synthetischen Daten. Die Tastaturbelegung ist simuliert; keine reale Bildschirmtastatur,
keine native Windows-/Android-Abnahme oder Prüfung von Browserpersistenz. Die Windows-Vorschau
wurde gebaut und paketiert, ihre EXEs hier nicht unter Windows ausgeführt.

Die schon dokumentierten Lücken bei Import-Zusammenführung, feldweiser Konfliktauflösung und
geführtem Notfall-Reimport bleiben bestehen. Die Änderungen und Tests sind konkret belegt;
**keine Freigabe als „originalgetreu“ und keine Behauptung einer lückenlosen Geräte-/Funktionsprüfung**.

Bei 320 px und doppelter Systemschrift werden einige lange Überschriften anderer Dialoge
weiterhin innerhalb des Wortes umgebrochen (beispielsweise Sozialverhalten/Änderungskonflikte).
Die Inhalte bleiben durch Scrollen erreichbar; dies ist eine sichtbare Reflow-Grenze und
kein Nachweis unveränderter Originaldarstellung.
