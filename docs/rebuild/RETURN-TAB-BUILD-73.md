# Rücklauf in der Eintragspille · 0.24.1+73

Neue Orga-Einträge haben vier gleich breite Optionen: **Notiz, Aufgabe, Termin,
Rücklauf**. Der Rücklauf wird direkt im selben Dialog angezeigt. Das zusätzliche
Rücklauf-Symbol im Kopf der Aufgaben-/Orga-Liste entfällt; das globale Plus-Menü
bleibt verfügbar. Die Aufgabenliste und ihre Rücklauffilter aus Build 72 bleiben
bestehen.

„Schüler auswählen“ ist im Rücklauf direkt sichtbar. Im Auswahldialog können
Schüler einzeln, alle oder keine gewählt werden. Bei einer Suche wählt „Treffer
auswählen“ nur die Treffer zusätzlich aus. Zugehörige gesperrte Schüler anderer
Formulare bleiben beim Leeren geschützt. Freie Namen bleiben möglich.
Bestehende Statuswerte und Notizen der weiterhin ausgewählten Schüler bleiben
beim Speichern erhalten. Neue Rückläufe aus einem Schülerkontext wählen diesen
Schüler vor; im Klassenkontext sind zunächst alle aktiven Schüler ausgewählt.

## Verhalten und Speicherung

Das bisherige Klassenformular wird wiederverwendet. Typwechsel sichern den
aktuellen Entwurf, bevor das Formular wechselt. Ein Speicherfehler lässt das
Formular mit seinen Eingaben offen. Aufgabe/Notiz/Termin und Rücklauf behalten
jeweils ihren Inhalt; vorhandene angefangene Eingaben bleiben als separate
Entwürfe erhalten. Speichern eines Rücklaufs legt keine zusätzliche Aufgabe an.
Text, Termin und Zuordnung werden beim ersten Öffnen des Rücklaufs vorbelegt.

Der neue Rücklauf-Tab gilt beim Anlegen. Gespeicherte Orga-Einträge behalten ihre
bisherigen drei Typen; vorhandene Rückläufe bearbeiten weiterhin ihre eigene
Teilnehmerliste. Keine Datenmigration und kein verändertes Sicherungsformat.

## Prüfung

Vier neue Tests prüfen die gleich breite Pille bei 320 Pixeln, Teilnehmerauswahl
und Speichern ohne zusätzliche Aufgabe, Tippen/Wischen und Entwurfserhalt bei
1,8-facher Schrift, blockierten Wechsel bei einem Speicherfehler sowie den Erhalt
bestehender Rücklaufstände. Dafür wurden auch die Rücklauf-Erinnerungsauswahl bei
großer Schrift und die Abstände der vier Pillen angepasst.

Der erste gezielte Lauf umfasst 74 Editor-/Entwurfs-/Integrationsprüfungen; zwei
neue Layout-/Testselektorbefunde wurden behoben. Anschließend bestehen alle 14
Prüfungen aus Rücklauf-Tab, Tone Controls und Navigation, einschließlich der neuen
Tests. Die frühere Annahme, Termin sei bei neuen Einträgen die letzte Swipe-Option,
ist im bestehenden Test angepasst. Statische Analyse ohne Befunde; Release-Webbuild.

Browserprüfung mit synthetischen Daten bei 320 und 390 Pixeln: vier Buttons in
einer Zeile, Auswahl zweier Schüler nach Leeren, Formularwechsel und Speichern.
Nachweise unter [evidence/build-73](evidence/build-73/). Keine vollständige Testsuite
und keine neue Android-Hardwareprüfung. Letzte APK bleibt Build 67.

[Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/).
