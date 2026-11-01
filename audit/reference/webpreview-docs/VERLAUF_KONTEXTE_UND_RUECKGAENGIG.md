# Verlauf, gemeinsame Kontexte und Gruppenrücknahme

Stand: Flutter 0.5.0+5, 31.10.2026. Fortsetzung des nativen HTML-Nachbaus;
alle Originaldateien bleiben unverändert. Verglichen wurden insbesondere
`scratch/reliable-app.js:51–54`, `review-interface.js:7–8`, `bulk-entries.js:19`
und `save-undo.js:3–7` des Prototyps. Browser wurden nicht verwendet.

## Neue Abläufe

### Bereichsbezogener Verlauf

Das Verlaufssymbol im Eintragsdialog öffnet einen eigenen Detaildialog mit dem
aktuellen Bereich vorausgewählt. „Gesamter Verlauf“ in der Schülerübersicht öffnet
alle Bereiche. Es gibt Textsuche, Bereichswahl, Von-/Bis-Datum und „Nur offene
Nachbereitung“. Datumsgrenzen gelten einschließlich des jeweiligen Tages.
Die Sortierung verwendet Beobachtungsdatum und optionale Beobachtungsuhrzeit.

Die Suche berücksichtigt auch Arbeitsauftrag, Zielkriterium, Unterstützung,
Erinnerungstext und gemeinsamen Kontext einschließlich Beteiligter. Nur erwähnte
Kinder erhalten weiterhin keine fremde Einzelbewertung. Gelöschte bzw.
zurückgenommene Einträge erscheinen nicht im Verlauf.

Eine Karte aufklappen und „Bearbeiten“ wählen öffnet die gespeicherte Beobachtung
oder Orga-Notiz direkt. Nach erfolgreichem Speichern kehrt die App zum gefilterten
Verlauf zurück. Beim Schließen des Verlaufs bleibt das zuvor geöffnete
Eingabeformular mitsamt Freitext und Tag-Auswahl erhalten. Ungespeicherte Eingaben
werden vor dem Wechsel als eigener Entwurf gesichert.

### Gemeinsamer Kontext

Im Kontextdialog lassen sich Text, zusätzlich beteiligte Schüler und weitere
Namen bearbeiten. Beteiligte mit verknüpften Einträgen bleiben fest zugeordnet;
das schützt auch die spätere Wiederherstellung bereits gelöschter Beobachtungen.
Doppelte weitere Namen werden zusammengefasst. Das Hinzufügen einer beteiligten
Person erzeugt keine Einzelbeobachtung.

Unter „Individuelle Beobachtungen“ öffnet „Beobachtung bearbeiten“ den Eintrag des
betreffenden Kindes. Der gemeinsame Kontext bleibt im Hintergrund erhalten;
seine ungespeicherten Änderungen werden vorher gesichert. Speichern der
Einzelbeobachtung führt zum Kontextdialog zurück. Die übrigen Beobachtungen
werden dadurch nicht verändert.

Änderungen an Beteiligten, die im Kontextdialog vorgenommen wurden, werden beim
späteren Bearbeiten einer Beobachtung nicht durch deren älteren Teilnehmerstand
ersetzt. Bei einem tatsächlichen Versionskonflikt zeigt der Kontextdialog den
aktuellen Text und die Beteiligten. Erst „Meine Änderungen auf diesen Stand
anwenden“ übernimmt den neuen Ausgangsstand für einen erneuten Speicherversuch.

### Gruppen rückgängig machen

Nach dem Speichern bietet die Meldung „Rückgängig“ an. Unter
„… → Gruppenerfassungen“ bleibt der Vorgang auch nach erneutem Laden erreichbar.
Das gilt für Sozial-/Arbeitsbeobachtungen, Hausübungen und Orga; auch die direkte
Empfängerwahl beim Aufgeben einer Hausübung verwendet diesen Gruppenweg.
Bei nur einem Empfänger bleibt der Wiederherstellungsdialog auf Hausübung
festgelegt; ein unzulässiger Wechsel zu einer anderen Gruppenart ist ausgeschlossen.

Die Rücknahme ist nur möglich, solange alle betroffenen Einträge und der gemeinsame
Kontext unverändert sind, keine weiteren Beobachtungen den Kontext verwenden und
keine Bearbeitungsentwürfe für diese Einträge oder den Kontext vorliegen. Geprüft
werden die Revision und der ursprünglich protokollierte Inhalt. Änderungen eines
Kindes verhindern die Rücknahme der gesamten Gruppe. In diesem Fall bleiben die
Daten erhalten und können einzeln bearbeitet werden.

Bei erfolgreicher Rücknahme werden die Einträge mit einer Löschmarkierung und
neuer Revision versehen. Geplante Orga-Erinnerungen werden beendet. Eingaben,
Aufgabenzeilen, Auswahlen und Empfänger werden atomar als neuer Gruppenentwurf
wiederhergestellt und geöffnet. Erneutes Speichern verwendet neue IDs; der alte
Vorgang bleibt in der Historie. Wiederholte Rücknahmeaufrufe erzeugen keine
zusätzlichen Entwürfe. Ein zurückgenommener alter Speicherversuch kann die Einträge
nicht wieder aktivieren. Archivierte Schüler dürfen beim erneuten Speichern
weiterhin nicht als aktive Empfänger verwendet werden.

## Speicherung und Prüfungen

Datenbank/Vollsicherung Version 5 ergänzt `orga.deleted` sowie den Rücknahmestand
und die ID des Wiederherstellungsentwurfs in `group_saves`. Vorhandene
Flutter-Datenbanken und Vollsicherungen der Versionen 1–4 werden ergänzt.
Es werden keine ursprünglichen Einträge, Checklisten-IDs oder Änderungsprotokolle
physisch entfernt. Die HTML-Datenmigration ist weiterhin offen.

Rücknahme, Entwurfswiederherstellung, Änderungsprotokoll und Outbox werden in einer
Transaktion geschrieben. Ein Test löst absichtlich beim zweiten Eintrag einen
SQL-Fehler aus und prüft, dass auch die vorherigen Änderungen vollständig
zurückgerollt werden. Weitere Tests prüfen erneutes Laden, erneutes Speichern,
Blockierung bei Änderungen/Entwürfen/zusätzlichen Beobachtungen, beschädigte
Sicherungen sowie Migration und Rücknahme einer echten Version-4-Datei.

Lokale Widgettests prüfen unter anderem den Wechsel zwischen Eingabe, Verlauf,
Bearbeitung und Kontext, erhaltene Entwürfe, die Rückgängig-Aktion sowie 320 Pixel
Breite mit simulierter Bildschirmtastatur. Die direkt mit Flutter gerenderten
Ansichten 19–24 zeigen die neuen Abläufe. Aktuelle Ergebnisse: `FLUTTER_STATUS.md`.

## Weiterhin offen

Zielbelege und weitere Zielprüfungsoptionen, vollständige Hausübungsrückmeldungen,
Gesprächsvorbereitung, sämtliche Darstellungsregler, Entwurfsschutz für alle
Nebendialoge, vollständige Orga-/Stammdaten-Papierkörbe und HTML-Datenübernahme.
Die neue Gruppenrücknahme ist keine allgemeine Rücknahme beliebiger Einzeländerungen.
Native Windows-/Android-Builds, Geräteprüfungen und Browserpersistenz stehen aus.
Schriftmetriken und einzelne Bedienungsdetails sind noch nicht pixelgleich zum HTML.
Synchronisation und Scanner bleiben spätere Schritte. Es wurde nichts veröffentlicht.
