# Schülerkarten und Beobachtungsformulare – Build 34

Stand: **0.16.0-rebuild.14+34**, 3. November 2026.

„Zuletzt verwendet“ entfällt in den Beobachtungsformularen. Die Vorschläge aus
früheren Arbeitsaufträgen werden weder beim Anlegen noch beim Bearbeiten angezeigt.
Vorhandene Auftragstags und Freitexte bleiben erhalten und bearbeitbar.

Die untere Zweierreihe der Schülerkarten ist jetzt als Gruppe zentriert. Beide
Reihen sind symmetrisch zur Kartenmitte angeordnet; Symbole und Beschriftungen
liegen auf derselben Mittelachse. Badges beeinflussen die Ausrichtung nicht.

**32 betroffene Flutter-Tests bestanden**, statische Analyse ohne Befunde.
Die vorhandenen Tests prüfen jetzt zusätzlich die tatsächlichen Mittelpunkte
beider Reihen und der Beschriftungen bei 320, 390 und 1200 px Breite, 200 %
Systemschrift und 120 % App-Skalierung. Der Formular-Test prüft fehlende frühere
Vorschläge und den unveränderten Erhalt bestehender Auftragstags und fremder Einträge.

- [Tests](evidence/app34-focused-tests.log)
- [Analyse](evidence/app34-analyze.log)
- [Sieben aktuelle Ansichten](card-centering-renderings/README.md)
- [Android-Build](evidence/app34-apk-build.log)
- [APK-Verifikation](evidence/app34-apk-verification.json)

Die Datenstruktur, Paketkennung und Testsignatur bleiben unverändert. Build 34 als
Update über FLEX Test installieren, nicht deinstallieren. Kein physischer
Android-Gerätelauf und keine Browsertests. Die umfassende Prüfung mit 218 Tests
steht im [Bericht zu Build 33](APP_UI_AUDIT_BUILD_33.md); diese kleine Korrektur
wurde mit den beiden betroffenen Testsammlungen geprüft.
