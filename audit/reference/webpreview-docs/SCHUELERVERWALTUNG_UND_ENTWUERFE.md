# Schülerverwaltung und Entwürfe – Version 0.8.0+8

Referenz sind die aktuelle HTML-Datei, `pupil-colors.js` sowie `protectEditor`,
`commitPupil`, `showDrafts` und die späteren Formularfassungen in
`review-interface.js`. Die Referenzdateien bleiben unverändert.

## Was sich geändert hat

| Bisherige Flutter-Fassung | Aktuelle Umsetzung |
| --- | --- |
| Sechs abweichende Standardfarben | Zehn Originalfarben; erster noch unbenutzter Farbwert, danach dieselbe HSL-Folge wie im Prototyp |
| Keine eigene Schülerfarbe | Eigene Farbe über RGB-Regler und Hexwert; Vorschau und freie Wahl |
| Archivieren speichert sofort und getrennt vom eingegebenen Namen | Name, Farbe und Archiv-Haken gemeinsam mit Speichern übernehmen |
| Unfertige Schülerdaten gehen beim Schließen verloren | Dauerhafter Entwurf bei Schreibpause (400 ms), Schließen, Escape/Zurück und Lebenszykluswechsel |
| Schülerentwürfe fehlen in den Listen | Fortsetzen/Verwerfen unter … → Entwürfe, im Schüler-Menü und als Hinweis beim erneuten Öffnen |
| Nur allgemeine Fehlermeldung bei veralteten Schülerdaten | Aktuell/Entwurf je Feld; explizite Wahl bei widersprüchlichen Änderungen, anschließendes Speichern als neue Fassung |
| Schülerhistorie zeigt lediglich den Namen | Änderungsverlauf mit Name, Farbe und Archivstatus |

## Bedienung

- **Schüler → +** öffnet „Schüler hinzufügen“. Der Name bleibt wie im HTML auf
  80 Zeichen begrenzt. Gleiche Namen werden auch dann erkannt, wenn der vorhandene
  Schüler archiviert ist; Groß-/Kleinschreibung und äußere Leerzeichen sind dabei egal.
- **Schüler → … → Schüler bearbeiten** öffnet „Schüler verwalten“.
  „Schüler archivieren“ markiert zunächst nur die Eingabe. Erst **Speichern**
  übernimmt alle Änderungen. Zum Zurückholen aus dem Archiv den Haken entfernen.
- **Eigene Farbe wählen** zeigt Farbwert und RGB-Regler. Der native Flutter-Wähler
  ersetzt den vom Browser/Betriebssystem abhängigen HTML-Farbpicker; dessen
  konkretes Aussehen wird nicht identisch reproduziert.
- **Schließen/Escape/Zurück** sichert geänderte Formulare als Entwurf. Ein lediglich
  geöffnetes und unverändertes Formular erzeugt keinen leeren Entwurf.
- **… → Entwürfe → Fortsetzen** öffnet genau diesen gespeicherten Entwurf.
  **Verwerfen** entfernt ihn nach Rückfrage, ohne gespeicherte Schüler zu verändern.
  Ein angefangener neuer Schüler erscheint bis zum endgültigen Speichern nicht
  in der Schülerübersicht.
- Bei zwischenzeitlich geänderten Schülerdaten zeigt das Formular die Fassungen.
  Änderungen an verschiedenen Feldern bleiben erhalten. Für widersprüchliche
  Änderungen muss pro Feld gewählt werden. **Mit aktueller Fassung fortsetzen**
  aktualisiert nur den Entwurf; **Speichern** übernimmt ihn anschließend.
- Falls derselbe Entwurf inzwischen anderswo geändert oder verworfen wurde,
  bleiben die Eingaben im Formular. **Als eigenen Entwurf sichern** legt eine
  unabhängige Kopie an, ohne den anderen Entwurf zu überschreiben.

## Datenhaltung und Grenzen

SQLite und Flutter-Vollsicherungen verwenden jetzt Version 6. Die Migration
5→6 ergänzt ausschließlich `pupil_drafts`; Versionen 1–5 bleiben lesbar. Ein
Schülerentwurf speichert Name, Farbe, auch einen unvollständigen Farbwert,
Archivstatus, ursprüngliche Schülerfassung und eigene Versionsnummer.

Speichern prüft sowohl die Schülerfassung als auch den exakten Entwurf. Schüler,
Änderungsjournal, Operation und Outbox werden in einer Transaktion geschrieben;
erst deren Erfolg entfernt den zugehörigen Entwurf. Andere Entwürfe bleiben
bestehen. Fehler und Konflikte schließen das Formular nicht. Frühere Namen und
Farben bleiben im Änderungsjournal erhalten.

Getestet werden synthetische Daten, einschließlich echtem SQLite-Dateineustart,
Migration einer Version-5-Datei und -Sicherung, unvollständiger Eingaben,
Schreibfehlern und kollidierenden Änderungen. Konkrete Testergebnisse und
Build-/Prozessnachweise stehen in `FLUTTER_STATUS.md`.

Unmittelbares Beenden des Betriebssystemprozesses vor dem Abschluss eines
Schreibvorgangs kann weiterhin die letzten Eingaben verlieren. Der Lebenszyklus
wurde im Widgettest simuliert; Windows-/Android-Geräteunterbrechungen und
Browserpersistenz wurden nicht getestet. Vollständige HTML-Datenmigration,
Darstellungsregler und gleichwertige Löschverwaltung bleiben separate Schritte.
