# Build 78 · Prüfnachweise

- 615 Flutter-Tests: `flutter-tests.log` (vollständiger Lauf am festen Quellstand).
- Statische Analyse und Dart-Formatprüfung: ohne Befunde.
- 11 SQLite-Schematests, 3 Serverprüfungen, 2 native JVM-Tests bestanden.
- Signierte ARM64/ARMv7-APKs, Release-Webbuild und Browserprüfung erfolgreich.
- Vergleichbare synthetische 100-MB-Rundläufe für v2 und v3: JSON-Messwerte.
- Browserbilder verwenden ausschließlich synthetische Bestandsdaten.
- Kein physischer Android-Lauf, kein echter Microsoft-Login.

Ein früherer paralleler Test-/Buildlauf überschritt beim absichtlich teuren PIN-Test
30 Sekunden. Weitere Zwischenläufe verwendeten während der Änderungen noch ältere
kompilierte Dateinamenlogik. Der abschließende vollständige Lauf ist fehlerfrei;
Tests mit mehreren vollwertigen KDF-Ableitungen erhalten zwei Minuten Zeitlimit.
Die Produktions-KDF-Stärke wurde nicht reduziert.

GitHub-CI Build 77: [Run 43627349625](https://github.com/Flowzym/FLEX-Notes/actions/runs/43627349625),
alle vier Jobs erfolgreich. Der neue Remote-Lauf ist separat zu prüfen.
