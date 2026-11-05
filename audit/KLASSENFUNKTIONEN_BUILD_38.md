# FLEX-Klasse: Kalender, Materialien, Rückläufe und Entwicklung

Stand: 05.11.2026. Umsetzung für **eine FLEX-Klasse**; keine zusätzliche Klassenverwaltung.
Version: **0.16.0-rebuild.18+38**. Paketkennung und Testsignatur bleiben erhalten.

## Nutzbare Funktionen

- **Kalender:** Heute-/Tages-, Wochen- und Monatsansicht für Unterricht, Orga-Termine,
  Aufgaben, HÜ, Zielüberprüfungen, Rücklauffristen und Ferien. Filter und direkte Bearbeitung.
  Unterricht mit Fach, Raum, Ablauf, Materialien, Wiederholungen, A/B-Wochen und Enddatum.
  Einzelne Stunden ändern/verschieben/absagen; Änderungen ab einer Durchführung teilen
  die Serie und erhalten frühere Stunden. „Serien, Ferien & Ausfälle verwalten“ erlaubt
  Bearbeitung, Papierkorb/Wiederherstellung und Rücknahme einzelner Ausnahmen.
- **Materialien & Planungen:** DOCX/PDF-Dateiauswahl auf Android, HTTPS-/OneDrive-Links,
  Fach-/Themenangaben, Wochenplan-Zuordnung und Verknüpfung mit Unterricht oder Rückläufen.
  PDFs über Androids PDF-Renderer in FLEX, DOCX über eine externe geeignete Anwendung.
  Offlinekopien, Aktualisierung, Status, Papierkorb und getrennte verschlüsselte Materialpakete.
  Unterricht öffnet auch HÜ-Erfassung und Schülerbeobachtung mit Datum/Fach vorbelegt.
- **Rückläufe:** Formular, Zustimmung, Material oder Beitrag; Teilnehmer aus der FLEX-Klasse,
  Frist, Erinnerung, Notizen, Teilzahlungen/Beträge, Mehrfachauswahl, Abschluss/Wiederöffnung,
  Änderungsverlauf und PDF. „Abgelehnt“ zählt bei Zustimmung als beantwortet.
- **Orga-Serien und Erinnerungen:** Täglich, wöchentlich, zweiwöchentlich oder monatlich;
  Enddatum, Wochentage und Ferien auslassen. Wiederholung über das sichtbare Seriensymbol
  eines gespeicherten Termins oder einer fälligen Aufgabe. Einzeln geänderte, erledigte oder
  gelöschte Durchführungen bleiben bei Serienänderungen erhalten. Erinnerung eine Stunde,
  auf morgen 09:00 oder auf einen gewählten Zeitpunkt verschieben; Fristen bleiben gleich.
- **Entwicklungsübersicht:** Im Schülerdialog „Entwicklung“ öffnen; Zeitraum, Sozial/Arbeit
  und Thema/Tag/Freitext filtern. Wochen inklusive leerer Wochen, Originalbeobachtungen und
  Ziele. Ausgewählte Beobachtungen in die vorhandene Gesprächsvorbereitung übernehmen.
  Zahlen beschreiben dokumentierte Beobachtungen, keine automatisch vergebenen Bewertungen.
  Freitext ohne Tags wird nicht nachträglich einer Tonart zugeordnet.

## Daten und Verknüpfungen

SQL-Schema 7 und Sicherungsformat 1 bleiben kompatibel. Neue Klassenobjekte verwenden
versionierte Dokumente im vorhandenen transaktionalen Speicher, mit Revisionen und
Änderungsverlauf. Alte Sicherungen sind weiterhin lesbar. Neue Daten werden mit exportiert,
beim Zusammenführen unabhängig von Katalogoptionen übernommen und auf gültige Schüler- und
Materialverweise geprüft. Passwortgeschützte Materialpakete enthalten die Dateiinhalte;
notwendige Passwörter außerhalb der App aufbewahren.

Kalender-, Material- und Rücklaufeditoren verwenden die vorhandene Entwurfssicherung.
Speichern und Entwurfsentfernung erfolgen gemeinsam. Veraltete Fassungen werden abgewiesen.
Serienquellen und Löschmarkierungen bleiben bei Speicherwartung erhalten, damit das Leeren
des Papierkorbs keine Durchführung neu erzeugt oder eine Serienzuordnung beschädigt.

## Bewusste Grenzen

- **Direkte OneDrive-Anmeldung benötigt noch eine eigene Microsoft-Appregistrierung.**
  Diese Version enthält keine Client-ID. [Einrichtung](../docs/ONEDRIVE_EINRICHTEN.md).
- ICS ist manueller Import/Export, keine Kalendersynchronisierung. Import mit Vorschau
  und stabilen IDs; bestehende Ereignisse müssen zur Änderung ausdrücklich ausgewählt werden.
  Unterstützt werden einzelne Ereignisse sowie einfache tägliche, wöchentliche und monatliche
  Serien. Nicht unterstützte Regeln, mehrtägige Termine, abgetrennte Serienausnahmen und
  monatliche ICS-Serien am 29.–31. werden mit Hinweis ausgelassen. FLEX-eigene monatliche
  Wiederholungen verwenden bei kurzen Monaten deren letzten Tag. Exportiert wird der
  sichtbare Zeitraum als einzelne Ereignisse, kein unbegrenztes Serienskelett.
- Orga-Serien erzeugen beim Öffnen/Nachladen einen begrenzten Horizont von einem Jahr.
  Versäumte historische Durchführungen werden nicht nachträglich erfunden.
- Die nächsten maximal 200 Android-Erinnerungen werden eingeplant und beim Nachladen
  ergänzt. Android-Berechtigungen und Energiesparverhalten gelten weiterhin.
- Offlineimport, lokale PDF-Anzeige und Materialpakete richten sich in diesem Build an
  Android. Web/Windows behalten Links, Metadaten und die übrigen Klassenfunktionen.
- Keine automatische Synchronisierung oder Bearbeitung der OneDrive-Originaldokumente.
- Kein physischer Android-Gerätelauf und kein Browserlauf in dieser Arbeitsumgebung.
  Echte OneDrive-Anmeldung, Word-Übergabe, PDF-Rendering, Update mit bestehenden Daten und
  Benachrichtigungen bei geschlossenem Prozess sind am Gerät noch abzunehmen.

## Prüfnachweise

Automatisierte Prüfungen decken insbesondere Kalenderarithmetik über Zeitumstellungen,
A/B-Wochen, Ausnahmen, Serienbeendigung, Papierkorbwartung, Datenimport/-zuordnungen,
Transaktionsrücknahmen, verschobene Erinnerungen, verschlüsselte Materialpakete,
DOCX/PDF-Typprüfung, Gerätecodeflow/Abbruch/Refresh und sichere Download-Header ab.
Widgettests prüfen Entwurfswiederherstellung, Fokus nach Autosave, Seriensplitting,
Rücklauf- und Zahlungsaktionen, Navigation per Swipe sowie große Schrift auf 390-Pixel-Displays.
Direkte Flutter-Aufnahmen von Kalender und Materialseite wurden visuell geprüft.
Die abschließenden Testergebnisse und APK-Prüfsummen stehen im Build-38-Releaseordner.
