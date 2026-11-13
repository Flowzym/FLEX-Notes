# Kalender: klare Bedienung und frei wählbares Wochenende · 0.23.2+71

Die Wochenansicht erzwang bisher Samstag/Sonntag und deaktivierte den Schalter,
sobald Wochenenddaten vorhanden waren oder ein Wochenendtag ausgewählt war.
Nun dient diese Automatik nur als Anfangswert. Nach der ersten Betätigung gilt
die ausdrückliche Auswahl, auch nach Datenaktualisierung und Wochenwechsel.
Der Schalter bleibt bedienbar. Diese Ansichtsauswahl gilt für die laufende
App-Sitzung; sie ist keine neue dauerhaft gespeicherte Einstellung.

Bei ausgeblendeten Wochenendtagen zeigt ein kleiner Link die Anzahl dortiger
Einträge und blendet Sa/So wieder ein. Fälligkeiten der gesamten Woche bleiben
über die Zusammenfassung erreichbar. Es werden keine Einträge verändert.

## Kalenderkopf

- Unterlagen, Stundenplan und Verwalten sind direkt beschriftete Werkzeuge.
- Tag/Woche/Monat bleibt oberhalb des Zeitraums; Heute steht direkt daneben.
- Unterricht und Sa/So sind beschriftete Anzeigeschalter mit sichtbarem Häkchen.
  Filter steht in derselben Optionszeile.
- Fälligkeiten erscheinen als schmale, bei Bedarf umbrechende Zeile ohne große
  hinterlegte Karte. Kategorien bleiben antippbar.
- Das doppelte Anlegen-Symbol entfällt. Alle Anlegefunktionen sind weiterhin im
  globalen Plus-Menü vorhanden. Die Monatsauswahl meldet ihr Datum jetzt sofort
  an dieses Menü, auch ohne vorher die Tagesansicht zu öffnen.
- Bei normaler Schrift passen die drei Werkzeuge auch bei 320 Pixel Breite in
  eine Zeile. Große Schrift darf natürlich umbrechen; keine Funktion wird in
  ein zusätzliches Menü verschoben.

## Validierung

Der gezielte Lauf umfasst 41 Prüfungen aus Kalender, Navigation, Quick-Add und
Stundenplan. Drei neue Regressionstests prüfen das Aus-/Einblenden trotz Termin,
HÜ-Fälligkeit oder ausgewähltem Sonntag, einschließlich Neuladen, Wochenwechsel
und erneutem Anzeigen über den Hinweis. Die Quick-Add-Prüfung wählt ausdrücklich
einen anderen Tag im Monatsraster und kontrolliert das Datum im Terminformular.

Die Layoutprüfungen decken 320/390/1100 Pixel und bis zu doppelte Schrift ab.
Nach der letzten Anpassung der Schriftvererbung und Symbolabstände bestanden
die neun Integrationsprüfungen und drei Kalender-Layoutprüfungen erneut.
Analyse, Formatierung und Diff-Prüfung ohne Befunde. Die vollständige Testsuite
und echte Android-Hardware wurden für diese Änderung nicht erneut geprüft.

Release-Webbuild und Browserprüfung mit synthetischen Daten; Nachweise unter
[evidence/build-71](evidence/build-71/). Datenmodell, Sicherungsformat und
Webadresse bleiben erhalten. Keine neue APK; letzte installierbare Fassung 67.

[Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/).
