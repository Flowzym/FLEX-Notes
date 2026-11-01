# Sozialverhalten, Arbeitsverhalten und Kalender

Stand: **0.16.0-rebuild.4+24**, 01.11.2026.

Grundlage sind die in diesem Chat bestätigten Screenshots für beide
Beobachtungsdialoge sowie die nachgereichten Kalenderansichten mit und ohne
Uhrzeit. Die vorhandene PNG-Textur wird auch innerhalb dieser Dialoge verwendet.

## Umsetzung

- Grüner Kopf mit Zurück, Schülername, Verlauf und Schließen; Bereichstitel
  in Serifenschrift, farbige Schülerkante und gerundeter Modalrahmen.
- Texturierter Inhalt, unscharfer Hintergrund hinter dem Modal und feste
  Fußleiste mit Datum, unabhängigem Schalter „Später ergänzen“ und zwei Aktionen.
- Positiv/Negativ als breite Auswahl; negative Auswahl in Pfirsichfarbe.
- Beobachtungen entsprechend den gelieferten Sozial-positiv-/Arbeit-negativ-
  Beispielen. Auswahl bleibt an Ort und Stelle sichtbar; gewählte Texte bleiben
  auch bei nachträglichen Katalogänderungen im Eintrag und Entwurf erhalten.
- Sterne speichern Favoriten je Bereich und Wertung. Der Stift öffnet eine
  bearbeitbare Liste (eine Beobachtung pro Zeile). Einstellungen liegen in der
  bestehenden preferences-Tabelle und sind Teil der Vollsicherung.
- „Beteiligt“, „Zielbezug“, „Reaktion / Unterstützung“ und „Kontext / Quelle“
  sind unabhängig aufklappbar. Verbergen löscht keine Eingaben. Beteiligte
  bleiben Tags. Beim Fortsetzen werden befüllte Bereiche wieder geöffnet.
- Auftrag und Beobachtung mit Platzhaltern; Zeitpunkt-Tags bei Sozialverhalten.
  Neue Einträge haben keinen vorgewählten Zeitpunkt; bestehende Werte bleiben
  erhalten. Der leere Zeitpunkt ist nun als optionale Angabe gültig.
- „Speichern & weiter“ speichert über den vorhandenen Revisionsweg, wechselt
  zum nächsten aktiven Schüler und setzt dessen vorhandenen neuen Entwurf fort.
  Sonst öffnet es einen leeren Eintrag mit gleichem Datum/Uhrzeit. Inhalte
  werden nicht auf den nächsten Schüler kopiert. Fehler verhindern den Wechsel.
  Nach dem letzten Schüler wird gespeichert und der Dialog geschlossen.
- Verlauf zeigt die gespeicherten Beobachtungen des Schülers im selben Bereich.
- Kalender mit Montag als Wochenbeginn, Monats-/Jahreswahl, Monatsnavigation,
  „Heute“, optionaler Uhrzeit mit Stunden-/Minutenlisten und Entfernen-Button.
  Datum und Uhrzeit werden erst mit „Übernehmen“ angewendet; 00:00 bleibt von
  einer fehlenden Uhrzeit unterscheidbar. Erforderliche Uhrzeiten bleiben offen.

## Prüfungen

- Flutter-Analyse ohne Befunde.
- 60 Tests bestanden, darunter vier neue Fälle: sicherer Schülerwechsel mit
  Speicherfehler und vorhandenem Folgeentwurf; Referenzdialoge, Favoriten,
  unabhängige Zusatzfelder und optionale Zeit; Kalender mit Schaltjahr und
  Mitternacht bei 320 px; Katalog/Favoriten mit konkurrierenden Änderungen,
  Sicherungs-Rundlauf und atomarer Ablehnung beschädigter Sicherungen.
- Bestehende Prüfungen aller fünf Bereiche bei Desktopgröße und 320 px mit
  1,35-facher Schrift und eingeblendeter Tastatur bestehen weiterhin.
- Direkte Flutter-Renderings mit Originalschriften, synthetischen Daten und
  Originaltextur unter `renderings/reference-*`. Kein Browserlauf.
- Webbuild erfolgreich (inklusive Wasm-Vorprüfung); fünf ausgelieferte
  Ressourcen mit HTTP 200, bytegleichen Inhalten und COOP/COEP geprüft.
  Build- und Auslieferungsprotokolle unter `evidence/dialog-*`.

## Grenzen

Die Angleichung orientiert sich an den Screenshots; eine vollständige
Pixelgleichheit ist nicht behauptet. Die Katalogbearbeitung ist eine Zeilenliste,
weil dazu kein geöffneter Referenzdialog vorliegt. Die noch offenen Funktionen
anderer Bereiche aus STATUS.md bleiben bestehen. Keine native Windows-/Android-
Ausführung und keine Prüfung der Browserpersistenz.
