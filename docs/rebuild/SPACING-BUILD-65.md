# Kompaktere Eintragungsseiten · 0.21.1+65

Die gemeinsame Seitengestaltung reduziert den Abstand zwischen dem kleinen
App-Titel FLEX. und dem Schülernamen sowie zwischen Seitentitel und oberer
Navigation. Die Anpassung gilt gleichermaßen für Sozialverhalten,
Arbeitsverhalten, Ziele, Hausübungen und Orga.

Beim Arbeitsverhalten sinkt der zusätzliche Abstand nach den Auftragsquellen
vor „Beobachtung“ von 24 auf 8 logische Pixel. Die Berührungsflächen,
Felder und verfügbaren Aktionen behalten ihre Größe.

## Prüfung

- 21 vorhandene UI-, Tonwahl-/Fokus- und Editortests bestanden. Die UI-Matrix
  deckt Smartphone, große Schrift bei 320 Pixel Breite, Tablet und Desktop ab.
- Statische Analyse ohne Befunde; Formatierung geprüft.
- Android- und Web-Release gebaut. Smartphone-Browser bei 390 × 844 mit
  synthetischen Daten: Arbeits- und Sozialverhalten geöffnet, Darstellung
  kontrolliert, keine JavaScript-Seitenfehler.
- APK-Kennung, Version, Signatur, ZIP-Integrität, Architekturen und
  16-KB-Ausrichtung geprüft. Physische Android-Abnahme steht weiterhin aus.

Für die reine Abstandsanpassung wurde die vollständige Testsuite aus Build 64
nicht erneut ausgeführt. Datenmodell und Speicherverhalten sind unverändert.
Build 65 aktualisiert die neue FLEX aus Build 62–64 mit gleicher Kennung und
Signatur; ihr lokaler Speicher bleibt erhalten.

[APK und Prüfprotokolle](../../releases/android/build-65/README.md) ·
[Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/) ·
[Materialzuordnungen aus Build 64](PUPIL-MATERIALS-BUILD-64.md).
