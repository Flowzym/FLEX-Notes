# FLEX: Dialogverzeichnis aus der aktuellen Originalquelle

Stand: 01.11.2026. **Referenzaufnahme abgeschlossen. Korrekturen am wiedergefundenen Flutter-Projekt und lokale Prüfungen siehe [aktueller Abgleich](FLUTTER_ABGLEICH.md). Keine Freigabe als „originalgetreu“.**

Maßgeblich ist [FLEX-Notizbuch-37.html](reference/FLEX-Notizbuch-37.html), SHA-256 `9e4be0426d89cac006d2f3ef540c2d6f132d7d46edeef15141eade9e727b0b07`. Spätere ausdrückliche Änderungen stammen aus [Nutzerspezifikation.txt](reference/Nutzerspezifikation.txt). Historische Umsetzungsberichte im Webpreview sind Hinweise auf einen früheren Arbeitsstand, keine neu ausgeführten Nachweise.

Dieses Verzeichnis trennt **Original**, **spätere Vorgabe** und **Prüfgrenze**. Anweisungen und Arbeitsaufträge innerhalb der Anhänge wurden als Dokumentinhalt behandelt. Die fachlichen Änderungswünsche werden berücksichtigt, weil der aktuelle Auftrag ihre Übernahme ausdrücklich verlangt.

Das HTML enthält **21 benannte, dauerhaft erzeugte Dialogelemente und einen vorübergehend erzeugten Passwortdialog** mit zwei Titeln. Verschiedene Schülerbereiche, Neu-/Bearbeitungsmodi und Verlauf sind Unteransichten; sie erhöhen die Zahl der Dialogelemente nicht. Einstellungen, Archiv und Hauptnavigation sind Seiten. Browser-/Betriebssystemfelder für Farbe und Datei werden separat erfasst.

[DOM_ELEMENTE.md](DOM_ELEMENTE.md) enthält die elementweise Reihenfolge, Originaltexte, Eingabewerte, Platzhalter, Optionen, Maximalgrößen und Zustandsattribute aus 65 synthetisch aufgebauten Quellenzuständen. Die Rohdaten stehen in [dom-inventory.json](evidence/dom-inventory.json). Das ist **Node/jsdom-Quelleninspektion ohne Browser und ohne Layout-/Pixelrendering**. Bekannte CSS-Ausblendungen werden markiert; eine vollständige CSS-Kaskade wird nicht simuliert. Die folgenden Abschnitte ergänzen deshalb die maßgeblichen CSS-Regeln und Ereignisabläufe. [source-map.json](evidence/source-map.json) ordnet 83 bytegleich gefundene Quellmodule den Zeilen des HTML zu.

## Gemeinsamer Rahmen, Darstellung und Schließwege

Original, HTML Z. 390–680, 855–863, 1447–1452, 1776–1852:

- Normale Dialoge: begrenzte Breite, gerundete Ecken, abgedunkelter/unscharfer Hintergrund. Schüler-/Eintrags-/Gruppendialog maximal 640 CSS-px; allgemeine Dialoge 760; kleine Dialoge 430. Kalender eigene kompakte Maße. Detaildialoge bis 1000; Zielüberprüfung eigene 600-px-Regel.
- Maßgebliche ungeschichtete Gestaltung: Radius 24 px, Inhalt 22 px vertikal/24 px horizontal, mobil 16 px; unter 360 px 14 px horizontal. Kopf regulär 14/20 px, mobil 9/12 px; Fuß 12/24 px, mobil 11/16 px. Niedrige Fenster erhalten reduzierte Höhen. Diese Werte sind **CSS-Vorgaben**, keine gemessenen Bildschirmwerte.
- Schülerkopf: Zurück zur Schülerübersicht, Schülername, Bereichstitel, Verlaufssymbol, X. Avatar und „Einträge für“ sind per CSS verborgen. Die älteren, zusätzlich im Inhalt vorhandenen Bereichsüberschriften/-navigation sind ebenfalls per CSS verborgen. Das Symbol neben X ist durch den Code als **„Verlauf ansehen“** belegt.
- Schülername kleiner Sans-Text, Bereich Georgia/Times-Serif, regulär 24 px, mobil 21 px; allgemeine Dialogtitel Sans 18 px. Sans im HTML Segoe UI/System. Linker Farbstreifen folgt `--pupil-accent`, also der Schülerfarbe, nicht einer festen Bereichsfarbe.
- Scrollender Inhalt; bei Eintragsformularen separate Datums-/Nachbereitungsleiste vor den Speicheraktionen. `Später ergänzen` ist unabhängig von Datum und optionaler Uhrzeit.
- Original-Detaildialoge werden bei höchstens 600 px Breite randlos/vollhoch. **Spätere Vorgabe ersetzt dies:** auch Ziele, HÜ, Verlauf und Unterdialoge bleiben erkennbare Modals mit Außenabstand und Rundung. Keine Vollbildseite.
- Kopf/Datumsleiste/Fuß haben eigene Füllvariablen. **Spätere Vorgabe:** eine gemeinsame Farbe für Kopf und Fuß, getrennte Transparenzwerte beibehalten; alle Dialoge einschließlich Unterdialoge einbeziehen.
- Native `<dialog>`-Escape erzeugt `cancel`. `protectEditor` fängt dies bei Eintrag, HÜ-Editor, Aufgabenkommentar, Schülerdaten, neuem Schüler, Zielprüfung, Situation und Klassen-Orga ab. X/Abbrechen mit `data-close` verwenden dort denselben Entwurfspfad.
- Außenklick hat im Original keinen pauschalen Light-Dismiss-Handler. Android-Zurück ist keine separat implementierte HTML-Aktion; für Flutter muss er den Entwurfspfad auslösen. Nicht aus HTML-Ausführung als geprüft ausgeben.
- Geschützte Bearbeitung: Änderungen sichern; erst dann schließen. Fehler öffnet „Entwurf nicht gesichert“. Erfolgreiches Speichern entfernt den zugehörigen Editorentwurf. `studentDialog` nutzt andere, laufend geschriebene Bereichsentwürfe; nicht mit `protectEditor` gleichsetzen. Gruppen haben wiederum eigene Schlüssel und Schließblockade.
- Kalender-X/Escape verwirft nicht übernommene Auswahl. Passwort-Abbruch liefert keinen Wert. Auswahlkatalog-X/Abbrechen veröffentlicht nichts; dieser Katalog gehört im HTML nicht zu `protectedEditors`.

## Vollständiges Register

| Nr. | HTML-Identität | Titel / Ansichten | Öffnung und Kontext |
| --- | --- | --- | --- |
| D01 | `studentDialog` | Schülerübersicht; Sozialverhalten; Arbeitsverhalten; Orga; Ziele; Hausübung; Verlauf | Schülerkarte, Bereichsshortcut oder Eintrags-/Entwurfsnavigation; ein Schüler |
| D02 | `addDialog` | Schüler hinzufügen | Schüler-Hinzufügen; neuer Schüler |
| D03 | `pupilDialog` | Schüler verwalten | Schülermenü → Schüler bearbeiten; vorhandener Schüler |
| D04 | `optionsDialog` | Sozialverhalten · Auswahl / Arbeitsverhalten · Auswahl; historische Erinnerungsliste | Stift „Auswahl bearbeiten“; globale Auswahlliste des Bereichs |
| D05 | `recordDialog` | Eintrag bearbeiten | Bearbeiten im Verlauf/Beleg; konkreter Eintrag; Aufgabenzuweisung wird zu D07 umgeleitet |
| D06 | `bulkDialog` | Für mehrere erfassen | Mehrere auswählen → Für mehrere erfassen; ausgewählte Schüler |
| D07 | `homeworkEditDialog` | Hausübung bearbeiten | Stift der HÜ-Karte oder Bearbeiten ihres Zuweisungseintrags |
| D08 | `homeworkTaskDialog` | Kommentar & Stand | Sprechblase einer bestimmten Aufgabe/Teilaufgabe |
| D09 | `goalReviewDialog` | Ziel überprüfen | Zielkarte oder fälliges Ziel; konkretes Ziel |
| D10 | `situationDialog` | Gemeinsame Situation | Gemeinsamen Kontext bearbeiten / Situation öffnen |
| D11 | `draftDialog` | Gesicherte Entwürfe | Entwürfe-Menü, Schüler-Menü oder Entwurfshinweis |
| D12 | `discardEditDialog` | Entwurf nicht gesichert | Fehlgeschlagene Entwurfssicherung beim Schließen eines geschützten Editors |
| D13 | `briefDialog` | Gespräch vorbereiten | Schülermenü; ausgewählte Einträge des Schülers |
| D14 | `calendarDialog` | Datum wählen / Datum & Uhrzeit | Kalenderbutton des auslösenden Felds |
| D15 | `backupDialog` | Datensicherung | Sicherung öffnen / Sicherungsbutton; gesamter Arbeitsbereich |
| D16 | temporär, ohne Original-ID | Sicherung öffnen / Sicherung verschlüsseln | Verschlüsselter Import bzw. Export aus D15/D18 |
| D17 | `importReview` | Sicherung prüfen | Nach erfolgreichem Lesen/Entschlüsseln/Prüfen einer Datei |
| D18 | `maintenanceDialog` | Speicher pflegen / Papierkorb endgültig leeren | Einstellungen → Daten bzw. D19 |
| D19 | `trashDialog` | Papierkorb | Einstellungen → Daten |
| D20 | `conflictDialog` | Änderungskonflikte | Menü oder Konflikthinweis |
| D21 | `classTasksDialog` | Klassen-Orga | Klassen-Orga-Menü; Klasse ohne Schülerpflicht |
| D22 | `classTaskDialog` | Klassen-Orga | D21 → Eintrag hinzufügen oder vorhandenen Eintrag öffnen |

## D01: Schülerdialog und seine Ansichten

### Schülerübersicht

Kopf: Schülername, Verlauf, X; Bereichs-Zurück verborgen. Inhalt: Filter `Aktuell`, `Diese Woche`, `Offen`; `Einträge durchsuchen`; Menü `•••` mit `Schüler bearbeiten`, `Gespräch vorbereiten`, `Gesicherte Entwürfe`; fünf Zugänge `Ziele`, `Sozial`, `Arbeit`, `HÜ`, `Orga`; aktuelle Gruppen für Anstehendes, noch zu ergänzende Dokumentation und letzte Einträge; `Gesamter Verlauf →`. Datenabhängige Gruppen tragen Anzahl, Leerhinweis und begrenzte Vorschau mit weiterer Aufklappmöglichkeit. Bei Suche/Zeitraum werden die gefilterten Einträge gezeigt. Kein Speicherfuß ohne Eingabeformular. Original: HTML Z. 1630–1688, 884–917; Elementfolge `overview-empty`.

### Sozialverhalten: neuer Eintrag

Sichtbare Reihenfolge nach dem Kopf:

1. Etwaige Entwurfs-/Speicherhinweise.
2. Zusammengehörige Auswahl `Positiv` / `Negativ`, zunächst positiv. Umschalten ändert die angebotene Liste, nicht Freitext oder bereits ausgewählte Beobachtungen. Gemischte positive/negative Auswahl ist zulässig.
3. `Beobachtung` mit Stift `Auswahl bearbeiten`; Vorschlagspillen mit separatem Favoritenstern. Favoriten vor übrigen Einträgen, zunächst höchstens sechs; bei mehr Angeboten `Alle N anzeigen` / `Weniger anzeigen`.
4. `Was ist passiert?` mit kleinerem `optional bei Auswahl`.
5. Zeitpunkt-Pillen; darunter **ein gemeinsamer Eingaberahmen** mit ausgewählten Beobachtungstags, ausgewähltem Zeitpunkt und mehrzeiligem Freitext, Platzhalter `Beobachtung …`.
6. Originalüberschrift `Weitere Angaben`, darin in dieser Reihenfolge `Beteiligt`, `Zielbezug`, `Reaktion / Unterstützung`, `Quelle & gemeinsamer Kontext`.
7. Separate Leiste: `Beobachtet am`, Datum/Kalender, `Später ergänzen`.
8. Fuß: `Speichern & weiter →`, `Eintrag speichern` im HTML. **Spätere Vorgabe: rechter Button „Speichern“.**

Originale positive Beobachtungen in Reihenfolge: `Hilft anderen`; `Nimmt Hilfe an`; `Hält Gesprächsregeln ein`; `Geht respektvoll mit anderen um`; `Klärt einen Konflikt im Gespräch`; `Hält gemeinsame Absprachen ein`.

Originale negative Beobachtungen: `Unterbricht andere wiederholt`; `Spricht andere abwertend an`; `Hält gemeinsame Absprachen nicht ein`; `Stört die Zusammenarbeit`.

Die Original-Zeitpunkttexte sind `Vor dem Unterricht`, `Während des Unterrichts`, `Nach dem Unterricht`, `Pause`. **Spätere ausdrückliche Ersetzung:** `Vor Unterricht`, `Unterricht`, `Nach Unterricht`, `Pause`.

Zeitpunkt ist eine Einfachauswahl in der letzten HTML-Fassung: neuer Tag ersetzt den alten; Entfernen löscht nur den Zeitpunkt. Er wird als erkannter erster Textabsatz und als normalisierter Kontext verarbeitet. Frühere Situation/Freitext-Felder werden beim ausdrücklichen Speichern zusammengeführt; keine pauschale Textzerlegung beliebiger Narrative. Der Aufgaben-/Situations-Mehrfachauswahlcode aus einer früheren Erweiterung ist dafür nicht maßgeblich.

Beobachtungsauswahl wird getrennt als `{tone,text}` gespeichert. Der gewählte Vorschlag verschwindet inklusive Stern aus der Vorschlagsliste (CSS); im Feld erscheint `+`/`−`, Originaltext und Entfernen-X. Entfernen gibt den Vorschlag wieder frei. Stern-Klick verändert nur `favorites[category][tone]` und speichert die Favoritenpräferenz; er darf nicht zugleich die Beobachtung auswählen. Text und Stern teilen eine äußere Fläche, beide Innenbuttons sind transparent.

Validierung: Beobachtungsauswahl oder Beobachtungstext genügt; nicht immer Freitext verlangen. Originalfehlermeldung: `Bitte kurz beschreiben, was passiert ist, oder eine Beobachtung auswählen.` Ein ungültiger Beobachtungszeitpunkt, veralteter Zielbezug oder Speicherfehler blockiert Erfolg/Fortsetzung. Quelle: HTML Z. 940, 1268–1278, 1707–1739, 1767–1774, 2271–2323.

### Arbeitsverhalten: neuer Eintrag

Reihenfolge: Kopf/Hinweise → `Positiv` / `Negativ` → **`Auftrag`** (gegebenenfalls `Zuletzt verwendet`, maximal sechs Vorschläge) → `Beobachtung` und Stift → Beobachtungspillen/Sterne → `Konkrete Beobachtung` mit `optional`, gemeinsamer Tag-/Freitextrahmen, Platzhalter `Beobachtung …` → optionale Angaben → Datum/Nachbereitung → Speicheraktionen.

Positive Liste: `Beginnt selbstständig`; `Arbeitet konzentriert`; `Bleibt bei Schwierigkeiten dran`; `Fragt gezielt nach Hilfe`; `Schließt die Aufgabe ab`; `Arbeitet sorgfältig`.

Negative Liste: `Beginnt erst nach mehreren Aufforderungen`; `Beschäftigt sich wiederholt mit anderem`; `Unterbricht die Arbeit vorzeitig`; `Bearbeitet die vereinbarte Aufgabe nicht`; `Lässt vereinbarte Arbeitsschritte aus`.

Auftrag hat eigene Tags plus Freitext, Platzhalter `Auftrag …`, zugänglicher Name `Auftrag – eigener Text`; mehrere Tags sind möglich. Lesbare Zusammensetzung mit ` · `, getrennte Metadaten `tagFields.task={tags,free}`. Alte freie Auftragstexte werden nicht nachträglich an jedem ` · ` zu Tags zerlegt. Ausgewählte Vorschläge verschwinden, Entfernen setzt den Fokus in die Eingabe. Backspace bei leerem Freitext fokussiert zunächst den letzten Tag. Beobachtungstext bleibt vom Auftrag unabhängig.

Original erlaubt **Auftrag allein**, Beobachtungsauswahl oder Beobachtungstext. Fehler: `Bitte einen Auftrag, eine Auswahl oder eine Beobachtung eingeben.` Optionale Reihenfolge im HTML: Zielbezug, Reaktion/Unterstützung, Quelle/gemeinsamer Kontext. `Beteiligt` ist dort im Einzel-Arbeitsformular nicht vorhanden; der spätere Bericht 0.15.3 beschreibt seine Ergänzung. Nicht als Originalfeld ausgeben. Speicheraktionen wie Sozialverhalten.

### Optionale Angaben in Sozial/Arbeit

| Abschnitt | Originale Felder/Reihenfolge und Zustand | Datenwirkung / späteres Soll |
| --- | --- | --- |
| Beteiligt | Schalter, bei Aktivierung `Schüler auswählen`, Schüler-Pillen (Mehrfachauswahl), `Weitere Namen`, Eingabe `Name; Name …` | Namen/IDs dedupliziert; vorhandene archivierte Beteiligte bleiben darstellbar. Ausschalten behält die Auswahl im Entwurfsobjekt, aber `participantValues` liefert dann leer. Nennung erzeugt keine fremde Einzelbewertung. Reines Einklappen darf nach späterer Vorgabe keine Werte löschen. |
| Zielbezug | Schalter, `Ziel auswählen`, Select mit `Ohne Zielzuordnung` und aktiven eigenen Zielen; ohne Ziel `Kein aktives Ziel vorhanden.` und Select deaktiviert | Original-Ausschalten leert Ziel-ID/-text ausdrücklich. Alte Verknüpfung zeigt gespeicherten Wortlaut, auch bei beendetem/fehlendem Ziel. Von bloßem Sichtbarkeitsschalter unterscheiden; keine unbemerkte Löschung durch UI-Umstellung. |
| Reaktion / Unterstützung | Schalter, Text `Unterstützung …`, beim Neuanlegen maxlength 300; verborgen und deaktiviert bei Aus | Eingabe bleibt zunächst im Entwurf; Original speichert `supportNote` bei Aus leer. Später verlangt das Dokument Werterhalt beim Einklappen. Die fachliche Aktivierung muss deshalb separat vom Sichtbarkeitszustand bleiben. |
| Quelle & gemeinsamer Kontext | Aufklappbereich; `Quelle`: `Selbst beobachtet` (Standard), `Berichtet`, `Eigene Einordnung`; `Gemeinsamer Ablauf`, Textarea `Kontext …`, maxlength 3000 | Quelle und gemeinsamer Ablauf werden separat von der individuellen Beobachtung gespeichert. Später: Schalter **„Kontext / Quelle“**; Überschrift „Weitere Angaben“ und zusätzliche Trennlinie entfallen. |

### Orga: neuer schülerbezogener Eintrag

Reihenfolge: Kopf `Orga` → `Notiz oder Aufgabe` → Werkzeugleiste `☐ Checkliste`, `• Aufzählung`, `1. Nummerierung` → mehrzeilige Eingabe `Notiz …` → `Als Aufgabe` → optional `Termin`/`optional`, `Aufgabe erledigt` → `Erinnern` → optional `Erinnern am`, `Erinnerungstext`/`optional` (`Wie Notiz …`), `Erinnerung quittiert`, Hinweis `Anzeige in der App` → gespeicherte Orga-Liste mit `Alle`, `Offen`, `Erledigt` und Anzahl → Datum/Nachbereitung → `Speichern & weiter →`, `Speichern`.

Neu schülerbezogen standardmäßig Notiz (`orgTask=false`), keine Erinnerung. Text ist erforderlich; Fehler `Bitte eine Notiz eingeben.` Aufgabentermin optional und datumrein, Erinnerung eigener Datums-/Zeitwert. Fehler `Bitte einen gültigen Aufgabentermin wählen.` bzw. `Bitte ein Datum für die Erinnerung wählen.` Ohne eigenen Erinnerungstext wird der Notiztext verwendet.

Checklisten/Aufzählungen/Nummerierungen sind Werkzeuge des Originaltextfelds, kein separat erfundener Titel-Pflichtblock. Checklistenstände bleiben unabhängig vom Aufgabenabschluss. Listenaktionen: `Aufgabe erledigen`, bei erledigt `✓ Erledigt · wieder öffnen`; Erinnerung `Quittieren`. Aufgabe erledigen beendet ihre Erinnerung; Quittieren erledigt keine Aufgabe; Wiederöffnen reaktiviert keine Erinnerung. Notizen erscheinen nicht in den Aufgabenfiltern Offen/Erledigt. Original Z. 1741–1757, 2325–2355, 2546–2569.

### Ziele: Arbeitsbereich und neues Ziel

Arbeitsbereich: Kopf → `In Arbeit N`, `+ Neues Ziel` (bzw. `Entwurf fortsetzen`) → aktive Ziele nach nächstem Prüftermin → gegebenenfalls `Abgeschlossene Ziele N` aufklappbar. Leer: `Noch kein Ziel vereinbart.` / `Halte fest, was als Nächstes gelingen soll.`; nach Abschlüssen `Keine aktiven Ziele.` / `Ein neues Ziel kannst du jederzeit ergänzen.`

Zielkarte: Zieltext; Stift `Ziel bearbeiten`, Papierkorb `Ziel löschen`; optional `Zielkriterium`, `Nächster Schritt`; `Überprüfen · Datum`, `Termin überschritten`/`Heute` oder `Ohne Prüftermin`; bei Abschluss `Erreicht`/`Beendet`; Aktion `Erreicht` oder `Wieder öffnen`; bei aktiv `Ziel überprüfen`; `Überprüfungen · N` und `Zugeordnete Beobachtungen · N`. Belege öffnen den konkreten Eintrag. Zieltermin und nächster Prüftermin sind unterschiedliche Werte.

Neuanlage: `Zur Zielübersicht` → `Was soll erreicht werden?`, Textarea `Ziel …` maxlength 3000 → `Zielkriterium optional`, `Zielkriterium …` maxlength 2000 → `Nächster Schritt optional`, `Nächster Schritt …` maxlength 2000 → `Zieltermin optional`, Vorschläge `Bis Freitag`, `Eine Woche`, `Zwei Wochen`, `Ein Monat`, Datum → `Vereinbart am`, `Später ergänzen` → `Ziel speichern`. Kein Speichern-&-weiter-Button in diesem HTML-Modus.

Datumsvorschläge: nächster Freitag einschließlich heute; +7/+14 Tage; gleicher Kalendertag im nächsten Monat, am Monatsende begrenzt. Zieltext erforderlich (`Bitte ein Ziel formulieren.`); Termin optional, sonst `Bitte einen gültigen Zieltermin eingeben.` Erfolgreich Status `active`. Zurück zur Zielübersicht erhält den Bereichsentwurf. Original Z. 1440–1445, 1619–1628, 1854–1886, 2210–2221.

### HÜ: Arbeitsbereich

Kopf → Anzahl `N offen` bzw. `Alles erledigt`, `+ Hausübung` → offene Karten nach Fälligkeit → gegebenenfalls aufklappbar `Erledigt (N)`. Ohne HÜ: `Noch keine Hausübung.` / `Mit „+ Hausübung“ legst du eine Aufgabenliste an.`; ohne offene: `Keine offenen Aufgaben.` / `Erledigte Aufgaben findest du unten.`

Original-Karte: Fach oder `Hausübung`; `Aufgegeben am DD.MM.YYYY` (sonst `Aufgabedatum unbekannt`); optional `Bis …`; Fortschritt erledigt/gesamt; Chevron; Stift `Hausübung bearbeiten`. Aufgeklappt Aufgaben/Teilaufgaben: Checkbox, Text, Sprechblase `Kommentar und Bearbeitungsstand: <Aufgabe>`, optional Status und Kommentar. Teilaufgabe eingerückt, eigener Stand. Unten `Notiz & Verlauf`, gegebenenfalls `Löschen`. Ein-/Ausklappzustand bleibt innerhalb der Sitzung erhalten. Das Screenshot-Muster `HÜ · Datum` ist eine spätere Darstellungsreferenz, nicht der exakte Kartenkopf dieses HTML.

**Spätere Änderung:** Checkboxen vollständig durch direkt sichtbare `Offen`, `Vollständig`, `Teilweise`, `Nicht erledigt` ersetzen; Aufgabenname und Kommentar-Shortcut davor, Kommentarvorschau danach. Buttons umbrechbar. Klick speichert sofort; identischer Stand bleibt No-op; parallele Klicks nicht doppelt protokollieren; Schreibfehler am betroffenen Eintrag, vorheriger gespeicherter Stand maßgeblich, erneuter Versuch möglich. Kommentar, andere Aufgaben, Teilaufgaben, sonstige Angaben und Historie erhalten. Die vorgeschlagenen Farben sind Arbeitsstand, keine verbindlichen HTML-Farben.

### HÜ: Aufgeben

`← Zur Aufgabenliste` → `Aufgaben` → mindestens eine nummerierte Aufgabenzeile (`Aufgabe …`, maxlength 1000) mit Enter-Button `↵`, `Teilaufgabe hinzufügen`, Entfernen-X → `Aufgabe hinzufügen` → `Fach optional` (`Fach …`, maxlength 100), `Fällig am optional` → Original `Weitere Angaben`, `Für welche Schüler?` mit einzelnen Checkboxen (durch spätere HTML-Erweiterung als Schalter gestaltet) → `Aufgegeben am`, `Später ergänzen` → `Hausübung aufgeben`.

Enter fügt nach der aktuellen Aufgabe und ihren Kindern eine weitere Hauptaufgabe ein; bei Teilaufgabe ein Geschwister. Teilaufgabenbutton bindet an die Hauptaufgabe, keine beliebige Verschachtelung. Hauptaufgabe entfernen macht ihre Kinder zu Hauptaufgaben. Kein originaler Drag-/Umordnungsbutton belegt. Leere Zeilen bleiben bei Bearbeitung/Entwurf, werden vor Speicherung herausgefiltert. Mindestens eine Aufgabe und ein Empfänger erforderlich. Fehler `Bitte mindestens eine Aufgabe eingeben.`, `Bitte eine Aufgabe und mindestens einen Schüler angeben.`, `Bitte ein gültiges Datum eingeben.`

Aktueller Schüler zunächst gewählt; andere aktive Schüler auswählbar, aktueller archivierter Schüler bleibt gegebenenfalls sichtbar. **Später:** individuelle Schüler-Schalter durch mehrfach auswählbare Tagbuttons ersetzen; übergeordneter Sichtbarkeitsschalter darf bestehen. Auswahl wirklich zum Speichern verwenden, nicht lediglich hervorheben. Pro Empfänger eigener Datensatz und individuelle Aufgaben-/Rückmeldungszuordnung; gemeinsamer Vorgang. Die Bearbeitung einer schon bestehenden HÜ in D07 ist keine nachträgliche neue Empfängerzuweisung.

### HÜ: Notiz & Verlauf

`← Zur Aufgabenliste` → Fach/`Hausübung`, Aufgabedatum, ggf. Fälligkeit → `Notiz` (`Notiz …`, maxlength 5000) → Originalabschnitt `Abgabe & Zeitpunkt`: `Abgabe / Vorlage` mit `Nicht überprüft`, `Vorgelegt`, `Nicht vorgelegt`, `Abwesend`, Beobachtungsdatum mit optionaler Uhrzeit → `Verlauf (N)` mit konkreten Rückmeldungen → `Notiz speichern`, Hinweis `Der Aufgabenstand bleibt erhalten.`

Notiz oder gegenüber gespeichertem Wert geänderte Abgabe erforderlich: `Bitte eine Notiz oder eine geänderte Abgabe eintragen.` Eine reine Abgabenotiz überschreibt keinen Aufgabenstand. Historie ist der konkreten HÜ zugeordnet, nicht global. Später „Abgabe & Zeitpunkt“ als Schalter, Inhalte beim Einklappen erhalten. Original Z. 1582–1617.

### Verlauf

Kopf mit Zurück/X; Verlaufsknopf im Kopf verborgen → `Suchen …` (zugänglicher Name `Verlauf durchsuchen`) → Bereichsauswahl `Alle Bereiche`, `Sozialverhalten`, `Arbeitsverhalten`, `Hausübung`, `Organisatorisches`, `Ziele` → `Von`, `Bis` → `Nur offene Nachbereitung` → Einträge absteigend nach Beobachtungsdatum.

Pro Eintrag: Bereich/Datum, Text und Auswahl, fachabhängige Angaben (Auftrag, Ziel, Beteiligte, Quelle, gemeinsamer Kontext, HÜ-Stand/Abgabe, Orga-Zustand), Erfassungsdatum; `Bearbeiten`, `Später ergänzen` oder `Dokumentation vollständig`, `Löschen`; vorhandene frühere Fassungen aufklappbar. Ziel hat zusätzliche Status-/Belegaktionen, Orga Aufgaben-/Quittieraktionen. Historische Fassungen werden gelesen, nicht beliebig überschrieben. Der HTML-Verlauf wechselt die Ansicht desselben Schülerdialogs. Ein separater Flutter-Verlauf wird nur durch historische Dokumentation beschrieben.

## D02/D03: Schüler hinzufügen/verwalten

Quelle Z. 922, 925, 1544–1560, 2150–2188, 2502–2504, 2533.

D02: Kopf `Schüler hinzufügen`, X → `Name`, `Name …`, maxlength 80, erforderlich → `Farbe`, zehn Farbbuttons → `Eigene Farbe wählen`, natives `input[type=color]` → `Hinzufügen` im Inhalt. D03: Kopf `Schüler verwalten`, X → Name → dieselbe Farbe → `Schüler archivieren` → Hinweis `Alle Einträge bleiben erhalten. Archivierte Schüler findest du im Menü unter „Archiv“.` und nach Archivwahl Anzahl offener Vorgänge → Fuß `Speichern`.

Palette in Originalreihenfolge: `#53747e`, `#756582`, `#49765a`, `#b87943`, `#ac5d72`, `#487f85`, `#8a7845`, `#6478a6`, `#8c6553`, `#73834c`. Neu erster unbenutzter Farbwert, danach berechnete HSL-Folge; Verwalten lädt vorhandene Farbe. Eigene Farbe ist kein zusätzliches HTML-Dialogelement.

Leerer Name wird nicht gespeichert; doppelte Namen beim Anlegen fallunabhängig erkannt: `Dieser Schüler ist bereits vorhanden.` D03 speichert Name, vorherige Namen, Farbe und Archivstatus; Fehler `Bitte einen Namen eingeben.` bzw. `Änderung nicht gespeichert. Bitte erneut versuchen.` Archivieren beseitigt keine offenen Verpflichtungen. Beide Dialoge haben geschützte Entwürfe.

Originalauffälligkeit: Der **letzte** `addForm.onsubmit` (Z. 2533) fügt nur `{id,name}` hinzu und überschreibt damit die frühere Farbübernahme. `persist` vergibt dann eine Farbe. Die sichtbare Farbauswahl beim Neuanlegen ist deshalb nicht automatisch als korrekt gespeichert belegt. Flutter soll eine ausdrücklich gewählte Farbe erhalten, keinen Originalfehler nachbauen.

## D04: Auswahl bearbeiten

Kopf `<Bereich> · Auswahl`, X (`Bearbeitung schließen`) → `Diese Auswahllisten gelten für alle Schüler. Bereits gespeicherte Einträge behalten ihren ursprünglichen Text.` → `＋ Positiv` / `− Negativ` → Fehlerbereich → pro Eintrag Textfeld maxlength 150 und Entfernen-Button → `Neuer Auswahleintrag`, `Eigener Text …`, `＋ Hinzufügen` → Hinweis zur Übernahme mit Änderungen speichern → Fuß `Abbrechen`, `Änderungen speichern`.

Beide Listen getrennt editierbar, Eingaben beim Tonwechsel gehalten. Leere Liste: `Die Liste ist leer. Füge unten einen Eintrag hinzu.` Hinzufügen/Umbenennen/Entfernen erst mit explizitem Speichern übernommen. Duplikate/zu lange/zu viele Einträge werden geprüft (genaue Originalmeldungen im Quellenbeleg); bereits gespeicherte Beobachtungstexte bleiben unverändert. Favoriten und offene Bereichsentwürfe werden zur Listenänderung abgeglichen. Bei Persistenzfehler wird der Editor wieder geöffnet und zeigt `Die Änderungen sind noch nicht gespeichert. Bitte erneut versuchen oder die Daten exportieren.`

**Kein Umordnungsbutton im aktuellen HTML-Katalogeditor.** Historischer Flutter-Bericht nennt zusätzliche Katalogfunktionen und dauerhaften Katalogentwurf; das belegt deren Originaltreue nicht. Erinnerungsliste ist noch im Code, der spätere Orga-Einstieg ersetzt den eigenständigen Erinnerungsbereich. Original Z. 924, 1158–1174, 1341–1343.

## D05: Eintrag bearbeiten

Kopf `Eintrag bearbeiten`, X; Abschluss `Änderungen speichern`. Felder laden vorhandenen Eintrag. Speichern ist revisionsbewusst; Schülerzuordnung ist bei HÜ-Rückmeldung deaktiviert. Neu-/Bearbeitungsformular sind **nicht dieselbe Feldfolge**.

- Sozial: `Bereich` (Sozial/Arbeit) → `Was ist passiert? optional bei Auswahl`, Zeitpunkt-Pillen, ausgewählte Beobachtungen/Freitext → `Beteiligt` → aufklappbar `Auswahl bearbeiten` mit Bewertung Positiv/Negativ, Beobachtungstext (maxlength 300), Entfernen und `Beobachtung ergänzen` → `Reaktion / Unterstützung` → `Zielbezug` → Original `Weitere Angaben` mit `Schüler` → `Quelle`, ggf. `Gemeinsamen Kontext bearbeiten` → feste Leiste `Beobachtet am`, `Später ergänzen`.
- Arbeit: `Bereich` → `Notiz` mit Beobachtungstags/Freitext → `Auftrag`, letzte Vorschläge/Tagfeld → Auswahl bearbeiten → Reaktion/Unterstützung → Zielbezug → Schüler → Quelle/Kontextzugang → Datum/Nachbereitung. **Auftrag steht hier im Original nach Notiz, beim Neuanlegen davor.**
- Orga: `Notiz`, Listenwerkzeuge/Text → Als Aufgabe/Termin/Erledigt → Erinnern/Erinnerungsfelder → Schüler → Datum/Nachbereitung.
- Ziel: `Ziel` → `Zielkriterium optional` → `Nächster Schritt optional` → `Zieltermin optional` mit vier Vorschlägen, daneben `Stand` (`In Arbeit`, `Erreicht`, `Beendet`) → Schüler → `Schülerperspektive · optional`, `Eigene Sicht …` maxlength 2000 → `Vereinbart am`, `Später ergänzen`.
- HÜ-Zuweisung wird zu D07 umgeleitet. HÜ-Rückmeldung: `Bearbeitungsstand`, `Abgabe`, `Ergänzung`; bei aufgabenbezogener Rückmeldung stattdessen zusätzlich `Bearbeitungsstand dieser Aufgabe` mit Offen/Vollständig/Teilweise/Nicht erledigt, globaler Stand verborgen; Zugehörigkeit bleibt erhalten.

Validierung von Datum, Inhalt/Auswahl, Ziel-/Erinnerungstermin und Zielbezug; Fehler lässt Editor offen. Änderungen werden mit früherer Fassung protokolliert. Bereichswechsel entfernt fachfremden Kontext; Schülerwechsel setzt die neue Zielauswahl zurück. Ziel-Standänderung erzeugt Zielüberprüfung. Quelle Z. 1281–1300, 1475–1484, 1608, 1628, 1741–1757, 1767–1774, 2494, 2526.

## D06: Für mehrere erfassen

Kopf, X → `Für N Schüler: <Namen>` → Fehlerbereich → `Bereich` (Sozial/Arbeit/HÜ/Organisatorisches) → bereichsspezifische Felder → Datum/Nachbereitung → Status `Individuelle Einträge · gemeinsamer Kontext` / `Entwurf gesichert` / `Entwurf noch nicht gesichert`, `Für N Schüler speichern`.

- Arbeit: Auftrag-Tagfeld → Gemeinsamer Ablauf → pro Schüler `Beobachtung · <Name>`, Textarea `Beobachtung …` maxlength 3000 und **eigene** positive/negative Auswahlbuttons.
- Sozial: Gemeinsamer Ablauf mit Zeitpunkt-Tag/Freitext → Beteiligt → dieselben individuellen Blöcke. Die späte Erweiterung entfernt die früheren gemeinsamen Bewertungslisten. Keine gemeinsame Bewertung auf alle übertragen.
- HÜ: `Neue Hausübung` mit Aufgaben-/Teilaufgabenzeilen → `Fach optional` → `Fällig am · optional`.
- Orga: `Eigene Notiz` mit Listenwerkzeugen → Als Aufgabe → Erinnern und deren abhängige Felder.

Start über Hauptauswahl erst ab zwei aktiven Schülern. Bereichswechsel leert im Original gemeinsame Auswahl und Fälligkeit. Empfänger müssen aktiv sein; jede individuelle Bewertung bleibt beim richtigen Kind. Gemeinsamer Kontext wird separat angelegt. Fehler u. a. `Die Auswahl enthält einen nicht mehr aktiven Schüler. Bitte die Schülerauswahl neu treffen.`, `Bitte eine Beobachtung, eine Auswahl oder einen Kontext eingeben.`, `Noch nicht gespeichert. Dein Entwurf bleibt erhalten.` Speicherung aller Daten zusammen; erst bei Erfolg Entwurf entfernen und schließen. Gruppenrücknahme hat eine eigene Sicherungskopie und darf keine fremden Änderungen beseitigen. Quelle Z. 1487–1519, 2499–2501.

## D07: Hausübung bearbeiten

Kopf `Hausübung bearbeiten`, X → Aufgabedatum → `Aufgaben & Teilaufgaben` und dieselben Zeilenaktionen wie Neuanlage → `Fach`, `Fällig am` → Fuß `Abbrechen`, `Speichern`. Kein ursprünglicher Empfängerwähler, kein neuer Abgabe-/Standeditor. Vorhandene Aufgaben-IDs erhalten; leere Zeilen herausfiltern; Kinder entfernter Hauptaufgaben werden Hauptaufgaben. Zugehöriger Zuweisungseintrag erhält aktualisierten Text und Aufgabenrevision. Kommentare/Stände der erhaltenen Aufgaben bleiben zugeordnet. Fehler `Änderung nicht gespeichert. Bitte erneut versuchen.`; geschützter Entwurf inklusive Zeilenstruktur. Quelle Z. 1605–1608.

## D08: Aufgabenkommentar

Original: Kopf `Kommentar & Stand`, X → genauer Aufgabentext → `Bearbeitungsstand`: `Vollständig`, `Teilweise`, `Nicht erledigt` als Radios → `Kommentar optional`, Textarea `Notiz …` maxlength 3000 → `Abbrechen`, `Speichern`. Bei offenem Stand keine Radioauswahl; ohne Wahl bleibt vorhandener Stand erhalten. Unveränderte Werte schließen ohne neue Rückmeldung. Fehlende Aufgabe: `Diese Aufgabe wurde inzwischen entfernt.`; Schreibfehler: `Änderung nicht gespeichert. Dein Kommentar bleibt im Eingabefeld.`

**Später:** Shortcut öffnet kleinen **„Kommentar“**-Modus, Stand nur als Information, keine Standbuttons; Text sofort fokussieren. Entwurf enthält Aufgabe **und Modus**. Nach expliziter Übernahme einer neueren Fassung darf Kommentar-Speichern nicht den neueren Stand zurücksetzen. Kein solcher Kommentar-only-Modus im Original-HTML; er ist als gezielte Änderung umzusetzen. Quelle Z. 1612–1617, 2150–2188, 2530.

## D09: Ziel überprüfen

Kopf `Ziel überprüfen`, X → `<Schüler> · <Ziel>` → `Zielkriterium: …` oder `Noch kein Zielkriterium festgehalten.` → Belege oder `Noch keine verknüpften Beobachtungen.` → `Was hat sich gezeigt? optional`, `Beobachtung …` maxlength 2000 → `Entscheidung` mit `Fortführen` (Standard), `Ziel erreicht`, `Beenden, ohne es als erreicht zu markieren` → nur bei Fortführen `Nächster Schritt optional` (bisheriger Schritt), `Nächste Überprüfung` (heute + 7 Tage) → Fehler → `Überprüfung speichern`.

Fortführen benötigt gültigen datumreinen Prüftermin: `Bitte einen gültigen nächsten Prüftermin wählen.` Erreicht/Beendet blenden nächste Angaben aus und speichern keine nächste Frist; beide Zustände unterscheiden sich. Prüfung wird angehängt, Zieltermin bleibt separat. Fehler kein Schließen, Entwurfsschutz. Original Z. 2210–2221.

## D10: Gemeinsame Situation

Kopf `Gemeinsame Situation`, X → Beteiligtennamen → `Gemeinsamer Ablauf`, `Kontext …`, maxlength 12000 → je verknüpfter Einzelbeobachtung Schülername, Text, Auswahltexte und `Beobachtung bearbeiten` → `Kontext speichern`.

Original bearbeitet hier **nur den Kontexttext**, nicht die Teilnehmerliste. Historische Flutter-Dokumentation beschreibt zusätzliche Teilnehmerbearbeitung mit fest gebundenen Beobachtungsteilnehmern; als Flutter-Erweiterung kennzeichnen. Individuelle Beobachtungen bleiben getrennt. Speicherung mit Rollback bei Fehler; geschützter Entwurf. Quelle Z. 2496–2498.

## D11: Gesicherte Entwürfe

Kopf, X → Bereichsentwürfe absteigend nach Änderungsdatum: Schüler/Bereich bzw. `Gemeinsam · <Bereich> · <Namen>`, Textvorschau, Datum/Zeit, `Fortsetzen`, `Verwerfen` → zusätzlich `Begonnene Bearbeitungen`, Typ und Vorschau, `Öffnen` für geschützte Editoren. Leer: `Keine gesicherten Entwürfe.`

Bereichsentwurf speichert Schüler, Bereich, HÜ-Modus und Feedback-ID; Gruppenentwurf Empfänger; Editorentwurf `editorId`, `ownerId`, ursprüngliche Fassung, Felder, Aufgabenzeilen, Auswahl, Beteiligte. Kommentar-Owner ist `homeworkId|taskId`. Fortsetzen muss genau diese Identität wieder öffnen. Wiederholtes Rendern darf keine doppelten Hinweise erzeugen. Bei mehreren echten Entwürfen nicht willkürlich zusammenführen.

Editorhinweis beim Öffnen: `Ein gesicherter Entwurf ist vorhanden.` oder `Eine neuere Fassung liegt vor. Abweichungen beim Speichern bleiben als Konflikt erhalten.`, `Entwurf übernehmen`, `Entwurf verwerfen`. **Später kompakter**, keine hohen Karten mit unnötigem Leerraum; Fehlertext weiter vollständig. Quelle Z. 1227–1244, 2150–2188, 2530.

## D12: Entwurf nicht gesichert

Kein gewöhnliches X. Titel → `Die Eingabe ist nur in dieser Sitzung vorhanden.` → `Weiterbearbeiten`, `Sicherung exportieren`, `Verwerfen` in dieser Reihenfolge. Weiterbearbeiten schließt nur die Warnung. Export nutzt Sicherungsablauf. Erst Verwerfen entfernt den Entwurf und schließt den ursprünglichen Editor. Nicht bei jedem normalen Schließen erzwingen, nur bei tatsächlichem Sicherungsfehler. Quelle Z. 2173–2186.

## D13: Gespräch vorbereiten

Kopf, X → `Namen weiterer Beteiligter aufnehmen` (aus) → `Von` (leer), `Bis` (heute) → `Alle auswählen`, `Auswahl leeren` → Eintragsauswahl mit Datum/Bereich/Inhalt → `Auswahl zusammenstellen` → zunächst verborgene Textvorschau → `Text kopieren`, `Als Textdatei sichern`.

Keine Auswahl: `Bitte mindestens einen Eintrag auswählen.` Datumswechsel leert Auswahl. Zusammenstellung aus ausgewählten eigenen Einträgen und offenen eigenen Erinnerungen, danach `Nächste Schritte`. Namensoption entfernt strukturierte Beteiligtenzeilen, keine freie Textanonymisierung. Vorschau im Original nicht editierbar. Dateiname `FLEX-Gespraech-JJJJ-MM-TT.txt`. Kopierfehler: `Kopieren nicht verfügbar. Bitte als Textdatei sichern.` Neues Öffnen setzt Auswahl/Vorschau zurück; kein `protectEditor` für diesen Dialog. Historische Dokumentation darf daraus keinen bestehenden Freitextentwurf erfinden. Quelle Z. 927, 1313–1320, 2527–2529.

## D14: Kalender

Titel `Datum wählen` oder `Datum & Uhrzeit`, X (`Kalender schließen`) → vorheriger Monat `‹`, Monat-Select (de-AT: Jänner … Dezember), Jahr-Select (aktuelles/gewähltes Jahr ±10), nächster Monat `›` → Mo–So, Tagesraster; heute markiert, ausgewählter Tag hervorgehoben → nur im Zeitmodus `Uhrzeit optional`, Zeitfeld und `Ohne Uhrzeit` (ohne Zeit deaktiviert) → `Heute`, `Datum entfernen` → nur Zeitmodus `Übernehmen`.

Datumreines Feld: Tages-/Heute-Klick übernimmt sofort. Zeitmodus: Tageswahl bleibt vorläufig, Übernehmen schreibt Datum und Zeit zusammen. Datum entfernen übernimmt im Original sofort leeren Wert und schließt. Zeit ohne Datum ergänzt beim Übernehmen heute. X/Escape verwirft vorläufige Wahl, Fokus kehrt zum auslösenden Button zurück. Pfeiltasten ±1/±7 Tage, Monatswechsel mit Fokusbeibehaltung. `00:00` ist explizite Uhrzeit und nicht fehlende Zeit.

**Später:** gemeinsamer Kalenderzugang, optionales Hinzufügen/Entfernen der Uhrzeit innerhalb des Kalenders, kein vorgeschalteter Formular-Uhrzeitschalter; dokumentierter Flutter-Stand nennt `Uhrzeit hinzufügen` und `Übernehmen`. Datum-/Zeitübernahme und Abbruch als Einheit testen. Aufgabentermin/Prüftermin bleiben datumrein, Erinnerung von Beobachtungsdatum getrennt. Quelle Z. 1346–1383; ein separater Uhrzeitdialog gehört nicht zu dieser HTML-Endfassung.

## D15/D16: Sicherung und Passwort

D15: Kopf `Datensicherung`, X → `Sicherung mit Passwort verschlüsseln` (an) → `Darstellung und Hintergrundbild mitsichern` (an) → `Exportieren`, `Importieren` → verborgenes Dateiinput JSON → `Auswahllisten aus der Sicherung übernehmen` (an) → Hinweis auf Unterrichtsdaten/Entwürfe einschließlich Papierkorb/früherer Fassungen und geschützte Ablage. Kein eigener Fuß nötig.

D16 Exporttitel `Sicherung verschlüsseln`, Importtitel `Sicherung öffnen`; **kein X im Original** → `Passwort`, Passwortfeld required/autocomplete off, sofortiger Fokus → `Das Passwort wird nicht gespeichert. Ohne Passwort kann eine verschlüsselte Sicherung nicht wiederhergestellt werden.` → `Abbrechen`, `Fortfahren`. Escape/Abbruch liefert null; kein Entwurf des Passworts. Verschlüsselte Sicherung wird erst danach mit WebCrypto verarbeitet; `encryptBackup` verlangt mindestens zwölf Zeichen (das Feld selbst besitzt nur `required`). Original verlangt keine zweite Passwortwiederholung; abweichende Flutter-Bedienung separat bewerten. Quelle Z. 923, 2228–2230, 2535–2544.

## D17: Sicherung prüfen

Kopf, X → Anzahl neuer/abweichender Datensätze; Liste gleicher Namen mit unterschiedlichen IDs; Hinweis auf Neuberechnung der HÜ-Stände → falls Wiederherstellung nach kaputtem Speicher: Diagnosehinweis, `Bisherigen Speicher als Datei sichern`, Bestätigung `Diese Sicherung als neuen Datenstand verwenden` → Darstellungsübernahme-Schalter, wenn enthalten, sonst Erhaltungshinweis → normale Importwahl: `Neuere Fassungen übernehmen; bei unklaren Konflikten aktuelle Daten behalten.` (Standard) oder `Bei Konflikten ausdrücklich die Fassung aus der Datei übernehmen.` → Hinweis auf getrennte Darstellung, erhaltene Fassungen/Konflikte und ID-Zuordnung → `Import übernehmen` bzw. `Sicherung wiederherstellen`.

Dateigrenze 15 MiB, Strukturprüfung vor Öffnung. Fehler u. a. `Datei zu groß (maximal 15 MB).`, `Keine gültige FLEX-Sicherung.`, `Import nicht gespeichert. Bitte erneut versuchen.`, `Bitte die Wiederherstellung als neuen Datenstand bestätigen.` Bei Wiederherstellung bleiben alte Speicherstände zur Diagnose erhalten. Keine Zusammenführung anhand gleicher Namen. Daten-, Entwurfs- und Darstellungsfehler getrennt melden; übernommenen Datenbestand nicht als vollständig erfolgreiche Darstellungsübernahme ausgeben. Quelle Z. 928, 1308, 2093–2148, 2230–2231.

## D18: Pflege / endgültiges Leeren

Kopf je Modus, X → modusspezifische Beschreibung → `Vollständige Sicherung herunterladen` → `Ich habe die Sicherung gespeichert und andere App-Tabs geschlossen.` (aus) → nur Leeren `Zum endgültigen Löschen LÖSCHEN eingeben`, leere Eingabe → Fehlerbereich → `Ausführen`.

Ohne Bestätigung/exaktes Wort: `Bitte zuerst die Sicherung bestätigen und die erforderliche Eingabe ausfüllen.` Ausführen während Operation deaktiviert. Pflege erhält Einträge, frühere Fassungen und Entwürfe; Leeren entfernt gelöschte Daten und bereinigt Zielverweise. Fremde aktive Sitzungen, fehlende Locks, Speicherfehler und zwischenzeitliche Änderungen blockieren. Aktiven Speicherzeiger erst nach geprüftem neuen Bestand wechseln; alte Schlüssel erst danach bereinigen. Keine Verwechslung mit gewöhnlichem Eintragsspeichern. Quelle Z. 2240–2255.

## D19: Papierkorb

Kopf, X → `Hier abgelegte Einträge sind ausgeblendet und weiterhin in Sicherungen enthalten.` → je gelöschtem Eintrag Schüler/Bereich, Textvorschau bis 240 Zeichen, `Wiederherstellen` → bei leer `Der Papierkorb ist leer.` → Fuß `Papierkorb endgültig leeren` öffnet D18.

Wiederherstellen entfernt Löschmarken einschließlich verknüpfter HÜ/Erinnerungen/abgeleiteter Einträge; Fehler rollt zurück. Der Originaldialog listet `db.entries`, nicht sämtliche Datentypen. Historische Flutter-Dokumente erweitern ihn um Schüler-/Klassen-Orga. Quelle Z. 2232–2234.

## D20: Änderungskonflikte

Kopf, X → pro ungelöstem Konflikt Titel des betroffenen Datensatzes, Feldname → zwei Spalten `Aktuelle Fassung` und `Andere Fassung` mit umbrechenden Werten → `Aktuelle behalten`, `Andere übernehmen`. Schmal untereinander; Werte selbst scrollbar. Leer `Keine offenen Konflikte.` Kein allgemeiner Speicherfuß.

Aktion bezieht sich auf konkrete Entität/Feld; beide Alternativen und frühere Fassungen bleiben nachvollziehbar. Konflikt erst nach erfolgreichem Persistieren als gelöst markieren; bei Fehler bisherigen Zustand wiederherstellen. Quelle Z. 2508–2516.

## D21/D22: Klassen-Orga

D21 Kopf `Klassen-Orga`, X → `Alle`, `Offen`, `Erledigt` → klickbare Karten mit Notiz/Aufgabe offen/Aufgabe erledigt, Textvorschau, ggf. Termin und aktive Erinnerung → leer `Keine Einträge.` → Fuß `Eintrag hinzufügen`.

D22 Kopf `Klassen-Orga`, X → `Notiz oder Aufgabe`, Textarea `Notiz …` maxlength 12000, Listenwerkzeuge → `Als Aufgabe` (hier bei Neu **an**) → optional Termin/Aufgabe erledigt → `Erinnern` → dieselben Erinnerungsfelder wie Schüler-Orga → `Speichern`. **Kein Schülerwähler, keine Schülerpflicht.** Kein originaler Beobachtungsdatum-/Später-ergänzen-Fuß in diesem Klassenformular. Vorhandene Daten laden; geschützter Entwurf; Aufgaben-/Erinnerungsdatum und Quittierung/Erledigung getrennt wie D01. Quelle Z. 2518–2524, endgültig Z. 2560–2569.

## Nicht als zusätzliche HTML-Modals zählen

- **Einstellungen:** Seite mit Darstellung/Bedienung/Daten. Darstellung: Stilvorlagen Ruhig/Bild dezent/Bild klar, Lesbarkeitsschutz, Flächenkopplung; aufklappbare Gruppen Hintergrund, Hauptansicht, Buttons & Eingabefelder, Dialoge; Live-Vorschau. Dialogfarbe/Transparenz, Kopf-/Fußtransparenz sind verschiedene Flächen. Die spätere gemeinsame Leistenfarbe fehlt als eigener Originalfarbwert.
- **Farbe:** `input[type=color]` plus HEX/Paletten, vom Browser/OS gezeichnet. HTML legt das native Pickerfenster nicht fest; ein Flutter-HSV-/RGB-Picker kann nicht pauschal „identisch“ heißen.
- **Bild:** verborgenes Dateiinput, `Bild wählen`, `Bild entfernen`, Bild-verwendet-Schalter, Abdunklung und Tönung. Original-Hintergrund mit `cover`; unterschiedliche Desktop-/Mobilbilder und fünf Modi sind dokumentierte Flutter-Erweiterungen. Spätere Mindestvorgabe: Gestreckt/Füllend/Eingepasst klar unterscheiden; ein Vorschaubild muss denselben Modus verwenden. Originalbilder aus Screenshots liegen hier nicht als separate Dateien vor.
- **Bestätigungen und Rückgängig:** Entwurf-Verwerfen im Bereichsbanner sowie Rücknahme-/Löschhinweise sind teils Inline-Zustände. Kein zusätzliches benanntes HTML-Dialogelement erfinden. Native `confirm`/`prompt` gehören nicht zum ermittelten App-Dialogregister.

## Verbindliche Übernahmen aus der späteren Spezifikation

1. Alle Fach-/Nebenansichten bleiben Modals, auch schmal; Hauptseiten Übersicht/Schüler bleiben Seiten.
2. Gemeinsame Kopf-/Fußfarbe mit wirksamer Transparenz, bei jedem Dialog; Sans-Labels/Serifentitel und durchgängige Tagflächen tatsächlich rendern.
3. Abstand unter Positiv/Negativ verkleinern; Entwurfshinweise kompakt.
4. Zeitpunkttexte exakt kurz; nur ein Zeitpunkt im Sozialfeld, Freitext erhalten.
5. `Weitere Angaben` samt zusätzlichem Trenner entfernen; `Kontext / Quelle` und `Reaktion / Unterstützung` über Schalter; bloßes Einklappen erhält Daten.
6. Kalender mit integrierter optionaler Zeit, kein Formular-Uhrzeitschalter; fehlend ≠ 00:00; Abbruch unverändert.
7. HÜ-Stände direkt mit vier Buttons, sofortiges robustes Speichern; Kommentar separat und aufgabengebunden, Fokus/Entwurf/Versionskonflikt schützen.
8. Einzelne Schüler innerhalb Formularen als Tagbuttons, Mehrfachauswahl und Entwurfsfortsetzung erhalten.
9. Aufgabenabschluss, Erinnerungsquittierung und getrennte Termine beibehalten; Klassen-Orga ohne Schülerzwang.
10. `Speichern & weiter` erst nach bestätigtem Commit zum **nächsten aktiven Schüler in bestehender Reihenfolge**; am letzten Schüler bleiben und Hinweis. Kein Umlauf zum ersten und kein Erfolg bei Fehler.
11. Einheitliche Bereichssymbole gemäß Spezifikation; die erwähnten Bildentwürfe sind keine nachgewiesen eingebauten Assets.

Die endgültige Abnahme verlangt Inhalts-, Darstellungs- und Bedienungsabgleich. Dieses Quellenverzeichnis allein ist dafür kein ausreichender Nachweis.
