# Nachweise Build 72

Ausschließlich synthetische Schüler und Einträge in der Browserprüfung.

- `regression-tests.log`: 73 bestehende gezielte Prüfungen nach der Zuordnungsänderung.
- `verified-assignment-tests.log`: alle 15 neuen Zuordnungsprüfungen sowie weitere
  Entwurfs-/Übersichtsprüfungen; ein alter Textfeld-Selektor schlägt in diesem Lauf fehl.
  `draft-selector-regression.log` belegt den erfolgreichen gezielten Wiederholungslauf
  nach Eingrenzung auf das erste Aufgabenfeld.
- `navigation-tests.log`: 24 Prüfungen nach dem Umzug der Aufgaben.
- `returns-navigation-tests.log`: 13 erfolgreiche Prüfungen, zwei wegen veränderter
  Scrollpositionen zu korrigierende UI-Testselektoren.
  `returns-integration-tests.log` enthält danach alle fünf erfolgreichen Hub-Tests,
  einschließlich Rücklauf-Filter, Suche und Abschließen bei großer Schrift.
- Analyse und Release-Webbuild beziehen sich auf den abschließenden App-Code.
- Zuordnungs-Screenshots entstanden vor der letzten Rücklaufnavigation-Anpassung;
  die Zuordnungsformulare selbst blieben gleich. Die abschließenden Kalender-/
  Aufgaben-/Orga-Bilder und `browser-check.json` zeigen den abschließenden Webbuild.

Keine vollständige Testsuite und keine Prüfung auf echter Android-Hardware.
