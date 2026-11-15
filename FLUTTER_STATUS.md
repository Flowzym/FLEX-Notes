# Aktueller Flutter-Stand

**0.32.0+83**, Branch `redesign/cream-olive`.

Build 83 überarbeitet die Materialablage: direkte individuelle Schülerzuordnung,
optionale und getrennte Einsatzdaten, Schülerfilter, wirksame Suche in
„Bereitgelegt“ und kompakte Materialdetails. Bestehende Daten und Dateireferenzen
bleiben erhalten. [Materialprüfung](docs/rebuild/MATERIAL-BUILD-83.md).

Build 82 integriert Microsofts native MSAL-Anmeldung für Android mit der
bereitgestellten Entra-Registrierung. Die Tokenverwaltung bleibt im SDK;
Kontobindung und serialisierte Cacheoperationen schützen laufende Anfragen
beim Abmelden. Web behält die Code-Anmeldung. Vorhandene Daten bleiben erhalten;
Android verlangt nach dem Update einmalig eine neue Microsoft-Anmeldung.

[OneDrive-Einrichtung und Geräteabnahme](docs/rebuild/ONEDRIVE-SETUP.md).


[Änderungen und Grenzen](docs/rebuild/NAVIGATION-BUILD-80.md) ·
[Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/) ·
[GitHub-PR](https://github.com/Flowzym/FLEX-Notes/pull/1) ·
[Android-APKs](releases/android/build-83/README.md).

Einheitliche Navigationspillen, wählbare Wischrichtung und Standardreiter;
Notizen mittig unter Live. Weitere Bereiche oben rechts, Scanner unten direkt.
Klassen-Orga unter Organisation mit sichtbaren Filtern. Termin-Tags bleiben in
Entwürfen, Vorlagen, Sicherungen und Importkonflikten erhalten und sind suchbar.

Kalendertermine und einzelne Unterrichtsstunden lassen sich per langem Drücken
verschieben und an den Griffen zeitlich anpassen. Wischrichtung bleibt beim Umlauf
von Tag/Woche/Monat gleich; Tages-/Wochenraster nutzen die Höhe besser.

Review-Ergänzungen: Schuljahresabschluss, Archiv und ausdrückliche Löschprüfung;
Pseudonyme für Gesprächsberichte; Eintragsvorlagen/Katalogaustausch; lokales
Fehlerprotokoll; Schüler-Papierkorb, Zeitstempel und Volltextindex. Tabletansicht
mit Schülerliste und Details nebeneinander. Android ergänzt Widget/Shortcuts,
geschützte Benachrichtigungsaktionen, Offline-Diktat und eine eigene Kamera mit
Live-Kantenerkennung ohne Google Play Services.

Schema-8-Migration erhält bestehende Daten. Neue Sicherungen benötigen Build 79;
ältere Sicherungen bleiben lesbar. Vor Installation eine unabhängige vollständige
Sicherung anlegen. APKs verwenden das bestehende dauerhafte Zertifikat.

Der [taggesteuerte Releaseprozess](docs/rebuild/RELEASING.md) ist implementiert,
die Einrichtung der GitHub-Signiersecrets ist wegen fehlenden Zugriffs (403)
noch nicht bestätigt. Branch-/PR-CI baut weiterhin ohne Signierschlüssel.
[Physische Android-Abnahme](docs/rebuild/ANDROID-ACCEPTANCE-BUILD-79.md) bleibt offen;
die eigene Microsoft-Appregistrierung ist seit Build 82 eingerichtet. Lokale und automatisierte Prüfungen
belegen keine Kamera-, Diktat- oder Launcherfunktion auf einem konkreten Handy.
