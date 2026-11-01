# Papierkorb endgültig leeren – Version 0.10.0+10

Referenz sind `purgedState`, `performMaintenance` und der Speicherpflegedialog
der aktuellen HTML-Datei. Der Prototyp bleibt bytegleich. Die Flutter-Umsetzung
übernimmt Vollsicherung, Bestätigung und das Wort **LÖSCHEN** und ergänzt eine
konkrete Vorschau der betroffenen Inhalte.

## Bedienung

1. Begonnene Bearbeitungen schließen; sie bleiben als Entwürfe gespeichert.
2. **… → Einstellungen → Daten → Papierkorb öffnen → Papierkorb endgültig leeren**.
3. Anzahl der Einträge, betroffenen Entwürfe, nicht mehr verwendeten Kontexte,
   Gruppenbelege und verbleibenden Zielverknüpfungen prüfen.
4. **Vollständige Sicherung herunterladen** und die gespeicherte Datei prüfen.
5. **Ich habe die Sicherung gespeichert und andere App-Tabs geschlossen.** bestätigen.
6. Exakt **LÖSCHEN** eingeben und **Ausführen** wählen.

Abbruch oder Fehler bei der Sicherung geben die Löschung nicht frei.
Auch eine Vollsicherung oberhalb der bisherigen Importgrößengrenze wird vor der
Freigabe abgewiesen, damit die Sicherung später wieder eingelesen werden kann. Während einer
laufenden Ausgabe/Bereinigung sind doppelte Aktionen und Schließen gesperrt. Bei
zwischenzeitlichen Änderungen muss der Dialog mit einer neuen Vorschau und
Sicherung erneut geöffnet werden. Ein leerer Papierkorb kann nicht geleert werden.
Nach erfolgreicher Bereinigung bleibt das aktuelle Fenster benutzbar; andere
Fenster müssen neu gestartet werden.

Ein aus einem offenen Editor geöffneter Papierkorb bietet weiterhin
Wiederherstellung. Zum endgültigen Leeren führt er zu den Daten-Einstellungen.
Dadurch bleibt kein älteres Eingabeformular unter dem Bereinigungsdialog offen.

## Welche Inhalte entfernt werden

- Alle Orga- und Schulbereich-Einträge, die zum geprüften Zeitpunkt im Papierkorb liegen.
- Zugehörige Checklistenpunkte und Bearbeitungsentwürfe dieser Einträge.
- Deren frühere Fassungen, Operationen und Outbox-Einträge.
- Betroffene gespeicherte Gruppenanfragen einschließlich etwaiger Rücknahmebelege.
  Andere Einzeleinträge derselben Gruppe bleiben bearbeitbar. Die alte komplette
  Gruppenanfrage kann nicht wiederholt oder als Ganzes zurückgenommen werden.
- Gemeinsame Kontexte der entfernten Beobachtungen, sofern kein verbleibender
  Eintrag oder unabhängiger Schul-/Kontextentwurf sie benötigt; einschließlich
  Kontextverlauf und Beteiligtenindex.
- Strukturierte Ziel-ID und Zieltext gelöschter Ziele in verbleibenden Beobachtungen,
  ihren Entwürfen und früheren Fassungen/Operationen. Die Beobachtung erhält eine
  neue Revision. Selbst verfasster Freitext wird nicht anhand von Textgleichheit entfernt.

Schülerdaten, unabhängige Entwürfe, Wiederaufnahmeentwürfe mit eigener Gruppen-ID,
verbleibende Einträge und verwendete Kontexte bleiben bestehen. Vorgemerkte
HTML-Sicherungen und bereits gespeicherte Sicherungsdateien werden unverändert
aufbewahrt. Sie können weiterhin Kopien der entfernten Inhalte enthalten.

## Speicherung und Schutz

Datenbank und Flutter-Vollsicherung sind jetzt **Version 7**. Datenbanken 1–6 und
Flutter-Sicherungen 1–6 werden übernommen; unbekannte Versionen werden abgewiesen.
Die Migration 6→7 erhält alle Tabelleninhalte und ergänzt SQL-Schreibsperren.
Ältere App-Versionen sind für den neuen Datenbestand und neue Sicherungen nicht geeignet.

Vorschau und Vollsicherung stammen aus derselben SQLite-Lesetransaktion. Direkt vor
Löschung wird innerhalb der Schreibtransaktion der vollständige aktuelle Bestand
mit diesem Snapshot verglichen – einschließlich Entwürfen und Einstellungen.
Die gesamte Bereinigung wird gemeinsam bestätigt oder vollständig zurückgerollt.

Die interne Einstellung `trash_maintenance_v1` enthält die lokale Generation,
gesperrte IDs nach Objekttyp und bisher erreichte Operationsnummern pro Gerät.
Sie enthält keine entfernten Texte oder Schülerzuordnungen. Die IDs verhindern
Wiederanlage über veraltete Entwürfe oder Gruppenwiederholungen. Die fortlaufenden
Operationsnummern werden nach dem Entfernen alter Journale nicht erneut vergeben.

Jeder Schreibpfad prüft die beim Aufruf erfasste Generation in seiner Transaktion.
Ein bereits wartendes Autosave kann sich nicht nachträglich als neuer Stand ausgeben.
Erneutes Laden/Initialisieren desselben alten Repository-Objekts hebt die Sperre
nicht auf. Zusätzlich verhindern dauerhafte SQLite-Trigger die Wiederanlage
entfernter Einträge/Entwürfe und bereinigter Ziel-/Kontextverweise, auch über eine
bereits geöffnete ältere Verbindung ohne die neue Repository-Prüfung.

Vollsicherungen enthalten die ID-Sperren und Zählerstände. Beim Import werden
Widersprüche zwischen diesen Sperren und den gelieferten Datensätzen abgewiesen.
Die lokale Sitzungskennung wird nicht als fremde Fenstersitzung übernommen.
Eine Sicherung vor dem Leeren lässt sich weiterhin in einem neuen leeren
Arbeitsbereich wiederherstellen. Ein bereinigter Bestand gilt wegen seiner
Löschsperren nicht als neuer leerer Arbeitsbereich.

Es handelt sich um logisches Entfernen aus dem aktiven Datenbestand, nicht um
forensisch sicheres Überschreiben von Datenträgern. SQLite-Seiten/WAL,
Betriebssystemkopien und bestehende Backups können alte Bytes enthalten.
Physische Speicherkompaktierung ist ein separater offener Schritt. Das spätere
Synchronisationsprotokoll muss diese Bereinigung ausdrücklich berücksichtigen;
aktuell existiert kein Synchronisationstransport.

## Nachweise und Grenzen

Synthetische Tests prüfen unter anderem vollständige Sicherungswiederherstellung,
Erinnerung/Checklisten, Zielverlauf, abhängige und unabhängige Entwürfe, teilweise
geleerte Gruppen, archivierte Schüler, Kontextaufbewahrung, neue Operationsnummern,
Wiederanlageversuche, zwei geöffnete Repository-Instanzen, wartende Schreibvorgänge,
SQLite-Schreibsperren sowie vollständiges Zurückrollen bei einem simulierten Fehler.

Widgettests prüfen Sicherungsabbruch/-fehler, Bestätigung, veraltete Vorschau,
Abbruch während einer laufenden Ausgabe sowie 320-Pixel-Darstellung mit simulierter
Tastatur. Drei zusätzliche direkte Flutter-Renderings zeigen Vorschau,
Bestätigung und Ergebnis. Die Dateiausgabe wird an der Plattformschnittstelle auf
exakte UTF-8-JSON-Bytes geprüft. Native Dateidialoge und Browserpersistenz sind damit
nicht als Gerätetest bestätigt. Aktuelle Gesamtergebnisse: `FLUTTER_STATUS.md`.
