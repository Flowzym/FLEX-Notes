# Gesprächsvorbereitung – Version 0.7.0+7

Der neue Flutter-Dialog ersetzt die bisherige vereinfachte Auswahl mit Kopierknopf.
Referenz ist der unveränderte aktuelle HTML-Prototyp, insbesondere `briefDialog`,
`showBrief`, `briefEntries`, `drawBriefItems`, `createBrief` und die spätere Option
`briefIncludeNames` in `review-interface.js`. Es wurde keine HTML-Datei verändert.

## Bedienung

1. Schüler öffnen → **… → Gespräch vorbereiten**.
2. Bei Bedarf **Von** und **Bis** einstellen. Anfangs sind alle bisherigen Einträge
   bis einschließlich heute sichtbar. Beide Datumsgrenzen lassen sich entfernen.
3. Einzelne Einträge markieren oder **Alle auswählen** verwenden.
   **Auswahl leeren** setzt die Auswahl zurück.
4. Optional **Namen weiterer Beteiligter aufnehmen** einschalten.
5. **Auswahl zusammenstellen** erstellt die lesbare Vorschau.
6. **Text kopieren** oder **Als Textdatei sichern** gibt genau diese Vorschau aus.
   Der Dateiname lautet `FLEX-Gespraech-JJJJ-MM-TT.txt`, die Kodierung ist UTF-8.

Das Detailfenster folgt dem HTML-Ablauf: Beteiligtenoption, zwei Datumsfelder,
Auswahlaktionen, Eintragsliste, Zusammenstellen, Textvorschau und Exportaktionen.
Auf Mobilgeräten nutzt es die Bildschirmbreite; lange Listen und die Vorschau
sind scrollbar. Die Vorschau ist wie im Prototyp ein erzeugter Text und kein
zusätzliches bearbeitbares Gesprächsprotokoll.

## Fachliche Inhalte

- Ziele: aktueller Status, Zielkriterium, nächster Schritt, Zieltermin, nächster
  Prüftermin und bereits erfasste Schülerperspektive.
- Sozial-/Arbeitsbeobachtungen: Text, positive/negative Auswahl, Auftrag oder
  Situation, Zielbezug mit damaliger Zielbeschreibung, Unterstützung und Quelle.
- Gemeinsame Kontexte: gemeinsamer Ablauf; bei nur erwähnten Schülern ausdrücklich
  **Als beteiligt genannt · keine eigene Bewertung**. Die individuellen
  Beobachtungen anderer Kinder werden nicht in deren Bericht übernommen.
- Hausübung: Aufgaben/Teilaufgaben, Fach und Fälligkeit sowie separat auswählbare
  Rückmeldungen mit ihrem eigenen Datum, Stand, Abgabe und Kommentar.
- Orga: Notiz und Checklisten, Aufgabenstand und -termin, davon getrennte Erinnerung
  mit Zeitpunkt und Zustand. Quittierung wird nicht als Aufgabenabschluss ausgegeben.
- Noch nicht abgeschlossene Dokumentation bleibt als solche gekennzeichnet.

Wie im HTML folgen nach den ausgewählten Einträgen **Offene Absprachen /
Erinnerungen** und **Nächste Schritte**. Der Erinnerungsabschnitt enthält die
aktuell offenen Erinnerungen dieses Schülers, unabhängig vom ausgewählten
Beobachtungszeitraum. Quittierte, beendete, gelöschte sowie klassenbezogene
Erinnerungen und Erinnerungen anderer Schüler werden dort nicht angehängt.

Die Beteiligtenoption betrifft strukturierte Namensangaben. Freitexte bleiben
unverändert; Namen, die in einem eigenen Text stehen, werden nicht automatisch
entfernt. Die Vorschau enthält weiterhin den Namen des ausgewählten Schülers.
Entwürfe, technische IDs, Änderungsjournale und Sicherungsinhalte gehören nicht
zum Gesprächsexport.

## Verlässliche Auswahl und Ausgabe

Datumsgrenzen gelten einschließlich Anfangs- und Endtag. Ein vertauschter oder
ungültiger Zeitraum lässt sich nicht zusammenstellen. Entfernt man das Bis-Datum,
wird der Zeitraum korrekt als **ohne Enddatum** bezeichnet.

Datumsänderungen leeren wie im Prototyp die Auswahl. Änderungen an Auswahl,
Beteiligtenoption oder relevanten Schülerdaten verwerfen die bisherige Vorschau.
Vor Zusammenstellung und Ausgabe werden die Daten erneut geladen. Eine dann
bemerkte Änderung stoppt den Export und fordert zum erneuten Zusammenstellen auf;
neue Inhalte werden nicht unbemerkt in bereits geprüften Text eingefügt.

Eine abgebrochene Dateiauswahl wird als Abbruch behandelt. Bei Speicher- oder
Zwischenablagefehlern bleiben Auswahl und Vorschau für einen weiteren Versuch
verfügbar. Während einer Ausgabe ist keine zweite Ausgabe möglich. Exportiert
wird der zuvor geprüfte Textstand.

Wie im Prototyp beginnen Auswahl und Vorschau beim nächsten Öffnen neu. Die
Gesprächsvorbereitung verändert weder gespeicherte Einträge noch deren Entwürfe.
Zur dauerhaften Aufbewahrung dient die TXT-Datei. Datenbank und Vollsicherungsformat
bleiben Version 5; keine Datenmigration ist für diesen Schritt erforderlich.

Nebenbei korrigiert: **Schüler → … → Entwürfe** öffnet eine begonnene Zielüberprüfung
oder Hausübungsrückmeldung wieder im passenden Nebenformular. Zuvor führte dieser
schülerspezifische Einstieg fälschlich zum allgemeinen Eintragseditor.

## Trennung und Prüfung

- `lib/domain/conversation_brief.dart`: reine Auswahl-/Berichtsprojektion und
  Datumsprüfung, unabhängig von Flutter und Dateidialogen.
- `lib/ui/conversation_brief.dart`: Referenzdialog und Vorschauzustand.
- `lib/application/brief_output.dart`: Textdatei-/Zwischenablage-Anbindung.

Neue Tests prüfen Fachinhalte, Datumsgrenzen, Namensoption, Erwähnungen ohne fremde
Einzelbewertung, Rückmeldungsdatum, Erinnerungen, unveränderte Ausgangsdaten,
Auswahländerungen, parallel geänderte Daten, leere Berichte, Abbrüche und Fehler.
Die Plattformschnittstellentests prüfen exakte UTF-8-Bytes, Dateinamen, MIME-Typ und
Zwischenablagetext mit Testimplementierungen. Sie ersetzen keine native Prüfung
des Windows-/Android-Dateidialogs. Es wurden keine Browsertests durchgeführt.

Renderings 33–36 zeigen Auswahl und Exportvorschau auf Desktop und Mobilgeräten.
Alle Testdaten sind synthetisch; die ausgelieferte Anwendung enthält keine
Beispieldaten. Tatsächliche Prüfergebnisse: `FLUTTER_STATUS.md`.
