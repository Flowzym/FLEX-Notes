# Direkte Flutter-Renderings

121 PNGs mit synthetischen Daten; kein Browser. 111 Bilder gehören zur neuen Matrix mit 37 Zuständen bei 1440 × 1000 sowie 320 × 700, letztere zusätzlich mit Schriftfaktor 2 und 280 px Tastatur-Inset. Zehn weitere Bilder stammen aus den vorhandenen Flutter-Renderingtests.

- `manifest.jsonl`: eindeutige Matrixdateien mit Parametern, Bildhash und Hash des geprüften Quellmanifests.
- `manifest-all.json` / `SHA256SUMS`: alle 121 PNGs.
- [Prüfnachweis](../PRUEFNACHWEIS.md): Bedienungs-/Persistenztests, Sichtprüfungsumfang und Grenzen.
- [Visuelle Stichprobe](../evidence/visual-review.json): tatsächlich betrachtete Ansichten, keine pauschale Behauptung über alle Bilder.

Beispiele: [Sozialfehler schmal](social-error-narrow.png), [große Schrift/Tastatur](social-error-large-keyboard.png), [HÜ bearbeiten breit](homework-edit-wide.png), [Kalender schmal](calendar-narrow.png), [Entwürfe](menu-drafts-filled-narrow.png), [Konflikt](conflicts-filled-narrow.png).

Die schwarze/abgedunkelte Fläche unter dem Dialog in den Tastaturvarianten ist der freigehaltene Betriebssystembereich, keine gerenderte Tastatur. Lange Dialoge sind scrollbar; Bilder zeigen jeweils eine Position. Originaltreue ist nicht freigegeben.
