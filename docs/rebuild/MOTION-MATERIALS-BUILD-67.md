# Übergänge und Materialkarten · 0.21.3+67

Alle oberen Reiter verwenden beim Tippen und Wischen denselben Übergang:
140 Millisekunden, kurze gerichtete Bewegung um 16 logische Pixel und Einblendung
mit schnell abklingender Kurve. Live und Kalender verwenden keine zusätzliche
volle Seitengleitbewegung mehr. Die Inhalte bleiben eingebunden, damit Suche,
Scrollpositionen und Eingaben erhalten bleiben. Die Systemvorgabe für reduzierte
Animationen wird berücksichtigt.

Materialkarten in der Listenansicht verwenden kleinere Vorschauen (48 × 64).
Kategorie und Schülerzuordnung stehen gemeinsam bei den Angaben. Auf breiten
Ansichten stehen Aktionen rechts daneben, auf Smartphones in derselben Zeile
wie die Verfügbarkeit. Die separate volle Aktionszeile entfällt. Alle Aktionen
bleiben sichtbar und behalten Berührungsflächen von 44 × 44. Die Rasteransicht
behält ihre große Bildvorschau; große Schrift kann mehrzeilige Angaben nutzen.

## Prüfung

- 36 Navigations- und Materialprüfungen bestanden, einschließlich Reihenfolge,
  Seitenränder, erhaltene Such-/Scrollzustände, Reglerbedienung, Mehrfachauswahl,
  Favoriten, Bereitlegen, Wiederherstellung und Materialzuordnung.
- Ein neuer Test vergleicht die Übergänge nach Tippen und Wischen in allen fünf
  Bereichen: gleiche Zwischenposition, passende Richtung und rascher Abschluss.
- 10 UI-Prüfungen bestanden, einschließlich Smartphone, großer Schrift, Tablet
  und Desktop. Statische Analyse ohne Befunde; Formatierung geprüft.
- Android- und Web-Release gebaut. Browserprüfung mit Touch-Ereignissen sowie
  Materialansichten bei 390 und 600 Pixel Breite. APK-Signatur, Kennung, Version,
  ZIP-Integrität und 16-KB-Ausrichtung geprüft.

Die vollständige Testsuite wurde zuletzt für Build 66 ausgeführt. Physische
Android-Abnahme bleibt offen. Datenmodell und Sicherungsformat bleiben
unverändert. Build 67 aktualisiert FLEX aus Build 62–66 mit gleicher Signatur.

[APK und Prüfprotokolle](../../releases/android/build-67/README.md) ·
[Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/).
