# Schüler-/Personenzuordnung, Aufgaben und integrierte Rückläufe · 0.24.0+72

Beim Anlegen von Notizen, Aufgaben und Terminen kann ein Schüler gewählt und/oder
ein anderer Name frei eingetragen werden. Ein gemeinsamer kompakter Zuordnungsbereich
öffnet die Schülerauswahl mit Suche sowie ein Feld für weitere Namen.
Abbrechen im Auswahldialog übernimmt keine Änderungen.

## Formulare und Sichtbarkeit

- Orga: Schülerzuordnung beim Anlegen und in unveröffentlichten Entwürfen;
  weitere Namen auch in bestehenden Einträgen. Der bisherige Schutz vor dem
  Umhängen bereits gespeicherter Orga-Einträge bleibt bestehen.
- Ziele, Sozial, Arbeit und HÜ: Der zugehörige Schüler bleibt fest vorausgewählt.
  Weitere Schüler und frei eingegebene Namen sind jetzt in allen vier Formularen
  über denselben Bereich erreichbar. HÜ-Empfänger für getrennte Schülerkopien
  bleiben eine eigene vorhandene Funktion.
- Unterricht, Material, Materialpakete, Planung und Rückläufe: gemeinsame Auswahl
  im Hauptformular. Bestehende Rücklaufstände und datierte Materialzuordnungen
  ausgewählter Schüler bleiben erhalten. Einzelne Stundenplan-Ausnahmen behalten
  ihre bereits eingeschränkten Bearbeitungsfelder.
- Gruppenerfassung: freie Namen für Sozial, Arbeit, HÜ und Orga.
- Die Aufgaben-/Notizlisten zeigen auch Einträge aktiver Schüler; die Zuordnung
  bleibt zusätzlich in der jeweiligen Schüleransicht sichtbar. Suche, Kalender,
  lesbarer Verlauf und Gesprächsexport berücksichtigen die Namen. Der Export
  ohne Namen lässt auch die zusätzlichen Namen weg.

## Navigation

Aufgaben wurden vom Kalender nach Organisation verschoben. Die Reihenfolge dort
lautet Orga, Aufgaben, Notizen; alle Reiter sind per Wischen erreichbar.
Rückläufe sind in Aufgaben integriert und haben keinen eigenen Reiter mehr.
Die gemeinsame Liste sortiert offene Aufgaben und Rückläufe vor erledigten und
danach nach Fälligkeit. Offen/Erledigt gilt für beide Arten; ein unabhängiger
Artenfilter erlaubt Alle Arten, Aufgaben oder Rückläufe. Auch die Orga-Gesamtansicht
zeigt Rückläufe und bietet den Artenfilter einschließlich Notizen und Terminen.
Suche berücksichtigt Titel, Notizen und Beteiligte. Der vorhandene Rücklaufdialog
mit Teilnehmerständen, Frist, Zahlung, Materialien und Export bleibt erreichbar.
Ein neuer UI-Test prüft Filtern, Suche, Öffnen und Abschließen eines Rücklaufs bei
1,8-facher Schrift; gelöschte Rückläufe werden aus den normalen Listen ausgeschlossen.
Im Kalender entfällt die obere Seitennavigationspille samt Abstand. Tag/Woche/Monat,
Zeitraum-Wischen und das kontextabhängige Plus bleiben bestehen. Kalenderzustand
und Aufgabenfilter bleiben bei Bereichswechseln erhalten. Einträge werden durch
diesen Umzug weder kopiert noch verändert.

## Daten und Grenzen

Neue Orga-Namen werden im optionalen Feld `otherParticipants` und den bestehenden
Orga-Metadaten gespeichert. Das SQL-Schema bleibt unverändert. Schülerdatensätze
verwenden ihre vorhandenen Teilnehmerfelder; Klassendokumente erlauben dieselben
optionalen Namen sowie validierte Schülerreferenzen. Alte Einträge ohne dieses
Feld laden weiterhin. Sicherungen mit den neuen Klassenzuordnungen sollten mit
Build 72 oder neuer geöffnet werden. Es wird keine Kontaktverwaltung angelegt.

Die primäre Schülerzuordnung gespeicherter Einträge ist weiterhin fest; die
Schülerauswahl neuer Orga-Einträge ist ausdrücklich veränderbar. Schulbezogene
Beobachtungen und HÜ benötigen weiterhin einen Schüler als Bezug und erlauben
weitere freie Namen. Die Zuordnung ersetzt keine Versand- oder Freigabefunktion.

## Prüfung

15 neue Domänen-/Widgetprüfungen decken Auswahl, freie Namen, Abbrechen,
Typwechsel, Entwurfsautosave, Speichern/erneutes Öffnen, Gruppen, alte Daten,
Sicherungswiederherstellung und Zusammenführen ab. Darunter ist ein Formular bei
320 Pixel Breite und 1,8-facher Schrift sowie der Erhalt langer vorhandener Namen.
Gezielte vorhandene Prüfungen betreffen Entwürfe, Konflikte, Sicherungen,
Klassenformulare, Aufgabenübersicht, Navigation und Kalender. Alte Testselektoren,
die schlicht das erste Textfeld oder den einzigen Erledigen-Button annahmen,
wurden auf Aufgabe bzw. Eintrag eingegrenzt und erneut ausgeführt. Der Artenfilter
ist als eigenes Bedienelement für Screenreader ausgezeichnet.

Statische Analyse ohne Befunde, Format- und Diff-Prüfung sauber; Release-Webbuild
erfolgreich. Browser bei 390 und 320 Pixeln: Zuordnung nach Neuladen, Aufgaben unter
Organisation, Rückläufe in beiden Listen filterbar, Kalender ohne Seitennavigation.
Screenshots visuell kontrolliert, keine JavaScript-Seitenfehler. Nachweise mit synthetischen Daten
unter [evidence/build-72](evidence/build-72/). Keine vollständige Testsuite und
keine erneute Hardwareabnahme in diesem Schritt. Die letzte Android-APK bleibt
Build 67. Die private Webadresse und ihr Publikum bleiben unverändert.

[Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/).
