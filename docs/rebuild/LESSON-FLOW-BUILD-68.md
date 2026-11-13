# Ablauf und HÜ-Kontrolle · Webvorschau 0.22.0+68

Live → Ablauf ersetzt den Platzhalter durch einen bearbeitbaren Unterrichtsablauf.
Der Tag und ein vorhandener Unterrichtsblock können gewählt werden. Gespeicherte
Abläufe, insbesondere die aktive Durchführung, werden wieder geöffnet. Ein Ablauf
bleibt auch nach Entfernung seines Kalenderblocks erreichbar.

- Phasen mit Titel, optionalem Auftrag, Dauer, Materialien und Schülerzuordnung.
- Bearbeiten, Sortieren, Duplizieren, Entfernen und Übernehmen einer vorhandenen
  Planung. Der Grundablauf enthält Ankommen, HÜ-Kontrolle, Arbeitsphase, Austausch
  und Abschluss. Er wird erst bei einer bewussten Änderung oder beim Start gespeichert.
- Genau eine aktuelle Phase; Start, Pause, Fortsetzen, Überspringen und Abschluss.
  Die Zeitmessung bleibt eine Anzeige und wechselt keine Phase automatisch.
- Eigene Vorlagen ohne Tagesfortschritt. Anwenden ersetzt die Tagesphasen erst nach
  Bestätigung. Tagesänderungen verändern die Vorlage nicht.
- Offene Phasen auf einen anderen Tag übernehmen, mit neuen Phasen-IDs und
  ohne laufenden Timer. Quelle und Ziel werden in einer Transaktion gespeichert;
  die Quelle behält den Verweis auf den Folgetag. Vorhandene Zielphasen bleiben erhalten.
- Tagesunterlagen einschließlich datierter Schülerzuordnungen und Vorschauen;
  Materialien können direkt geöffnet werden.
- HÜ-Kontrolle nach Schülern, Fälligkeit und Suche; alle vier Aufgabenstände direkt
  bedienbar, Unteraufgaben und Aufgabendetails. Gerade geprüfte Aufgaben bleiben
  für die laufende Kontrolle sichtbar. Kommentare und bisherige Rückmeldungen bleiben
  erhalten. Erledigte Unterrichtsphasen verändern keinen Schülerstatus.
- Zyklische obere Navigation in allen fünf Bereichen, über Inhalt und Pille.
  Die 140-ms-Animation folgt auch am Übergang zwischen letztem und erstem Reiter
  der Wischrichtung. Senkrechtes Scrollen und Regler behalten ihre eigenen Gesten.

## Daten und Prüfung

Abläufe verwenden ein validiertes optionales `flow`-Feld vorhandener Planungsdokumente.
SQL-Schema und bestehende Einträge bleiben unverändert. Das Feld wird mitgesichert;
Referenzen auf Schüler und Materialien werden geprüft. Zusammenführen bildet auch
Schüler-IDs innerhalb von Phasen ab. Sicherungen mit Abläufen benötigen Build 68
oder neuer; ältere Sicherungen bleiben importierbar. Die bisherige Android-APK
bleibt Build 67, da hier ausdrücklich die Webvorschau erweitert wurde.

104 gezielte Tests bestanden: Ablauf-/HÜ-Domäne und UI, Navigation, Klassen-Daten,
Unterrichtsserien, Materialien, Backup-Zusammenführung, Kalender sowie UI-Matrix.
Danach 9 Domänentests mit zwei zusätzlichen Grenzfällen bestanden (106 unterschiedliche
Prüfungen). Diese decken erhaltene Abläufe nach Entfernen des Kalenderblocks,
Wiederanlage nach Löschen und vollständige Rücknahme einer Übernahme ab, wenn das
Ziel inzwischen geändert wurde. Keine vollständige Testsuite in diesem Schritt.

Statische Analyse ohne Befunde, Formatierung geprüft. Web-Release mit lokalen
Rendering-Ressourcen gebaut. Touch-Browser bei 390 × 844 sowie UI-Prüfungen bei
320 Pixeln mit 1,8-facher Schrift, Smartphone, Tablet und Desktop. Browsernachweise
liegen unter [evidence/build-68](evidence/build-68/). Im Release-Browser wurden
zusätzlich eine Phase angelegt, Start/Pause/Fortsetzen und der nächste Schritt
ausgeführt sowie eine HÜ-Rückmeldung gespeichert. Ablauf und HÜ-Stand blieben
nach Neuladen erhalten; keine JavaScript-Seitenfehler.

[Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/).
