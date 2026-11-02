# Einstellungen und Karten-Shortcuts – 0.16.0-rebuild.6+26

Stand: 2. November 2026. Grundlage bleibt der wiedergefundene rekonstruierte Flutter-Quellstand. Dies ist keine Wiederherstellung der verlorenen Originalquellen und keine Behauptung vollständiger Originaltreue.

## Quellen und Vorrang

1. [HTML-Referenz](reference/FLEX-Notizbuch-37.html): Settings-Funktionen Zeilen 1888–2092, Styles 682–741. Die tatsächlich erzeugte Endstruktur ist `settingsHTML`, nicht eine aus dem Begleittext erfundene Navigation.
2. [Neue Nutzerspezifikation](reference/SETTINGS_NUTZERSPEZIFIKATION.txt): Anforderungen an Wirkung, Speicherung, große Schrift, Tastatur und direkte Flutter-Renderings. Nicht belegte Details darin werden anhand der Originalquelle und der erhaltenen Dokumentation geklärt.
3. Spätere belegte Änderungen: [Dialogverfeinerung](reference/webpreview-docs/DIALOG_VERFEINERUNG.md), [Darstellung und Lesbarkeit](reference/webpreview-docs/DARSTELLUNG_UND_LESBARKEIT.md), [Desktop-/Mobilbilder](reference/webpreview-docs/BILDHINTERGRUENDE.md), [Settings-Korrekturen 0.15.2](reference/webpreview-docs/SETTINGS_KORREKTUREN.md).
4. Aktuelle ausdrückliche Änderung: Jeder der fünf Schülerkarten-Shortcuts öffnet unmittelbar das zugehörige Eintragsmodal.

Die erhaltenen Dokumente beschreiben frühere Prüfungen; sie sind keine Testnachweise des jetzigen Quellstands. Aktuelle Nachweise stehen unten separat.

## Tatsächlich vorhandene Struktur und Reihenfolge

Die HTML-Einstellungen sind eine Seite unter **… → Einstellungen**, kein eigener Einstellungsdialog. Modale Farbwahl, Sicherung/Import, Papierkorb und Speicherpflege öffnen darüber. Kopf: „Einstellungen“, danach „Änderungen werden automatisch auf diesem Gerät gespeichert.“

Drei gleich breite Reiter: **Darstellung → Bedienung → Daten**. Links/Rechts wechseln zyklisch, Home/End zum ersten/letzten Reiter. Aktiver Reiter und aufgeklappte Gruppen bleiben bei einem Bereichswechsel innerhalb derselben App-Sitzung erhalten. Sie sind keine dauerhaften Darstellungspräferenzen.

**Darstellung**, Reihenfolge im HTML:

1. „Stilvorlagen“ / „Schnell wählen, darunter gezielt anpassen.“: Ruhig, Bild dezent, Bild klar; ohne Bild deaktivierte Bildvorlagen und Hinweis. Danach Lesbarkeitsschutz und Erklärung.
2. „Alle Flächen gemeinsam einstellen“ und Erklärung zur Übernahme der Buttonwerte.
3. Aufklappgruppe „Hintergrund“ / „Farbe, Bild und Tönung“: Hintergrundfarbe, Zurücksetzen, Farbwahl/HEX, sieben Vorschläge, automatische Schrift; anschließend Bild verwenden, Bild wählen/Anderes Bild wählen, Bild entfernen, Dateiname oder Leerhinweis, Vorschau, Abdunklung, Bildtönung, Tönungsstärke, Tönung zurücksetzen und Hilfetext. Später dokumentiert: getrennte Desktop-/Mobilfelder und fünf Bildmodi.
4. „Hauptansicht“ / „Kopfbereich und Schülerkarten“: je Fläche Titel, Zurücksetzen, Erklärung, Transparenz, Farbfeld/HEX, Palette, automatische Farbe, Lesbarkeitshinweis.
5. „Buttons & Eingabefelder“ / „Farbe und Transparenz“: gleiche Reihenfolge für Buttons und Eingaben, mit den jeweiligen Originalerklärungen.
6. „Dialoge“ / „Hintergrund, Kopf- und Fußzeile“: Dialoghintergrund wie zuvor; dann „Dialogfenster“, Zurücksetzen, Bildhinweis, Kopfzeile, Fußzeile, Hilfetext einschließlich Datum/Nachbereitung. Später ausdrücklich ergänzt: gemeinsame Farbe „Dialogkopf und -fuß“.
7. „Live-Vorschau“ mit „Kopfbereich, Schülerkarte und Dialog mit deinen Einstellungen.“; Kopfbereich, Schülername, Shortcuts, Beobachtungsdialog, „Was ist passiert?“, „Hilft anderen“, „Beobachtung …“, „Eintrag speichern“. Breit neben den Optionen geöffnet, schmal darüber zunächst geschlossen. Keine echten Schülerdaten werden angelegt.
8. Status: gespeichert / wird gespeichert / nicht gespeichert. Fehler verschwinden nicht durch einen Seitenwechsel.

**Bedienung**: „Karten-Shortcuts“, Zurücksetzen, „Von links nach rechts, zuerst die obere Zeile. Mit den Pfeilen verschieben.“ Je Zeile Position, Symbol, vollständiger Bereichsname, nach vorne/nach hinten; Randaktionen deaktiviert.

**Daten**: „Sichern & wiederherstellen“ mit „Sicherung / Import öffnen“ und Passwortschutzhinweis; „Papierkorb“ mit Anzahl und „Papierkorb öffnen“; aufklappbare „Speicherpflege“ / „Technischen Speicher zusammenfassen“, Erhaltungshinweis, „Speicherpflege öffnen“.

## Zuordnung aller angebotenen Darstellungswerte

Alle unten genannten Werte liegen gemeinsam in SQLite `preferences.appearance` und in der bestehenden Vollsicherung. Prozentwerte für **Transparenz** werden im erhaltenen Flutter-Schema als Deckkraft `1 − Prozent/100` gespeichert. 0 % Transparenz = deckend, 100 % = keine Farbfüllung. Originalwerte werden nicht mit Deckkraft verwechselt.

| Beschriftung / Aktion | Gespeicherter Flutter-Wert | Standard / Bereich | Tatsächliche Wirkung |
| --- | --- | --- | --- |
| Hintergrund / Eigene Farbe | `backgroundColor` | `#4F6038`; gültige RGB-Farbe | App-Grundfläche, freie Bildränder und Dialogbild-Grundfläche. Auswahl schaltet ein eigenes Bild nicht aus. |
| Kopfbereich / Transparenz | `workspaceOpacity` | .88 = 12 % transparent; 0–1 | Hintergrund der Hauptnavigation; keine Text-/Symbolabblendung. |
| Kopfbereich / Eigene Farbe | `workspaceColor` | 0 = automatisch; RGB | Navigationsfläche; automatische kontrastierende Schrift. |
| Schülerkarten / Transparenz | `cardOpacity` | .82 = 18 % transparent; 0–1 | Kartenfüllung tatsächlich, ohne den früheren versteckten Multiplikator .07. |
| Schülerkarten / Eigene Farbe | `cardColor` | 0 = automatisch; RGB | Schüler- und Eintragskarten, inklusive Textkontrast. |
| Buttons / Transparenz | `buttonOpacity` | .94 = 6 % transparent; 0–1 | Auswahl-/Zusatzbuttons, Chips und gesamte Beobachtungsfläche einschließlich Stern. Primäre Speicheraktionen und aktive fachliche Auswahl bleiben hervorgehoben. |
| Buttons / Eigene Farbe | `buttonColor` | 0 = automatisch; RGB | Normale Button-/Tagflächen und deren Schrift/Symbole. |
| Eingabefelder / Transparenz | `fieldOpacity` | .94 = 6 % transparent; 0–1 | Schreibfelder, Auswahllisten, gemeinsam gerahmte Tags mit Freitext. |
| Eingabefelder / Eigene Farbe | `fieldColor` | 0 = automatisch; RGB | Eingabefüllung, passende Eingabeschrift und Hinweise. |
| Dialoghintergrund / Transparenz | `modalOpacity` | 0 über dem vorhandenen Standardbild; 0–1 | Farbfläche über dem Dialogbild. Kein deckender innerer Container verdeckt den Regler. Zurücksetzen ohne Bild setzt deckend wie im HTML. |
| Dialoghintergrund / Eigene Farbe | `modalColor` | 0 = automatisch; RGB | Modal-Inhaltsfläche und Inhaltskontrast. |
| Dialogkopf und -fuß / Eigene Farbe | `dialogColor` | 0 = automatisch; RGB | Gemeinsame Farbe aller `FlexModal`-Köpfe und -Füße, einschließlich Datum/Nachbereitung, HÜ/Ziele und Unterdialoge. |
| Kopfzeile | `headerOpacity` | .65 = 35 % transparent; 0–1 | Nur Farbfüllung des Dialogkopfs. |
| Fußzeile | `footerOpacity` | .65 = 35 % transparent; 0–1 | Abschluss-/Datumsbereich und Speicherzeile. |
| Alle Flächen gemeinsam einstellen | `coupleSurfaces` | false | Einschalten übernimmt Buttonfarbe und -deckkraft. Weitere Änderungen übertragen sich auf alle sechs Farbrollen und sieben Transparenzen. Ausschalten erhält die Werte. Gemeinsame Dialogleistenfarbe ist dabei enthalten. |
| Lesbarkeitsschutz | `readabilityProtection` | false | Bei aktivem Bild deckende Kopf-, Karten- und Dialogflächen. Gespeicherte Alpha-Werte bleiben erhalten. Manuelle Leseflächen-Transparenz schaltet Schutz aus; nur Button/Feld alleine nicht. |
| Bild verwenden | `imageEnabled` | true für den erhaltenen Texturstand | Schaltet beide Bilder gemeinsam; Ausschalten löscht keine Bilddaten. |
| Desktop-/Mobilbild wählen, ersetzen, entfernen | `desktopImage`, `mobileImage`, jeweiliges `…ImageName` | leer; Bildbytes als Base64, Name max. 120 Zeichen | Echter Dateiimport, Vorschau, App, Dialoge, Neustart und Vollsicherung verwenden dieselben Daten. Entfernen betrifft nur die gewählte Variante. |
| Fläche füllen / Filled | `desktopFit` / `mobileFit = cover` | Standard | Proportional füllen, mittig beschneiden. |
| Einpassen / Scaled | `…Fit = contain` | auswählbar | Vollständig proportional einpassen, Vergrößerung erlaubt, freie Flächen zeigen `backgroundColor`. |
| Strecken / Stretched | `…Fit = fill` | auswählbar | Beide Achsen unabhängig strecken; Verzerrung erlaubt. |
| Originalgröße | `…Fit = none` | spätere dokumentierte Option | Gespeicherte Pixelgröße mittig; große Bilder beschnitten. |
| Kacheln | `…Fit = tile` | spätere dokumentierte Option | In gespeicherter Pixelgröße wiederholen. |
| Bilddeckkraft | `backgroundOpacity` | .35 aus dem erhaltenen Rebuild; bei neuer Bildwahl 1; 0–1 | Nur Bildpixel. Bewahrte Rebuild-Option, kein zusätzlicher Original-Transparenzregler. |
| Abdunklung | `backgroundDim` | 0 für ältere Bilder ohne diese Einstellung; 0–.8 in Schritten .05 | Schwarze Ebene über Bild, unter allen Bedienelementen. Bildvorlagen setzen .45/.30. |
| Bildtönung | `backgroundTint` | `#203A2D`; RGB | Farbe der separaten Tönungsebene. |
| Stärke der Tönung | `backgroundTintStrength` | 0 für ältere Bilder; 0–.8 in Schritten .01 | Nur Tönungsebene. Tönung zurücksetzen setzt `#203A2D` und .25. |
| Akzentfarbe | `accent` | `#DAE9A6`; RGB | Aktive Navigation und ausgewählte Tags; fachliche Negativ-/Statusfarben bleiben separat. Bereits im Rebuild vorhanden. |
| Kartenrundung | `cardRadius` | 22; 0–32 | Schüler- und Eintragskarten. In erhaltener 0.15-Dokumentation belegt. |
| Schriftgröße | `textScale` | 1; .9, 1, 1.15, 1.3 angeboten; bestehende Werte bis 1.4 lesbar | Multipliziert Systemschrift, ersetzt sie nicht. Bereits im Rebuild vorhanden. |
| Kompakte Abstände | `compact` | false | Theme-Abstände und Innenabstände der Schülerkarten; Schrift bleibt gleich. |
| Gelasio für Überschriften | `serifHeaders` | false | Bereits vorhandene Überschriftenoption; Dialog- und Schülernamen behalten die im Dialogabgleich festgelegte Serifengestaltung. |
| Wald · dunkel / Papier · hell / Wie das System | `mode` | dark | Bewahrte Rebuild-Auswahl; nicht als HTML-Originalfunktion ausgegeben. |
| Karten-Shortcuts / Pfeile / Zurücksetzen | `shortcutOrder` | goal, social, work, homework, orga; jede Kategorie genau einmal | Sofortige Reihenfolge in tatsächlichen Karten und Vorschau; bleibt nach Neustart erhalten. |
| Darstellung zurücksetzen | alle Erscheinungswerte | bestätigter Rebuild-Standard | Bewahrte Rebuild-Funktion; erhält die Karten-Shortcut-Reihenfolge und verändert keine Schüler, Einträge oder Entwürfe. |

### Farbwahl und Rücksetzen

Das HTML besitzt tatsächlich native Farbfelder **und** direkte HEX-Eingaben. Sie sind also keine aus der neuen Spezifikation erfundene Ergänzung. Übernommen: `#RRGGBB`, sieben Vorschläge Oliv, Salbei, Sand, Hell, Blau, Pflaume, Graphit; automatische Farbe und Zurücksetzen je Fläche. Hintergrund-Oliv ist `#4F6038`, Flächen-Oliv `#303E2B`. Ungültiges HEX zeigt eine Fehlermeldung und überschreibt keinen gültigen Wert.

Flutter verwendet für das anklickbare Farbfeld ein gemeinsames Modal mit Farbton, Sättigung, Helligkeit, Vorschau, Abbrechen und Übernehmen. Das ist eine funktionale plattformeigene Umsetzung, keine identische Nachbildung des browser-/betriebssystemabhängigen HTML-Farbwählers. Farbwechsel erhalten vorhandene Transparenzen. Zurücksetzen einer Fläche setzt deren Farbe und Alpha zurück; bei aktiver Kopplung gelten ausdrücklich die Kopplungsregeln.

### Bildregeln

Die spätere Dokumentation legt **bis einschließlich 700 logische Pixel Fensterbreite mobil, darüber Desktop** fest. Das ist eine belegte spätere Änderung, keine aus dem neuen Text abgeleitete Zahl. Auswahl reagiert auf Fenstergröße/Drehung, nicht auf Plattformkennung. Fehlt ein Bild, dient die andere Variante als Ersatz; der Modus folgt weiterhin der aktuellen Fensterbreite. App, Dialoge und Vorschau verwenden denselben Renderer. Der App-Hintergrund liegt fest außerhalb der scrollenden Seiteninhalte.

Dateiauswahl akzeptiert JPEG, PNG und WebP bis 12 MiB und 48 Megapixel. Vor der vollen Dekodierung werden Abmessungen geprüft, längste Kante auf 1600 begrenzt, transparente Pixel wie beim HTML-Canvas auf `#203A2D` gelegt. Flutter speichert eine PNG-Fassung bis 5 MB. Das unterscheidet sich von der JPEG-Komprimierung und der 1,2-MB-Data-URL-Grenze des HTML. Abbruch, ungültige Datei und fehlgeschlagene Aufbereitung ersetzen kein vorhandenes Bild.

**Fehlende Originaldateien:** Vorhanden ist nur `assets/backgrounds/dark-texture.png` aus dem gefundenen Rebuild. Die zwei erwähnten grünen Tafelmotive sind auch im Upload/Referenzarchiv nicht als Bilddateien vorhanden. Sie wurden nicht erfunden oder durch generierte Motive ersetzt. Die getrennte Auswahl funktioniert mit eigenen Originaldateien.

## Konkrete korrigierte Abweichungen

- Shortcut öffnete zuerst Bereichsübersicht, dann musste „Eintrag anlegen“ betätigt werden → direkte Editorroute mit festem Schülerkontext, nur ein Modal. Neuster passender neuer Einzelentwurf wird fortgesetzt; fremde Schüler, andere Bereiche, Gruppen- und Bestandsbearbeitungsentwürfe werden nicht übernommen. Archivierte Schüler bleiben in der schreibgeschützten Bereichsansicht. Der Kartenkopf öffnet weiterhin die Übersicht mit bestehenden Einträgen.
- Eine lange ungegliederte Einstellungsseite → Originalreiter und vier aufklappbare Darstellungsgruppen, Live-Vorschau, Shortcut-Reihenfolge und Datenfunktionen am belegten Ort.
- Vier grobe Deckkraft-Chips ohne Nullwert, fehlende Regler → sieben echte Transparenzregler 0–100 %, zusätzliche getrennte Bildregler.
- Automatische Kartenfüllung multiplizierte die Deckkraft mit .07 → Regler wirkt unmittelbar auf die tatsächliche Füllung.
- Modals ersetzten Chip-/Feldfarben durch feste Werte → gemeinsame Palette für echte Dialoge, Karten und Vorschau. Gleiche Buttonfüllung unter Text und Stern, keine doppelte Alpha-Anwendung.
- Nur drei Flächenfarben gekoppelt, Leisten/Felder/Inhalt fehlten → vollständige Farb- und Transparenzkopplung; Farbauswahl verändert Alpha nicht.
- Unterschiedliche Mobilgrenzen 650/700, kein Ersatzbild, fehlende Bildmodi/Vorschau → eine 700-Regel, Ersatzbild, fünf dokumentierte Modi, gleiche Darstellung überall.
- Langsame Speicherung konnte jüngere Änderungen überschreiben → sofortige Vorschau, 250-ms-Speicherpause, Loslassen/Seiten- und Lebenszykluswechsel sichern ausstehende Werte, geordnete Schreibvorgänge, Rückkehr zum letzten erfolgreichen Stand bei Fehler.
- `PageStorage`-Kollision zwischen aufgeklappter Gruppe und Textfeld-/Seiten-Scrollposition → getrennte Schlüssel und Scrollcontroller. Wiederöffnen, Tabwechsel und ungültige HEX-Eingabe werden geprüft.

## Daten und Kompatibilität

Bestehende Vollsicherungen enthalten den kompletten `preferences`-Eintrag einschließlich beider Bilder, Modi, Farben und Alpha-Werte. Dateineustart und Wiederherstellung werden aktuell getestet. Fehlende einzelne Präferenzen erhalten definierte Standards; vorhandene Werte bleiben erhalten. Ungültige Zahlen/Farben/Modi/Reihenfolgen werden abgewiesen. Die Datenbank erhält keine neue Migration.

Die HTML-Optionen für selektive Übernahme/optionales Mitsichern der Darstellung sind weiterhin nicht vollständig im Rebuild implementiert. Daher sagt die aktuelle Datenansicht ausdrücklich „Vollsicherung enthält Darstellung und Hintergrundbilder“ statt eine nicht vorhandene Auswahl zu behaupten. HTML-Import bleibt eine unveränderte Vormerkung; die bereits dokumentierten Import-/Konfliktlücken sind durch diese Änderung nicht geschlossen. Es werden keine Synchronisations- oder Scannerfunktionen als verfügbar angeboten.

## Aktuelle Prüfung

- Gesamtlauf: **98 lokale Flutter-Tests bestanden** (`evidence/settings-tests.log`).
- Nach der abschließenden Anpassung der Navigation bei großer Systemschrift: **25 Settings-/Karten-/Dialogtests bestanden**, darunter 17 neue Settings-Tests (`evidence/settings-focused-tests.log`).
- `flutter analyze --no-pub`: keine Befunde (`evidence/settings-analyze.log`).
- **133 direkte Flutter-Renderings** in `settings-renderings/`: vollständige Dialogmatrix plus Settings, Schülerkarten und geänderte Dialogflächen. Ansichten 1100 Pixel und 320/390 Pixel breit; leere, befüllte, fehlerhafte Zustände; 130 % App-Schrift und 200 % Systemschrift sowie simulierte Tastatur-Insetfläche. Die Tastatur selbst wird vom lokalen Widgetrenderer nicht gezeichnet.
- Wirkungsprüfung aller sieben Transparenzen an den tatsächlichen Widgets und an gerenderten Pixeln bei 0/.5/1 Deckkraft. Getrennter Pixelvergleich beider Hälften der Text-/Sternbuttons. Bildmodusprüfung umfasst proportionale Ränder/Beschnitt, Strecken, Originalgröße und Kachelung.
- Echte SQLite-Datei schließen/neu öffnen, Vollsicherung wiederherstellen, fehlende Einzelwerte, ungültige Werte, schnelle geordnete Änderungen und erzwungener Speicherfehler einschließlich sichtbarer Fehlermeldung nach Seitenwechsel.
- Lokaler Flutter-Web-Releasebuild erfolgreich; Ressourcen einschließlich Drift-Worker, SQLite-WASM und lokalem CanvasKit werden mitgeliefert. Drei lokale Vorschau-Serverprüfungen bestanden (`evidence/settings-preview-server-tests.log`): Ressourcen/Header, belegter Port und unvollständiges Paket. Paketprüfung ohne Browser.

Visuell geprüft wurden insbesondere die Settings breit/schmal, ungültige HEX-Eingabe mit Tastaturfläche, Sozial-/Orga-Farben und die 200-%-Ansicht. Dabei gefundene gekürzte Navigationsbeschriftungen wurden korrigiert: schmal bei sehr großer Systemschrift umbrechende Hauptnavigation und übereinander angeordnete Einstellungsreiter. Das ist eine bewusst dokumentierte Barrierefreiheitsanpassung gegenüber den drei horizontalen HTML-Reitern.

Keine Browsertests, keine Ausführung des Windows-Starters und keine native Android-Abnahme. Farb-/Dateiwähler, Schriftmetriken, sticky Desktop-Vorschau und alle Detailabstände sind nicht als pixelidentisch zum HTML abgenommen. Die Desktop-Vorschau steht neben den Optionen und scrollt derzeit mit der Seite; die HTML-Vorlage verwendet dort sticky Positionierung. Diese Unterschiede und die offenen Importfunktionen schließen die Bezeichnung „vollständig originalgetreu“ aus.
