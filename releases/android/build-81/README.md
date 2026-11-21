# FLEX 0.30.1+81 für Android

- [ARM64 herunterladen](FLEX-0.30.1%2B81-arm64.apk) · für die meisten aktuellen Android-Handys
- [ARMv7 herunterladen](FLEX-0.30.1%2B81-armv7.apk) · für ältere 32-Bit-Geräte
- [Prüfsummen und Quellcommit](release-manifest.json)
- [Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/)

**Nach links wischen → der aktive Reiter wandert nach rechts.** Nach rechts
wischen führt zum Reiter links. Der Umlauf vom letzten zum ersten Reiter und
zurück bleibt erhalten. Das gilt auch für Tag/Woche/Monat; Wischen im
Kalenderraster verschiebt weiterhin den Zeitraum.

Die falsch gespeicherte Grundeinstellung aus Build 80 wird einmalig korrigiert.
Unter **⋯ → Einstellungen → Bedienung → Standardansichten → Beim Wischen nach
links** kann anschließend ausdrücklich „Reiter nach rechts“ oder „Reiter nach
links“ gewählt werden. Diese neue Auswahl bleibt bei Neustart und
Sicherungswiederherstellung erhalten. Andere Einstellungen bleiben unverändert.

Der Abstand zwischen der Dreipunktzeile und der oberen Navigation ist auf allen
Seiten um 8 Pixel reduziert. Pillengrößen bleiben gleich.

Gleiche App-Kennung und permanente Signatur wie Build 62–80. Als Update
installieren, nicht vorher deinstallieren oder App-Daten löschen. Schüler,
Einträge, Entwürfe und Materialien bleiben erhalten; Schema 8 ist unverändert.
Die ursprüngliche FLEX Test bleibt separat.

42 gezielte Flutter-Tests für Navigation, Einstellungen, Übernahme aus Build 80,
Neustart und Sicherungen erfolgreich; Analyse und Formatkontrolle ohne Befund.
Web- und Android-Releasebuilds erfolgreich. Beide APKs auf Version, App-Kennung,
permanentes Zertifikat, v1/v2/v3-Signatur, ZIP-/ELF-Ausrichtung und fehlende private
Signierdaten geprüft. Debugsymbole liegen separat; keine DWARF-Sektionen in der
App-Bibliothek. Physische Android-Geräteprüfung steht noch aus.

[ARM64-Prüfung](verification-arm64.json) · [ARMv7-Prüfung](verification-armv7.json)
