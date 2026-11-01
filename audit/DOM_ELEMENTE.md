# HTML-Elemente: vollständige Aufnahme der erfassten Zustände

Erzeugt aus `evidence/dom-inventory.json`. Node/jsdom source inspection; CSS removed; synthetic data; NOT rendered/browser/Flutter evidence.

Die Reihenfolge ist DOM-Reihenfolge nach den letzten JavaScript-Erweiterungen. CSS-Grid/Flex kann die optische Reihenfolge ändern. „Verborgen“ berücksichtigt HTML-Attribute, die Klasse hidden und ausdrücklich im Inspektor aufgeführte CSS-Regeln; dies ist keine vollständige CSS-Kaskade. Bedingt nicht erzeugte Inhalte werden in anderen Zuständen bzw. im manuellen [Dialogverzeichnis](DIALOGVERZEICHNIS.md) erfasst. Synthetische Namen und Werte sind keine Original-Nutzerdaten.

21 dauerhaft erzeugte benannte Dialoge, ein dynamischer Passwortdialog, 65 aufgenommene Quellenzustände.

## Originalkataloge

### behavior

```json
{
  "Sozialverhalten": {
    "positive": [
      "Hilft anderen",
      "Nimmt Hilfe an",
      "Hält Gesprächsregeln ein",
      "Geht respektvoll mit anderen um",
      "Klärt einen Konflikt im Gespräch",
      "Hält gemeinsame Absprachen ein"
    ],
    "negative": [
      "Unterbricht andere wiederholt",
      "Spricht andere abwertend an",
      "Hält gemeinsame Absprachen nicht ein",
      "Stört die Zusammenarbeit"
    ]
  },
  "Arbeitsverhalten": {
    "positive": [
      "Beginnt selbstständig",
      "Arbeitet konzentriert",
      "Bleibt bei Schwierigkeiten dran",
      "Fragt gezielt nach Hilfe",
      "Schließt die Aufgabe ab",
      "Arbeitet sorgfältig"
    ],
    "negative": [
      "Beginnt erst nach mehreren Aufforderungen",
      "Beschäftigt sich wiederholt mit anderem",
      "Unterbricht die Arbeit vorzeitig",
      "Bearbeitet die vereinbarte Aufgabe nicht",
      "Lässt vereinbarte Arbeitsschritte aus"
    ]
  }
}
```

### source

```json
[
  [
    "own",
    "Selbst beobachtet"
  ],
  [
    "reported",
    "Berichtet"
  ],
  [
    "interpretation",
    "Eigene Einordnung"
  ]
]
```

### delivery

```json
{
  "unknown": "Nicht überprüft",
  "submitted": "Vorgelegt",
  "missing": "Nicht vorgelegt",
  "absent": "Abwesend"
}
```

### status

```json
{
  "offen": "Offen",
  "erledigt": "Erledigt",
  "teilweise": "Teilweise erledigt",
  "nicht": "Nicht erledigt",
  "notchecked": "Nicht überprüft",
  "absent": "Wegen Abwesenheit offen"
}
```

### reminders

```json
[
  "Eltern kontaktieren",
  "Unterschrift einholen",
  "Gespräch führen",
  "Material nachfordern",
  "Hausübung nachfragen"
]
```

### pupilColors

```json
[
  "#53747e",
  "#756582",
  "#49765a",
  "#b87943",
  "#ac5d72",
  "#487f85",
  "#8a7845",
  "#6478a6",
  "#8c6553",
  "#73834c"
]
```

## add-empty

Dialog/Container: `addDialog`. Klassen: `small-dialog`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #addTitle | Schüler hinzufügen |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | normal |
| 3 | label | Name |  | normal |
| 4 | text | Name |  | normal |
| 5 | input #studentName |  | Wert: <br>Platzhalter: Name … | required=True, maxlength=80 |
| 6 | legend | Farbe |  | normal |
| 7 | button | aria-label: Farbe 1: #53747e<br>Tooltip: #53747e | Wert:  | type=button, pressed=true |
| 8 | button | aria-label: Farbe 2: #756582<br>Tooltip: #756582 | Wert:  | type=button, pressed=false |
| 9 | button | aria-label: Farbe 3: #49765a<br>Tooltip: #49765a | Wert:  | type=button, pressed=false |
| 10 | button | aria-label: Farbe 4: #b87943<br>Tooltip: #b87943 | Wert:  | type=button, pressed=false |
| 11 | button | aria-label: Farbe 5: #ac5d72<br>Tooltip: #ac5d72 | Wert:  | type=button, pressed=false |
| 12 | button | aria-label: Farbe 6: #487f85<br>Tooltip: #487f85 | Wert:  | type=button, pressed=false |
| 13 | button | aria-label: Farbe 7: #8a7845<br>Tooltip: #8a7845 | Wert:  | type=button, pressed=false |
| 14 | button | aria-label: Farbe 8: #6478a6<br>Tooltip: #6478a6 | Wert:  | type=button, pressed=false |
| 15 | button | aria-label: Farbe 9: #8c6553<br>Tooltip: #8c6553 | Wert:  | type=button, pressed=false |
| 16 | button | aria-label: Farbe 10: #73834c<br>Tooltip: #73834c | Wert:  | type=button, pressed=false |
| 17 | label | Eigene Farbe wählen |  | normal |
| 18 | input #studentColor |  | Wert: #53747e | type=color |
| 19 | text | Eigene Farbe wählen |  | normal |
| 20 | button | Hinzufügen | Wert:  | normal |

## overview-empty

Dialog/Container: `studentDialog`. Klassen: ``.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | verborgen, type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Schülerübersicht |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | text | Gespeichert · 12:00 |  | normal |
| 9 | button | Aktuell | Wert:  | type=button, pressed=true |
| 10 | button | Diese Woche | Wert:  | type=button, pressed=false |
| 11 | button | Offen | Wert:  | type=button, pressed=false |
| 12 | button #overviewSearchToggle | aria-label: Einträge durchsuchen<br>Tooltip: Einträge durchsuchen | Wert:  | type=button, expanded=false |
| 13 | summary | •••<br>aria-label: Schüleraktionen<br>Tooltip: Schüleraktionen |  | normal |
| 14 | button #managePupil | Schüler bearbeiten | Wert:  | eingeklappt, type=button |
| 15 | button #prepareBrief | Gespräch vorbereiten | Wert:  | eingeklappt, type=button |
| 16 | button #pupilDrafts | Gesicherte Entwürfe | Wert:  | eingeklappt, type=button |
| 17 | input #pupilOverviewSearch | aria-label: Schülereinträge durchsuchen | Wert: <br>Platzhalter: Suchen … | verborgen, type=search |
| 18 | button #overviewSearchClear | ×<br>aria-label: Suche schließen | Wert:  | verborgen, type=button |
| 19 | button | Ziele<br>aria-label: Ziele öffnen | Wert:  | type=button |
| 20 | button | Sozial<br>aria-label: Sozialverhalten öffnen | Wert:  | type=button |
| 21 | button | Arbeit<br>aria-label: Arbeitsverhalten öffnen | Wert:  | type=button |
| 22 | button | HÜ<br>aria-label: Hausübung öffnen | Wert:  | type=button |
| 23 | button | Orga<br>aria-label: Organisatorisches öffnen | Wert:  | type=button |
| 24 | text | Keine offenen Aufgaben, Ziele oder Erinnerungen. |  | normal |
| 25 | button | Gesamter Verlauf → | Wert:  | type=button |
| 26 | button #saveEntry | Speichern | Wert:  | verborgen, type=submit |

## Sozialverhalten-empty

Dialog/Container: `studentDialog`. Klassen: `entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Sozialverhalten |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | text | Gespeichert · 12:00 |  | normal |
| 9 | button | ← Bereiche | Wert:  | verborgen, type=button |
| 10 | button | Verlauf ansehen | Wert:  | verborgen, type=button |
| 11 | h3 | Sozialverhalten |  | verborgen |
| 12 | text | Auswahl, eigene Notiz oder beides. |  | normal |
| 13 | button | Positiv | Wert:  | type=button, pressed=true |
| 14 | button | Negativ | Wert:  | type=button, pressed=false |
| 15 | text | Beobachtung |  | normal |
| 16 | button #editOptions | aria-label: Auswahl bearbeiten<br>Tooltip: Auswahl bearbeiten | Wert:  | type=button |
| 17 | button | Hilft anderen | Wert:  | type=button, pressed=false |
| 18 | button | ☆<br>aria-label: Als Favorit markieren: Hilft anderen | Wert:  | type=button |
| 19 | button | Nimmt Hilfe an | Wert:  | type=button, pressed=false |
| 20 | button | ☆<br>aria-label: Als Favorit markieren: Nimmt Hilfe an | Wert:  | type=button |
| 21 | button | Hält Gesprächsregeln ein | Wert:  | type=button, pressed=false |
| 22 | button | ☆<br>aria-label: Als Favorit markieren: Hält Gesprächsregeln ein | Wert:  | type=button |
| 23 | button | Geht respektvoll mit anderen um | Wert:  | type=button, pressed=false |
| 24 | button | ☆<br>aria-label: Als Favorit markieren: Geht respektvoll mit anderen um | Wert:  | type=button |
| 25 | button | Klärt einen Konflikt im Gespräch | Wert:  | type=button, pressed=false |
| 26 | button | ☆<br>aria-label: Als Favorit markieren: Klärt einen Konflikt im Gespräch | Wert:  | type=button |
| 27 | button | Hält gemeinsame Absprachen ein | Wert:  | type=button, pressed=false |
| 28 | button | ☆<br>aria-label: Als Favorit markieren: Hält gemeinsame Absprachen ein | Wert:  | type=button |
| 29 | label | Was ist passiert? optional bei Auswahl |  | normal |
| 30 | text | Was ist passiert? |  | normal |
| 31 | text | optional bei Auswahl |  | normal |
| 32 | button | Vor dem Unterricht | Wert:  | type=button, pressed=false |
| 33 | button | Während des Unterrichts | Wert:  | type=button, pressed=false |
| 34 | button | Nach dem Unterricht | Wert:  | type=button, pressed=false |
| 35 | button | Pause | Wert:  | type=button, pressed=false |
| 36 | textarea #entryText |  | Wert: <br>Platzhalter: Beobachtung … | verborgen, maxlength=4000 |
| 37 | textarea #entryTextNarrativeFree |  | Wert: <br>Platzhalter: Beobachtung … | maxlength=4000 |
| 38 | h3 | Weitere Angaben |  | normal |
| 39 | label | Beteiligt |  | normal |
| 40 | input #entryParticipantsEnabled |  | Wert: on | type=checkbox, checked=False |
| 41 | text | Beteiligt |  | normal |
| 42 | text | Schüler auswählen |  | verborgen |
| 43 | button | Anna Beispiel | Wert:  | verborgen, type=button, disabled=True, pressed=false |
| 44 | button | Ben Beispiel | Wert:  | verborgen, type=button, disabled=True, pressed=false |
| 45 | label | Weitere Namen |  | verborgen |
| 46 | text | Weitere Namen |  | verborgen |
| 47 | input #entryParticipantsNames |  | Wert: <br>Platzhalter: Name; Name … | verborgen, type=text, disabled=True, maxlength=12000 |
| 48 | input #entryParticipantsValue |  | Wert: [] | verborgen, type=hidden |
| 49 | label | Zielbezug |  | normal |
| 50 | input #entryGoalLinkEnabled |  | Wert: on | type=checkbox, checked=False |
| 51 | text | Zielbezug |  | normal |
| 52 | label | Ziel auswählen |  | verborgen |
| 53 | text | Ziel auswählen |  | verborgen |
| 54 | select #entryGoalLink | Ohne Zielzuordnung | Wert: <br>Optionen: [{"value": "", "text": "Ohne Zielzuordnung", "selected": true}] | verborgen, disabled=True |
| 55 | text | Kein aktives Ziel vorhanden. |  | verborgen |
| 56 | label | Reaktion / Unterstützung |  | normal |
| 57 | input #supportNeeded |  | Wert: on | type=checkbox, checked=False |
| 58 | text | Reaktion / Unterstützung |  | normal |
| 59 | input #entrySupportNote | aria-label: Hilfreiche Reaktion oder Unterstützung | Wert: <br>Platzhalter: Unterstützung … | verborgen, disabled=True, maxlength=300 |
| 60 | summary | Quelle & gemeinsamer Kontext |  | normal |
| 61 | label | Quelle |  | eingeklappt |
| 62 | text | Quelle |  | eingeklappt |
| 63 | select #entrySourceKind | Selbst beobachtetBerichtetEigene Einordnung | Wert: own<br>Optionen: [{"value": "own", "text": "Selbst beobachtet", "selected": true}, {"value": "reported", "text": "Berichtet", "selected": false}, {"value": "interpretation", "text": "Eigene Einordnung", "selected": false}] | eingeklappt |
| 64 | label | Gemeinsamer Ablauf |  | eingeklappt |
| 65 | text | Gemeinsamer Ablauf |  | eingeklappt |
| 66 | textarea #entrySharedContext |  | Wert: <br>Platzhalter: Kontext … | eingeklappt, maxlength=3000 |
| 67 | label | Beobachtet am |  | normal |
| 68 | text | Beobachtet am |  | normal |
| 69 | input #observedAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 70 | input #observedAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 71 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 72 | label | Später ergänzen |  | normal |
| 73 | input #entryFollowUp |  | Wert: on | type=checkbox, checked=False |
| 74 | text | Später ergänzen |  | normal |
| 75 | button #saveNext | Speichern & weiter →<br>aria-label: Speichern und zum nächsten Schüler<br>Tooltip: Speichern und nächster Schüler | Wert:  | type=button |
| 76 | button #saveEntry | Eintrag speichern | Wert:  | type=submit |

## Sozialverhalten-negative

Dialog/Container: `studentDialog`. Klassen: `entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Sozialverhalten |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | text | Gespeichert · 12:00 |  | normal |
| 9 | button | ← Bereiche | Wert:  | verborgen, type=button |
| 10 | button | Verlauf ansehen | Wert:  | verborgen, type=button |
| 11 | h3 | Sozialverhalten |  | verborgen |
| 12 | text | Auswahl, eigene Notiz oder beides. |  | normal |
| 13 | button | Positiv | Wert:  | type=button, pressed=false |
| 14 | button | Negativ | Wert:  | type=button, pressed=true |
| 15 | text | Beobachtung |  | normal |
| 16 | button #editOptions | aria-label: Auswahl bearbeiten<br>Tooltip: Auswahl bearbeiten | Wert:  | type=button |
| 17 | button | Unterbricht andere wiederholt | Wert:  | type=button, pressed=false |
| 18 | button | ☆<br>aria-label: Als Favorit markieren: Unterbricht andere wiederholt | Wert:  | type=button |
| 19 | button | Spricht andere abwertend an | Wert:  | type=button, pressed=false |
| 20 | button | ☆<br>aria-label: Als Favorit markieren: Spricht andere abwertend an | Wert:  | type=button |
| 21 | button | Hält gemeinsame Absprachen nicht ein | Wert:  | type=button, pressed=false |
| 22 | button | ☆<br>aria-label: Als Favorit markieren: Hält gemeinsame Absprachen nicht ein | Wert:  | type=button |
| 23 | button | Stört die Zusammenarbeit | Wert:  | type=button, pressed=false |
| 24 | button | ☆<br>aria-label: Als Favorit markieren: Stört die Zusammenarbeit | Wert:  | type=button |
| 25 | label | Was ist passiert? optional bei Auswahl |  | normal |
| 26 | text | Was ist passiert? |  | normal |
| 27 | text | optional bei Auswahl |  | normal |
| 28 | button | Vor dem Unterricht | Wert:  | type=button, pressed=false |
| 29 | button | Während des Unterrichts | Wert:  | type=button, pressed=false |
| 30 | button | Nach dem Unterricht | Wert:  | type=button, pressed=false |
| 31 | button | Pause | Wert:  | type=button, pressed=false |
| 32 | textarea #entryText |  | Wert: <br>Platzhalter: Beobachtung … | verborgen, maxlength=4000 |
| 33 | textarea #entryTextNarrativeFree |  | Wert: <br>Platzhalter: Beobachtung … | maxlength=4000 |
| 34 | h3 | Weitere Angaben |  | normal |
| 35 | label | Beteiligt |  | normal |
| 36 | input #entryParticipantsEnabled |  | Wert: on | type=checkbox, checked=False |
| 37 | text | Beteiligt |  | normal |
| 38 | text | Schüler auswählen |  | verborgen |
| 39 | button | Anna Beispiel | Wert:  | verborgen, type=button, disabled=True, pressed=false |
| 40 | button | Ben Beispiel | Wert:  | verborgen, type=button, disabled=True, pressed=false |
| 41 | label | Weitere Namen |  | verborgen |
| 42 | text | Weitere Namen |  | verborgen |
| 43 | input #entryParticipantsNames |  | Wert: <br>Platzhalter: Name; Name … | verborgen, type=text, disabled=True, maxlength=12000 |
| 44 | input #entryParticipantsValue |  | Wert: [] | verborgen, type=hidden |
| 45 | label | Zielbezug |  | normal |
| 46 | input #entryGoalLinkEnabled |  | Wert: on | type=checkbox, checked=False |
| 47 | text | Zielbezug |  | normal |
| 48 | label | Ziel auswählen |  | verborgen |
| 49 | text | Ziel auswählen |  | verborgen |
| 50 | select #entryGoalLink | Ohne Zielzuordnung | Wert: <br>Optionen: [{"value": "", "text": "Ohne Zielzuordnung", "selected": true}] | verborgen, disabled=True |
| 51 | text | Kein aktives Ziel vorhanden. |  | verborgen |
| 52 | label | Reaktion / Unterstützung |  | normal |
| 53 | input #supportNeeded |  | Wert: on | type=checkbox, checked=False |
| 54 | text | Reaktion / Unterstützung |  | normal |
| 55 | input #entrySupportNote | aria-label: Hilfreiche Reaktion oder Unterstützung | Wert: <br>Platzhalter: Unterstützung … | verborgen, disabled=True, maxlength=300 |
| 56 | summary | Quelle & gemeinsamer Kontext |  | normal |
| 57 | label | Quelle |  | eingeklappt |
| 58 | text | Quelle |  | eingeklappt |
| 59 | select #entrySourceKind | Selbst beobachtetBerichtetEigene Einordnung | Wert: own<br>Optionen: [{"value": "own", "text": "Selbst beobachtet", "selected": true}, {"value": "reported", "text": "Berichtet", "selected": false}, {"value": "interpretation", "text": "Eigene Einordnung", "selected": false}] | eingeklappt |
| 60 | label | Gemeinsamer Ablauf |  | eingeklappt |
| 61 | text | Gemeinsamer Ablauf |  | eingeklappt |
| 62 | textarea #entrySharedContext |  | Wert: <br>Platzhalter: Kontext … | eingeklappt, maxlength=3000 |
| 63 | label | Beobachtet am |  | normal |
| 64 | text | Beobachtet am |  | normal |
| 65 | input #observedAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 66 | input #observedAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 67 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 68 | label | Später ergänzen |  | normal |
| 69 | input #entryFollowUp |  | Wert: on | type=checkbox, checked=False |
| 70 | text | Später ergänzen |  | normal |
| 71 | button #saveNext | Speichern & weiter →<br>aria-label: Speichern und zum nächsten Schüler<br>Tooltip: Speichern und nächster Schüler | Wert:  | type=button |
| 72 | button #saveEntry | Eintrag speichern | Wert:  | type=submit |

## Sozialverhalten-filled

Dialog/Container: `studentDialog`. Klassen: `entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Sozialverhalten |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | text | Gespeichert · 12:00 |  | normal |
| 9 | button | ← Bereiche | Wert:  | verborgen, type=button |
| 10 | button | Verlauf ansehen | Wert:  | verborgen, type=button |
| 11 | h3 | Sozialverhalten |  | verborgen |
| 12 | text | Auswahl, eigene Notiz oder beides. |  | normal |
| 13 | button | Positiv | Wert:  | type=button, pressed=false |
| 14 | button | Negativ | Wert:  | type=button, pressed=true |
| 15 | text | Beobachtung |  | normal |
| 16 | button #editOptions | aria-label: Auswahl bearbeiten<br>Tooltip: Auswahl bearbeiten | Wert:  | type=button |
| 17 | button | ✓Unterbricht andere wiederholt | Wert:  | verborgen, type=button, pressed=true |
| 18 | button | ☆<br>aria-label: Als Favorit markieren: Unterbricht andere wiederholt | Wert:  | verborgen, type=button |
| 19 | button | Spricht andere abwertend an | Wert:  | type=button, pressed=false |
| 20 | button | ☆<br>aria-label: Als Favorit markieren: Spricht andere abwertend an | Wert:  | type=button |
| 21 | button | Hält gemeinsame Absprachen nicht ein | Wert:  | type=button, pressed=false |
| 22 | button | ☆<br>aria-label: Als Favorit markieren: Hält gemeinsame Absprachen nicht ein | Wert:  | type=button |
| 23 | button | Stört die Zusammenarbeit | Wert:  | type=button, pressed=false |
| 24 | button | ☆<br>aria-label: Als Favorit markieren: Stört die Zusammenarbeit | Wert:  | type=button |
| 25 | label | Was ist passiert? optional bei Auswahl |  | normal |
| 26 | text | Was ist passiert? |  | normal |
| 27 | text | optional bei Auswahl |  | normal |
| 28 | button | Vor dem Unterricht | Wert:  | type=button, pressed=false |
| 29 | button | Während des Unterrichts | Wert:  | type=button, pressed=false |
| 30 | button | Nach dem Unterricht | Wert:  | type=button, pressed=false |
| 31 | button | Pause | Wert:  | type=button, pressed=false |
| 32 | button | + Hilft anderen×<br>aria-label: Auswahl entfernen: Hilft anderen | Wert:  | type=button |
| 33 | button | − Unterbricht andere wiederholt×<br>aria-label: Auswahl entfernen: Unterbricht andere wiederholt | Wert:  | type=button |
| 34 | textarea #entryText | Synthetische Beobachtung | Wert: Synthetische Beobachtung<br>Platzhalter: Beobachtung … | verborgen, maxlength=4000 |
| 35 | textarea #entryTextNarrativeFree |  | Wert: Synthetische Beobachtung<br>Platzhalter: Beobachtung … | maxlength=4000 |
| 36 | h3 | Weitere Angaben |  | normal |
| 37 | label | Beteiligt |  | normal |
| 38 | input #entryParticipantsEnabled |  | Wert: on | type=checkbox, checked=True |
| 39 | text | Beteiligt |  | normal |
| 40 | text | Schüler auswählen |  | normal |
| 41 | button | Anna Beispiel | Wert:  | type=button, pressed=false |
| 42 | button | Ben Beispiel | Wert:  | type=button, pressed=true |
| 43 | label | Weitere Namen |  | normal |
| 44 | text | Weitere Namen |  | normal |
| 45 | input #entryParticipantsNames |  | Wert: <br>Platzhalter: Name; Name … | type=text, maxlength=12000 |
| 46 | input #entryParticipantsValue |  | Wert: [{"studentId":"audit-b","name":"Ben Beispiel"}] | verborgen, type=hidden |
| 47 | label | Zielbezug |  | normal |
| 48 | input #entryGoalLinkEnabled |  | Wert: on | type=checkbox, checked=False |
| 49 | text | Zielbezug |  | normal |
| 50 | label | Ziel auswählen |  | verborgen |
| 51 | text | Ziel auswählen |  | verborgen |
| 52 | select #entryGoalLink | Ohne Zielzuordnung | Wert: <br>Optionen: [{"value": "", "text": "Ohne Zielzuordnung", "selected": true}] | verborgen, disabled=True |
| 53 | text | Kein aktives Ziel vorhanden. |  | verborgen |
| 54 | label | Reaktion / Unterstützung |  | normal |
| 55 | input #supportNeeded |  | Wert: on | type=checkbox, checked=True |
| 56 | text | Reaktion / Unterstützung |  | normal |
| 57 | input #entrySupportNote | aria-label: Hilfreiche Reaktion oder Unterstützung | Wert: Synthetische Unterstützung<br>Platzhalter: Unterstützung … | maxlength=300 |
| 58 | summary | Quelle & gemeinsamer Kontext |  | normal |
| 59 | label | Quelle |  | eingeklappt |
| 60 | text | Quelle |  | eingeklappt |
| 61 | select #entrySourceKind | Selbst beobachtetBerichtetEigene Einordnung | Wert: reported<br>Optionen: [{"value": "own", "text": "Selbst beobachtet", "selected": false}, {"value": "reported", "text": "Berichtet", "selected": true}, {"value": "interpretation", "text": "Eigene Einordnung", "selected": false}] | eingeklappt |
| 62 | label | Gemeinsamer Ablauf |  | eingeklappt |
| 63 | text | Gemeinsamer Ablauf |  | eingeklappt |
| 64 | textarea #entrySharedContext | Synthetischer Kontext | Wert: Synthetischer Kontext<br>Platzhalter: Kontext … | eingeklappt, maxlength=3000 |
| 65 | label | Beobachtet am |  | normal |
| 66 | text | Beobachtet am |  | normal |
| 67 | input #observedAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 68 | input #observedAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 69 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 70 | label | Später ergänzen |  | normal |
| 71 | input #entryFollowUp |  | Wert: on | type=checkbox, checked=True |
| 72 | text | Später ergänzen |  | normal |
| 73 | button #saveNext | Speichern & weiter →<br>aria-label: Speichern und zum nächsten Schüler<br>Tooltip: Speichern und nächster Schüler | Wert:  | type=button |
| 74 | button #saveEntry | Eintrag speichern | Wert:  | type=submit |

## Arbeitsverhalten-empty

Dialog/Container: `studentDialog`. Klassen: `entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Arbeitsverhalten |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | text | Gespeichert · 12:00 |  | normal |
| 9 | button | ← Bereiche | Wert:  | verborgen, type=button |
| 10 | button | Verlauf ansehen | Wert:  | verborgen, type=button |
| 11 | h3 | Arbeitsverhalten |  | verborgen |
| 12 | text | Auswahl, eigene Notiz oder beides. |  | normal |
| 13 | button | Positiv | Wert:  | type=button, pressed=true |
| 14 | button | Negativ | Wert:  | type=button, pressed=false |
| 15 | label | Auftrag |  | normal |
| 16 | text | Auftrag |  | normal |
| 17 | input #entryTaskFree | aria-label: Auftrag – eigener Text | Wert: <br>Platzhalter: Auftrag … | type=text, maxlength=1000 |
| 18 | input #entryTask |  | Wert: <br>Platzhalter: Auftrag … | verborgen, maxlength=1000 |
| 19 | text | Beobachtung |  | normal |
| 20 | button #editOptions | aria-label: Auswahl bearbeiten<br>Tooltip: Auswahl bearbeiten | Wert:  | type=button |
| 21 | button | Beginnt selbstständig | Wert:  | type=button, pressed=false |
| 22 | button | ☆<br>aria-label: Als Favorit markieren: Beginnt selbstständig | Wert:  | type=button |
| 23 | button | Arbeitet konzentriert | Wert:  | type=button, pressed=false |
| 24 | button | ☆<br>aria-label: Als Favorit markieren: Arbeitet konzentriert | Wert:  | type=button |
| 25 | button | Bleibt bei Schwierigkeiten dran | Wert:  | type=button, pressed=false |
| 26 | button | ☆<br>aria-label: Als Favorit markieren: Bleibt bei Schwierigkeiten dran | Wert:  | type=button |
| 27 | button | Fragt gezielt nach Hilfe | Wert:  | type=button, pressed=false |
| 28 | button | ☆<br>aria-label: Als Favorit markieren: Fragt gezielt nach Hilfe | Wert:  | type=button |
| 29 | button | Schließt die Aufgabe ab | Wert:  | type=button, pressed=false |
| 30 | button | ☆<br>aria-label: Als Favorit markieren: Schließt die Aufgabe ab | Wert:  | type=button |
| 31 | button | Arbeitet sorgfältig | Wert:  | type=button, pressed=false |
| 32 | button | ☆<br>aria-label: Als Favorit markieren: Arbeitet sorgfältig | Wert:  | type=button |
| 33 | label | Konkrete Beobachtung optional |  | normal |
| 34 | text | Konkrete Beobachtung |  | normal |
| 35 | text | optional |  | normal |
| 36 | textarea #entryText |  | Wert: <br>Platzhalter: Beobachtung … | maxlength=10000 |
| 37 | h3 | Weitere Angaben |  | normal |
| 38 | label | Zielbezug |  | normal |
| 39 | input #entryGoalLinkEnabled |  | Wert: on | type=checkbox, checked=False |
| 40 | text | Zielbezug |  | normal |
| 41 | label | Ziel auswählen |  | verborgen |
| 42 | text | Ziel auswählen |  | verborgen |
| 43 | select #entryGoalLink | Ohne Zielzuordnung | Wert: <br>Optionen: [{"value": "", "text": "Ohne Zielzuordnung", "selected": true}] | verborgen, disabled=True |
| 44 | text | Kein aktives Ziel vorhanden. |  | verborgen |
| 45 | label | Reaktion / Unterstützung |  | normal |
| 46 | input #supportNeeded |  | Wert: on | type=checkbox, checked=False |
| 47 | text | Reaktion / Unterstützung |  | normal |
| 48 | input #entrySupportNote | aria-label: Hilfreiche Reaktion oder Unterstützung | Wert: <br>Platzhalter: Unterstützung … | verborgen, disabled=True, maxlength=300 |
| 49 | summary | Quelle & gemeinsamer Kontext |  | normal |
| 50 | label | Quelle |  | eingeklappt |
| 51 | text | Quelle |  | eingeklappt |
| 52 | select #entrySourceKind | Selbst beobachtetBerichtetEigene Einordnung | Wert: own<br>Optionen: [{"value": "own", "text": "Selbst beobachtet", "selected": true}, {"value": "reported", "text": "Berichtet", "selected": false}, {"value": "interpretation", "text": "Eigene Einordnung", "selected": false}] | eingeklappt |
| 53 | label | Gemeinsamer Ablauf |  | eingeklappt |
| 54 | text | Gemeinsamer Ablauf |  | eingeklappt |
| 55 | textarea #entrySharedContext |  | Wert: <br>Platzhalter: Kontext … | eingeklappt, maxlength=3000 |
| 56 | label | Beobachtet am |  | normal |
| 57 | text | Beobachtet am |  | normal |
| 58 | input #observedAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 59 | input #observedAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 60 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 61 | label | Später ergänzen |  | normal |
| 62 | input #entryFollowUp |  | Wert: on | type=checkbox, checked=False |
| 63 | text | Später ergänzen |  | normal |
| 64 | button #saveNext | Speichern & weiter →<br>aria-label: Speichern und zum nächsten Schüler<br>Tooltip: Speichern und nächster Schüler | Wert:  | type=button |
| 65 | button #saveEntry | Eintrag speichern | Wert:  | type=submit |

## Arbeitsverhalten-negative

Dialog/Container: `studentDialog`. Klassen: `entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Arbeitsverhalten |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | text | Gespeichert · 12:00 |  | normal |
| 9 | button | ← Bereiche | Wert:  | verborgen, type=button |
| 10 | button | Verlauf ansehen | Wert:  | verborgen, type=button |
| 11 | h3 | Arbeitsverhalten |  | verborgen |
| 12 | text | Auswahl, eigene Notiz oder beides. |  | normal |
| 13 | button | Positiv | Wert:  | type=button, pressed=false |
| 14 | button | Negativ | Wert:  | type=button, pressed=true |
| 15 | label | Auftrag |  | normal |
| 16 | text | Auftrag |  | normal |
| 17 | input #entryTaskFree | aria-label: Auftrag – eigener Text | Wert: <br>Platzhalter: Auftrag … | type=text, maxlength=1000 |
| 18 | input #entryTask |  | Wert: <br>Platzhalter: Auftrag … | verborgen, maxlength=1000 |
| 19 | text | Beobachtung |  | normal |
| 20 | button #editOptions | aria-label: Auswahl bearbeiten<br>Tooltip: Auswahl bearbeiten | Wert:  | type=button |
| 21 | button | Beginnt erst nach mehreren Aufforderungen | Wert:  | type=button, pressed=false |
| 22 | button | ☆<br>aria-label: Als Favorit markieren: Beginnt erst nach mehreren Aufforderungen | Wert:  | type=button |
| 23 | button | Beschäftigt sich wiederholt mit anderem | Wert:  | type=button, pressed=false |
| 24 | button | ☆<br>aria-label: Als Favorit markieren: Beschäftigt sich wiederholt mit anderem | Wert:  | type=button |
| 25 | button | Unterbricht die Arbeit vorzeitig | Wert:  | type=button, pressed=false |
| 26 | button | ☆<br>aria-label: Als Favorit markieren: Unterbricht die Arbeit vorzeitig | Wert:  | type=button |
| 27 | button | Bearbeitet die vereinbarte Aufgabe nicht | Wert:  | type=button, pressed=false |
| 28 | button | ☆<br>aria-label: Als Favorit markieren: Bearbeitet die vereinbarte Aufgabe nicht | Wert:  | type=button |
| 29 | button | Lässt vereinbarte Arbeitsschritte aus | Wert:  | type=button, pressed=false |
| 30 | button | ☆<br>aria-label: Als Favorit markieren: Lässt vereinbarte Arbeitsschritte aus | Wert:  | type=button |
| 31 | label | Konkrete Beobachtung optional |  | normal |
| 32 | text | Konkrete Beobachtung |  | normal |
| 33 | text | optional |  | normal |
| 34 | textarea #entryText |  | Wert: <br>Platzhalter: Beobachtung … | maxlength=10000 |
| 35 | h3 | Weitere Angaben |  | normal |
| 36 | label | Zielbezug |  | normal |
| 37 | input #entryGoalLinkEnabled |  | Wert: on | type=checkbox, checked=False |
| 38 | text | Zielbezug |  | normal |
| 39 | label | Ziel auswählen |  | verborgen |
| 40 | text | Ziel auswählen |  | verborgen |
| 41 | select #entryGoalLink | Ohne Zielzuordnung | Wert: <br>Optionen: [{"value": "", "text": "Ohne Zielzuordnung", "selected": true}] | verborgen, disabled=True |
| 42 | text | Kein aktives Ziel vorhanden. |  | verborgen |
| 43 | label | Reaktion / Unterstützung |  | normal |
| 44 | input #supportNeeded |  | Wert: on | type=checkbox, checked=False |
| 45 | text | Reaktion / Unterstützung |  | normal |
| 46 | input #entrySupportNote | aria-label: Hilfreiche Reaktion oder Unterstützung | Wert: <br>Platzhalter: Unterstützung … | verborgen, disabled=True, maxlength=300 |
| 47 | summary | Quelle & gemeinsamer Kontext |  | normal |
| 48 | label | Quelle |  | eingeklappt |
| 49 | text | Quelle |  | eingeklappt |
| 50 | select #entrySourceKind | Selbst beobachtetBerichtetEigene Einordnung | Wert: own<br>Optionen: [{"value": "own", "text": "Selbst beobachtet", "selected": true}, {"value": "reported", "text": "Berichtet", "selected": false}, {"value": "interpretation", "text": "Eigene Einordnung", "selected": false}] | eingeklappt |
| 51 | label | Gemeinsamer Ablauf |  | eingeklappt |
| 52 | text | Gemeinsamer Ablauf |  | eingeklappt |
| 53 | textarea #entrySharedContext |  | Wert: <br>Platzhalter: Kontext … | eingeklappt, maxlength=3000 |
| 54 | label | Beobachtet am |  | normal |
| 55 | text | Beobachtet am |  | normal |
| 56 | input #observedAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 57 | input #observedAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 58 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 59 | label | Später ergänzen |  | normal |
| 60 | input #entryFollowUp |  | Wert: on | type=checkbox, checked=False |
| 61 | text | Später ergänzen |  | normal |
| 62 | button #saveNext | Speichern & weiter →<br>aria-label: Speichern und zum nächsten Schüler<br>Tooltip: Speichern und nächster Schüler | Wert:  | type=button |
| 63 | button #saveEntry | Eintrag speichern | Wert:  | type=submit |

## Arbeitsverhalten-filled

Dialog/Container: `studentDialog`. Klassen: `entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Arbeitsverhalten |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | text | Gespeichert · 12:00 |  | normal |
| 9 | button | ← Bereiche | Wert:  | verborgen, type=button |
| 10 | button | Verlauf ansehen | Wert:  | verborgen, type=button |
| 11 | h3 | Arbeitsverhalten |  | verborgen |
| 12 | text | Auswahl, eigene Notiz oder beides. |  | normal |
| 13 | button | Positiv | Wert:  | type=button, pressed=false |
| 14 | button | Negativ | Wert:  | type=button, pressed=true |
| 15 | label | Auftrag |  | normal |
| 16 | text | Auftrag |  | normal |
| 17 | input #entryTaskFree | aria-label: Auftrag – eigener Text | Wert: Lesen<br>Platzhalter: Auftrag … | type=text, maxlength=1000 |
| 18 | input #entryTask |  | Wert: Lesen<br>Platzhalter: Auftrag … | verborgen, maxlength=1000 |
| 19 | text | Beobachtung |  | normal |
| 20 | button #editOptions | aria-label: Auswahl bearbeiten<br>Tooltip: Auswahl bearbeiten | Wert:  | type=button |
| 21 | button | ✓Beginnt erst nach mehreren Aufforderungen | Wert:  | verborgen, type=button, pressed=true |
| 22 | button | ☆<br>aria-label: Als Favorit markieren: Beginnt erst nach mehreren Aufforderungen | Wert:  | verborgen, type=button |
| 23 | button | Beschäftigt sich wiederholt mit anderem | Wert:  | type=button, pressed=false |
| 24 | button | ☆<br>aria-label: Als Favorit markieren: Beschäftigt sich wiederholt mit anderem | Wert:  | type=button |
| 25 | button | Unterbricht die Arbeit vorzeitig | Wert:  | type=button, pressed=false |
| 26 | button | ☆<br>aria-label: Als Favorit markieren: Unterbricht die Arbeit vorzeitig | Wert:  | type=button |
| 27 | button | Bearbeitet die vereinbarte Aufgabe nicht | Wert:  | type=button, pressed=false |
| 28 | button | ☆<br>aria-label: Als Favorit markieren: Bearbeitet die vereinbarte Aufgabe nicht | Wert:  | type=button |
| 29 | button | Lässt vereinbarte Arbeitsschritte aus | Wert:  | type=button, pressed=false |
| 30 | button | ☆<br>aria-label: Als Favorit markieren: Lässt vereinbarte Arbeitsschritte aus | Wert:  | type=button |
| 31 | label | Konkrete Beobachtung optional |  | normal |
| 32 | text | Konkrete Beobachtung |  | normal |
| 33 | text | optional |  | normal |
| 34 | button | + Beginnt selbstständig×<br>aria-label: Auswahl entfernen: Beginnt selbstständig | Wert:  | type=button |
| 35 | button | − Beginnt erst nach mehreren Aufforderungen×<br>aria-label: Auswahl entfernen: Beginnt erst nach mehreren Aufforderungen | Wert:  | type=button |
| 36 | textarea #entryText | Synthetische Beobachtung | Wert: Synthetische Beobachtung<br>Platzhalter: Beobachtung … | maxlength=10000 |
| 37 | h3 | Weitere Angaben |  | normal |
| 38 | label | Zielbezug |  | normal |
| 39 | input #entryGoalLinkEnabled |  | Wert: on | type=checkbox, checked=False |
| 40 | text | Zielbezug |  | normal |
| 41 | label | Ziel auswählen |  | verborgen |
| 42 | text | Ziel auswählen |  | verborgen |
| 43 | select #entryGoalLink | Ohne Zielzuordnung | Wert: <br>Optionen: [{"value": "", "text": "Ohne Zielzuordnung", "selected": true}] | verborgen, disabled=True |
| 44 | text | Kein aktives Ziel vorhanden. |  | verborgen |
| 45 | label | Reaktion / Unterstützung |  | normal |
| 46 | input #supportNeeded |  | Wert: on | type=checkbox, checked=True |
| 47 | text | Reaktion / Unterstützung |  | normal |
| 48 | input #entrySupportNote | aria-label: Hilfreiche Reaktion oder Unterstützung | Wert: Synthetische Unterstützung<br>Platzhalter: Unterstützung … | maxlength=300 |
| 49 | summary | Quelle & gemeinsamer Kontext |  | normal |
| 50 | label | Quelle |  | eingeklappt |
| 51 | text | Quelle |  | eingeklappt |
| 52 | select #entrySourceKind | Selbst beobachtetBerichtetEigene Einordnung | Wert: reported<br>Optionen: [{"value": "own", "text": "Selbst beobachtet", "selected": false}, {"value": "reported", "text": "Berichtet", "selected": true}, {"value": "interpretation", "text": "Eigene Einordnung", "selected": false}] | eingeklappt |
| 53 | label | Gemeinsamer Ablauf |  | eingeklappt |
| 54 | text | Gemeinsamer Ablauf |  | eingeklappt |
| 55 | textarea #entrySharedContext | Synthetischer Kontext | Wert: Synthetischer Kontext<br>Platzhalter: Kontext … | eingeklappt, maxlength=3000 |
| 56 | label | Beobachtet am |  | normal |
| 57 | text | Beobachtet am |  | normal |
| 58 | input #observedAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 59 | input #observedAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 60 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 61 | label | Später ergänzen |  | normal |
| 62 | input #entryFollowUp |  | Wert: on | type=checkbox, checked=True |
| 63 | text | Später ergänzen |  | normal |
| 64 | button #saveNext | Speichern & weiter →<br>aria-label: Speichern und zum nächsten Schüler<br>Tooltip: Speichern und nächster Schüler | Wert:  | type=button |
| 65 | button #saveEntry | Eintrag speichern | Wert:  | type=submit |

## Organisatorisches-empty

Dialog/Container: `studentDialog`. Klassen: `entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Orga |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | text | Gespeichert · 12:00 |  | normal |
| 9 | button | ← Bereiche | Wert:  | verborgen, type=button |
| 10 | button | Verlauf ansehen | Wert:  | verborgen, type=button |
| 11 | h3 | Organisatorisches |  | verborgen |
| 12 | text | Eine kurze Notiz zu Material, Unterschriften oder Absprachen. |  | normal |
| 13 | label | Notiz oder Aufgabe |  | normal |
| 14 | text | Notiz oder Aufgabe |  | normal |
| 15 | button | ☐ Checkliste | Wert:  | type=button |
| 16 | button | • Aufzählung | Wert:  | type=button |
| 17 | button | 1. Nummerierung | Wert:  | type=button |
| 18 | textarea #entryText |  | Wert: <br>Platzhalter: Notiz … | required=True, maxlength=10000 |
| 19 | label | Als Aufgabe |  | normal |
| 20 | input #orgTask |  | Wert: on | type=checkbox, checked=False |
| 21 | text | Als Aufgabe |  | normal |
| 22 | label | Termin optional |  | verborgen |
| 23 | text | Termin |  | verborgen |
| 24 | text | optional |  | verborgen |
| 25 | input #orgTaskDue |  | Wert:  | verborgen, type=date |
| 26 | button | Datum wählen<br>aria-label: Termin optional: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | verborgen, type=button |
| 27 | label | Aufgabe erledigt |  | verborgen |
| 28 | input #orgTaskDone |  | Wert: on | verborgen, type=checkbox, checked=False |
| 29 | text | Aufgabe erledigt |  | verborgen |
| 30 | label | Erinnern |  | normal |
| 31 | input #orgEnabled |  | Wert: on | type=checkbox, checked=False |
| 32 | text | Erinnern |  | normal |
| 33 | label | Erinnern am |  | verborgen |
| 34 | text | Erinnern am |  | verborgen |
| 35 | input #orgDue |  | Wert:  | verborgen, type=hidden |
| 36 | input #orgDueDate | aria-label: Erinnern am | Wert:  | verborgen, type=date |
| 37 | button | Datum wählen<br>aria-label: Erinnern am: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | verborgen, type=button |
| 38 | label | Erinnerungstext optional |  | verborgen |
| 39 | text | Erinnerungstext |  | verborgen |
| 40 | text | optional |  | verborgen |
| 41 | input #orgText |  | Wert: <br>Platzhalter: Wie Notiz … | verborgen, maxlength=2000 |
| 42 | label | Erinnerung quittiert |  | verborgen |
| 43 | input #orgDone |  | Wert: on | verborgen, type=checkbox, checked=False |
| 44 | text | Erinnerung quittiert |  | verborgen |
| 45 | text | Anzeige in der App |  | verborgen |
| 46 | h3 | Weitere Angaben |  | verborgen |
| 47 | h3 | Orga |  | normal |
| 48 | button | Alle · 0 | Wert:  | type=button, pressed=true |
| 49 | button | Offen · 0 | Wert:  | type=button, pressed=false |
| 50 | button | Erledigt · 0 | Wert:  | type=button, pressed=false |
| 51 | text | Keine Einträge. |  | normal |
| 52 | label | Beobachtet am |  | normal |
| 53 | text | Beobachtet am |  | normal |
| 54 | input #observedAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 55 | input #observedAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 56 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 57 | label | Später ergänzen |  | normal |
| 58 | input #entryFollowUp |  | Wert: on | type=checkbox, checked=False |
| 59 | text | Später ergänzen |  | normal |
| 60 | button #saveNext | Speichern & weiter →<br>aria-label: Speichern und zum nächsten Schüler<br>Tooltip: Speichern und nächster Schüler | Wert:  | type=button |
| 61 | button #saveEntry | Speichern | Wert:  | type=submit |

## Ziele-empty

Dialog/Container: `studentDialog`. Klassen: `detail-view`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Ziele |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | text | Gespeichert · 12:00 |  | normal |
| 9 | h3 | In Arbeit 0 |  | normal |
| 10 | button #newGoal | +Neues Ziel | Wert:  | type=button |
| 11 | text | Noch kein Ziel vereinbart. |  | normal |
| 12 | text | Halte fest, was als Nächstes gelingen soll. |  | normal |
| 13 | button #saveEntry | Speichern | Wert:  | verborgen, type=submit |

## Hausübung-empty

Dialog/Container: `studentDialog`. Klassen: `detail-view`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Hausübung |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | text | Alles erledigt |  | normal |
| 9 | button | +Hausübung | Wert:  | type=button |
| 10 | text | Noch keine Hausübung. |  | normal |
| 11 | text | Mit „+ Hausübung“ legst du eine Aufgabenliste an. |  | normal |
| 12 | button #saveEntry | Speichern | Wert:  | verborgen, type=submit |

## Verlauf-empty

Dialog/Container: `studentDialog`. Klassen: `detail-view`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Verlauf |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | verborgen, type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | button | ← Bereiche | Wert:  | verborgen, type=button |
| 9 | button | Verlauf ansehen | Wert:  | verborgen, type=button |
| 10 | h3 | Verlauf |  | verborgen |
| 11 | text | Nach Datum, Bereich und Text filtern. |  | normal |
| 12 | input #historySearch | aria-label: Verlauf durchsuchen | Wert: <br>Platzhalter: Suchen … | type=search |
| 13 | select #historyCategory | Alle BereicheSozialverhaltenArbeitsverhaltenHausübungOrganisatorischesZiele<br>aria-label: Bereich | Wert: <br>Optionen: [{"value": "", "text": "Alle Bereiche", "selected": true}, {"value": "Sozialverhalten", "text": "Sozialverhalten", "selected": false}, {"value": "Arbeitsverhalten", "text": "Arbeitsverhalten", "selected": false}, {"value": "Hausübung", "text": "Hausübung", "selected": false}, {"value": "Organisatorisches", "text": "Organisatorisches", "selected": false}, {"value": "Ziele", "text": "Ziele", "selected": false}] | normal |
| 14 | label | VonDatum wählen |  | normal |
| 15 | text | Von |  | normal |
| 16 | input #historyFrom |  | Wert:  | verborgen, type=date |
| 17 | button | Datum wählen<br>aria-label: Datum: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 18 | label | BisDatum wählen |  | normal |
| 19 | text | Bis |  | normal |
| 20 | input #historyTo |  | Wert:  | verborgen, type=date |
| 21 | button | Datum wählen<br>aria-label: Datum: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 22 | label | Nur offene Nachbereitung |  | normal |
| 23 | input #historyReview |  | Wert: on | type=checkbox, checked=False |
| 24 | text | Nur offene Nachbereitung |  | normal |
| 25 | text | Keine passenden Einträge. |  | normal |
| 26 | button #saveEntry | Speichern | Wert:  | verborgen, type=submit |

## goal-new

Dialog/Container: `studentDialog`. Klassen: `detail-view entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Ziele |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | text | Gespeichert · 12:00 |  | normal |
| 9 | button #goalsBack | Zur Zielübersicht | Wert:  | type=button |
| 10 | label | Was soll erreicht werden? |  | normal |
| 11 | text | Was soll erreicht werden? |  | normal |
| 12 | textarea #entryText |  | Wert: <br>Platzhalter: Ziel … | required=True, maxlength=3000 |
| 13 | label | Zielkriterium optional |  | normal |
| 14 | text | Zielkriterium |  | normal |
| 15 | text | optional |  | normal |
| 16 | textarea #goalCriterion |  | Wert: <br>Platzhalter: Zielkriterium … | maxlength=2000 |
| 17 | label | Nächster Schritt optional |  | normal |
| 18 | text | Nächster Schritt |  | normal |
| 19 | text | optional |  | normal |
| 20 | textarea #goalStep |  | Wert: <br>Platzhalter: Nächster Schritt … | maxlength=2000 |
| 21 | label | Zieltermin optional |  | normal |
| 22 | text | Zieltermin |  | normal |
| 23 | text | optional |  | normal |
| 24 | button | Bis Freitag | Wert:  | type=button, pressed=false |
| 25 | button | Eine Woche | Wert:  | type=button, pressed=false |
| 26 | button | Zwei Wochen | Wert:  | type=button, pressed=false |
| 27 | button | Ein Monat | Wert:  | type=button, pressed=false |
| 28 | input #goalDue |  | Wert:  | verborgen, type=date |
| 29 | button | Datum wählen<br>aria-label: Zieltermin optional: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 30 | h3 | Weitere Angaben |  | verborgen |
| 31 | label | Vereinbart am |  | normal |
| 32 | text | Vereinbart am |  | normal |
| 33 | input #observedAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 34 | input #observedAtDate | aria-label: Vereinbart am | Wert: 2026-11-01 | verborgen, type=date |
| 35 | button | 01.11.2026<br>aria-label: Vereinbart am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 36 | label | Später ergänzen |  | normal |
| 37 | input #entryFollowUp |  | Wert: on | type=checkbox, checked=False |
| 38 | text | Später ergänzen |  | normal |
| 39 | button #saveEntry | Ziel speichern | Wert:  | type=submit |

## homework-new

Dialog/Container: `studentDialog`. Klassen: `detail-view entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Hausübung |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | button | ← Zur Aufgabenliste | Wert:  | type=button |
| 9 | label | Aufgaben |  | normal |
| 10 | text | Aufgaben |  | normal |
| 11 | text | 1. |  | normal |
| 12 | input | aria-label: Aufgabe 1 | Wert: <br>Platzhalter: Aufgabe … | maxlength=1000 |
| 13 | button | ↵<br>aria-label: Weitere Aufgabe<br>Tooltip: Enter: weitere Aufgabe | Wert:  | type=button |
| 14 | button | aria-label: Teilaufgabe hinzufügen<br>Tooltip: Teilaufgabe hinzufügen | Wert:  | type=button |
| 15 | button | ×<br>aria-label: Aufgabe entfernen<br>Tooltip: Aufgabe entfernen | Wert:  | type=button |
| 16 | button | +Aufgabe hinzufügen | Wert:  | type=button |
| 17 | textarea #hwTitle |  | Wert:  | verborgen |
| 18 | label | Fach optional |  | normal |
| 19 | text | Fach |  | normal |
| 20 | text | optional |  | normal |
| 21 | input #hwSubject |  | Wert: <br>Platzhalter: Fach … | maxlength=100 |
| 22 | label | Fällig am optional |  | normal |
| 23 | text | Fällig am |  | normal |
| 24 | text | optional |  | normal |
| 25 | input #hwDue |  | Wert:  | verborgen, type=date |
| 26 | button | Datum wählen<br>aria-label: Fällig am optional: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 27 | h3 | Weitere Angaben |  | normal |
| 28 | label | Für welche Schüler? |  | normal |
| 29 | text | Für welche Schüler? |  | normal |
| 30 | label | Anna Beispiel |  | normal |
| 31 | input |  | Wert: on | type=checkbox, checked=True |
| 32 | text | Anna Beispiel |  | normal |
| 33 | label | Ben Beispiel |  | normal |
| 34 | input |  | Wert: on | type=checkbox, checked=False |
| 35 | text | Ben Beispiel |  | normal |
| 36 | h3 | Weitere Angaben |  | verborgen |
| 37 | label | Aufgegeben am |  | normal |
| 38 | text | Aufgegeben am |  | normal |
| 39 | input #observedAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 40 | input #observedAtDate | aria-label: Aufgegeben am | Wert: 2026-11-01 | verborgen, type=date |
| 41 | button | 01.11.2026<br>aria-label: Aufgegeben am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 42 | label | Später ergänzen |  | normal |
| 43 | input #entryFollowUp |  | Wert: on | type=checkbox, checked=False |
| 44 | text | Später ergänzen |  | normal |
| 45 | button #saveEntry | Hausübung aufgeben | Wert:  | type=submit |

## orga-expanded

Dialog/Container: `studentDialog`. Klassen: `entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Orga |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | text | Gespeichert · 12:00 |  | normal |
| 9 | button | ← Bereiche | Wert:  | verborgen, type=button |
| 10 | button | Verlauf ansehen | Wert:  | verborgen, type=button |
| 11 | h3 | Organisatorisches |  | verborgen |
| 12 | text | Eine kurze Notiz zu Material, Unterschriften oder Absprachen. |  | normal |
| 13 | label | Notiz oder Aufgabe |  | normal |
| 14 | text | Notiz oder Aufgabe |  | normal |
| 15 | button | ☐ Checkliste | Wert:  | type=button |
| 16 | button | • Aufzählung | Wert:  | type=button |
| 17 | button | 1. Nummerierung | Wert:  | type=button |
| 18 | textarea #entryText | Synthetische Notiz | Wert: Synthetische Notiz<br>Platzhalter: Notiz … | required=True, maxlength=10000 |
| 19 | label | Als Aufgabe |  | normal |
| 20 | input #orgTask |  | Wert: on | type=checkbox, checked=True |
| 21 | text | Als Aufgabe |  | normal |
| 22 | label | Termin optional |  | normal |
| 23 | text | Termin |  | normal |
| 24 | text | optional |  | normal |
| 25 | input #orgTaskDue |  | Wert: 2026-11-04 | verborgen, type=date |
| 26 | button | 04.11.2026<br>aria-label: Termin optional: 04.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 27 | label | Aufgabe erledigt |  | normal |
| 28 | input #orgTaskDone |  | Wert: on | type=checkbox, checked=False |
| 29 | text | Aufgabe erledigt |  | normal |
| 30 | label | Erinnern |  | normal |
| 31 | input #orgEnabled |  | Wert: on | type=checkbox, checked=True |
| 32 | text | Erinnern |  | normal |
| 33 | label | Erinnern am |  | normal |
| 34 | text | Erinnern am |  | normal |
| 35 | input #orgDue |  | Wert: 2026-11-03T10:30 | verborgen, type=hidden |
| 36 | input #orgDueDate | aria-label: Erinnern am | Wert: 2026-11-03 | verborgen, type=date |
| 37 | button | 03.11.2026 · 10:30<br>aria-label: Erinnern am: 03.11.2026 · 10:30<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 38 | label | Erinnerungstext optional |  | normal |
| 39 | text | Erinnerungstext |  | normal |
| 40 | text | optional |  | normal |
| 41 | input #orgText |  | Wert: <br>Platzhalter: Wie Notiz … | maxlength=2000 |
| 42 | label | Erinnerung quittiert |  | normal |
| 43 | input #orgDone |  | Wert: on | type=checkbox, checked=False |
| 44 | text | Erinnerung quittiert |  | normal |
| 45 | text | Anzeige in der App |  | normal |
| 46 | h3 | Weitere Angaben |  | verborgen |
| 47 | h3 | Orga |  | normal |
| 48 | button | Alle · 0 | Wert:  | type=button, pressed=true |
| 49 | button | Offen · 0 | Wert:  | type=button, pressed=false |
| 50 | button | Erledigt · 0 | Wert:  | type=button, pressed=false |
| 51 | text | Keine Einträge. |  | normal |
| 52 | label | Beobachtet am |  | normal |
| 53 | text | Beobachtet am |  | normal |
| 54 | input #observedAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 55 | input #observedAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 56 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 57 | label | Später ergänzen |  | normal |
| 58 | input #entryFollowUp |  | Wert: on | type=checkbox, checked=False |
| 59 | text | Später ergänzen |  | normal |
| 60 | button #saveNext | Speichern & weiter →<br>aria-label: Speichern und zum nächsten Schüler<br>Tooltip: Speichern und nächster Schüler | Wert:  | type=button |
| 61 | button #saveEntry | Speichern | Wert:  | type=submit |

## options-positive

Dialog/Container: `optionsDialog`. Klassen: `option-editor`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #optionsTitle | Sozialverhalten · Auswahl |  | normal |
| 2 | button | ×<br>aria-label: Bearbeitung schließen | Wert:  | type=button |
| 3 | text | Diese Auswahllisten gelten für alle Schüler. Bereits gespeicherte Einträge behalten ihren ursprünglichen Text. |  | normal |
| 4 | button | ＋ Positiv | Wert:  | type=button, pressed=true |
| 5 | button | − Negativ | Wert:  | type=button, pressed=false |
| 6 | div #optionsError |  |  | verborgen |
| 7 | label | Auswahleintrag bearbeiten |  | normal |
| 8 | text | Auswahleintrag bearbeiten |  | verborgen |
| 9 | input |  | Wert: Hilft anderen | type=text, maxlength=150 |
| 10 | button | aria-label: Eintrag entfernen: Hilft anderen | Wert:  | type=button |
| 11 | label | Auswahleintrag bearbeiten |  | normal |
| 12 | text | Auswahleintrag bearbeiten |  | verborgen |
| 13 | input |  | Wert: Nimmt Hilfe an | type=text, maxlength=150 |
| 14 | button | aria-label: Eintrag entfernen: Nimmt Hilfe an | Wert:  | type=button |
| 15 | label | Auswahleintrag bearbeiten |  | normal |
| 16 | text | Auswahleintrag bearbeiten |  | verborgen |
| 17 | input |  | Wert: Hält Gesprächsregeln ein | type=text, maxlength=150 |
| 18 | button | aria-label: Eintrag entfernen: Hält Gesprächsregeln ein | Wert:  | type=button |
| 19 | label | Auswahleintrag bearbeiten |  | normal |
| 20 | text | Auswahleintrag bearbeiten |  | verborgen |
| 21 | input |  | Wert: Geht respektvoll mit anderen um | type=text, maxlength=150 |
| 22 | button | aria-label: Eintrag entfernen: Geht respektvoll mit anderen um | Wert:  | type=button |
| 23 | label | Auswahleintrag bearbeiten |  | normal |
| 24 | text | Auswahleintrag bearbeiten |  | verborgen |
| 25 | input |  | Wert: Klärt einen Konflikt im Gespräch | type=text, maxlength=150 |
| 26 | button | aria-label: Eintrag entfernen: Klärt einen Konflikt im Gespräch | Wert:  | type=button |
| 27 | label | Auswahleintrag bearbeiten |  | normal |
| 28 | text | Auswahleintrag bearbeiten |  | verborgen |
| 29 | input |  | Wert: Hält gemeinsame Absprachen ein | type=text, maxlength=150 |
| 30 | button | aria-label: Eintrag entfernen: Hält gemeinsame Absprachen ein | Wert:  | type=button |
| 31 | label | Neuer Auswahleintrag |  | normal |
| 32 | text | Neuer Auswahleintrag |  | normal |
| 33 | input #newOptionText |  | Wert: <br>Platzhalter: Eigener Text … | maxlength=150 |
| 34 | button | +＋ Hinzufügen | Wert:  | type=submit |
| 35 | text | Änderungen werden mit „Änderungen speichern“ übernommen. |  | normal |
| 36 | button | Abbrechen | Wert:  | type=button |
| 37 | button #saveOptions | Änderungen speichern | Wert:  | type=button |

## options-negative

Dialog/Container: `optionsDialog`. Klassen: `option-editor`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #optionsTitle | Sozialverhalten · Auswahl |  | normal |
| 2 | button | ×<br>aria-label: Bearbeitung schließen | Wert:  | type=button |
| 3 | text | Diese Auswahllisten gelten für alle Schüler. Bereits gespeicherte Einträge behalten ihren ursprünglichen Text. |  | normal |
| 4 | button | ＋ Positiv | Wert:  | type=button, pressed=false |
| 5 | button | − Negativ | Wert:  | type=button, pressed=true |
| 6 | div #optionsError |  |  | verborgen |
| 7 | label | Auswahleintrag bearbeiten |  | normal |
| 8 | text | Auswahleintrag bearbeiten |  | verborgen |
| 9 | input |  | Wert: Unterbricht andere wiederholt | type=text, maxlength=150 |
| 10 | button | aria-label: Eintrag entfernen: Unterbricht andere wiederholt | Wert:  | type=button |
| 11 | label | Auswahleintrag bearbeiten |  | normal |
| 12 | text | Auswahleintrag bearbeiten |  | verborgen |
| 13 | input |  | Wert: Spricht andere abwertend an | type=text, maxlength=150 |
| 14 | button | aria-label: Eintrag entfernen: Spricht andere abwertend an | Wert:  | type=button |
| 15 | label | Auswahleintrag bearbeiten |  | normal |
| 16 | text | Auswahleintrag bearbeiten |  | verborgen |
| 17 | input |  | Wert: Hält gemeinsame Absprachen nicht ein | type=text, maxlength=150 |
| 18 | button | aria-label: Eintrag entfernen: Hält gemeinsame Absprachen nicht ein | Wert:  | type=button |
| 19 | label | Auswahleintrag bearbeiten |  | normal |
| 20 | text | Auswahleintrag bearbeiten |  | verborgen |
| 21 | input |  | Wert: Stört die Zusammenarbeit | type=text, maxlength=150 |
| 22 | button | aria-label: Eintrag entfernen: Stört die Zusammenarbeit | Wert:  | type=button |
| 23 | label | Neuer Auswahleintrag |  | normal |
| 24 | text | Neuer Auswahleintrag |  | normal |
| 25 | input #newOptionText |  | Wert: <br>Platzhalter: Eigener Text … | maxlength=150 |
| 26 | button | +＋ Hinzufügen | Wert:  | type=submit |
| 27 | text | Änderungen werden mit „Änderungen speichern“ übernommen. |  | normal |
| 28 | button | Abbrechen | Wert:  | type=button |
| 29 | button #saveOptions | Änderungen speichern | Wert:  | type=button |

## pupil

Dialog/Container: `pupilDialog`. Klassen: `small-dialog`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #pupilTitle | Schüler verwalten |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | normal |
| 3 | label | Name |  | normal |
| 4 | text | Name |  | normal |
| 5 | input #pupilName |  | Wert: Anna Beispiel | maxlength=80 |
| 6 | legend | Farbe |  | normal |
| 7 | button | aria-label: Farbe 1: #53747e<br>Tooltip: #53747e | Wert:  | type=button, pressed=false |
| 8 | button | aria-label: Farbe 2: #756582<br>Tooltip: #756582 | Wert:  | type=button, pressed=false |
| 9 | button | aria-label: Farbe 3: #49765a<br>Tooltip: #49765a | Wert:  | type=button, pressed=false |
| 10 | button | aria-label: Farbe 4: #b87943<br>Tooltip: #b87943 | Wert:  | type=button, pressed=false |
| 11 | button | aria-label: Farbe 5: #ac5d72<br>Tooltip: #ac5d72 | Wert:  | type=button, pressed=false |
| 12 | button | aria-label: Farbe 6: #487f85<br>Tooltip: #487f85 | Wert:  | type=button, pressed=false |
| 13 | button | aria-label: Farbe 7: #8a7845<br>Tooltip: #8a7845 | Wert:  | type=button, pressed=false |
| 14 | button | aria-label: Farbe 8: #6478a6<br>Tooltip: #6478a6 | Wert:  | type=button, pressed=false |
| 15 | button | aria-label: Farbe 9: #8c6553<br>Tooltip: #8c6553 | Wert:  | type=button, pressed=false |
| 16 | button | aria-label: Farbe 10: #73834c<br>Tooltip: #73834c | Wert:  | type=button, pressed=false |
| 17 | label | Eigene Farbe wählen |  | normal |
| 18 | input #pupilColor |  | Wert: #65846c | type=color |
| 19 | text | Eigene Farbe wählen |  | normal |
| 20 | label | Schüler archivieren |  | normal |
| 21 | input #pupilArchived |  | Wert: on | type=checkbox, checked=False |
| 22 | text | Schüler archivieren |  | normal |
| 23 | text | Alle Einträge bleiben erhalten. Archivierte Schüler findest du im Menü unter „Archiv“. |  | normal |
| 24 | button #commitPupil | Speichern | Wert:  | normal |

## drafts

Dialog/Container: `draftDialog`. Klassen: ``.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #draftTitle | Gesicherte Entwürfe |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | normal |
| 3 | text | Keine gesicherten Entwürfe. |  | normal |

## brief-empty

Dialog/Container: `briefDialog`. Klassen: `detail-view`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #briefTitle | Gespräch vorbereiten |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | normal |
| 3 | label | Namen weiterer Beteiligter aufnehmen |  | normal |
| 4 | input #briefIncludeNames |  | Wert: on | type=checkbox, checked=False |
| 5 | text | Namen weiterer Beteiligter aufnehmen |  | normal |
| 6 | label | Von |  | normal |
| 7 | text | Von |  | normal |
| 8 | input #briefFrom |  | Wert:  | verborgen, type=date |
| 9 | button | Datum wählen<br>aria-label: Von: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 10 | label | Bis |  | normal |
| 11 | text | Bis |  | normal |
| 12 | input #briefTo |  | Wert: 2026-11-01 | verborgen, type=date |
| 13 | button | Datum wählen<br>aria-label: Bis: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 14 | button #selectBriefAll | Alle auswählen | Wert:  | normal |
| 15 | button #clearBrief | Auswahl leeren | Wert:  | normal |
| 16 | text | Keine Einträge in diesem Zeitraum. |  | normal |
| 17 | button #createBrief | Auswahl zusammenstellen | Wert:  | normal |
| 18 | button #copyBrief | Text kopieren | Wert:  | verborgen |
| 19 | button #downloadBrief | Als Textdatei sichern | Wert:  | verborgen |

## class-list-empty

Dialog/Container: `classTasksDialog`. Klassen: `detail-view`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 | Klassen-Orga |  | normal |
| 2 | button | × | Wert:  | type=button |
| 3 | button | Alle | Wert:  | type=button, pressed=true |
| 4 | button | Offen | Wert:  | type=button, pressed=false |
| 5 | button | Erledigt | Wert:  | type=button, pressed=false |
| 6 | text | Keine Einträge. |  | normal |
| 7 | button #newClassTask | Eintrag hinzufügen | Wert:  | type=button |

## class-new

Dialog/Container: `classTaskDialog`. Klassen: ``.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 | Klassen-Orga |  | normal |
| 2 | button | × | Wert:  | type=button |
| 3 | label | Notiz oder Aufgabe |  | normal |
| 4 | text | Notiz oder Aufgabe |  | normal |
| 5 | button | ☐ Checkliste | Wert:  | type=button |
| 6 | button | • Aufzählung | Wert:  | type=button |
| 7 | button | 1. Nummerierung | Wert:  | type=button |
| 8 | textarea #classTaskText |  | Wert: <br>Platzhalter: Notiz … | required=True, maxlength=12000 |
| 9 | label | Als Aufgabe |  | normal |
| 10 | input #classOrgTask |  | Wert: on | type=checkbox, checked=True |
| 11 | text | Als Aufgabe |  | normal |
| 12 | label | Termin optional |  | normal |
| 13 | text | Termin |  | normal |
| 14 | text | optional |  | normal |
| 15 | input #classOrgTaskDue |  | Wert:  | verborgen, type=date |
| 16 | button | Datum wählen<br>aria-label: Termin optional: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 17 | label | Aufgabe erledigt |  | normal |
| 18 | input #classOrgTaskDone |  | Wert: on | type=checkbox, checked=False |
| 19 | text | Aufgabe erledigt |  | normal |
| 20 | label | Erinnern |  | normal |
| 21 | input #classOrgEnabled |  | Wert: on | type=checkbox, checked=False |
| 22 | text | Erinnern |  | normal |
| 23 | label | Erinnern am |  | verborgen |
| 24 | text | Erinnern am |  | verborgen |
| 25 | input #classOrgDue |  | Wert:  | verborgen, type=hidden |
| 26 | input #classOrgDueDate | aria-label: Erinnern am | Wert:  | verborgen, type=date |
| 27 | button | Datum wählen<br>aria-label: Erinnern am: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | verborgen, type=button |
| 28 | label | Erinnerungstext optional |  | verborgen |
| 29 | text | Erinnerungstext |  | verborgen |
| 30 | text | optional |  | verborgen |
| 31 | input #classOrgText |  | Wert: <br>Platzhalter: Wie Notiz … | verborgen, maxlength=2000 |
| 32 | label | Erinnerung quittiert |  | verborgen |
| 33 | input #classOrgDone |  | Wert: on | verborgen, type=checkbox, checked=False |
| 34 | text | Erinnerung quittiert |  | verborgen |
| 35 | text | Anzeige in der App |  | verborgen |
| 36 | button | Speichern | Wert:  | type=submit |

## trash-empty

Dialog/Container: `trashDialog`. Klassen: ``.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #trashTitle | Papierkorb |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Hier abgelegte Einträge sind ausgeblendet und weiterhin in Sicherungen enthalten. |  | normal |
| 4 | text | Der Papierkorb ist leer. |  | normal |
| 5 | button | Papierkorb endgültig leeren | Wert:  | type=button |

## maintenance

Dialog/Container: `maintenanceDialog`. Klassen: ``.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #maintenanceTitle | Speicher pflegen |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Das Änderungsprotokoll wird zu einem geprüften Ausgangsstand zusammengefasst. Einträge, frühere Fassungen und Entwürfe bleiben erhalten. Alte technische Speicherstände werden anschließend entfernt. |  | normal |
| 4 | button #maintenanceExport | Vollständige Sicherung herunterladen | Wert:  | type=button |
| 5 | label | Ich habe die Sicherung gespeichert und andere App-Tabs geschlossen. |  | normal |
| 6 | input #maintenanceReady |  | Wert: on | type=checkbox, checked=False |
| 7 | text | Ich habe die Sicherung gespeichert und andere App-Tabs geschlossen. |  | normal |
| 8 | label | Zum endgültigen Löschen LÖSCHEN eingeben |  | verborgen |
| 9 | text | Zum endgültigen Löschen LÖSCHEN eingeben |  | verborgen |
| 10 | input #purgeWord |  | Wert:  | verborgen, type=text |
| 11 | p #maintenanceError |  |  | verborgen |
| 12 | button #commitMaintenance | Ausführen | Wert:  | type=button |

## purge

Dialog/Container: `maintenanceDialog`. Klassen: ``.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #maintenanceTitle | Papierkorb endgültig leeren |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Gelöschte Einträge und ihre alten technischen Speicherstände werden endgültig entfernt. Verknüpfungen zu gelöschten Zielen werden bereinigt. Vorhandene Sicherungsdateien bleiben unverändert. |  | normal |
| 4 | button #maintenanceExport | Vollständige Sicherung herunterladen | Wert:  | type=button |
| 5 | label | Ich habe die Sicherung gespeichert und andere App-Tabs geschlossen. |  | normal |
| 6 | input #maintenanceReady |  | Wert: on | type=checkbox, checked=False |
| 7 | text | Ich habe die Sicherung gespeichert und andere App-Tabs geschlossen. |  | normal |
| 8 | label | Zum endgültigen Löschen LÖSCHEN eingeben |  | normal |
| 9 | text | Zum endgültigen Löschen LÖSCHEN eingeben |  | normal |
| 10 | input #purgeWord |  | Wert:  | type=text |
| 11 | p #maintenanceError |  |  | verborgen |
| 12 | button #commitMaintenance | Ausführen | Wert:  | type=button |

## conflicts-empty

Dialog/Container: `conflictDialog`. Klassen: `detail-view`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 | Änderungskonflikte |  | normal |
| 2 | button | × | Wert:  | type=button |
| 3 | text | Keine offenen Konflikte. |  | normal |

## backup

Dialog/Container: `backupDialog`. Klassen: `small-dialog`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #backupTitle | Datensicherung |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | normal |
| 3 | label | Sicherung mit Passwort verschlüsseln |  | normal |
| 4 | input #encryptBackup |  | Wert: on | type=checkbox, checked=True |
| 5 | text | Sicherung mit Passwort verschlüsseln |  | normal |
| 6 | label | Darstellung und Hintergrundbild mitsichern |  | normal |
| 7 | input #exportAppearance |  | Wert: on | type=checkbox, checked=True |
| 8 | text | Darstellung und Hintergrundbild mitsichern |  | normal |
| 9 | button #exportData | Exportieren | Wert:  | normal |
| 10 | button #importData | Importieren | Wert:  | normal |
| 11 | input #importFile |  | Wert:  | verborgen, type=file |
| 12 | label | Auswahllisten aus der Sicherung übernehmen |  | normal |
| 13 | input #importOptionLists |  | Wert: on | type=checkbox, checked=True |
| 14 | text | Auswahllisten aus der Sicherung übernehmen |  | normal |
| 15 | text | Die Datei enthält Unterrichtsdaten und Entwürfe im Klartext, einschließlich Papierkorb und früherer Fassungen. Mit eingeschalteter Option enthält sie zusätzlich Einstellungen und Bild. Bewahre sie an einem geschützten Ort auf. |  | normal |

## Sozialverhalten-edit

Dialog/Container: `recordDialog`. Klassen: `entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #recordTitle | Eintrag bearbeiten |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | normal |
| 3 | label | Bereich |  | normal |
| 4 | text | Bereich |  | normal |
| 5 | select #recordCategory | SozialverhaltenArbeitsverhalten | Wert: Sozialverhalten<br>Optionen: [{"value": "Sozialverhalten", "text": "Sozialverhalten", "selected": true}, {"value": "Arbeitsverhalten", "text": "Arbeitsverhalten", "selected": false}] | normal |
| 6 | label | Was ist passiert? optional bei Auswahl |  | normal |
| 7 | text | Was ist passiert? |  | normal |
| 8 | text | optional bei Auswahl |  | normal |
| 9 | button | Vor dem Unterricht | Wert:  | type=button, pressed=false |
| 10 | button | Während des Unterrichts | Wert:  | type=button, pressed=false |
| 11 | button | Nach dem Unterricht | Wert:  | type=button, pressed=false |
| 12 | button | Pause | Wert:  | type=button, pressed=false |
| 13 | button | + Hilft anderen ×<br>aria-label: Auswahl entfernen: Hilft anderen | Wert:  | type=button |
| 14 | textarea #recordText | Synthetischer Eintrag | Wert: Synthetischer Eintrag<br>Platzhalter: Beobachtung … | verborgen, maxlength=4000 |
| 15 | textarea #recordTextNarrativeFree |  | Wert: Synthetischer Eintrag<br>Platzhalter: Beobachtung … | maxlength=4000 |
| 16 | label | Beteiligt |  | normal |
| 17 | input #recordParticipantsEnabled |  | Wert: on | type=checkbox, checked=True |
| 18 | text | Beteiligt |  | normal |
| 19 | text | Schüler auswählen |  | normal |
| 20 | button | Anna Beispiel | Wert:  | type=button, pressed=false |
| 21 | button | Ben Beispiel | Wert:  | type=button, pressed=true |
| 22 | label | Weitere Namen |  | normal |
| 23 | text | Weitere Namen |  | normal |
| 24 | input #recordParticipantsNames |  | Wert: <br>Platzhalter: Name; Name … | type=text, maxlength=12000 |
| 25 | input #recordParticipantsValue |  | Wert: [{"studentId":"audit-b","name":"Ben Beispiel"}] | verborgen, type=hidden |
| 26 | summary | Auswahl bearbeiten |  | normal |
| 27 | select | PositivNegativ<br>aria-label: Bewertung der Beobachtung | Wert: positive<br>Optionen: [{"value": "positive", "text": "Positiv", "selected": true}, {"value": "negative", "text": "Negativ", "selected": false}] | eingeklappt |
| 28 | input | aria-label: Beobachtung | Wert: Hilft anderen | eingeklappt, maxlength=300 |
| 29 | button | ×<br>aria-label: Beobachtung entfernen | Wert:  | eingeklappt, type=button |
| 30 | button #addRecordChoice | Beobachtung ergänzen | Wert:  | eingeklappt |
| 31 | label | Reaktion / Unterstützung |  | normal |
| 32 | input #recordSupport |  | Wert: on | type=checkbox, checked=True |
| 33 | text | Reaktion / Unterstützung |  | normal |
| 34 | input #recordSupportNote | aria-label: Benötigte Unterstützung | Wert: Synthetische Unterstützung<br>Platzhalter: Unterstützung … | normal |
| 35 | label | Zielbezug |  | normal |
| 36 | input #recordGoalLinkEnabled |  | Wert: on | type=checkbox, checked=False |
| 37 | text | Zielbezug |  | normal |
| 38 | label | Ziel auswählen |  | verborgen |
| 39 | text | Ziel auswählen |  | verborgen |
| 40 | select #recordGoalLink | Ohne Zielzuordnung | Wert: <br>Optionen: [{"value": "", "text": "Ohne Zielzuordnung", "selected": true}] | verborgen, disabled=True |
| 41 | text | Kein aktives Ziel vorhanden. |  | verborgen |
| 42 | h3 | Weitere Angaben |  | normal |
| 43 | label | Schüler |  | normal |
| 44 | text | Schüler |  | normal |
| 45 | select #recordPupil | Anna BeispielBen Beispiel | Wert: audit-a<br>Optionen: [{"value": "audit-a", "text": "Anna Beispiel", "selected": true}, {"value": "audit-b", "text": "Ben Beispiel", "selected": false}] | normal |
| 46 | label | Quelle |  | normal |
| 47 | text | Quelle |  | normal |
| 48 | select #recordSourceKind | Selbst beobachtetBerichtetEigene Einordnung | Wert: reported<br>Optionen: [{"value": "own", "text": "Selbst beobachtet", "selected": false}, {"value": "reported", "text": "Berichtet", "selected": true}, {"value": "interpretation", "text": "Eigene Einordnung", "selected": false}] | normal |
| 49 | button | Gemeinsamen Kontext bearbeiten | Wert:  | type=button |
| 50 | label | Beobachtet am |  | normal |
| 51 | text | Beobachtet am |  | normal |
| 52 | input #recordAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 53 | input #recordAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 54 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 55 | label | Später ergänzen |  | normal |
| 56 | input #recordFollowUp |  | Wert: on | type=checkbox, checked=True |
| 57 | text | Später ergänzen |  | normal |
| 58 | text | Die bisherige Fassung bleibt im Änderungsverlauf. |  | normal |
| 59 | button #commitRecord | Änderungen speichern | Wert:  | normal |

## Arbeitsverhalten-edit

Dialog/Container: `recordDialog`. Klassen: `entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #recordTitle | Eintrag bearbeiten |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | normal |
| 3 | label | Bereich |  | normal |
| 4 | text | Bereich |  | normal |
| 5 | select #recordCategory | SozialverhaltenArbeitsverhalten | Wert: Arbeitsverhalten<br>Optionen: [{"value": "Sozialverhalten", "text": "Sozialverhalten", "selected": false}, {"value": "Arbeitsverhalten", "text": "Arbeitsverhalten", "selected": true}] | normal |
| 6 | label | Notiz |  | normal |
| 7 | text | Notiz |  | normal |
| 8 | button | + Beginnt selbstständig ×<br>aria-label: Auswahl entfernen: Beginnt selbstständig | Wert:  | type=button |
| 9 | textarea #recordText | Synthetischer Eintrag | Wert: Synthetischer Eintrag | normal |
| 10 | label | Auftrag |  | normal |
| 11 | text | Auftrag |  | normal |
| 12 | text | Zuletzt verwendet |  | normal |
| 13 | button | Lesen | Wert:  | type=button, pressed=false |
| 14 | input #recordTaskFree | aria-label: Auftrag – eigener Text | Wert: Lesen<br>Platzhalter: Auftrag … | type=text, maxlength=1000 |
| 15 | input #recordTask |  | Wert: Lesen | verborgen, maxlength=1000 |
| 16 | summary | Auswahl bearbeiten |  | normal |
| 17 | select | PositivNegativ<br>aria-label: Bewertung der Beobachtung | Wert: positive<br>Optionen: [{"value": "positive", "text": "Positiv", "selected": true}, {"value": "negative", "text": "Negativ", "selected": false}] | eingeklappt |
| 18 | input | aria-label: Beobachtung | Wert: Beginnt selbstständig | eingeklappt, maxlength=300 |
| 19 | button | ×<br>aria-label: Beobachtung entfernen | Wert:  | eingeklappt, type=button |
| 20 | button #addRecordChoice | Beobachtung ergänzen | Wert:  | eingeklappt |
| 21 | label | Reaktion / Unterstützung |  | normal |
| 22 | input #recordSupport |  | Wert: on | type=checkbox, checked=True |
| 23 | text | Reaktion / Unterstützung |  | normal |
| 24 | input #recordSupportNote | aria-label: Benötigte Unterstützung | Wert: Synthetische Unterstützung<br>Platzhalter: Unterstützung … | normal |
| 25 | label | Zielbezug |  | normal |
| 26 | input #recordGoalLinkEnabled |  | Wert: on | type=checkbox, checked=False |
| 27 | text | Zielbezug |  | normal |
| 28 | label | Ziel auswählen |  | verborgen |
| 29 | text | Ziel auswählen |  | verborgen |
| 30 | select #recordGoalLink | Ohne Zielzuordnung | Wert: <br>Optionen: [{"value": "", "text": "Ohne Zielzuordnung", "selected": true}] | verborgen, disabled=True |
| 31 | text | Kein aktives Ziel vorhanden. |  | verborgen |
| 32 | h3 | Weitere Angaben |  | normal |
| 33 | label | Schüler |  | normal |
| 34 | text | Schüler |  | normal |
| 35 | select #recordPupil | Anna BeispielBen Beispiel | Wert: audit-a<br>Optionen: [{"value": "audit-a", "text": "Anna Beispiel", "selected": true}, {"value": "audit-b", "text": "Ben Beispiel", "selected": false}] | normal |
| 36 | label | Quelle |  | normal |
| 37 | text | Quelle |  | normal |
| 38 | select #recordSourceKind | Selbst beobachtetBerichtetEigene Einordnung | Wert: reported<br>Optionen: [{"value": "own", "text": "Selbst beobachtet", "selected": false}, {"value": "reported", "text": "Berichtet", "selected": true}, {"value": "interpretation", "text": "Eigene Einordnung", "selected": false}] | normal |
| 39 | button | Gemeinsamen Kontext bearbeiten | Wert:  | type=button |
| 40 | label | Beobachtet am |  | normal |
| 41 | text | Beobachtet am |  | normal |
| 42 | input #recordAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 43 | input #recordAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 44 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 45 | label | Später ergänzen |  | normal |
| 46 | input #recordFollowUp |  | Wert: on | type=checkbox, checked=True |
| 47 | text | Später ergänzen |  | normal |
| 48 | text | Die bisherige Fassung bleibt im Änderungsverlauf. |  | normal |
| 49 | button #commitRecord | Änderungen speichern | Wert:  | normal |

## Organisatorisches-edit

Dialog/Container: `recordDialog`. Klassen: `entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #recordTitle | Eintrag bearbeiten |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | normal |
| 3 | label | Notiz |  | normal |
| 4 | text | Notiz |  | normal |
| 5 | button | ☐ Checkliste | Wert:  | type=button |
| 6 | button | • Aufzählung | Wert:  | type=button |
| 7 | button | 1. Nummerierung | Wert:  | type=button |
| 8 | textarea #recordText | Synthetischer Eintrag | Wert: Synthetischer Eintrag | normal |
| 9 | label | Als Aufgabe |  | normal |
| 10 | input #recordOrgTask |  | Wert: on | type=checkbox, checked=False |
| 11 | text | Als Aufgabe |  | normal |
| 12 | label | Termin optional |  | verborgen |
| 13 | text | Termin |  | verborgen |
| 14 | text | optional |  | verborgen |
| 15 | input #recordOrgTaskDue |  | Wert:  | verborgen, type=date |
| 16 | button | Datum wählen<br>aria-label: Termin optional: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | verborgen, type=button |
| 17 | label | Aufgabe erledigt |  | verborgen |
| 18 | input #recordOrgTaskDone |  | Wert: on | verborgen, type=checkbox, checked=False |
| 19 | text | Aufgabe erledigt |  | verborgen |
| 20 | label | Erinnern |  | normal |
| 21 | input #recordOrgEnabled |  | Wert: on | type=checkbox, checked=False |
| 22 | text | Erinnern |  | normal |
| 23 | label | Erinnern am |  | verborgen |
| 24 | text | Erinnern am |  | verborgen |
| 25 | input #recordOrgDue |  | Wert:  | verborgen, type=hidden |
| 26 | input #recordOrgDueDate | aria-label: Erinnern am | Wert:  | verborgen, type=date |
| 27 | button | Datum wählen<br>aria-label: Erinnern am: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | verborgen, type=button |
| 28 | label | Erinnerungstext optional |  | verborgen |
| 29 | text | Erinnerungstext |  | verborgen |
| 30 | text | optional |  | verborgen |
| 31 | input #recordOrgText |  | Wert: <br>Platzhalter: Wie Notiz … | verborgen, maxlength=2000 |
| 32 | label | Erinnerung quittiert |  | verborgen |
| 33 | input #recordOrgDone |  | Wert: on | verborgen, type=checkbox, checked=False |
| 34 | text | Erinnerung quittiert |  | verborgen |
| 35 | text | Anzeige in der App |  | verborgen |
| 36 | h3 | Weitere Angaben |  | normal |
| 37 | label | Schüler |  | normal |
| 38 | text | Schüler |  | normal |
| 39 | select #recordPupil | Anna BeispielBen Beispiel | Wert: audit-a<br>Optionen: [{"value": "audit-a", "text": "Anna Beispiel", "selected": true}, {"value": "audit-b", "text": "Ben Beispiel", "selected": false}] | normal |
| 40 | label | Beobachtet am |  | normal |
| 41 | text | Beobachtet am |  | normal |
| 42 | input #recordAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 43 | input #recordAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 44 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 45 | label | Später ergänzen |  | normal |
| 46 | input #recordFollowUp |  | Wert: on | type=checkbox, checked=False |
| 47 | text | Später ergänzen |  | normal |
| 48 | text | Die bisherige Fassung bleibt im Änderungsverlauf. |  | normal |
| 49 | button #commitRecord | Änderungen speichern | Wert:  | normal |

## Ziele-edit

Dialog/Container: `recordDialog`. Klassen: `entry-experience editing-goal`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #recordTitle | Eintrag bearbeiten |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | normal |
| 3 | label | Ziel |  | normal |
| 4 | text | Ziel |  | normal |
| 5 | textarea #recordText | Synthetischer Eintrag | Wert: Synthetischer Eintrag | normal |
| 6 | label | Zielkriterium optional |  | normal |
| 7 | text | Zielkriterium |  | normal |
| 8 | text | optional |  | normal |
| 9 | textarea #recordGoalCriterion | Synthetisches Kriterium | Wert: Synthetisches Kriterium<br>Platzhalter: Zielkriterium … | maxlength=2000 |
| 10 | label | Nächster Schritt optional |  | normal |
| 11 | text | Nächster Schritt |  | normal |
| 12 | text | optional |  | normal |
| 13 | textarea #recordGoalStep | Synthetischer Schritt | Wert: Synthetischer Schritt | maxlength=2000 |
| 14 | label | Zieltermin optional |  | normal |
| 15 | text | Zieltermin |  | normal |
| 16 | text | optional |  | normal |
| 17 | button | Bis Freitag | Wert:  | type=button, pressed=false |
| 18 | button | Eine Woche | Wert:  | type=button, pressed=false |
| 19 | button | Zwei Wochen | Wert:  | type=button, pressed=false |
| 20 | button | Ein Monat | Wert:  | type=button, pressed=false |
| 21 | input #recordGoalDue |  | Wert: 2026-11-10 | verborgen, type=date |
| 22 | button | 10.11.2026<br>aria-label: Zieltermin optional: 10.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 23 | label | Stand |  | normal |
| 24 | text | Stand |  | normal |
| 25 | select #recordGoalStatus | In ArbeitErreichtBeendet | Wert: active<br>Optionen: [{"value": "active", "text": "In Arbeit", "selected": true}, {"value": "reached", "text": "Erreicht", "selected": false}, {"value": "closed", "text": "Beendet", "selected": false}] | normal |
| 26 | h3 | Weitere Angaben |  | normal |
| 27 | label | Schüler |  | normal |
| 28 | text | Schüler |  | normal |
| 29 | select #recordPupil | Anna BeispielBen Beispiel | Wert: audit-a<br>Optionen: [{"value": "audit-a", "text": "Anna Beispiel", "selected": true}, {"value": "audit-b", "text": "Ben Beispiel", "selected": false}] | normal |
| 30 | label | Schülerperspektive · optional |  | normal |
| 31 | text | Schülerperspektive · optional |  | normal |
| 32 | textarea #recordGoalPerspective |  | Wert: <br>Platzhalter: Eigene Sicht … | maxlength=2000 |
| 33 | label | Vereinbart am |  | normal |
| 34 | text | Vereinbart am |  | normal |
| 35 | input #recordAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 36 | input #recordAtDate | aria-label: Vereinbart am | Wert: 2026-11-01 | verborgen, type=date |
| 37 | button | 01.11.2026<br>aria-label: Vereinbart am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 38 | label | Später ergänzen |  | normal |
| 39 | input #recordFollowUp |  | Wert: on | type=checkbox, checked=False |
| 40 | text | Später ergänzen |  | normal |
| 41 | text | Die bisherige Fassung bleibt im Änderungsverlauf. |  | normal |
| 42 | button #commitRecord | Änderungen speichern | Wert:  | normal |

## goal-review-continue

Dialog/Container: `goalReviewDialog`. Klassen: `detail-view`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #goalReviewTitle | Ziel überprüfen |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Anna Beispiel · Synthetischer Eintrag |  | normal |
| 4 | text | Zielkriterium: Synthetisches Kriterium |  | normal |
| 5 | text | Noch keine verknüpften Beobachtungen. |  | normal |
| 6 | label | Was hat sich gezeigt? optional |  | normal |
| 7 | text | Was hat sich gezeigt? |  | normal |
| 8 | text | optional |  | normal |
| 9 | textarea #goalReviewNote |  | Wert: <br>Platzhalter: Beobachtung … | maxlength=2000 |
| 10 | label | Entscheidung |  | normal |
| 11 | text | Entscheidung |  | normal |
| 12 | select #goalReviewOutcome | FortführenZiel erreichtBeenden, ohne es als erreicht zu markieren | Wert: continue<br>Optionen: [{"value": "continue", "text": "Fortführen", "selected": true}, {"value": "reached", "text": "Ziel erreicht", "selected": false}, {"value": "closed", "text": "Beenden, ohne es als erreicht zu markieren", "selected": false}] | normal |
| 13 | label | Nächster Schritt optional |  | normal |
| 14 | text | Nächster Schritt |  | normal |
| 15 | text | optional |  | normal |
| 16 | textarea #goalReviewStep |  | Wert: Synthetischer Schritt | maxlength=2000 |
| 17 | label | Nächste Überprüfung |  | normal |
| 18 | text | Nächste Überprüfung |  | normal |
| 19 | input #goalReviewDue |  | Wert: 2026-11-08 | verborgen, type=date |
| 20 | button | Datum wählen<br>aria-label: Nächste Überprüfung: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 21 | p #goalReviewError |  |  | verborgen |
| 22 | button | Überprüfung speichern | Wert:  | type=submit |

## goal-review-reached

Dialog/Container: `goalReviewDialog`. Klassen: `detail-view`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #goalReviewTitle | Ziel überprüfen |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Anna Beispiel · Synthetischer Eintrag |  | normal |
| 4 | text | Zielkriterium: Synthetisches Kriterium |  | normal |
| 5 | text | Noch keine verknüpften Beobachtungen. |  | normal |
| 6 | label | Was hat sich gezeigt? optional |  | normal |
| 7 | text | Was hat sich gezeigt? |  | normal |
| 8 | text | optional |  | normal |
| 9 | textarea #goalReviewNote |  | Wert: <br>Platzhalter: Beobachtung … | maxlength=2000 |
| 10 | label | Entscheidung |  | normal |
| 11 | text | Entscheidung |  | normal |
| 12 | select #goalReviewOutcome | FortführenZiel erreichtBeenden, ohne es als erreicht zu markieren | Wert: reached<br>Optionen: [{"value": "continue", "text": "Fortführen", "selected": false}, {"value": "reached", "text": "Ziel erreicht", "selected": true}, {"value": "closed", "text": "Beenden, ohne es als erreicht zu markieren", "selected": false}] | normal |
| 13 | label | Nächster Schritt optional |  | verborgen |
| 14 | text | Nächster Schritt |  | verborgen |
| 15 | text | optional |  | verborgen |
| 16 | textarea #goalReviewStep |  | Wert: Synthetischer Schritt | verborgen, maxlength=2000 |
| 17 | label | Nächste Überprüfung |  | verborgen |
| 18 | text | Nächste Überprüfung |  | verborgen |
| 19 | input #goalReviewDue |  | Wert: 2026-11-08 | verborgen, type=date |
| 20 | button | Datum wählen<br>aria-label: Nächste Überprüfung: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | verborgen, type=button |
| 21 | p #goalReviewError |  |  | verborgen |
| 22 | button | Überprüfung speichern | Wert:  | type=submit |

## goal-review-error

Dialog/Container: `goalReviewDialog`. Klassen: `detail-view`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #goalReviewTitle | Ziel überprüfen |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Anna Beispiel · Synthetischer Eintrag |  | normal |
| 4 | text | Zielkriterium: Synthetisches Kriterium |  | normal |
| 5 | text | Noch keine verknüpften Beobachtungen. |  | normal |
| 6 | label | Was hat sich gezeigt? optional |  | normal |
| 7 | text | Was hat sich gezeigt? |  | normal |
| 8 | text | optional |  | normal |
| 9 | textarea #goalReviewNote |  | Wert: <br>Platzhalter: Beobachtung … | maxlength=2000 |
| 10 | label | Entscheidung |  | normal |
| 11 | text | Entscheidung |  | normal |
| 12 | select #goalReviewOutcome | FortführenZiel erreichtBeenden, ohne es als erreicht zu markieren | Wert: continue<br>Optionen: [{"value": "continue", "text": "Fortführen", "selected": true}, {"value": "reached", "text": "Ziel erreicht", "selected": false}, {"value": "closed", "text": "Beenden, ohne es als erreicht zu markieren", "selected": false}] | normal |
| 13 | label | Nächster Schritt optional |  | normal |
| 14 | text | Nächster Schritt |  | normal |
| 15 | text | optional |  | normal |
| 16 | textarea #goalReviewStep |  | Wert: Synthetischer Schritt | maxlength=2000 |
| 17 | label | Nächste Überprüfung |  | normal |
| 18 | text | Nächste Überprüfung |  | normal |
| 19 | input #goalReviewDue |  | Wert:  | verborgen, type=date |
| 20 | button | Datum wählen<br>aria-label: Nächste Überprüfung: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 21 | p #goalReviewError | Bitte einen gültigen nächsten Prüftermin wählen. |  | normal |
| 22 | text | Bitte einen gültigen nächsten Prüftermin wählen. |  | normal |
| 23 | button | Überprüfung speichern | Wert:  | type=submit |

## goal-list-filled

Dialog/Container: `studentDialog`. Klassen: `detail-view`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Ziele |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | text | Gespeichert · 12:00 |  | normal |
| 9 | h3 | In Arbeit 1 |  | normal |
| 10 | button #newGoal | +Neues Ziel | Wert:  | type=button |
| 11 | h3 | Synthetischer Eintrag |  | normal |
| 12 | button | aria-label: Ziel bearbeiten<br>Tooltip: Ziel bearbeiten | Wert:  | type=button |
| 13 | button | aria-label: Ziel löschen<br>Tooltip: Ziel löschen | Wert:  | type=button |
| 14 | text | Zielkriterium |  | normal |
| 15 | text | Synthetisches Kriterium |  | normal |
| 16 | text | Nächster Schritt |  | normal |
| 17 | text | Synthetischer Schritt |  | normal |
| 18 | text | Überprüfen · 08.11.2026 |  | normal |
| 19 | button | Erreicht | Wert:  | type=button |
| 20 | button | Ziel überprüfen | Wert:  | type=button |
| 21 | button #saveEntry | Speichern | Wert:  | verborgen, type=submit |

## homework-list-filled

Dialog/Container: `studentDialog`. Klassen: `detail-view`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Hausübung |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | text | 1 offen |  | normal |
| 9 | button | +Hausübung | Wert:  | type=button |
| 10 | button | DeutschAufgegeben am 01.11.2026Bis 05.11.20260/2 | Wert:  | type=button, expanded=true |
| 11 | button | aria-label: Hausübung bearbeiten<br>Tooltip: Bearbeiten | Wert:  | type=button |
| 12 | label | Aufgabe A |  | normal |
| 13 | input |  | Wert: on | type=checkbox, checked=False |
| 14 | text | Aufgabe A |  | normal |
| 15 | button | aria-label: Kommentar und Bearbeitungsstand: Aufgabe A<br>Tooltip: Kommentar & Stand | Wert:  | type=button |
| 16 | label | Teilaufgabe B |  | normal |
| 17 | input |  | Wert: on | type=checkbox, checked=False |
| 18 | text | Teilaufgabe B |  | normal |
| 19 | button | aria-label: Kommentar und Bearbeitungsstand: Teilaufgabe B<br>Tooltip: Kommentar & Stand | Wert:  | type=button |
| 20 | button | Notiz & Verlauf | Wert:  | type=button |
| 21 | button | Löschen<br>aria-label: Hausübung löschen | Wert:  | type=button |
| 22 | button #saveEntry | Speichern | Wert:  | verborgen, type=submit |

## homework-edit

Dialog/Container: `homeworkEditDialog`. Klassen: `detail-view`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 | Hausübung bearbeiten |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Aufgegeben am 01.11.2026 |  | normal |
| 4 | label | Aufgaben & Teilaufgaben |  | normal |
| 5 | text | Aufgaben & Teilaufgaben |  | normal |
| 6 | text | 1. |  | normal |
| 7 | input | aria-label: Aufgabe 1 | Wert: Aufgabe A<br>Platzhalter: Aufgabe … | maxlength=1000 |
| 8 | button | ↵<br>aria-label: Weitere Aufgabe<br>Tooltip: Enter: weitere Aufgabe | Wert:  | type=button |
| 9 | button | aria-label: Teilaufgabe hinzufügen<br>Tooltip: Teilaufgabe hinzufügen | Wert:  | type=button |
| 10 | button | ×<br>aria-label: Aufgabe entfernen<br>Tooltip: Aufgabe entfernen | Wert:  | type=button |
| 11 | text | ↳ |  | normal |
| 12 | input | aria-label: Teilaufgabe 2 | Wert: Teilaufgabe B<br>Platzhalter: Teilaufgabe … | maxlength=1000 |
| 13 | button | ↵<br>aria-label: Weitere Teilaufgabe<br>Tooltip: Enter: weitere Teilaufgabe | Wert:  | type=button |
| 14 | button | aria-label: Teilaufgabe hinzufügen<br>Tooltip: Teilaufgabe hinzufügen | Wert:  | type=button |
| 15 | button | ×<br>aria-label: Aufgabe entfernen<br>Tooltip: Aufgabe entfernen | Wert:  | type=button |
| 16 | button | +Aufgabe hinzufügen | Wert:  | type=button |
| 17 | label | Fach |  | normal |
| 18 | text | Fach |  | normal |
| 19 | input #homeworkEditSubject |  | Wert: Deutsch | maxlength=100 |
| 20 | label | Fällig am |  | normal |
| 21 | text | Fällig am |  | normal |
| 22 | input #homeworkEditDue |  | Wert: 2026-11-05 | verborgen, type=date |
| 23 | button | 05.11.2026<br>aria-label: Fällig am: 05.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 24 | button | Abbrechen | Wert:  | type=button |
| 25 | button | Speichern | Wert:  | type=submit |

## homework-comment-open

Dialog/Container: `homeworkTaskDialog`. Klassen: `small-dialog`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #homeworkTaskTitle | Kommentar & Stand |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Aufgabe A |  | normal |
| 4 | legend | Bearbeitungsstand |  | normal |
| 5 | label | Vollständig |  | normal |
| 6 | input |  | Wert: erledigt | type=radio, checked=False |
| 7 | text | Vollständig |  | normal |
| 8 | label | Teilweise |  | normal |
| 9 | input |  | Wert: teilweise | type=radio, checked=False |
| 10 | text | Teilweise |  | normal |
| 11 | label | Nicht erledigt |  | normal |
| 12 | input |  | Wert: nicht | type=radio, checked=False |
| 13 | text | Nicht erledigt |  | normal |
| 14 | label | Kommentar optional |  | normal |
| 15 | text | Kommentar |  | normal |
| 16 | text | optional |  | normal |
| 17 | textarea #hwTaskComment |  | Wert: <br>Platzhalter: Notiz … | maxlength=3000 |
| 18 | button | Abbrechen | Wert:  | type=button |
| 19 | button | Speichern | Wert:  | type=submit |

## homework-note-history

Dialog/Container: `studentDialog`. Klassen: `detail-view entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Hausübung |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | button #backHomework | ← Zur Aufgabenliste | Wert:  | type=button |
| 9 | text | Deutsch |  | normal |
| 10 | text | Aufgegeben am 01.11.2026 |  | normal |
| 11 | text | · bis 05.11.2026 |  | normal |
| 12 | label | Notiz |  | normal |
| 13 | text | Notiz |  | normal |
| 14 | textarea #hwFeedback |  | Wert: <br>Platzhalter: Notiz … | maxlength=5000 |
| 15 | h3 | Abgabe & Zeitpunkt |  | normal |
| 16 | label | Abgabe / Vorlage |  | normal |
| 17 | text | Abgabe / Vorlage |  | normal |
| 18 | select #delivery | Nicht überprüftVorgelegtNicht vorgelegtAbwesend | Wert: unknown<br>Optionen: [{"value": "unknown", "text": "Nicht überprüft", "selected": true}, {"value": "submitted", "text": "Vorgelegt", "selected": false}, {"value": "missing", "text": "Nicht vorgelegt", "selected": false}, {"value": "absent", "text": "Abwesend", "selected": false}] | normal |
| 19 | h3 | Weitere Angaben |  | verborgen |
| 20 | label | Beobachtet am |  | normal |
| 21 | text | Beobachtet am |  | normal |
| 22 | input #observedAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 23 | input #observedAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 24 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 25 | button #saveEntry | Notiz speichern | Wert:  | type=submit |

## bulk-Sozialverhalten

Dialog/Container: `bulkDialog`. Klassen: `entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #bulkTitle | Für mehrere erfassen |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Für 2 Schüler: |  | normal |
| 4 | text | Anna Beispiel, Ben Beispiel |  | normal |
| 5 | div #bulkError |  |  | verborgen |
| 6 | label | Bereich |  | normal |
| 7 | text | Bereich |  | normal |
| 8 | select #bulkCategory | SozialverhaltenArbeitsverhaltenHausübungOrganisatorisches | Wert: Sozialverhalten<br>Optionen: [{"value": "Sozialverhalten", "text": "Sozialverhalten", "selected": true}, {"value": "Arbeitsverhalten", "text": "Arbeitsverhalten", "selected": false}, {"value": "Hausübung", "text": "Hausübung", "selected": false}, {"value": "Organisatorisches", "text": "Organisatorisches", "selected": false}] | normal |
| 9 | label | Gemeinsamer Ablauf |  | normal |
| 10 | text | Gemeinsamer Ablauf |  | normal |
| 11 | button | Vor dem Unterricht | Wert:  | type=button, pressed=false |
| 12 | button | Während des Unterrichts | Wert:  | type=button, pressed=false |
| 13 | button | Nach dem Unterricht | Wert:  | type=button, pressed=false |
| 14 | button | Pause | Wert:  | type=button, pressed=false |
| 15 | textarea #bulkText |  | Wert: <br>Platzhalter: Beobachtung … | verborgen, maxlength=4000 |
| 16 | textarea #bulkTextNarrativeFree |  | Wert: <br>Platzhalter: Beobachtung … | maxlength=4000 |
| 17 | h3 | Weitere Angaben |  | verborgen |
| 18 | label | Beteiligt |  | normal |
| 19 | input #bulkParticipantsEnabled |  | Wert: on | type=checkbox, checked=False |
| 20 | text | Beteiligt |  | normal |
| 21 | text | Schüler auswählen |  | verborgen |
| 22 | button | Anna Beispiel | Wert:  | verborgen, type=button, disabled=True, pressed=false |
| 23 | button | Ben Beispiel | Wert:  | verborgen, type=button, disabled=True, pressed=false |
| 24 | label | Weitere Namen |  | verborgen |
| 25 | text | Weitere Namen |  | verborgen |
| 26 | input #bulkParticipantsNames |  | Wert: <br>Platzhalter: Name; Name … | verborgen, type=text, disabled=True, maxlength=12000 |
| 27 | input #bulkParticipantsValue |  | Wert: [] | verborgen, type=hidden |
| 28 | label | Beobachtung · Anna Beispiel |  | normal |
| 29 | text | Beobachtung · Anna Beispiel |  | normal |
| 30 | textarea #individual-audit-a |  | Wert: <br>Platzhalter: Beobachtung … | maxlength=3000 |
| 31 | button | + Hilft anderen | Wert:  | type=button, pressed=false |
| 32 | button | + Nimmt Hilfe an | Wert:  | type=button, pressed=false |
| 33 | button | + Hält Gesprächsregeln ein | Wert:  | type=button, pressed=false |
| 34 | button | + Geht respektvoll mit anderen um | Wert:  | type=button, pressed=false |
| 35 | button | + Klärt einen Konflikt im Gespräch | Wert:  | type=button, pressed=false |
| 36 | button | + Hält gemeinsame Absprachen ein | Wert:  | type=button, pressed=false |
| 37 | button | − Unterbricht andere wiederholt | Wert:  | type=button, pressed=false |
| 38 | button | − Spricht andere abwertend an | Wert:  | type=button, pressed=false |
| 39 | button | − Hält gemeinsame Absprachen nicht ein | Wert:  | type=button, pressed=false |
| 40 | button | − Stört die Zusammenarbeit | Wert:  | type=button, pressed=false |
| 41 | label | Beobachtung · Ben Beispiel |  | normal |
| 42 | text | Beobachtung · Ben Beispiel |  | normal |
| 43 | textarea #individual-audit-b |  | Wert: <br>Platzhalter: Beobachtung … | maxlength=3000 |
| 44 | button | + Hilft anderen | Wert:  | type=button, pressed=false |
| 45 | button | + Nimmt Hilfe an | Wert:  | type=button, pressed=false |
| 46 | button | + Hält Gesprächsregeln ein | Wert:  | type=button, pressed=false |
| 47 | button | + Geht respektvoll mit anderen um | Wert:  | type=button, pressed=false |
| 48 | button | + Klärt einen Konflikt im Gespräch | Wert:  | type=button, pressed=false |
| 49 | button | + Hält gemeinsame Absprachen ein | Wert:  | type=button, pressed=false |
| 50 | button | − Unterbricht andere wiederholt | Wert:  | type=button, pressed=false |
| 51 | button | − Spricht andere abwertend an | Wert:  | type=button, pressed=false |
| 52 | button | − Hält gemeinsame Absprachen nicht ein | Wert:  | type=button, pressed=false |
| 53 | button | − Stört die Zusammenarbeit | Wert:  | type=button, pressed=false |
| 54 | label | Beobachtet am |  | normal |
| 55 | text | Beobachtet am |  | normal |
| 56 | input #bulkObservedAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 57 | input #bulkObservedAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 58 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 59 | label | Später ergänzen |  | normal |
| 60 | input #bulkFollowUp |  | Wert: on | type=checkbox, checked=False |
| 61 | text | Später ergänzen |  | normal |
| 62 | text | Individuelle Einträge · gemeinsamer Kontext |  | normal |
| 63 | button #saveBulk | Für 2 Schüler speichern | Wert:  | type=button |

## bulk-Arbeitsverhalten

Dialog/Container: `bulkDialog`. Klassen: `entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #bulkTitle | Für mehrere erfassen |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Für 2 Schüler: |  | normal |
| 4 | text | Anna Beispiel, Ben Beispiel |  | normal |
| 5 | div #bulkError |  |  | verborgen |
| 6 | label | Bereich |  | normal |
| 7 | text | Bereich |  | normal |
| 8 | select #bulkCategory | SozialverhaltenArbeitsverhaltenHausübungOrganisatorisches | Wert: Arbeitsverhalten<br>Optionen: [{"value": "Sozialverhalten", "text": "Sozialverhalten", "selected": false}, {"value": "Arbeitsverhalten", "text": "Arbeitsverhalten", "selected": true}, {"value": "Hausübung", "text": "Hausübung", "selected": false}, {"value": "Organisatorisches", "text": "Organisatorisches", "selected": false}] | normal |
| 9 | label | Auftrag |  | normal |
| 10 | text | Auftrag |  | normal |
| 11 | text | Zuletzt verwendet |  | normal |
| 12 | button | Lesen | Wert:  | type=button, pressed=false |
| 13 | input #bulkContextFree | aria-label: Auftrag – eigener Text | Wert: <br>Platzhalter: Auftrag … | type=text, maxlength=1000 |
| 14 | input #bulkContext |  | Wert:  | verborgen, maxlength=1000 |
| 15 | label | Gemeinsamer Ablauf |  | normal |
| 16 | text | Gemeinsamer Ablauf |  | normal |
| 17 | textarea #bulkText |  | Wert:  | maxlength=3000 |
| 18 | h3 | Weitere Angaben |  | verborgen |
| 19 | label | Beobachtung · Anna Beispiel |  | normal |
| 20 | text | Beobachtung · Anna Beispiel |  | normal |
| 21 | textarea #individual-audit-a |  | Wert: <br>Platzhalter: Beobachtung … | maxlength=3000 |
| 22 | button | + Beginnt selbstständig | Wert:  | type=button, pressed=false |
| 23 | button | + Arbeitet konzentriert | Wert:  | type=button, pressed=false |
| 24 | button | + Bleibt bei Schwierigkeiten dran | Wert:  | type=button, pressed=false |
| 25 | button | + Fragt gezielt nach Hilfe | Wert:  | type=button, pressed=false |
| 26 | button | + Schließt die Aufgabe ab | Wert:  | type=button, pressed=false |
| 27 | button | + Arbeitet sorgfältig | Wert:  | type=button, pressed=false |
| 28 | button | − Beginnt erst nach mehreren Aufforderungen | Wert:  | type=button, pressed=false |
| 29 | button | − Beschäftigt sich wiederholt mit anderem | Wert:  | type=button, pressed=false |
| 30 | button | − Unterbricht die Arbeit vorzeitig | Wert:  | type=button, pressed=false |
| 31 | button | − Bearbeitet die vereinbarte Aufgabe nicht | Wert:  | type=button, pressed=false |
| 32 | button | − Lässt vereinbarte Arbeitsschritte aus | Wert:  | type=button, pressed=false |
| 33 | label | Beobachtung · Ben Beispiel |  | normal |
| 34 | text | Beobachtung · Ben Beispiel |  | normal |
| 35 | textarea #individual-audit-b |  | Wert: <br>Platzhalter: Beobachtung … | maxlength=3000 |
| 36 | button | + Beginnt selbstständig | Wert:  | type=button, pressed=false |
| 37 | button | + Arbeitet konzentriert | Wert:  | type=button, pressed=false |
| 38 | button | + Bleibt bei Schwierigkeiten dran | Wert:  | type=button, pressed=false |
| 39 | button | + Fragt gezielt nach Hilfe | Wert:  | type=button, pressed=false |
| 40 | button | + Schließt die Aufgabe ab | Wert:  | type=button, pressed=false |
| 41 | button | + Arbeitet sorgfältig | Wert:  | type=button, pressed=false |
| 42 | button | − Beginnt erst nach mehreren Aufforderungen | Wert:  | type=button, pressed=false |
| 43 | button | − Beschäftigt sich wiederholt mit anderem | Wert:  | type=button, pressed=false |
| 44 | button | − Unterbricht die Arbeit vorzeitig | Wert:  | type=button, pressed=false |
| 45 | button | − Bearbeitet die vereinbarte Aufgabe nicht | Wert:  | type=button, pressed=false |
| 46 | button | − Lässt vereinbarte Arbeitsschritte aus | Wert:  | type=button, pressed=false |
| 47 | label | Beobachtet am |  | normal |
| 48 | text | Beobachtet am |  | normal |
| 49 | input #bulkObservedAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 50 | input #bulkObservedAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 51 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 52 | label | Später ergänzen |  | normal |
| 53 | input #bulkFollowUp |  | Wert: on | type=checkbox, checked=False |
| 54 | text | Später ergänzen |  | normal |
| 55 | text | Individuelle Einträge · gemeinsamer Kontext |  | normal |
| 56 | button #saveBulk | Für 2 Schüler speichern | Wert:  | type=button |

## bulk-Hausübung

Dialog/Container: `bulkDialog`. Klassen: `entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #bulkTitle | Für mehrere erfassen |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Für 2 Schüler: |  | normal |
| 4 | text | Anna Beispiel, Ben Beispiel |  | normal |
| 5 | div #bulkError |  |  | verborgen |
| 6 | label | Bereich |  | normal |
| 7 | text | Bereich |  | normal |
| 8 | select #bulkCategory | SozialverhaltenArbeitsverhaltenHausübungOrganisatorisches | Wert: Hausübung<br>Optionen: [{"value": "Sozialverhalten", "text": "Sozialverhalten", "selected": false}, {"value": "Arbeitsverhalten", "text": "Arbeitsverhalten", "selected": false}, {"value": "Hausübung", "text": "Hausübung", "selected": true}, {"value": "Organisatorisches", "text": "Organisatorisches", "selected": false}] | normal |
| 9 | label | Neue Hausübung |  | normal |
| 10 | text | Neue Hausübung |  | normal |
| 11 | textarea #bulkTitleInput |  | Wert: <br>Platzhalter: Aufgabe je Zeile … | verborgen, maxlength=3000 |
| 12 | text | 1. |  | normal |
| 13 | input | aria-label: Aufgabe 1 | Wert: <br>Platzhalter: Aufgabe … | maxlength=1000 |
| 14 | button | ↵<br>aria-label: Weitere Aufgabe<br>Tooltip: Enter: weitere Aufgabe | Wert:  | type=button |
| 15 | button | aria-label: Teilaufgabe hinzufügen<br>Tooltip: Teilaufgabe hinzufügen | Wert:  | type=button |
| 16 | button | ×<br>aria-label: Aufgabe entfernen<br>Tooltip: Aufgabe entfernen | Wert:  | type=button |
| 17 | button | +Aufgabe hinzufügen | Wert:  | type=button |
| 18 | label | Fach optional |  | normal |
| 19 | text | Fach |  | normal |
| 20 | text | optional |  | normal |
| 21 | input #bulkSubject |  | Wert:  | maxlength=100 |
| 22 | label | Fällig am · optional |  | normal |
| 23 | text | Fällig am · optional |  | normal |
| 24 | input #bulkDue |  | Wert:  | verborgen, type=date |
| 25 | button | Datum wählen<br>aria-label: Fällig am · optional: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 26 | h3 | Weitere Angaben |  | verborgen |
| 27 | label | Beobachtet am |  | normal |
| 28 | text | Beobachtet am |  | normal |
| 29 | input #bulkObservedAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 30 | input #bulkObservedAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 31 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 32 | label | Später ergänzen |  | normal |
| 33 | input #bulkFollowUp |  | Wert: on | type=checkbox, checked=False |
| 34 | text | Später ergänzen |  | normal |
| 35 | text | Individuelle Einträge · gemeinsamer Kontext |  | normal |
| 36 | button #saveBulk | Für 2 Schüler speichern | Wert:  | type=button |

## bulk-Organisatorisches

Dialog/Container: `bulkDialog`. Klassen: `entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #bulkTitle | Für mehrere erfassen |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Für 2 Schüler: |  | normal |
| 4 | text | Anna Beispiel, Ben Beispiel |  | normal |
| 5 | div #bulkError |  |  | verborgen |
| 6 | label | Bereich |  | normal |
| 7 | text | Bereich |  | normal |
| 8 | select #bulkCategory | SozialverhaltenArbeitsverhaltenHausübungOrganisatorisches | Wert: Organisatorisches<br>Optionen: [{"value": "Sozialverhalten", "text": "Sozialverhalten", "selected": false}, {"value": "Arbeitsverhalten", "text": "Arbeitsverhalten", "selected": false}, {"value": "Hausübung", "text": "Hausübung", "selected": false}, {"value": "Organisatorisches", "text": "Organisatorisches", "selected": true}] | normal |
| 9 | label | Eigene Notiz |  | normal |
| 10 | text | Eigene Notiz |  | normal |
| 11 | button | ☐ Checkliste | Wert:  | type=button |
| 12 | button | • Aufzählung | Wert:  | type=button |
| 13 | button | 1. Nummerierung | Wert:  | type=button |
| 14 | textarea #bulkText |  | Wert:  | maxlength=3000 |
| 15 | label | Als Aufgabe |  | normal |
| 16 | input #bulkOrgTask |  | Wert: on | type=checkbox, checked=False |
| 17 | text | Als Aufgabe |  | normal |
| 18 | label | Termin optional |  | verborgen |
| 19 | text | Termin |  | verborgen |
| 20 | text | optional |  | verborgen |
| 21 | input #bulkOrgTaskDue |  | Wert:  | verborgen, type=date |
| 22 | button | Datum wählen<br>aria-label: Termin optional: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | verborgen, type=button |
| 23 | label | Aufgabe erledigt |  | verborgen |
| 24 | input #bulkOrgTaskDone |  | Wert: on | verborgen, type=checkbox, checked=False |
| 25 | text | Aufgabe erledigt |  | verborgen |
| 26 | label | Erinnern |  | normal |
| 27 | input #bulkOrgEnabled |  | Wert: on | type=checkbox, checked=False |
| 28 | text | Erinnern |  | normal |
| 29 | label | Erinnern am |  | verborgen |
| 30 | text | Erinnern am |  | verborgen |
| 31 | input #bulkOrgDue |  | Wert:  | verborgen, type=hidden |
| 32 | input #bulkOrgDueDate | aria-label: Erinnern am | Wert:  | verborgen, type=date |
| 33 | button | Datum wählen<br>aria-label: Erinnern am: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | verborgen, type=button |
| 34 | label | Erinnerungstext optional |  | verborgen |
| 35 | text | Erinnerungstext |  | verborgen |
| 36 | text | optional |  | verborgen |
| 37 | input #bulkOrgText |  | Wert: <br>Platzhalter: Wie Notiz … | verborgen, maxlength=2000 |
| 38 | label | Erinnerung quittiert |  | verborgen |
| 39 | input #bulkOrgDone |  | Wert: on | verborgen, type=checkbox, checked=False |
| 40 | text | Erinnerung quittiert |  | verborgen |
| 41 | text | Anzeige in der App |  | verborgen |
| 42 | h3 | Weitere Angaben |  | verborgen |
| 43 | label | Beobachtet am |  | normal |
| 44 | text | Beobachtet am |  | normal |
| 45 | input #bulkObservedAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 46 | input #bulkObservedAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 47 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 48 | label | Später ergänzen |  | normal |
| 49 | input #bulkFollowUp |  | Wert: on | type=checkbox, checked=False |
| 50 | text | Später ergänzen |  | normal |
| 51 | text | Individuelle Einträge · gemeinsamer Kontext |  | normal |
| 52 | button #saveBulk | Für 2 Schüler speichern | Wert:  | type=button |

## bulk-error

Dialog/Container: `bulkDialog`. Klassen: `entry-experience`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #bulkTitle | Für mehrere erfassen |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Für 2 Schüler: |  | normal |
| 4 | text | Anna Beispiel, Ben Beispiel |  | normal |
| 5 | div #bulkError | Bitte eine Beobachtung, eine Auswahl oder einen Kontext eingeben. |  | normal |
| 6 | text | Bitte eine Beobachtung, eine Auswahl oder einen Kontext eingeben. |  | normal |
| 7 | label | Bereich |  | normal |
| 8 | text | Bereich |  | normal |
| 9 | select #bulkCategory | SozialverhaltenArbeitsverhaltenHausübungOrganisatorisches | Wert: Arbeitsverhalten<br>Optionen: [{"value": "Sozialverhalten", "text": "Sozialverhalten", "selected": false}, {"value": "Arbeitsverhalten", "text": "Arbeitsverhalten", "selected": true}, {"value": "Hausübung", "text": "Hausübung", "selected": false}, {"value": "Organisatorisches", "text": "Organisatorisches", "selected": false}] | normal |
| 10 | label | Auftrag |  | normal |
| 11 | text | Auftrag |  | normal |
| 12 | text | Zuletzt verwendet |  | normal |
| 13 | button | Lesen | Wert:  | type=button, pressed=false |
| 14 | input #bulkContextFree | aria-label: Auftrag – eigener Text | Wert: <br>Platzhalter: Auftrag … | type=text, maxlength=1000 |
| 15 | input #bulkContext |  | Wert:  | verborgen, maxlength=1000 |
| 16 | label | Gemeinsamer Ablauf |  | normal |
| 17 | text | Gemeinsamer Ablauf |  | normal |
| 18 | textarea #bulkText |  | Wert:  | maxlength=3000 |
| 19 | h3 | Weitere Angaben |  | verborgen |
| 20 | label | Beobachtung · Anna Beispiel |  | normal |
| 21 | text | Beobachtung · Anna Beispiel |  | normal |
| 22 | textarea #individual-audit-a |  | Wert: <br>Platzhalter: Beobachtung … | maxlength=3000 |
| 23 | button | + Beginnt selbstständig | Wert:  | type=button, pressed=false |
| 24 | button | + Arbeitet konzentriert | Wert:  | type=button, pressed=false |
| 25 | button | + Bleibt bei Schwierigkeiten dran | Wert:  | type=button, pressed=false |
| 26 | button | + Fragt gezielt nach Hilfe | Wert:  | type=button, pressed=false |
| 27 | button | + Schließt die Aufgabe ab | Wert:  | type=button, pressed=false |
| 28 | button | + Arbeitet sorgfältig | Wert:  | type=button, pressed=false |
| 29 | button | − Beginnt erst nach mehreren Aufforderungen | Wert:  | type=button, pressed=false |
| 30 | button | − Beschäftigt sich wiederholt mit anderem | Wert:  | type=button, pressed=false |
| 31 | button | − Unterbricht die Arbeit vorzeitig | Wert:  | type=button, pressed=false |
| 32 | button | − Bearbeitet die vereinbarte Aufgabe nicht | Wert:  | type=button, pressed=false |
| 33 | button | − Lässt vereinbarte Arbeitsschritte aus | Wert:  | type=button, pressed=false |
| 34 | label | Beobachtung · Ben Beispiel |  | normal |
| 35 | text | Beobachtung · Ben Beispiel |  | normal |
| 36 | textarea #individual-audit-b |  | Wert: <br>Platzhalter: Beobachtung … | maxlength=3000 |
| 37 | button | + Beginnt selbstständig | Wert:  | type=button, pressed=false |
| 38 | button | + Arbeitet konzentriert | Wert:  | type=button, pressed=false |
| 39 | button | + Bleibt bei Schwierigkeiten dran | Wert:  | type=button, pressed=false |
| 40 | button | + Fragt gezielt nach Hilfe | Wert:  | type=button, pressed=false |
| 41 | button | + Schließt die Aufgabe ab | Wert:  | type=button, pressed=false |
| 42 | button | + Arbeitet sorgfältig | Wert:  | type=button, pressed=false |
| 43 | button | − Beginnt erst nach mehreren Aufforderungen | Wert:  | type=button, pressed=false |
| 44 | button | − Beschäftigt sich wiederholt mit anderem | Wert:  | type=button, pressed=false |
| 45 | button | − Unterbricht die Arbeit vorzeitig | Wert:  | type=button, pressed=false |
| 46 | button | − Bearbeitet die vereinbarte Aufgabe nicht | Wert:  | type=button, pressed=false |
| 47 | button | − Lässt vereinbarte Arbeitsschritte aus | Wert:  | type=button, pressed=false |
| 48 | label | Beobachtet am |  | normal |
| 49 | text | Beobachtet am |  | normal |
| 50 | input #bulkObservedAt |  | Wert: 2026-11-01 | verborgen, type=hidden |
| 51 | input #bulkObservedAtDate | aria-label: Beobachtet am | Wert: 2026-11-01 | verborgen, type=date |
| 52 | button | 01.11.2026<br>aria-label: Beobachtet am: 01.11.2026<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 53 | label | Später ergänzen |  | normal |
| 54 | input #bulkFollowUp |  | Wert: on | type=checkbox, checked=False |
| 55 | text | Später ergänzen |  | normal |
| 56 | text | Individuelle Einträge · gemeinsamer Kontext |  | normal |
| 57 | button #saveBulk | Für 2 Schüler speichern | Wert:  | type=button |

## calendar-date

Dialog/Container: `calendarDialog`. Klassen: ``.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #calendarTitle | Datum wählen |  | normal |
| 2 | button #calendarClose | ×<br>aria-label: Kalender schließen | Wert:  | type=button |
| 3 | button #calendarPrev | ‹<br>aria-label: Vorheriger Monat | Wert:  | type=button |
| 4 | select #calendarMonth | JännerFebruarMärzAprilMaiJuniJuliAugustSeptemberOktoberNovemberDezember<br>aria-label: Monat | Wert: 10<br>Optionen: [{"value": "0", "text": "Jänner", "selected": false}, {"value": "1", "text": "Februar", "selected": false}, {"value": "2", "text": "März", "selected": false}, {"value": "3", "text": "April", "selected": false}, {"value": "4", "text": "Mai", "selected": false}, {"value": "5", "text": "Juni", "selected": false}, {"value": "6", "text": "Juli", "selected": false}, {"value": "7", "text": "August", "selected": false}, {"value": "8", "text": "September", "selected": false}, {"value": "9", "text": "Oktober", "selected": false}, {"value": "10", "text": "November", "selected": true}, {"value": "11", "text": "Dezember", "selected": false}] | normal |
| 5 | select #calendarYear | 201620172018201920202021202220232024202520262027202820292030203120322033203420352036<br>aria-label: Jahr | Wert: 2026<br>Optionen: [{"value": "2016", "text": "2016", "selected": false}, {"value": "2017", "text": "2017", "selected": false}, {"value": "2018", "text": "2018", "selected": false}, {"value": "2019", "text": "2019", "selected": false}, {"value": "2020", "text": "2020", "selected": false}, {"value": "2021", "text": "2021", "selected": false}, {"value": "2022", "text": "2022", "selected": false}, {"value": "2023", "text": "2023", "selected": false}, {"value": "2024", "text": "2024", "selected": false}, {"value": "2025", "text": "2025", "selected": false}, {"value": "2026", "text": "2026", "selected": true}, {"value": "2027", "text": "2027", "selected": false}, {"value": "2028", "text": "2028", "selected": false}, {"value": "2029", "text": "2029", "selected": false}, {"value": "2030", "text": "2030", "selected": false}, {"value": "2031", "text": "2031", "selected": false}, {"value": "2032", "text": "2032", "selected": false}, {"value": "2033", "text": "2033", "selected": false}, {"value": "2034", "text": "2034", "selected": false}, {"value": "2035", "text": "2035", "selected": false}, {"value": "2036", "text": "2036", "selected": false}] | normal |
| 6 | button #calendarNext | ›<br>aria-label: Nächster Monat | Wert:  | type=button |
| 7 | text | Mo |  | normal |
| 8 | text | Di |  | normal |
| 9 | text | Mi |  | normal |
| 10 | text | Do |  | normal |
| 11 | text | Fr |  | normal |
| 12 | text | Sa |  | normal |
| 13 | text | So |  | normal |
| 14 | button | 1<br>aria-label: 01.11.2026 | Wert:  | type=button, pressed=false |
| 15 | button | 2<br>aria-label: 02.11.2026 | Wert:  | type=button, pressed=false |
| 16 | button | 3<br>aria-label: 03.11.2026 | Wert:  | type=button, pressed=false |
| 17 | button | 4<br>aria-label: 04.11.2026 | Wert:  | type=button, pressed=false |
| 18 | button | 5<br>aria-label: 05.11.2026 | Wert:  | type=button, pressed=false |
| 19 | button | 6<br>aria-label: 06.11.2026 | Wert:  | type=button, pressed=false |
| 20 | button | 7<br>aria-label: 07.11.2026 | Wert:  | type=button, pressed=false |
| 21 | button | 8<br>aria-label: 08.11.2026 | Wert:  | type=button, pressed=false |
| 22 | button | 9<br>aria-label: 09.11.2026 | Wert:  | type=button, pressed=false |
| 23 | button | 10<br>aria-label: 10.11.2026 | Wert:  | type=button, pressed=false |
| 24 | button | 11<br>aria-label: 11.11.2026 | Wert:  | type=button, pressed=false |
| 25 | button | 12<br>aria-label: 12.11.2026 | Wert:  | type=button, pressed=false |
| 26 | button | 13<br>aria-label: 13.11.2026 | Wert:  | type=button, pressed=false |
| 27 | button | 14<br>aria-label: 14.11.2026 | Wert:  | type=button, pressed=false |
| 28 | button | 15<br>aria-label: 15.11.2026 | Wert:  | type=button, pressed=false |
| 29 | button | 16<br>aria-label: 16.11.2026 | Wert:  | type=button, pressed=false |
| 30 | button | 17<br>aria-label: 17.11.2026 | Wert:  | type=button, pressed=false |
| 31 | button | 18<br>aria-label: 18.11.2026 | Wert:  | type=button, pressed=false |
| 32 | button | 19<br>aria-label: 19.11.2026 | Wert:  | type=button, pressed=false |
| 33 | button | 20<br>aria-label: 20.11.2026 | Wert:  | type=button, pressed=false |
| 34 | button | 21<br>aria-label: 21.11.2026 | Wert:  | type=button, pressed=false |
| 35 | button | 22<br>aria-label: 22.11.2026 | Wert:  | type=button, pressed=false |
| 36 | button | 23<br>aria-label: 23.11.2026 | Wert:  | type=button, pressed=false |
| 37 | button | 24<br>aria-label: 24.11.2026 | Wert:  | type=button, pressed=false |
| 38 | button | 25<br>aria-label: 25.11.2026 | Wert:  | type=button, pressed=false |
| 39 | button | 26<br>aria-label: 26.11.2026 | Wert:  | type=button, pressed=false |
| 40 | button | 27<br>aria-label: 27.11.2026 | Wert:  | type=button, pressed=false |
| 41 | button | 28<br>aria-label: 28.11.2026 | Wert:  | type=button, pressed=false |
| 42 | button | 29<br>aria-label: 29.11.2026 | Wert:  | type=button, pressed=false |
| 43 | button | 30<br>aria-label: 30.11.2026 | Wert:  | type=button, pressed=false |
| 44 | button #calendarToday | Heute | Wert:  | type=button |
| 45 | button #calendarClear | Datum entfernen | Wert:  | type=button |

## calendar-time

Dialog/Container: `calendarDialog`. Klassen: ``.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #calendarTitle | Datum & Uhrzeit |  | normal |
| 2 | button #calendarClose | ×<br>aria-label: Kalender schließen | Wert:  | type=button |
| 3 | button #calendarPrev | ‹<br>aria-label: Vorheriger Monat | Wert:  | type=button |
| 4 | select #calendarMonth | JännerFebruarMärzAprilMaiJuniJuliAugustSeptemberOktoberNovemberDezember<br>aria-label: Monat | Wert: 10<br>Optionen: [{"value": "0", "text": "Jänner", "selected": false}, {"value": "1", "text": "Februar", "selected": false}, {"value": "2", "text": "März", "selected": false}, {"value": "3", "text": "April", "selected": false}, {"value": "4", "text": "Mai", "selected": false}, {"value": "5", "text": "Juni", "selected": false}, {"value": "6", "text": "Juli", "selected": false}, {"value": "7", "text": "August", "selected": false}, {"value": "8", "text": "September", "selected": false}, {"value": "9", "text": "Oktober", "selected": false}, {"value": "10", "text": "November", "selected": true}, {"value": "11", "text": "Dezember", "selected": false}] | normal |
| 5 | select #calendarYear | 201620172018201920202021202220232024202520262027202820292030203120322033203420352036<br>aria-label: Jahr | Wert: 2026<br>Optionen: [{"value": "2016", "text": "2016", "selected": false}, {"value": "2017", "text": "2017", "selected": false}, {"value": "2018", "text": "2018", "selected": false}, {"value": "2019", "text": "2019", "selected": false}, {"value": "2020", "text": "2020", "selected": false}, {"value": "2021", "text": "2021", "selected": false}, {"value": "2022", "text": "2022", "selected": false}, {"value": "2023", "text": "2023", "selected": false}, {"value": "2024", "text": "2024", "selected": false}, {"value": "2025", "text": "2025", "selected": false}, {"value": "2026", "text": "2026", "selected": true}, {"value": "2027", "text": "2027", "selected": false}, {"value": "2028", "text": "2028", "selected": false}, {"value": "2029", "text": "2029", "selected": false}, {"value": "2030", "text": "2030", "selected": false}, {"value": "2031", "text": "2031", "selected": false}, {"value": "2032", "text": "2032", "selected": false}, {"value": "2033", "text": "2033", "selected": false}, {"value": "2034", "text": "2034", "selected": false}, {"value": "2035", "text": "2035", "selected": false}, {"value": "2036", "text": "2036", "selected": false}] | normal |
| 6 | button #calendarNext | ›<br>aria-label: Nächster Monat | Wert:  | type=button |
| 7 | text | Mo |  | normal |
| 8 | text | Di |  | normal |
| 9 | text | Mi |  | normal |
| 10 | text | Do |  | normal |
| 11 | text | Fr |  | normal |
| 12 | text | Sa |  | normal |
| 13 | text | So |  | normal |
| 14 | button | 1<br>aria-label: 01.11.2026 | Wert:  | type=button, pressed=true |
| 15 | button | 2<br>aria-label: 02.11.2026 | Wert:  | type=button, pressed=false |
| 16 | button | 3<br>aria-label: 03.11.2026 | Wert:  | type=button, pressed=false |
| 17 | button | 4<br>aria-label: 04.11.2026 | Wert:  | type=button, pressed=false |
| 18 | button | 5<br>aria-label: 05.11.2026 | Wert:  | type=button, pressed=false |
| 19 | button | 6<br>aria-label: 06.11.2026 | Wert:  | type=button, pressed=false |
| 20 | button | 7<br>aria-label: 07.11.2026 | Wert:  | type=button, pressed=false |
| 21 | button | 8<br>aria-label: 08.11.2026 | Wert:  | type=button, pressed=false |
| 22 | button | 9<br>aria-label: 09.11.2026 | Wert:  | type=button, pressed=false |
| 23 | button | 10<br>aria-label: 10.11.2026 | Wert:  | type=button, pressed=false |
| 24 | button | 11<br>aria-label: 11.11.2026 | Wert:  | type=button, pressed=false |
| 25 | button | 12<br>aria-label: 12.11.2026 | Wert:  | type=button, pressed=false |
| 26 | button | 13<br>aria-label: 13.11.2026 | Wert:  | type=button, pressed=false |
| 27 | button | 14<br>aria-label: 14.11.2026 | Wert:  | type=button, pressed=false |
| 28 | button | 15<br>aria-label: 15.11.2026 | Wert:  | type=button, pressed=false |
| 29 | button | 16<br>aria-label: 16.11.2026 | Wert:  | type=button, pressed=false |
| 30 | button | 17<br>aria-label: 17.11.2026 | Wert:  | type=button, pressed=false |
| 31 | button | 18<br>aria-label: 18.11.2026 | Wert:  | type=button, pressed=false |
| 32 | button | 19<br>aria-label: 19.11.2026 | Wert:  | type=button, pressed=false |
| 33 | button | 20<br>aria-label: 20.11.2026 | Wert:  | type=button, pressed=false |
| 34 | button | 21<br>aria-label: 21.11.2026 | Wert:  | type=button, pressed=false |
| 35 | button | 22<br>aria-label: 22.11.2026 | Wert:  | type=button, pressed=false |
| 36 | button | 23<br>aria-label: 23.11.2026 | Wert:  | type=button, pressed=false |
| 37 | button | 24<br>aria-label: 24.11.2026 | Wert:  | type=button, pressed=false |
| 38 | button | 25<br>aria-label: 25.11.2026 | Wert:  | type=button, pressed=false |
| 39 | button | 26<br>aria-label: 26.11.2026 | Wert:  | type=button, pressed=false |
| 40 | button | 27<br>aria-label: 27.11.2026 | Wert:  | type=button, pressed=false |
| 41 | button | 28<br>aria-label: 28.11.2026 | Wert:  | type=button, pressed=false |
| 42 | button | 29<br>aria-label: 29.11.2026 | Wert:  | type=button, pressed=false |
| 43 | button | 30<br>aria-label: 30.11.2026 | Wert:  | type=button, pressed=false |
| 44 | label | Uhrzeit optional |  | normal |
| 45 | text | Uhrzeit |  | normal |
| 46 | text | optional |  | normal |
| 47 | input #calendarTime | aria-label: Uhrzeit (optional) | Wert:  | type=time |
| 48 | button #calendarNoTime | Ohne Uhrzeit | Wert:  | type=button, disabled=True |
| 49 | button #calendarToday | Heute | Wert:  | type=button |
| 50 | button #calendarClear | Datum entfernen | Wert:  | type=button |
| 51 | button #calendarApply | Übernehmen | Wert:  | type=button |

## situation

Dialog/Container: `situationDialog`. Klassen: `detail-view`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 | Gemeinsame Situation |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Anna Beispiel, Ben Beispiel |  | normal |
| 4 | label | Gemeinsamer Ablauf |  | normal |
| 5 | text | Gemeinsamer Ablauf |  | normal |
| 6 | textarea #situationText |  | Wert: Gemeinsamer synthetischer Ablauf<br>Platzhalter: Kontext … | maxlength=12000 |
| 7 | h3 | Anna Beispiel |  | normal |
| 8 | text | Synthetischer Eintrag |  | normal |
| 9 | text | Hilft anderen |  | normal |
| 10 | button | Beobachtung bearbeiten | Wert:  | type=button |
| 11 | button | Kontext speichern | Wert:  | type=submit |

## history-filled

Dialog/Container: `studentDialog`. Klassen: `detail-view`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | button #modalBack | aria-label: Zur Schülerübersicht<br>Tooltip: Schülerübersicht | Wert:  | type=button |
| 2 | text | A |  | verborgen |
| 3 | text | Einträge für |  | verborgen |
| 4 | h2 #modalName | Anna Beispiel |  | normal |
| 5 | text | Verlauf |  | normal |
| 6 | button #modalHistory | aria-label: Verlauf ansehen<br>Tooltip: Verlauf ansehen | Wert:  | verborgen, type=button |
| 7 | button #closeStudent | ×<br>aria-label: Schüler schließen | Wert:  | normal |
| 8 | button | ← Bereiche | Wert:  | verborgen, type=button |
| 9 | button | Verlauf ansehen | Wert:  | verborgen, type=button |
| 10 | h3 | Verlauf |  | verborgen |
| 11 | text | Nach Datum, Bereich und Text filtern. |  | normal |
| 12 | input #historySearch | aria-label: Verlauf durchsuchen | Wert: <br>Platzhalter: Suchen … | type=search |
| 13 | select #historyCategory | Alle BereicheSozialverhaltenArbeitsverhaltenHausübungOrganisatorischesZiele<br>aria-label: Bereich | Wert: <br>Optionen: [{"value": "", "text": "Alle Bereiche", "selected": true}, {"value": "Sozialverhalten", "text": "Sozialverhalten", "selected": false}, {"value": "Arbeitsverhalten", "text": "Arbeitsverhalten", "selected": false}, {"value": "Hausübung", "text": "Hausübung", "selected": false}, {"value": "Organisatorisches", "text": "Organisatorisches", "selected": false}, {"value": "Ziele", "text": "Ziele", "selected": false}] | normal |
| 14 | label | VonDatum wählen |  | normal |
| 15 | text | Von |  | normal |
| 16 | input #historyFrom |  | Wert:  | verborgen, type=date |
| 17 | button | Datum wählen<br>aria-label: Datum: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 18 | label | BisDatum wählen |  | normal |
| 19 | text | Bis |  | normal |
| 20 | input #historyTo |  | Wert:  | verborgen, type=date |
| 21 | button | Datum wählen<br>aria-label: Datum: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 22 | label | Nur offene Nachbereitung |  | normal |
| 23 | input #historyReview |  | Wert: on | type=checkbox, checked=False |
| 24 | text | Nur offene Nachbereitung |  | normal |
| 25 | text | Sozialverhalten |  | normal |
| 26 | text | 01.11.2026 |  | normal |
| 27 | text | + Hilft anderen |  | normal |
| 28 | text | Synthetischer Eintrag |  | normal |
| 29 | text | Beteiligt: Ben Beispiel |  | normal |
| 30 | text | Reaktion / Unterstützung ergänzen: Synthetische Unterstützung |  | normal |
| 31 | text | Erfasst: 01.11.2026, 12:00 · Später ergänzen |  | normal |
| 32 | button | Bearbeiten | Wert:  | normal |
| 33 | button | Dokumentation vollständig | Wert:  | normal |
| 34 | button | Löschen | Wert:  | normal |
| 35 | summary | 1 frühere Fassungen |  | normal |
| 36 | text | 01.11.2026, 12:00 |  | eingeklappt |
| 37 | text | Beteiligt: Ben Beispiel · Synthetischer Eintrag |  | eingeklappt |
| 38 | text | Hilft anderen |  | eingeklappt |
| 39 | text | Gemeinsamer Kontext |  | normal |
| 40 | text | Gemeinsamer synthetischer Ablauf |  | normal |
| 41 | text | Berichtete Beobachtung |  | normal |
| 42 | text | Arbeitsverhalten |  | normal |
| 43 | text | 01.11.2026 |  | normal |
| 44 | text | Auftrag: |  | normal |
| 45 | text | Lesen |  | normal |
| 46 | text | + Beginnt selbstständig |  | normal |
| 47 | text | Synthetischer Eintrag |  | normal |
| 48 | text | Reaktion / Unterstützung ergänzen: Synthetische Unterstützung |  | normal |
| 49 | text | Erfasst: 01.11.2026, 12:00 · Später ergänzen |  | normal |
| 50 | button | Bearbeiten | Wert:  | normal |
| 51 | button | Dokumentation vollständig | Wert:  | normal |
| 52 | button | Löschen | Wert:  | normal |
| 53 | text | Gemeinsamer Kontext |  | normal |
| 54 | text | Synthetischer Kontext |  | normal |
| 55 | text | Berichtete Beobachtung |  | normal |
| 56 | text | Organisatorisches |  | normal |
| 57 | text | 01.11.2026 |  | normal |
| 58 | text | Synthetischer Eintrag |  | normal |
| 59 | text | Erfasst: 01.11.2026, 12:00 |  | normal |
| 60 | button | Bearbeiten | Wert:  | normal |
| 61 | button | Später ergänzen | Wert:  | normal |
| 62 | button | Löschen | Wert:  | normal |
| 63 | text | Notiz |  | normal |
| 64 | text | Ziele |  | normal |
| 65 | text | 01.11.2026 |  | normal |
| 66 | text | Synthetischer Eintrag |  | normal |
| 67 | text | Status: In Arbeit · Zieltermin: 10.11.2026 Zielkriterium: Synthetisches Kriterium Nächster Schritt: Synthetischer Schritt |  | normal |
| 68 | button | Als erreicht markieren | Wert:  | type=button |
| 69 | text | Erfasst: 01.11.2026, 12:00 |  | normal |
| 70 | button | Bearbeiten | Wert:  | normal |
| 71 | button | Später ergänzen | Wert:  | normal |
| 72 | button | Löschen | Wert:  | normal |
| 73 | text | Hausübung |  | normal |
| 74 | text | 01.11.2026 |  | normal |
| 75 | text | Aufgegeben: Aufgabe A Teilaufgabe B Fach: Deutsch Fällig: 05.11.2026 |  | normal |
| 76 | text | Erfasst: 01.11.2026, 12:00 |  | normal |
| 77 | button | Bearbeiten | Wert:  | normal |
| 78 | button | Später ergänzen | Wert:  | normal |
| 79 | button | Löschen | Wert:  | normal |
| 80 | button #saveEntry | Speichern | Wert:  | verborgen, type=submit |

## brief-filled

Dialog/Container: `briefDialog`. Klassen: `detail-view`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #briefTitle | Gespräch vorbereiten |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | normal |
| 3 | label | Namen weiterer Beteiligter aufnehmen |  | normal |
| 4 | input #briefIncludeNames |  | Wert: on | type=checkbox, checked=False |
| 5 | text | Namen weiterer Beteiligter aufnehmen |  | normal |
| 6 | label | Von |  | normal |
| 7 | text | Von |  | normal |
| 8 | input #briefFrom |  | Wert:  | verborgen, type=date |
| 9 | button | Datum wählen<br>aria-label: Von: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 10 | label | Bis |  | normal |
| 11 | text | Bis |  | normal |
| 12 | input #briefTo |  | Wert: 2026-11-01 | verborgen, type=date |
| 13 | button | Datum wählen<br>aria-label: Bis: Datum wählen<br>Tooltip: Datum im Kalender wählen | Wert:  | type=button |
| 14 | button #selectBriefAll | Alle auswählen | Wert:  | normal |
| 15 | button #clearBrief | Auswahl leeren | Wert:  | normal |
| 16 | label | 01.11.2026 · SozialverhaltenBeteiligt: Ben Beispiel Synthetischer Eintrag Hilft anderen |  | normal |
| 17 | input |  | Wert: on | type=checkbox, checked=True |
| 18 | text | 01.11.2026 · Sozialverhalten |  | normal |
| 19 | text | Beteiligt: Ben Beispiel Synthetischer Eintrag Hilft anderen |  | normal |
| 20 | label | 01.11.2026 · ArbeitsverhaltenAuftrag: Lesen Synthetischer Eintrag Beginnt selbstständig |  | normal |
| 21 | input |  | Wert: on | type=checkbox, checked=True |
| 22 | text | 01.11.2026 · Arbeitsverhalten |  | normal |
| 23 | text | Auftrag: Lesen Synthetischer Eintrag Beginnt selbstständig |  | normal |
| 24 | label | 01.11.2026 · OrganisatorischesSynthetischer Eintrag |  | normal |
| 25 | input |  | Wert: on | type=checkbox, checked=True |
| 26 | text | 01.11.2026 · Organisatorisches |  | normal |
| 27 | text | Synthetischer Eintrag |  | normal |
| 28 | label | 01.11.2026 · ZieleStatus: In Arbeit · Zieltermin: 10.11.2026 Zielkriterium: Synthetisches Kriterium Nächster Schritt: Synthetischer Schritt Synthetischer Eintrag |  | normal |
| 29 | input |  | Wert: on | type=checkbox, checked=True |
| 30 | text | 01.11.2026 · Ziele |  | normal |
| 31 | text | Status: In Arbeit · Zieltermin: 10.11.2026 Zielkriterium: Synthetisches Kriterium Nächster Schritt: Synthetischer Schritt Synthetischer Eintrag |  | normal |
| 32 | label | 01.11.2026 · HausübungAufgegeben: Aufgabe A Teilaufgabe B Fach: Deutsch Fällig: 05.11.2026 |  | normal |
| 33 | input |  | Wert: on | type=checkbox, checked=True |
| 34 | text | 01.11.2026 · Hausübung |  | normal |
| 35 | text | Aufgegeben: Aufgabe A Teilaufgabe B Fach: Deutsch Fällig: 05.11.2026 |  | normal |
| 36 | button #createBrief | Auswahl zusammenstellen | Wert:  | normal |
| 37 | text | Gesprächsvorbereitung – Anna Beispiel Zeitraum: alle bisherigen Einträge bis 2026-11-01 01.11.2026 · Sozialverhalten Synthetischer Eintrag + Hilft anderen Unterstützung: Synthetische Unterstützung 01.11.2026 · Arbeitsverhalten Auftrag: Lesen Synthetischer Eintrag + Beginnt selbstständig Unterstützung: Synthetische Unterstützung 01.11.2026 · Organisatorisches Synthetischer Eintrag 01.11.2026 · Ziele Status: In Arbeit · Zieltermin: 10.11.2026 Zielkriterium: Synthetisches Kriterium Nächster Schritt: Synthetischer Schritt Synthetischer Eintrag 01.11.2026 · Hausübung Aufgegeben: Aufgabe A Teilaufgabe B Fach: Deutsch Fällig: 05.11.2026 Offene Absprachen / Erinnerungen Nächste Schritte |  | normal |
| 38 | button #copyBrief | Text kopieren | Wert:  | normal |
| 39 | button #downloadBrief | Als Textdatei sichern | Wert:  | normal |

## import-configured

Dialog/Container: `importReview`. Klassen: ``.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #importTitle | Sicherung prüfen |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | normal |
| 3 | text | Die vorhandenen Daten konnten nicht sicher geladen werden. Die Sicherung wird als neuer Datenstand wiederhergestellt. Der bisherige Speicher bleibt zur Diagnose erhalten. |  | verborgen |
| 4 | button #exportDamagedStorage | Bisherigen Speicher als Datei sichern | Wert:  | verborgen, type=button |
| 5 | label | Diese Sicherung als neuen Datenstand verwenden |  | verborgen |
| 6 | input #confirmRecovery |  | Wert: on | verborgen, type=checkbox, checked=False |
| 7 | text | Diese Sicherung als neuen Datenstand verwenden |  | verborgen |
| 8 | text | Diese Sicherung enthält keine Darstellungseinstellungen. Deine aktuellen Einstellungen bleiben erhalten. |  | normal |
| 9 | label | Neuere Fassungen übernehmen; bei unklaren Konflikten aktuelle Daten behalten. |  | normal |
| 10 | input |  | Wert: latest | type=radio, checked=True |
| 11 | text | Neuere Fassungen übernehmen; bei unklaren Konflikten aktuelle Daten behalten. |  | normal |
| 12 | label | Bei Konflikten ausdrücklich die Fassung aus der Datei übernehmen. |  | normal |
| 13 | input |  | Wert: incoming | type=radio, checked=False |
| 14 | text | Bei Konflikten ausdrücklich die Fassung aus der Datei übernehmen. |  | normal |
| 15 | text | Darstellung kann getrennt übernommen werden. Abweichende Fassungen bleiben in Verlauf und Konfliktliste erhalten. Schüler werden ausschließlich über ihre ID zugeordnet. Gleiche Namen werden nicht automatisch zusammengeführt. |  | normal |
| 16 | button #confirmImport | Import übernehmen | Wert:  | normal |

## import-recovery

Dialog/Container: `importReview`. Klassen: ``.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #importTitle | Sicherung prüfen |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | normal |
| 3 | text | Die vorhandenen Daten konnten nicht sicher geladen werden. Die Sicherung wird als neuer Datenstand wiederhergestellt. Der bisherige Speicher bleibt zur Diagnose erhalten. |  | normal |
| 4 | button #exportDamagedStorage | Bisherigen Speicher als Datei sichern | Wert:  | type=button |
| 5 | label | Diese Sicherung als neuen Datenstand verwenden |  | normal |
| 6 | input #confirmRecovery |  | Wert: on | type=checkbox, checked=False |
| 7 | text | Diese Sicherung als neuen Datenstand verwenden |  | normal |
| 8 | text | Diese Sicherung enthält keine Darstellungseinstellungen. Deine aktuellen Einstellungen bleiben erhalten. |  | normal |
| 9 | label | Neuere Fassungen übernehmen; bei unklaren Konflikten aktuelle Daten behalten. |  | verborgen |
| 10 | input |  | Wert: latest | verborgen, type=radio, checked=True |
| 11 | text | Neuere Fassungen übernehmen; bei unklaren Konflikten aktuelle Daten behalten. |  | verborgen |
| 12 | label | Bei Konflikten ausdrücklich die Fassung aus der Datei übernehmen. |  | verborgen |
| 13 | input |  | Wert: incoming | verborgen, type=radio, checked=False |
| 14 | text | Bei Konflikten ausdrücklich die Fassung aus der Datei übernehmen. |  | verborgen |
| 15 | text | Darstellung kann getrennt übernommen werden. Abweichende Fassungen bleiben in Verlauf und Konfliktliste erhalten. Schüler werden ausschließlich über ihre ID zugeordnet. Gleiche Namen werden nicht automatisch zusammengeführt. |  | normal |
| 16 | button #confirmImport | Sicherung wiederherstellen | Wert:  | normal |

## maintenance-error

Dialog/Container: `maintenanceDialog`. Klassen: ``.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #maintenanceTitle | Papierkorb endgültig leeren |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Gelöschte Einträge und ihre alten technischen Speicherstände werden endgültig entfernt. Verknüpfungen zu gelöschten Zielen werden bereinigt. Vorhandene Sicherungsdateien bleiben unverändert. |  | normal |
| 4 | button #maintenanceExport | Vollständige Sicherung herunterladen | Wert:  | type=button |
| 5 | label | Ich habe die Sicherung gespeichert und andere App-Tabs geschlossen. |  | normal |
| 6 | input #maintenanceReady |  | Wert: on | type=checkbox, checked=False |
| 7 | text | Ich habe die Sicherung gespeichert und andere App-Tabs geschlossen. |  | normal |
| 8 | label | Zum endgültigen Löschen LÖSCHEN eingeben |  | normal |
| 9 | text | Zum endgültigen Löschen LÖSCHEN eingeben |  | normal |
| 10 | input #purgeWord |  | Wert:  | type=text |
| 11 | p #maintenanceError | Bitte zuerst die Sicherung bestätigen und die erforderliche Eingabe ausfüllen. |  | normal |
| 12 | text | Bitte zuerst die Sicherung bestätigen und die erforderliche Eingabe ausfüllen. |  | normal |
| 13 | button #commitMaintenance | Ausführen | Wert:  | type=button |

## calendar-midnight

Dialog/Container: `calendarDialog`. Klassen: ``.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #calendarTitle | Datum & Uhrzeit |  | normal |
| 2 | button #calendarClose | ×<br>aria-label: Kalender schließen | Wert:  | type=button |
| 3 | button #calendarPrev | ‹<br>aria-label: Vorheriger Monat | Wert:  | type=button |
| 4 | select #calendarMonth | JännerFebruarMärzAprilMaiJuniJuliAugustSeptemberOktoberNovemberDezember<br>aria-label: Monat | Wert: 10<br>Optionen: [{"value": "0", "text": "Jänner", "selected": false}, {"value": "1", "text": "Februar", "selected": false}, {"value": "2", "text": "März", "selected": false}, {"value": "3", "text": "April", "selected": false}, {"value": "4", "text": "Mai", "selected": false}, {"value": "5", "text": "Juni", "selected": false}, {"value": "6", "text": "Juli", "selected": false}, {"value": "7", "text": "August", "selected": false}, {"value": "8", "text": "September", "selected": false}, {"value": "9", "text": "Oktober", "selected": false}, {"value": "10", "text": "November", "selected": true}, {"value": "11", "text": "Dezember", "selected": false}] | normal |
| 5 | select #calendarYear | 201620172018201920202021202220232024202520262027202820292030203120322033203420352036<br>aria-label: Jahr | Wert: 2026<br>Optionen: [{"value": "2016", "text": "2016", "selected": false}, {"value": "2017", "text": "2017", "selected": false}, {"value": "2018", "text": "2018", "selected": false}, {"value": "2019", "text": "2019", "selected": false}, {"value": "2020", "text": "2020", "selected": false}, {"value": "2021", "text": "2021", "selected": false}, {"value": "2022", "text": "2022", "selected": false}, {"value": "2023", "text": "2023", "selected": false}, {"value": "2024", "text": "2024", "selected": false}, {"value": "2025", "text": "2025", "selected": false}, {"value": "2026", "text": "2026", "selected": true}, {"value": "2027", "text": "2027", "selected": false}, {"value": "2028", "text": "2028", "selected": false}, {"value": "2029", "text": "2029", "selected": false}, {"value": "2030", "text": "2030", "selected": false}, {"value": "2031", "text": "2031", "selected": false}, {"value": "2032", "text": "2032", "selected": false}, {"value": "2033", "text": "2033", "selected": false}, {"value": "2034", "text": "2034", "selected": false}, {"value": "2035", "text": "2035", "selected": false}, {"value": "2036", "text": "2036", "selected": false}] | normal |
| 6 | button #calendarNext | ›<br>aria-label: Nächster Monat | Wert:  | type=button |
| 7 | text | Mo |  | normal |
| 8 | text | Di |  | normal |
| 9 | text | Mi |  | normal |
| 10 | text | Do |  | normal |
| 11 | text | Fr |  | normal |
| 12 | text | Sa |  | normal |
| 13 | text | So |  | normal |
| 14 | button | 1<br>aria-label: 01.11.2026 | Wert:  | type=button, pressed=true |
| 15 | button | 2<br>aria-label: 02.11.2026 | Wert:  | type=button, pressed=false |
| 16 | button | 3<br>aria-label: 03.11.2026 | Wert:  | type=button, pressed=false |
| 17 | button | 4<br>aria-label: 04.11.2026 | Wert:  | type=button, pressed=false |
| 18 | button | 5<br>aria-label: 05.11.2026 | Wert:  | type=button, pressed=false |
| 19 | button | 6<br>aria-label: 06.11.2026 | Wert:  | type=button, pressed=false |
| 20 | button | 7<br>aria-label: 07.11.2026 | Wert:  | type=button, pressed=false |
| 21 | button | 8<br>aria-label: 08.11.2026 | Wert:  | type=button, pressed=false |
| 22 | button | 9<br>aria-label: 09.11.2026 | Wert:  | type=button, pressed=false |
| 23 | button | 10<br>aria-label: 10.11.2026 | Wert:  | type=button, pressed=false |
| 24 | button | 11<br>aria-label: 11.11.2026 | Wert:  | type=button, pressed=false |
| 25 | button | 12<br>aria-label: 12.11.2026 | Wert:  | type=button, pressed=false |
| 26 | button | 13<br>aria-label: 13.11.2026 | Wert:  | type=button, pressed=false |
| 27 | button | 14<br>aria-label: 14.11.2026 | Wert:  | type=button, pressed=false |
| 28 | button | 15<br>aria-label: 15.11.2026 | Wert:  | type=button, pressed=false |
| 29 | button | 16<br>aria-label: 16.11.2026 | Wert:  | type=button, pressed=false |
| 30 | button | 17<br>aria-label: 17.11.2026 | Wert:  | type=button, pressed=false |
| 31 | button | 18<br>aria-label: 18.11.2026 | Wert:  | type=button, pressed=false |
| 32 | button | 19<br>aria-label: 19.11.2026 | Wert:  | type=button, pressed=false |
| 33 | button | 20<br>aria-label: 20.11.2026 | Wert:  | type=button, pressed=false |
| 34 | button | 21<br>aria-label: 21.11.2026 | Wert:  | type=button, pressed=false |
| 35 | button | 22<br>aria-label: 22.11.2026 | Wert:  | type=button, pressed=false |
| 36 | button | 23<br>aria-label: 23.11.2026 | Wert:  | type=button, pressed=false |
| 37 | button | 24<br>aria-label: 24.11.2026 | Wert:  | type=button, pressed=false |
| 38 | button | 25<br>aria-label: 25.11.2026 | Wert:  | type=button, pressed=false |
| 39 | button | 26<br>aria-label: 26.11.2026 | Wert:  | type=button, pressed=false |
| 40 | button | 27<br>aria-label: 27.11.2026 | Wert:  | type=button, pressed=false |
| 41 | button | 28<br>aria-label: 28.11.2026 | Wert:  | type=button, pressed=false |
| 42 | button | 29<br>aria-label: 29.11.2026 | Wert:  | type=button, pressed=false |
| 43 | button | 30<br>aria-label: 30.11.2026 | Wert:  | type=button, pressed=false |
| 44 | label | Uhrzeit optional |  | normal |
| 45 | text | Uhrzeit |  | normal |
| 46 | text | optional |  | normal |
| 47 | input #calendarTime | aria-label: Uhrzeit (optional) | Wert: 00:00 | type=time |
| 48 | button #calendarNoTime | Ohne Uhrzeit | Wert:  | type=button |
| 49 | button #calendarToday | Heute | Wert:  | type=button |
| 50 | button #calendarClear | Datum entfernen | Wert:  | type=button |
| 51 | button #calendarApply | Übernehmen | Wert:  | type=button |

## conflicts-filled

Dialog/Container: `conflictDialog`. Klassen: `detail-view`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 | Änderungskonflikte |  | normal |
| 2 | button | × | Wert:  | type=button |
| 3 | h3 | Synthetischer Eintrag |  | normal |
| 4 | text | text |  | normal |
| 5 | text | Aktuelle Fassung |  | normal |
| 6 | text | "Synthetischer Eintrag" |  | normal |
| 7 | text | Andere Fassung |  | normal |
| 8 | text | "Andere synthetische Fassung" |  | normal |
| 9 | button | Aktuelle behalten | Wert:  | normal |
| 10 | button | Andere übernehmen | Wert:  | normal |

## trash-filled

Dialog/Container: `trashDialog`. Klassen: ``.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #trashTitle | Papierkorb |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Hier abgelegte Einträge sind ausgeblendet und weiterhin in Sicherungen enthalten. |  | normal |
| 4 | text | Anna Beispiel · Organisatorisches |  | normal |
| 5 | text | Synthetischer Eintrag |  | normal |
| 6 | button | Wiederherstellen | Wert:  | type=button |
| 7 | button | Papierkorb endgültig leeren | Wert:  | type=button |

## editor-draft-resume

Dialog/Container: `homeworkTaskDialog`. Klassen: `small-dialog`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #homeworkTaskTitle | Kommentar & Stand |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Aufgabe A |  | normal |
| 4 | legend | Bearbeitungsstand |  | normal |
| 5 | label | Vollständig |  | normal |
| 6 | input |  | Wert: erledigt | type=radio, checked=False |
| 7 | text | Vollständig |  | normal |
| 8 | label | Teilweise |  | normal |
| 9 | input |  | Wert: teilweise | type=radio, checked=False |
| 10 | text | Teilweise |  | normal |
| 11 | label | Nicht erledigt |  | normal |
| 12 | input |  | Wert: nicht | type=radio, checked=False |
| 13 | text | Nicht erledigt |  | normal |
| 14 | label | Kommentar optional |  | normal |
| 15 | text | Kommentar |  | normal |
| 16 | text | optional |  | normal |
| 17 | textarea #hwTaskComment |  | Wert: <br>Platzhalter: Notiz … | maxlength=3000 |
| 18 | button | Abbrechen | Wert:  | type=button |
| 19 | button | Speichern | Wert:  | type=submit |

## editor-draft-offer

Dialog/Container: `homeworkTaskDialog`. Klassen: `small-dialog`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #homeworkTaskTitle | Kommentar & Stand |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Ein gesicherter Entwurf ist vorhanden. |  | normal |
| 4 | button | Entwurf übernehmen | Wert:  | type=button |
| 5 | button | Entwurf verwerfen | Wert:  | type=button |
| 6 | text | Aufgabe A |  | normal |
| 7 | legend | Bearbeitungsstand |  | normal |
| 8 | label | Vollständig |  | normal |
| 9 | input |  | Wert: erledigt | type=radio, checked=False |
| 10 | text | Vollständig |  | normal |
| 11 | label | Teilweise |  | normal |
| 12 | input |  | Wert: teilweise | type=radio, checked=False |
| 13 | text | Teilweise |  | normal |
| 14 | label | Nicht erledigt |  | normal |
| 15 | input |  | Wert: nicht | type=radio, checked=False |
| 16 | text | Nicht erledigt |  | normal |
| 17 | label | Kommentar optional |  | normal |
| 18 | text | Kommentar |  | normal |
| 19 | text | optional |  | normal |
| 20 | textarea #hwTaskComment |  | Wert: <br>Platzhalter: Notiz … | maxlength=3000 |
| 21 | button | Abbrechen | Wert:  | type=button |
| 22 | button | Speichern | Wert:  | type=submit |

## editor-draft-resumed

Dialog/Container: `homeworkTaskDialog`. Klassen: `small-dialog`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #homeworkTaskTitle | Kommentar & Stand |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | text | Aufgabe A |  | normal |
| 4 | legend | Bearbeitungsstand |  | normal |
| 5 | label | Vollständig |  | normal |
| 6 | input |  | Wert: erledigt | type=radio, checked=False |
| 7 | text | Vollständig |  | normal |
| 8 | label | Teilweise |  | normal |
| 9 | input |  | Wert: teilweise | type=radio, checked=False |
| 10 | text | Teilweise |  | normal |
| 11 | label | Nicht erledigt |  | normal |
| 12 | input |  | Wert: nicht | type=radio, checked=False |
| 13 | text | Nicht erledigt |  | normal |
| 14 | label | Kommentar optional |  | normal |
| 15 | text | Kommentar |  | normal |
| 16 | text | optional |  | normal |
| 17 | textarea #hwTaskComment |  | Wert: Unfertiger synthetischer Kommentar<br>Platzhalter: Notiz … | maxlength=3000 |
| 18 | button | Abbrechen | Wert:  | type=button |
| 19 | button | Speichern | Wert:  | type=submit |

## drafts-filled

Dialog/Container: `draftDialog`. Klassen: ``.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #draftTitle | Gesicherte Entwürfe |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | normal |
| 3 | text | Anna Beispiel · Sozialverhalten |  | normal |
| 4 | text | Synthetische Beobachtung |  | normal |
| 5 | text | 01.11.2026, 12:00 |  | normal |
| 6 | button | Fortsetzen | Wert:  | normal |
| 7 | button | Verwerfen | Wert:  | normal |
| 8 | text | Anna Beispiel · Arbeitsverhalten |  | normal |
| 9 | text | Synthetische Beobachtung |  | normal |
| 10 | text | 01.11.2026, 12:00 |  | normal |
| 11 | button | Fortsetzen | Wert:  | normal |
| 12 | button | Verwerfen | Wert:  | normal |
| 13 | text | Anna Beispiel · Organisatorisches |  | normal |
| 14 | text | Synthetische Notiz |  | normal |
| 15 | text | 01.11.2026, 12:00 |  | normal |
| 16 | button | Fortsetzen | Wert:  | normal |
| 17 | button | Verwerfen | Wert:  | normal |
| 18 | h3 | Begonnene Bearbeitungen |  | normal |
| 19 | text | Aufgabenrückmeldung |  | normal |
| 20 | text | Unfertiger synthetischer Kommentar |  | normal |
| 21 | button | Öffnen | Wert:  | type=button |

## comment-save-error

Dialog/Container: `homeworkTaskDialog`. Klassen: `small-dialog`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 #homeworkTaskTitle | Kommentar & Stand |  | normal |
| 2 | button | ×<br>aria-label: Schließen | Wert:  | type=button |
| 3 | div | Nicht gespeichert – bitte exportieren. Bitte Fenster offen lassen und erneut speichern.Sicherung exportieren |  | normal |
| 4 | text | Nicht gespeichert – bitte exportieren. Bitte Fenster offen lassen und erneut speichern. |  | normal |
| 5 | button | Sicherung exportieren | Wert:  | type=button |
| 6 | text | Aufgabe A |  | normal |
| 7 | legend | Bearbeitungsstand |  | normal |
| 8 | label | Vollständig |  | normal |
| 9 | input |  | Wert: erledigt | type=radio, checked=False |
| 10 | text | Vollständig |  | normal |
| 11 | label | Teilweise |  | normal |
| 12 | input |  | Wert: teilweise | type=radio, checked=False |
| 13 | text | Teilweise |  | normal |
| 14 | label | Nicht erledigt |  | normal |
| 15 | input |  | Wert: nicht | type=radio, checked=False |
| 16 | text | Nicht erledigt |  | normal |
| 17 | label | Kommentar optional |  | normal |
| 18 | text | Kommentar |  | normal |
| 19 | text | optional |  | normal |
| 20 | textarea #hwTaskComment |  | Wert: Unfertiger synthetischer Kommentar<br>Platzhalter: Notiz … | maxlength=3000 |
| 21 | button | Abbrechen | Wert:  | type=button |
| 22 | button | Speichern | Wert:  | type=submit |

## draft-close-error

Dialog/Container: `discardEditDialog`. Klassen: `small-dialog`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 | Entwurf nicht gesichert |  | normal |
| 2 | div | Entwurf nur in dieser Sitzung – bitte exportieren. Bitte Fenster offen lassen und erneut speichern.Sicherung exportieren |  | normal |
| 3 | text | Entwurf nur in dieser Sitzung – bitte exportieren. Bitte Fenster offen lassen und erneut speichern. |  | normal |
| 4 | button | Sicherung exportieren | Wert:  | type=button |
| 5 | text | Die Eingabe ist nur in dieser Sitzung vorhanden. |  | normal |
| 6 | button #keepEditing | Weiterbearbeiten | Wert:  | type=button |
| 7 | button #exportFailedDraft | Sicherung exportieren | Wert:  | type=button |
| 8 | button #discardEditing | Verwerfen | Wert:  | type=button |

## Sicherung öffnen

Dialog/Container: `audit-password`. Klassen: `small-dialog`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 | Sicherung öffnen |  | normal |
| 2 | label | Passwort |  | normal |
| 3 | text | Passwort |  | normal |
| 4 | input |  | Wert:  | type=password, required=True |
| 5 | text | Das Passwort wird nicht gespeichert. Ohne Passwort kann eine verschlüsselte Sicherung nicht wiederhergestellt werden. |  | normal |
| 6 | button | Abbrechen | Wert:  | type=button |
| 7 | button | Fortfahren | Wert:  | type=submit |

## Sicherung verschlüsseln

Dialog/Container: `audit-password`. Klassen: `small-dialog`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 | Sicherung verschlüsseln |  | normal |
| 2 | label | Passwort |  | normal |
| 3 | text | Passwort |  | normal |
| 4 | input |  | Wert:  | type=password, required=True |
| 5 | text | Das Passwort wird nicht gespeichert. Ohne Passwort kann eine verschlüsselte Sicherung nicht wiederhergestellt werden. |  | normal |
| 6 | button | Abbrechen | Wert:  | type=button |
| 7 | button | Fortfahren | Wert:  | type=submit |

## settings-page

Dialog/Container: `settingsPage`. Klassen: ``.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 | Einstellungen |  | normal |
| 2 | text | Änderungen werden automatisch auf diesem Gerät gespeichert. |  | normal |
| 3 | button #settings-tab-appearance | Darstellung | Wert:  | type=button |
| 4 | button #settings-tab-interaction | Bedienung | Wert:  | type=button |
| 5 | button #settings-tab-data | Daten | Wert:  | type=button |
| 6 | h2 | Stilvorlagen |  | normal |
| 7 | text | Schnell wählen, darunter gezielt anpassen. |  | normal |
| 8 | button | Ruhig | Wert:  | type=button, pressed=false |
| 9 | button | Bild dezent | Wert:  | type=button, disabled=True, pressed=false |
| 10 | button | Bild klar | Wert:  | type=button, disabled=True, pressed=false |
| 11 | text | Für Bildvorlagen zuerst unter Hintergrund ein Bild wählen. |  | normal |
| 12 | label | Lesbarkeitsschutz |  | normal |
| 13 | input #readabilityProtection |  | Wert: on | type=checkbox, checked=False |
| 14 | text | Lesbarkeitsschutz |  | normal |
| 15 | text | Sorgt bei Hintergrundbildern für deckende Leseflächen. |  | normal |
| 16 | label | Alle Flächen gemeinsam einstellen |  | normal |
| 17 | input #appearanceLinked |  | Wert: on | type=checkbox, checked=False |
| 18 | text | Alle Flächen gemeinsam einstellen |  | normal |
| 19 | text | Übernimmt zunächst die Buttonwerte. Danach gelten Farb- und Transparenzänderungen für alle Flächen. Ausschalten ermöglicht wieder getrennte Werte. |  | normal |
| 20 | summary | HintergrundFarbe, Bild und TönungFarbe aktiv |  | normal |
| 21 | h3 | Hintergrund |  | eingeklappt |
| 22 | button #resetBackground | Zurücksetzen | Wert:  | eingeklappt, type=button |
| 23 | text | Wähle eine Farbe. Helle oder dunkle Schrift passt sich automatisch an. |  | eingeklappt |
| 24 | input #appBackground | aria-label: Hintergrundfarbe wählen | Wert: #4f6038 | eingeklappt, type=color |
| 25 | label | Eigene Farbe |  | eingeklappt |
| 26 | text | Eigene Farbe |  | eingeklappt |
| 27 | input #appBackgroundHex |  | Wert: #4F6038 | eingeklappt, type=text, maxlength=7 |
| 28 | text | HEX-Farbwert, z. B. #4F6038 |  | eingeklappt |
| 29 | button | aria-label: Oliv<br>Tooltip: Oliv | Wert:  | eingeklappt, type=button, pressed=true |
| 30 | button | aria-label: Salbei<br>Tooltip: Salbei | Wert:  | eingeklappt, type=button, pressed=false |
| 31 | button | aria-label: Sand<br>Tooltip: Sand | Wert:  | eingeklappt, type=button, pressed=false |
| 32 | button | aria-label: Hell<br>Tooltip: Hell | Wert:  | eingeklappt, type=button, pressed=false |
| 33 | button | aria-label: Blau<br>Tooltip: Blau | Wert:  | eingeklappt, type=button, pressed=false |
| 34 | button | aria-label: Pflaume<br>Tooltip: Pflaume | Wert:  | eingeklappt, type=button, pressed=false |
| 35 | button | aria-label: Graphit<br>Tooltip: Graphit | Wert:  | eingeklappt, type=button, pressed=false |
| 36 | text | Aa |  | eingeklappt |
| 37 | text | Helle Schrift · automatisch |  | eingeklappt |
| 38 | h3 | Hintergrundbild |  | eingeklappt |
| 39 | text | Zum Beispiel dein Tafelbild. Das Bild bleibt auf diesem Gerät. Bei einer vollständigen Sicherung kannst du es mitsichern. |  | eingeklappt |
| 40 | label | Bild verwenden |  | eingeklappt |
| 41 | input #useBackgroundImage |  | Wert: on | eingeklappt, type=checkbox, checked=False, disabled=True |
| 42 | text | Bild verwenden |  | eingeklappt |
| 43 | button #chooseBackgroundImage | Bild wählen | Wert:  | eingeklappt, type=button |
| 44 | input #backgroundImageFile |  | Wert:  | verborgen, eingeklappt, type=file |
| 45 | button #removeBackgroundImage | Bild entfernen | Wert:  | eingeklappt, type=button, disabled=True |
| 46 | text | Noch kein Bild gewählt. JPEG, PNG oder WebP, maximal 12 MB. |  | eingeklappt |
| 47 | label | Abdunklung 40 % |  | eingeklappt |
| 48 | text | Abdunklung |  | eingeklappt |
| 49 | text | 40 % |  | eingeklappt |
| 50 | input #backgroundDim |  | Wert: 40 | eingeklappt, type=range, disabled=True |
| 51 | input #backgroundTint | aria-label: Bildtönung wählen | Wert: #203a2d | eingeklappt, type=color |
| 52 | label | Bildtönung |  | eingeklappt |
| 53 | text | Bildtönung |  | eingeklappt |
| 54 | input #backgroundTintHex |  | Wert: #203A2D | eingeklappt, type=text, maxlength=7 |
| 55 | label | Stärke der Tönung 25 % |  | eingeklappt |
| 56 | text | Stärke der Tönung |  | eingeklappt |
| 57 | text | 25 % |  | eingeklappt |
| 58 | input #backgroundTintStrength |  | Wert: 25 | eingeklappt, type=range |
| 59 | button #resetImageTint | Tönung zurücksetzen | Wert:  | eingeklappt, type=button |
| 60 | text | Die Tönung legt Farbe über das Bild. Bei 0 % bleibt die Bildfarbe unverändert. Ausschalten behält das Bild für später. |  | eingeklappt |
| 61 | summary | HauptansichtKopfbereich und SchülerkartenKopf 12 % · Karten 18 % |  | normal |
| 62 | h3 | Kopfbereich |  | eingeklappt |
| 63 | button | Zurücksetzen | Wert:  | eingeklappt, type=button |
| 64 | text | Farbe und Transparenz unabhängig einstellen. Bei 100 % ist der Hintergrund vollständig sichtbar, ohne Weichzeichnung. Schrift und Symbole bleiben deckend. |  | eingeklappt |
| 65 | label | Transparenz 12 % |  | eingeklappt |
| 66 | text | Transparenz |  | eingeklappt |
| 67 | text | 12 % |  | eingeklappt |
| 68 | input #headerTransparency |  | Wert: 12 | eingeklappt, type=range |
| 69 | input #headerColor | aria-label: Farbe für Kopfbereich | Wert: #000000 | eingeklappt, type=color |
| 70 | label | Eigene Farbe |  | eingeklappt |
| 71 | text | Eigene Farbe |  | eingeklappt |
| 72 | input #headerColorHex | aria-label: Kopfbereich HEX-Farbe | Wert:  | eingeklappt, type=text, maxlength=7 |
| 73 | button | aria-label: Oliv<br>Tooltip: Oliv | Wert:  | eingeklappt, type=button, pressed=false |
| 74 | button | aria-label: Salbei<br>Tooltip: Salbei | Wert:  | eingeklappt, type=button, pressed=false |
| 75 | button | aria-label: Sand<br>Tooltip: Sand | Wert:  | eingeklappt, type=button, pressed=false |
| 76 | button | aria-label: Hell<br>Tooltip: Hell | Wert:  | eingeklappt, type=button, pressed=false |
| 77 | button | aria-label: Blau<br>Tooltip: Blau | Wert:  | eingeklappt, type=button, pressed=false |
| 78 | button | aria-label: Pflaume<br>Tooltip: Pflaume | Wert:  | eingeklappt, type=button, pressed=false |
| 79 | button | aria-label: Graphit<br>Tooltip: Graphit | Wert:  | eingeklappt, type=button, pressed=false |
| 80 | button | Farbe dem Hintergrund anpassen | Wert:  | eingeklappt, type=button, pressed=true |
| 81 | text | Bei hoher Transparenz kann ein unruhiges Bild die Lesbarkeit beeinträchtigen. |  | eingeklappt |
| 82 | h3 | Schülerkarten |  | eingeklappt |
| 83 | button | Zurücksetzen | Wert:  | eingeklappt, type=button |
| 84 | text | Farbe und Transparenz unabhängig einstellen. Bei 100 % ist der Hintergrund vollständig sichtbar, ohne Weichzeichnung. Schrift und Symbole bleiben deckend. |  | eingeklappt |
| 85 | label | Transparenz 18 % |  | eingeklappt |
| 86 | text | Transparenz |  | eingeklappt |
| 87 | text | 18 % |  | eingeklappt |
| 88 | input #cardTransparency |  | Wert: 18 | eingeklappt, type=range |
| 89 | input #cardColor | aria-label: Farbe für Schülerkarten | Wert: #000000 | eingeklappt, type=color |
| 90 | label | Eigene Farbe |  | eingeklappt |
| 91 | text | Eigene Farbe |  | eingeklappt |
| 92 | input #cardColorHex | aria-label: Schülerkarten HEX-Farbe | Wert:  | eingeklappt, type=text, maxlength=7 |
| 93 | button | aria-label: Oliv<br>Tooltip: Oliv | Wert:  | eingeklappt, type=button, pressed=false |
| 94 | button | aria-label: Salbei<br>Tooltip: Salbei | Wert:  | eingeklappt, type=button, pressed=false |
| 95 | button | aria-label: Sand<br>Tooltip: Sand | Wert:  | eingeklappt, type=button, pressed=false |
| 96 | button | aria-label: Hell<br>Tooltip: Hell | Wert:  | eingeklappt, type=button, pressed=false |
| 97 | button | aria-label: Blau<br>Tooltip: Blau | Wert:  | eingeklappt, type=button, pressed=false |
| 98 | button | aria-label: Pflaume<br>Tooltip: Pflaume | Wert:  | eingeklappt, type=button, pressed=false |
| 99 | button | aria-label: Graphit<br>Tooltip: Graphit | Wert:  | eingeklappt, type=button, pressed=false |
| 100 | button | Farbe dem Hintergrund anpassen | Wert:  | eingeklappt, type=button, pressed=true |
| 101 | text | Bei hoher Transparenz kann ein unruhiges Bild die Lesbarkeit beeinträchtigen. |  | eingeklappt |
| 102 | summary | Buttons & EingabefelderFarbe und TransparenzButtons 6 % · Felder 6 % |  | normal |
| 103 | h3 | Buttons |  | eingeklappt |
| 104 | button | Zurücksetzen | Wert:  | eingeklappt, type=button |
| 105 | text | Hintergrund der Auswahl- und Zusatzbuttons in Dialogen. Aktive Auswahl und Positiv-/Negativfarben bleiben erkennbar. |  | eingeklappt |
| 106 | label | Transparenz 6 % |  | eingeklappt |
| 107 | text | Transparenz |  | eingeklappt |
| 108 | text | 6 % |  | eingeklappt |
| 109 | input #buttonTransparency |  | Wert: 6 | eingeklappt, type=range |
| 110 | input #buttonColor | aria-label: Button-Hintergrundfarbe | Wert: #000000 | eingeklappt, type=color |
| 111 | label | Eigene Farbe |  | eingeklappt |
| 112 | text | Eigene Farbe |  | eingeklappt |
| 113 | input #buttonColorHex |  | Wert: #NANNANNAN | eingeklappt, type=text, maxlength=7 |
| 114 | button | aria-label: Oliv<br>Tooltip: Oliv | Wert:  | eingeklappt, type=button, pressed=false |
| 115 | button | aria-label: Salbei<br>Tooltip: Salbei | Wert:  | eingeklappt, type=button, pressed=false |
| 116 | button | aria-label: Sand<br>Tooltip: Sand | Wert:  | eingeklappt, type=button, pressed=false |
| 117 | button | aria-label: Hell<br>Tooltip: Hell | Wert:  | eingeklappt, type=button, pressed=false |
| 118 | button | aria-label: Blau<br>Tooltip: Blau | Wert:  | eingeklappt, type=button, pressed=false |
| 119 | button | aria-label: Pflaume<br>Tooltip: Pflaume | Wert:  | eingeklappt, type=button, pressed=false |
| 120 | button | aria-label: Graphit<br>Tooltip: Graphit | Wert:  | eingeklappt, type=button, pressed=false |
| 121 | button | Farbe automatisch anpassen | Wert:  | eingeklappt, type=button, pressed=true |
| 122 | text | 0 %: deckend. 100 %: keine Farbfüllung. |  | eingeklappt |
| 123 | h3 | Eingabefelder |  | eingeklappt |
| 124 | button | Zurücksetzen | Wert:  | eingeklappt, type=button |
| 125 | text | Hintergrund der Schreibfelder und Auswahllisten in Dialogen. |  | eingeklappt |
| 126 | label | Transparenz 6 % |  | eingeklappt |
| 127 | text | Transparenz |  | eingeklappt |
| 128 | text | 6 % |  | eingeklappt |
| 129 | input #fieldTransparency |  | Wert: 6 | eingeklappt, type=range |
| 130 | input #fieldColor | aria-label: Eingabefeld-Hintergrundfarbe | Wert: #000000 | eingeklappt, type=color |
| 131 | label | Eigene Farbe |  | eingeklappt |
| 132 | text | Eigene Farbe |  | eingeklappt |
| 133 | input #fieldColorHex |  | Wert: #NANNANNAN | eingeklappt, type=text, maxlength=7 |
| 134 | button | aria-label: Oliv<br>Tooltip: Oliv | Wert:  | eingeklappt, type=button, pressed=false |
| 135 | button | aria-label: Salbei<br>Tooltip: Salbei | Wert:  | eingeklappt, type=button, pressed=false |
| 136 | button | aria-label: Sand<br>Tooltip: Sand | Wert:  | eingeklappt, type=button, pressed=false |
| 137 | button | aria-label: Hell<br>Tooltip: Hell | Wert:  | eingeklappt, type=button, pressed=false |
| 138 | button | aria-label: Blau<br>Tooltip: Blau | Wert:  | eingeklappt, type=button, pressed=false |
| 139 | button | aria-label: Pflaume<br>Tooltip: Pflaume | Wert:  | eingeklappt, type=button, pressed=false |
| 140 | button | aria-label: Graphit<br>Tooltip: Graphit | Wert:  | eingeklappt, type=button, pressed=false |
| 141 | button | Farbe automatisch anpassen | Wert:  | eingeklappt, type=button, pressed=true |
| 142 | text | 0 %: deckend. 100 %: keine Farbfüllung. |  | eingeklappt |
| 143 | summary | DialogeHintergrund, Kopf- und FußzeileFläche 0 % |  | normal |
| 144 | h3 | Dialoghintergrund |  | eingeklappt |
| 145 | button | Zurücksetzen | Wert:  | eingeklappt, type=button |
| 146 | text | Farbfläche über dem Dialogbild. Kopf- und Fußzeile stellst du separat ein. |  | eingeklappt |
| 147 | label | Transparenz 0 % |  | eingeklappt |
| 148 | text | Transparenz |  | eingeklappt |
| 149 | text | 0 % |  | eingeklappt |
| 150 | input #modalTransparency |  | Wert: 0 | eingeklappt, type=range |
| 151 | input #modalColor | aria-label: Dialog-Hintergrundfarbe | Wert: #000000 | eingeklappt, type=color |
| 152 | label | Eigene Farbe |  | eingeklappt |
| 153 | text | Eigene Farbe |  | eingeklappt |
| 154 | input #modalColorHex |  | Wert:  | eingeklappt, type=text, maxlength=7 |
| 155 | button | aria-label: Oliv<br>Tooltip: Oliv | Wert:  | eingeklappt, type=button, pressed=false |
| 156 | button | aria-label: Salbei<br>Tooltip: Salbei | Wert:  | eingeklappt, type=button, pressed=false |
| 157 | button | aria-label: Sand<br>Tooltip: Sand | Wert:  | eingeklappt, type=button, pressed=false |
| 158 | button | aria-label: Hell<br>Tooltip: Hell | Wert:  | eingeklappt, type=button, pressed=false |
| 159 | button | aria-label: Blau<br>Tooltip: Blau | Wert:  | eingeklappt, type=button, pressed=false |
| 160 | button | aria-label: Pflaume<br>Tooltip: Pflaume | Wert:  | eingeklappt, type=button, pressed=false |
| 161 | button | aria-label: Graphit<br>Tooltip: Graphit | Wert:  | eingeklappt, type=button, pressed=false |
| 162 | button | Farbe automatisch anpassen | Wert:  | eingeklappt, type=button, pressed=true |
| 163 | text | 0 %: deckend. 100 %: keine Farbfüllung. Das aktivierte Hintergrundbild bleibt sichtbar. |  | eingeklappt |
| 164 | h3 | Dialogfenster |  | eingeklappt |
| 165 | button #resetModalAppearance | Zurücksetzen | Wert:  | eingeklappt, type=button |
| 166 | text | Das eingeschaltete Hintergrundbild erscheint auch in den Dialogfenstern, mit derselben Tönung und Abdunklung. |  | eingeklappt |
| 167 | label | Kopfzeile 35 % |  | eingeklappt |
| 168 | text | Kopfzeile |  | eingeklappt |
| 169 | text | 35 % |  | eingeklappt |
| 170 | input #modalHeaderTransparency |  | Wert: 35 | eingeklappt, type=range |
| 171 | label | Fußzeile 35 % |  | eingeklappt |
| 172 | text | Fußzeile |  | eingeklappt |
| 173 | text | 35 % |  | eingeklappt |
| 174 | input #modalFooterTransparency |  | Wert: 35 | eingeklappt, type=range |
| 175 | text | 0 %: deckend. 100 %: vollständig transparent. Die Fußzeilen-Einstellung gilt auch für Datum und Nachbereitung. Text und Schaltflächen bleiben sichtbar. |  | eingeklappt |
| 176 | summary | Live-Vorschau |  | normal |
| 177 | h2 | Vorschau |  | eingeklappt |
| 178 | text | Kopfbereich, Schülerkarte und Dialog mit deinen Einstellungen. |  | eingeklappt |
| 179 | text | Übersicht · Schüler · … |  | eingeklappt |
| 180 | text | Schülername |  | eingeklappt |
| 181 | text | Ziele |  | eingeklappt |
| 182 | text | Sozial |  | eingeklappt |
| 183 | text | Arbeit |  | eingeklappt |
| 184 | text | HÜ |  | eingeklappt |
| 185 | text | Orga |  | eingeklappt |
| 186 | text | Beobachtung |  | eingeklappt |
| 187 | text | Was ist passiert? |  | eingeklappt |
| 188 | button | Hilft anderen | Wert:  | eingeklappt, type=button |
| 189 | label | Beispieleingabe |  | eingeklappt |
| 190 | text | Beispieleingabe |  | eingeklappt |
| 191 | textarea #previewControlField | aria-label: Beispieleingabe | Wert: <br>Platzhalter: Beobachtung … | eingeklappt |
| 192 | text | Eintrag speichern |  | eingeklappt |
| 193 | h2 | Karten-Shortcuts |  | verborgen |
| 194 | button #resetShortcutOrder | Zurücksetzen | Wert:  | verborgen, type=button |
| 195 | text | Von links nach rechts, zuerst die obere Zeile. Mit den Pfeilen verschieben. |  | verborgen |
| 196 | text | 1 |  | verborgen |
| 197 | text | Ziele |  | verborgen |
| 198 | button | ↑<br>aria-label: Ziele nach vorne | Wert:  | verborgen, type=button, disabled=True |
| 199 | button | ↓<br>aria-label: Ziele nach hinten | Wert:  | verborgen, type=button |
| 200 | text | 2 |  | verborgen |
| 201 | text | Sozialverhalten |  | verborgen |
| 202 | button | ↑<br>aria-label: Sozialverhalten nach vorne | Wert:  | verborgen, type=button |
| 203 | button | ↓<br>aria-label: Sozialverhalten nach hinten | Wert:  | verborgen, type=button |
| 204 | text | 3 |  | verborgen |
| 205 | text | Arbeitsverhalten |  | verborgen |
| 206 | button | ↑<br>aria-label: Arbeitsverhalten nach vorne | Wert:  | verborgen, type=button |
| 207 | button | ↓<br>aria-label: Arbeitsverhalten nach hinten | Wert:  | verborgen, type=button |
| 208 | text | 4 |  | verborgen |
| 209 | text | Hausübung |  | verborgen |
| 210 | button | ↑<br>aria-label: Hausübung nach vorne | Wert:  | verborgen, type=button |
| 211 | button | ↓<br>aria-label: Hausübung nach hinten | Wert:  | verborgen, type=button |
| 212 | text | 5 |  | verborgen |
| 213 | text | Organisatorisches |  | verborgen |
| 214 | button | ↑<br>aria-label: Organisatorisches nach vorne | Wert:  | verborgen, type=button |
| 215 | button | ↓<br>aria-label: Organisatorisches nach hinten | Wert:  | verborgen, type=button, disabled=True |
| 216 | h2 | Sichern & wiederherstellen |  | verborgen |
| 217 | text | Daten und Entwürfe exportieren oder eine Sicherung einlesen. Darstellung und Hintergrundbild sind optional. |  | verborgen |
| 218 | button | Sicherung / Import öffnen | Wert:  | verborgen, type=button |
| 219 | text | Passwortschutz lässt sich beim Export wählen. |  | verborgen |
| 220 | h2 | Papierkorb |  | verborgen |
| 221 | text | 1 gelöschte Einträge. Hier wiederherstellen oder endgültig entfernen. |  | verborgen |
| 222 | button | Papierkorb öffnen | Wert:  | verborgen, type=button |
| 223 | summary | SpeicherpflegeTechnischen Speicher zusammenfassen |  | verborgen |
| 224 | text | Einträge und frühere Fassungen bleiben erhalten. |  | verborgen, eingeklappt |
| 225 | button | Speicherpflege öffnen | Wert:  | verborgen, eingeklappt, type=button |
| 226 | text | Auf diesem Gerät gespeichert. |  | normal |

## discardEditDialog

Dialog/Container: `discardEditDialog`. Klassen: `small-dialog`.

| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |
| --- | --- | --- | --- | --- |
| 1 | h2 | Entwurf nicht gesichert |  | normal |
| 2 | text | Die Eingabe ist nur in dieser Sitzung vorhanden. |  | normal |
| 3 | button #keepEditing | Weiterbearbeiten | Wert:  | type=button |
| 4 | button #exportFailedDraft | Sicherung exportieren | Wert:  | type=button |
| 5 | button #discardEditing | Verwerfen | Wert:  | type=button |

## Laufdiagnostik

```json
[]
```

Eine leere Diagnostikliste bestätigt nur, dass dieser Inspektionslauf keine jsdom-Ausnahme meldete. Sie ist kein Nachweis für Layout, vollständige Fachkorrektheit, Flutter oder reale Plattformbedienung.
