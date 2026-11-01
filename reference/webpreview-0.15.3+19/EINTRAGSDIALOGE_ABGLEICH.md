# Eintragsdialoge: Abgleich mit dem aktuellen Prototyp

Stand: 31.10.2026, Flutter 0.5.0+5. Referenz ist die unveränderte Datei
`work/FLEX-Notizbuch/FLEX-Notizbuch.html` aus „FLEX-Notizbuch (37).html“.
Verglichen wurden die tatsächlichen HTML-/CSS-/JavaScript-Funktionen einschließlich
späterer Überschreibungen. Die frühen Formularfunktionen allein bilden den letzten
Stand nicht ab. Es wurden keine Browser verwendet.

## Festgestellte und korrigierte Unterschiede

| Dialog / Detail | Bisheriges Flutter-Verhalten | Umsetzung dieses Stands |
| --- | --- | --- |
| Sozial-/Arbeitsbeobachtung | Aktive Auswahlen außerhalb des Eingabefelds | Aktivierte Tags stehen innerhalb desselben Rahmens oberhalb des Freitexts; die zugehörige Vorschlagspille verschwindet und kehrt nach Entfernen zurück. |
| Bewertung | „Positiv / Zu beachten“, abweichende Auswahlgestaltung | „Positiv / Negativ“, flache Pillen, positive und negative Tags mit eigenen Farben und +/−. Beide Bewertungen können im selben Eintrag stehen. |
| Freitext | Keine durchgängige gemeinsame Tag-Eingabe | Auswahl, Entfernen und Wechsel des Situationszeitpunkts ändern den freien Text nicht. Entfernen setzt den Fokus zurück; Backspace im leeren Feld fokussiert erst den letzten Tag. |
| Sozial: Situation | Auswahlen außerhalb des Textfelds | „Vor / Während / Nach dem Unterricht / Pause“ oberhalb; genau ein aktiver Zeitpunkt als Tag im Feld „Was ist passiert?“. Ein Wechsel ersetzt nur diesen Tag. |
| Arbeit: Auftrag | Einfaches Kontextfeld, andere Reihenfolge | „Auftrag“ vor den Beobachtungsoptionen; „Zuletzt verwendet“ aus gespeicherten Arbeitsbeobachtungen; gewählte Vorschläge als entfernbare Tags plus freier Zusatz. |
| Beobachtungsauswahl | Feste Liste ohne Pflege | Favoriten mit Stern, bevorzugte Reihenfolge, zunächst sechs Optionen, Alle/Weniger und „Auswahl bearbeiten“ mit Hinzufügen, Umbenennen, Umordnen und Entfernen. Eigene Katalogentwürfe schützen ungespeicherte Änderungen. |
| Weitere Angaben | Zusätzliche Aufklappbereiche und Checkboxen | Sichtbare Abschnittsüberschrift, kompakte Schalter; Reaktion/Unterstützung zeigt ihr Eingabefeld. Quelle und gemeinsamer Kontext bleiben eine eigene aufklappbare Ergänzung. |
| Beteiligte | Nur über Gruppenweg vollständig möglich | Im Einzelbeobachtungsformular „Beteiligt“, unmittelbar sichtbare Schülerauswahl und „Weitere Namen“. Gemeinsamer Kontext wird getrennt gespeichert; Erwähnung erzeugt keine fremde Einzelbewertung. |
| Datum / Nachbereitung | Im scrollenden Formular bzw. eingeklappt | Feste Leiste oberhalb der Speicheraktionen: Beobachtet/Aufgegeben/Vereinbart am, optionale Uhrzeit, „Später ergänzen“. Sie bleibt beim Scrollen zugänglich. |
| Tastatur / kleine Fenster | Nicht mit fester Leiste abgestimmt | Kompakter Kopf und Fuß bei geringer Höhe; kein vorübergehender Überlauf beim Ein-/Ausblenden der Tastatur im geprüften 320-Pixel-Ablauf. |
| Ziele | Kleiner Dialog, zusätzliche Überschrift, keine Terminangebote | Breiter Detaildialog, auf schmalen Ansichten volle verfügbare Fläche; Terminangebote Bis Freitag / Eine Woche / Zwei Wochen / Ein Monat; Schülerperspektive beim Bearbeiten. |
| Hausübung: Aufgabenzeilen | Abweichende Zeilenaktionen und Entfernen der Teilaufgaben mit dem Elternteil | Enter/neue Zeile mit Fokus, Teilaufgabe und Entfernen je Zeile. Entfernen einer Hauptaufgabe macht ihre Teilaufgaben zu Hauptaufgaben. Leere Zeilen bleiben im Entwurf, werden beim Speichern entfernt. |
| Hausübung: Empfänger | Nur das geöffnete Kind | „Weitere Angaben / Für welche Schüler?“ direkt beim Aufgeben, auch ausschließlich andere Kinder wählbar. Gemeinsame Transaktion und getrennte Aufgaben-IDs/Zustände je Kind. |
| Hausübung: Felder | Fach und Termin immer untereinander | Nebeneinander bei ausreichender Breite, untereinander auf schmalen Ansichten. Breiter Detaildialog wie beim Ziel. |
| Orga | Checkboxen und abweichende Metadatenanordnung | Kompakte Schalter, feste Datums-/Nachbereitungsleiste, eigene Beobachtungsuhrzeit. Termin und Erinnerung bleiben unabhängig. Listen behalten echte Checklistenfelder. |
| Gruppen | Abweichende Auftrags-/Hausübungsfelder und Datumsanordnung | Gemeinsame Tag-Eingaben für Auftrag/Situationszeitpunkt, gleiche Aufgabenzeilen und feste Metadatenleiste. Individuelle Bewertungen bleiben je Kind, wie in der späten Gruppenfassung des Prototyps. |

## Maßgebliche Referenzstellen

Alle Pfade relativ zu `work/FLEX-Notizbuch/scratch/`:

- `field-tags.js:4–17`, `observation-tags.js:1–5`, `pill-selection.js:2`:
  getrennte Tag-/Freitextwerte, Eingabefeldrahmen, Entfernen und verborgene aktive Vorschläge.
- `social-narrative.js`, `entry-experience.js`, `modal-interaction.js:3–8`:
  Feldreihenfolge, Zusatzangaben und feste Datums-/Nachbereitungsleiste.
- `entry-switches.js`, `entry-switches.css`, `participants.js:10`:
  Schalter sowie Beteiligte mit Schülerauswahl und weiteren Namen.
- `entry-refinement.js:13–20`, `homework-simple.js`, `goals-refined.js`:
  sichtbare Zusatzangaben, Terminangebote, Hausübungszeilen und Detailformulare.
- `review-interface.js`, `review-source.js`, `review-detail.js`:
  später ergänzte Einzelbewertungen, Quellen und gemeinsame Situationen.
- `design-system.css`, `compact-modals.css`, `field-tags.css`,
  `observation-tags.css`, `modal-interaction.css`: aktuelle Darstellung.

Die Reihenfolge der eingebetteten Fassungen in der HTML-Datei ist berücksichtigt.
Beispielsweise bleiben die spät ergänzten individuellen Gruppenbewertungen bei
jedem Kind; sie werden nicht in das gemeinsame Kontextfeld verschoben.

## Daten und Prüfung

Die Flutter-Datenbank ist Version 5. Vorhandene Versionen 1–4 und Vollsicherungen
1–4 bleiben lesbar. Die neue optionale Uhrzeit ist von Erfassungszeitpunkt,
Aufgabentermin und Erinnerungszeit getrennt. Aufgaben-Tags werden zusätzlich zum
lesbaren Kontext als `tagFields.task` gespeichert. Alte Texte mit „ · “ werden
nicht nachträglich in vermeintliche Tags zerlegt. Katalogänderungen schreiben
bereits gespeicherte Beobachtungstexte nicht um.

Die neuen Tests prüfen Auswahl/Entfernen/Fokus, gemischte Bewertungen, Entwurfsfortsetzung,
Favoriten/Kataloge, Aufgabenzeilen/Empfänger, atomare Speicherung und Wiederholung,
Beteiligtenverweise, echte SQLite-Migration 3 → 4 sowie Sicherungswiederherstellung.
Bilddateien 12–18 unter `flutter_app/build/review/` zeigen die überarbeiteten
Dialoge mit synthetischen Daten. Aktuelle Prüfergebnisse: `FLUTTER_STATUS.md`.

## Verbleibende Abweichungen

Dies ist ein Quellcode- und Ablaufabgleich mit lokaler Flutter-Bildkontrolle,
kein gerenderter HTML-Pixelvergleich. Insbesondere bleiben abweichende Schriftmetriken
(Roboto/Liberation Serif statt systemabhängiger Segoe UI/Georgia), native
Datums-/Zeitinteraktionen und Details der Auswahlkatalogverwaltung. Der Bereichsverlauf, die direkte Kontext-/
Beobachtungsbearbeitung und Gruppenrücknahme sind jetzt ergänzt; siehe
`VERLAUF_KONTEXTE_UND_RUECKGAENGIG.md`. Der Sozial-Hinweis lautet nun
„optional bei Auswahl“.

Weitere fachliche Ergänzungen aus dem Gesamtprototyp bleiben offen: Zielbelege,
alle Zielprüfungsoptionen, vollständiger Hausübungs-Rückmeldungsverlauf und
Gesprächsvorbereitung. Beteiligte mit verknüpften Einträgen bleiben im Kontext
fest zugeordnet; zusätzliche Beteiligte können dort bearbeitet werden.

Die vollständige HTML-Datenmigration, native Betriebssystemtests und Browserpersistenz
sind nicht Bestandteil dieses Prüfnachweises. Die weiteren Grenzen stehen in
`UI_ABGLEICH.md`; die Originaldateien bleiben erhalten.
