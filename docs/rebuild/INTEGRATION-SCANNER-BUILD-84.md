# Integrations-, Daten- und Bedienprüfung · FLEX 0.33.0+84

Stand: 15. November 2026. Geprüft mit synthetischen Daten, ohne Änderungen an
einem echten Microsoft-Konto oder an Schülerdaten des Nutzers.

Die Prüfung hat reale Lücken zwischen Speicherung und Anzeige sowie ein Risiko
für bearbeitete OneDrive-Dateien gefunden. Die unten genannten Fehler wurden
reproduziert, korrigiert und durch Regressionstests abgesichert. Das ist keine
Zusicherung, dass jede denkbare Gerätekonfiguration und Kombination fehlerfrei ist.

## Behobene Fehler und Widersprüche

1. **Rücklauf beim Schüler fehlte.** Rückläufe liegen als Klassenvorgänge vor;
   die Schülerübersicht, der Verlauf, die Orga-Zähler und Entwurfslisten fragten
   bisher andere Eintragsarten ab. Sie berücksichtigen nun zugeordnete Rückläufe.
   Beim Schüler gelten sein eigener Status und seine Notiz, in der Klassenliste
   die Gesamtzahlen. Die verzögerte Volltextsuche blendet Rückläufe nicht wieder aus.
2. **Ein erfolgreich gespeicherter Rücklauf verschwand hinter Filtern.** Nach
   dem Anlegen werden widersprechende Such-/Statusfilter aufgehoben. Der
   Rücklauf-Filter öffnet beim Hinzufügen direkt den passenden Editor. Beim
   Anlegen aus einer Notizansicht öffnet sich anschließend die Rücklaufansicht.
3. **Rücklaufentwürfe waren nicht überall erreichbar.** Sie erscheinen nun in
   Schüler-, Aufgaben-, Klassen-Orga- und passenden Editor-Entwurfslisten;
   Fortsetzen und Löschen verwenden denselben gespeicherten Entwurf.
4. **Schülerkontext ging beim Schnellzugriff verloren.** Ein neuer Rücklauf
   aus dem Schülerbereich wählt diesen Schüler vor. Die Klassenfunktion lässt
   weiterhin mehrere Teilnehmer zu.
5. **Speicherfehler standen außerhalb des sichtbaren Formularbereichs.**
   Fehlermeldungen werden in den sichtbaren Bereich gescrollt und für
   Bildschirmleser angekündigt. Eingaben bleiben erhalten; ein erneuter
   Speicherversuch erzeugt keinen zweiten Vorgang.
6. **Bearbeitete OneDrive-PDF konnte überschrieben werden.** Nach lokalem
   Bearbeiten behält die Datei ihre ID und Zuordnungen, ist aber vom Original
   getrennt. Ein erneutes Einlesen desselben Cloud-Originals verwendete trotzdem
   diese ID. Jetzt erhält das Original eine eigene stabile ID; wiederholtes
   Einlesen erzeugt keine weiteren Kopien. Lokale Bytes, Tags, Schüler und
   Einsatzdaten bleiben erhalten. Direktauswahl und Ordnereinlesen verwenden
   dieselbe Identitätslogik.
7. **Offline-Dateien warteten unnötig auf OneDrive.** Vorhandene lokale Dateien
   öffnen sofort. Cloud-Aktualisierungen bleiben über die vorhandene Aktion
   „Offline laden / aktualisieren“ erreichbar. Abgelaufene/widerrufene
   Web-Anmeldungen bieten wieder eine Anmeldung an; normale Netzfehler löschen
   die Sitzung nicht. Nach erfolgreicher Anmeldung öffnet sich die Dateiauswahl
   direkt. Eine fehlende Dateiberechtigung wird nicht mehr pauschal als fehlende
   Entra-Einrichtung bezeichnet.
8. **Gemeinsame Rücklaufanhänge fehlten in der Schüler-Vorschau.** Die Karte
   zeigt nun sowohl gemeinsame Unterlagen des Vorgangs als auch die Dateien des
   ausgewählten Schülers. Dateien anderer Teilnehmer werden dort nicht angezeigt.

## Scanner

Die eigene CameraX-Aufnahme erhält eine Creme/Olive-Oberfläche mit großem
Auslöser, Dokument-/Fotomodus, Kameralicht, Statushinweis, Seitenzähler,
Miniaturbild der letzten Aufnahme und „Weiter“. Die letzte Aufnahme kann vor
der Weitergabe angesehen oder entfernt werden. Dokumente und normale Fotos
verwenden dieselbe Serienaufnahme; Fotos werden nicht automatisch beschnitten.

Die Live-Kantenanzeige wird geglättet. Die optionale automatische Aufnahme
verlangt ausreichend sichere Kanten und etwa eine Sekunde ruhiges Halten.
Ein kurzer Erkennungsaussetzer, Nachfokussieren oder Öffnen der Vorschau löst
keine Doppelaufnahme aus. Nach dem Einlegen der nächsten Seite wird wieder
ausgelöst. Langsames kontinuierliches Verschieben gilt nicht als ruhig gehalten.
Die Erkennung wurde für geringeren Kontrast erweitert; uniforme Flächen und
Rauschen lösen in den Testbildern nicht aus. Der Zuschnitt wird am tatsächlich
aufgenommenen Bild nochmals bestimmt.

Aufnahmen bleiben verschlüsselt dem Entwurf zugeordnet. Erst nach dauerhaftem
Speichern im Flutter-Entwurf wird die native Aufnahme quittiert. Wiederanlauf,
Abbruch, Speicherausfall und erneutes Übernehmen sind geprüft. Neue Fotos
verwenden denselben Weg; ältere ausstehende Fotoentwürfe bleiben lesbar.

Die Bearbeitung zeigt die Bilder vor den Metadaten und bietet weiterhin
Filtervorschauen, Zuschnitt mit Einrasten, Vergleich, Rückgängig/Wiederholen,
Schwärzen, Ersetzen und Sortieren. Der doppelte Serienknopf entfällt in der
nativen Aufnahme. Tags und die Zuordnung zu Schüler/Eintrag bleiben sichtbar.
Eine reine Fotoserie speichert JPG-Dateien; gemischte Dokument-/Fotoserien
beginnen mit PDF als Ausgabeformat. Bestehende Originale werden beim Schwärzen
nur nach der bereits vorhandenen ausdrücklichen Bestätigung entfernt.

## Umfang der Prüfung

| Bereich | Überprüfte Zusammenhänge |
| --- | --- |
| Einträge | Sozial/Arbeit/Ziele/HÜ/Orga, Typwechsel, Unteraufgaben, Personen, Entwürfe, Vorlagen und Versionenkonflikte |
| Rückläufe | Anlegen, einzelne/mehrere Schüler, Status, Suche/Filter, Entwürfe, Anhänge, persistenter Neustart |
| Materialien | Individuelle Zuordnung und Einsatzdaten, Pakete/Planungen/Bereitgelegt, Papierkorb, Dateiversionen, OneDrive-Identität |
| Anhänge | Entwurf → veröffentlichter Eintrag, HÜ-Unteraufgaben, entfernte Aufgaben, wiederaufgenommene Scans, atomare Verknüpfungen |
| Datenhaltung | Migrationen, revisionsgeprüfte Schreibzugriffe, veraltete asynchrone Antworten, verschlüsselte Sicherung, Zusammenführen und Rollback |
| Kalender/Ablauf | Wiederholungen, Zeitänderungen, Swipe-Richtung, individuelle Phasen, Materialverweise, Aufgaben und Rückläufe |
| Oberfläche | Gefüllte Hauptseiten und Editoren, 320/390/768/1280 Pixel, große Schrift, Tastatur, Hell/Dunkel, direkte Bedienprüfung im Browser |

Die konkreten Ergebnisse und Releaseprüfungen stehen in
[Build 84](../../releases/android/build-84/README.md). Die neuen Regressionen
liegen in `return_workflow_test.dart`, `onedrive_material_integrity_test.dart`,
`document_scanner_ui_test.dart` und den nativen Kanten-/Stabilitätstests.

## Verbleibende Verbesserungen und Grenzen

- **OneDrive-Auswahl:** Suche, Mehrfachauswahl und Vorschaubilder direkt im
  Cloud-Ordner fehlen noch. Der Import ist auf PDF/DOCX begrenzt; geteilte
  Ordnerverknüpfungen werden beim Einlesen nicht unterstützt. Die Verbindung ist
  lesender Zugriff mit lokalen Kopien, kein automatischer bidirektionaler Sync.
  Schülerzuordnung erfolgt über die Materialbibliothek; eine direkte
  Cloud-Auswahl innerhalb der Schülerzuordnung würde einen Schritt sparen.
- **Abschluss von Rückläufen:** „Alle Teilnehmer erledigt“ und „Vorgang
  abgeschlossen“ sind getrennte Zustände. Eine Abschlussfrage nach dem letzten
  Rücklauf würde diese Unterscheidung verständlicher machen.
- **Lange Formulare:** Große Schrift und Tastatur erfordern Scrollen; feste
  Kopf-/Fußbereiche wechseln dafür bereits in einen gemeinsam scrollbaren
  Aufbau. Die vielen Metadaten könnten klarer gruppiert werden. Die Funktionen
  sind erreichbar, aber damit ist noch nicht jede Ansicht optimal kompakt.
- **Architektur:** Orga-, Schuleinträge und Klassenvorgänge verwenden verschiedene
  Datenmodelle. Das ist für ihre unterschiedlichen Inhalte sinnvoll, erzeugt
  aber wiederholte Abfragen in Übersichten, Zählern und Entwurfslisten. Gemeinsame
  Abfragedienste wären eine nächste gezielte Konsolidierung. Diese Runde ändert
  das Datenformat nicht durch einen großen Umbau.
- **Android-Geräteabnahme:** Live-Kantenqualität, Fokus, Kameralicht,
  Berechtigungsdialoge, Prozessunterbrechung durch Android und echte MSAL-
  Anmeldung müssen auf einem physischen Gerät geprüft werden. Native Tests und
  ein signierter Build ersetzen diese Abnahme nicht. Keine Zusicherung einer
  mit CamScanner gleichwertigen Erkennungsqualität unter allen Lichtbedingungen.
- **Werkzeugkette:** Zwei externe Plugins melden noch ihre künftige Umstellung
  auf Built-in Kotlin. Der aktuelle Build ist prüfbar; für ein späteres Flutter-
  Upgrade ist diese Umstellung zu berücksichtigen. GitHub-Signiersecrets und
  ein vollständig signierter Release-Lauf dort bleiben unbestätigt.

App-Kennung, permanentes Signierzertifikat und Schema 8 bleiben unverändert.
Das Update erfordert keine Neuinstallation und keine Übertragung der Daten.
