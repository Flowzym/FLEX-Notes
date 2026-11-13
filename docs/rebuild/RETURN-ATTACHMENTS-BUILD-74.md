# Rücklaufformular und Anhänge · 0.24.1+74

Rückläufe erhalten ein eigenes Formular mit Bezeichnung, vier gleichmäßigen
Schaltflächen für die Art, Schülerauswahl, kompakten Frist-/Erinnerungszeilen und
optionalem Hinweis. Eine gesetzte Frist lässt sich direkt wieder entfernen.
Der bisherige große Materialbutton wird durch einen sichtbaren Anhangsbereich
ersetzt: **Scan / Foto**, **Bilder / PDF** und **Material**. Er ist sowohl beim
Anlegen aus der Eintragspille als auch beim Bearbeiten vorhandener Rückläufe
verfügbar. Die vorhandene Teilnehmerauswahl und deren Statuswerte bleiben erhalten.

Scan / Foto öffnet den vorhandenen Scanner mit seiner Kamera-, Filter- und
Bearbeitungsoberfläche. Bilder / PDF startet unmittelbar die Dateiauswahl darin.
Importe können als PDF oder JPG gespeichert werden. Material öffnet die vorhandene
Materialauswahl. Zugeordnete Dateien erscheinen mit Miniatur, Namen, Dateityp und
Bearbeitungsaktion; gespeicherte Scanentwürfe mit Vorschau und „Scan fortsetzen“.

## Speicherung

Vor dem Aufruf von Scanner, Import oder Dateibearbeitung wird der Rücklaufentwurf
verbindlich gesichert. Ein Fehler verhindert den Wechsel. Neue Scans hängen über
eine `classroomDraft`-Referenz am Entwurf; bereits gespeicherte Unterlagen und
zugeordnete Materialien werden gemeinsam ohne doppelte Zeilen angezeigt.
Allgemeine Rücklaufunterlagen werden nicht automatisch als persönliche Abgaben
aller ausgewählten Schüler geführt.

Beim Speichern werden diese Verweise innerhalb derselben Datenbanktransaktion
auf den Rücklauf übertragen, einschließlich offener Scanbearbeitungen und ihrer
Quellrevision. Bei einem Fehler bleibt die ursprüngliche Zuordnung erhalten.
Auch ein sonst leerer Rücklaufentwurf bleibt erhalten, solange Anhänge existieren.
Wird der Entwurf ausdrücklich gelöscht, werden nur seine Verknüpfungen entfernt;
Dateien und Scans bleiben in der Material-/Scanverwaltung.

Sicherung, Wiederherstellung und Zusammenführung berücksichtigen den neuen
Verweistyp, einschließlich auseinanderentwickelter Entwürfe mit gleicher ID.
Es gibt keine SQL-Schemaänderung. Alte gespeicherte Verweise bleiben unverändert;
Sicherungen mit neuen Entwurfsverweisen benötigen zum Import diesen Appstand.

## Prüfung

- Vier neue Datentests: Veröffentlichung und Rollback, Löschen ohne Dateiverlust,
  Sicherung/Zusammenführung mit abweichenden Entwürfen und ungültige Verweise.
- Zwei zusätzliche Editorprüfungen bei 320 Pixeln und bis 1,8-facher Schrift:
  Vorschau/Entwurf/Typwechsel/Speichern sowie Fehler und Wiederholung vor Aufnahme.
- Ein neuer Scannertest prüft den direkten Import und den erhaltenen Scanentwurf.
- Abschließender Lauf: **35 Tests bestanden** aus Rücklaufanhängen, Rücklaufpille
  und Scanner-UI. Vorheriger Integrationslauf: 47 bestanden, zwei Fehler in neuen
  Testabläufen (zu früh konstruierter ungültiger Datensatz und Scrollen vor Ende
  der Texteingabefokussierung); beide korrigiert und erfolgreich nachgeprüft.
- Statische Analyse ohne Befunde. Release-Webbuild mit lokalen Webressourcen
  (`--no-web-resources-cdn`).

Browser: Bildimport, PDF- und JPG-Speicherung, Vorschauen, Typwechsel und erneut
geöffneter Rücklauf bei 320/390 Pixeln geprüft; Screenshots visuell geprüft.
Browsernachweise und reproduzierbarer Ablauf unter
[evidence/build-74](evidence/build-74/). Synthetische Daten; keine vollständige
Testsuite oder Android-Kameraprüfung. Keine neue APK, letzte APK bleibt Build 67.

[Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/).
