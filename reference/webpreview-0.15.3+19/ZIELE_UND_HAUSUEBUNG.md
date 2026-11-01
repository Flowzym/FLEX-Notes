# Ziele und Hausübungsrückmeldungen – Version 0.6.0+6

Referenz bleibt die unveränderte `work/FLEX-Notizbuch/FLEX-Notizbuch.html`.
Für diesen Schritt wurden insbesondere `goals.js`, `goal-review.js`,
`goal-links.js`, `goals-refined.js`, `homework-tasks-model.js`,
`homework-task-comments.js`, `homework-simple.js`, `reliable-app.js` und die
späteren Dialoganpassungen im aktuellen HTML gelesen. Es wurden ausschließlich
synthetische Datensätze eingesetzt. Die Oberfläche bleibt eine native Flutter-UI.

## Ziele

- Sozial-/Arbeitsbeobachtung → **Zielbezug** einschalten → aktives Ziel desselben
  Schülers wählen. Die ausgewählte Zielbeschreibung bleibt als damaliger Wortlaut
  erhalten, auch nach Umbenennen, Abschließen oder Löschen des Ziels.
- Zielkarte → **Ziel überprüfen**: Kriterium, aufklappbare zugeordnete Beobachtungen
  und direkte Bearbeitung eines Belegs; „Was hat sich gezeigt?“ und Entscheidung.
- **Fortführen** verlangt einen nächsten Prüftermin und erlaubt einen nächsten
  Schritt. **Ziel erreicht** und **Beenden, ohne es als erreicht zu markieren**
  sind unterschiedliche Zustände. Ein beendetes Ziel wird nicht als erreicht bezeichnet.
- **Erreicht**, **Wieder öffnen** und Änderungen von **Stand** im Ziel-Editor
  erzeugen ebenfalls einen nachvollziehbaren Überprüfungseintrag.
- Zieltermin und nächster Prüftermin sind getrennt. Die bisherige Bedeutung alter
  Flutter-Zieldaten bleibt über einen kompatiblen Lesezugriff erhalten; eine neue
  Überprüfung überschreibt nicht mehr den ursprünglichen Zieltermin.
- **Überprüfungen · N** zeigt Entscheidungen, Notizen, nächste Schritte und Termine.
  **Zugeordnete Beobachtungen · N** zeigt die passenden eigenen Belege.

## Hausübung

- Jede Aufgabenzeile hat **Kommentar & Stand** mit den Originaloptionen
  **Vollständig**, **Teilweise** und **Nicht erledigt**, dazu optional einen Kommentar.
  Ein unverändert offener Stand bleibt offen. Der Haken setzt eine Aufgabe auf
  vollständig beziehungsweise wieder offen. Teilaufgaben bleiben unabhängig.
- **Notiz & Verlauf** enthält eine neue Notiz, **Abgabe & Zeitpunkt** mit
  **Nicht überprüft**, **Vorgelegt**, **Nicht vorgelegt**, **Abwesend**, Datum und Uhrzeit.
  Eine Notiz oder geänderte Abgabe verändert den Aufgabenstand nicht.
- Der fachliche Verlauf zeigt einzelne Rückmeldungen mit Datum, Aufgabe, Stand
  beziehungsweise Abgabe und Kommentar. Rückmeldungen lassen sich bearbeiten und
  nach Bestätigung löschen. Das Journal erhält auch diese Korrekturen.
- Rückmeldungen erscheinen mit ihrem eigenen Beobachtungsdatum im Schülerverlauf
  und unter **Zuletzt**; sie sind unabhängig vom ursprünglichen Aufgabedatum filterbar.
- Zustände werden chronologisch aus einem erhaltenen Ausgangsstand und den noch
  gültigen Rückmeldungen berechnet. Eine ältere Abgabenotiz überschreibt keine neuere.
  Ein später datierter Aufgabenstand wird beim schnellen Abhaken erkannt und geschützt.
  Löschen der jüngsten Rückmeldung stellt den vorherigen Stand wieder her.
- Umbenennen und Ergänzen von Aufgaben bewahrt bestehende IDs und Rückmeldungen.
  Nach Entfernen einer Aufgabe bleibt ihr früherer Text im Rückmeldungsverlauf erhalten.

## Entwürfe, Speicherung und Kompatibilität

Zielüberprüfung, Aufgabenkommentar, Abgabenotiz und Rückmeldungskorrektur sichern
angefangene Eingaben nach Schreibpause, beim Schließen/Escape und beim
Lebenszykluswechsel. Unter **… → Entwürfe** öffnet **Fortsetzen** wieder den
passenden Dialog. Bei Schreibfehlern bleibt der Dialog offen.

Der Entwurf hält die ursprüngliche Revision fest. Gleichzeitige Änderungen werden
nicht still überschrieben. Nach Sichtung der aktuellen Fassung lässt sich mit
**Mit aktueller Fassung fortsetzen** dieselbe Rückmeldung auf die neue Basis anwenden.
Dabei bleiben zwischenzeitliche Änderungen anderer Aufgaben erhalten. Erfolgreiches
Speichern entfernt nur den zugehörigen Entwurf, gemeinsam mit Eintrag und Journal
in einer SQLite-Transaktion. Gruppenrücknahmen erkennen auch diese Bearbeitungen.

Fachlogik liegt in `lib/domain/school_feedback.dart`, Dialoge in
`lib/ui/school_feedback_editor.dart`, Transaktionen im bestehenden Repository.
Datenbankversion 5 bleibt bestehen; die zusätzlichen Daten liegen im vorhandenen
fachlichen JSON-Payload. Alte Aufgabenstände/Kommentare werden beim ersten neuen
Feedback als Ausgangsstand übernommen. Alte Zielüberprüfungen bleiben lesbar.
Die eigene Vollsicherung umfasst neue Rückmeldungen und unfertige Dialoge.
HTML-Altdaten werden weiterhin nur unverändert vorgemerkt; ihre vollständige
Migration und Zusammenführung stehen aus.

## Nachweise und verbleibende Grenzen

Der aktuelle Prüfstand steht in `FLUTTER_STATUS.md`. Direkte Flutter-Renderings
25–32 zeigen Zielüberprüfung/Belege, Aufgabenkommentar, Notiz/Abgabe/Verlauf,
Zielbezug und Überprüfungsverlauf auf Desktop beziehungsweise Mobilgeräten.
Es wurde kein Browser geöffnet und kein pixelweiser HTML-Vergleich durchgeführt.

Der vollständige Nachbau aller App-Bereiche bleibt offen, unter anderem die
Gesprächsvorbereitung mit vollständigem Filter-/Dateiexportablauf, weitere
Darstellungsregler, Stammdatenentwürfe und die gleichwertige Löschverwaltung.
Windows-/Android-Builds und Geräteverhalten sind hier weiterhin nicht bestätigt.
Synchronisation, Scanner und native Benachrichtigungen folgen später.
