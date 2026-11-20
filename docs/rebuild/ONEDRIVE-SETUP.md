# OneDrive in FLEX · Build 87

Die öffentliche Microsoft-Registrierung ist hinterlegt:
`299f0cd6-a732-425b-8318-e7d7364dd2e3`. Sie unterstützt persönliche Microsoft-Konten
und Organisationskonten. Zugriff entsteht erst nach Anmeldung und Zustimmung.

## Android verbinden

1. Die mit dem bisherigen FLEX-Zertifikat signierte APK installieren.
2. **Material → OneDrive → OneDrive verbinden** antippen.
3. Im Microsoft-Anmeldefenster das Konto wählen und den Lesezugriff bestätigen.
4. Im Explorer eine PDF-, DOCX-, JPG- oder PNG-Datei zur Vorschau öffnen. Mit **Übernehmen** lassen sich Schüler und Einsatzdaten zuordnen. FLEX speichert beim Bestätigen.

Android verwendet die offizielle **MSAL 8.7.0** mit einem Konto zur Zeit.
Microsoft verwaltet Anmeldesitzung und Token-Erneuerung. Der manuelle
Anmeldecode entfällt. Bei abgelaufener Zustimmung bietet FLEX erneutes Anmelden
an; Hintergrundanfragen öffnen keine Anmeldefenster.

Unter **Material → OneDrive → Konto trennen** wird der MSAL-Kontozugang
entfernt. Bereits importierte Materialien und alle Schüler-/Unterrichtsdaten
bleiben erhalten. Für ein anderes Konto anschließend erneut verbinden.
Eine vorhandene Microsoft-Browsersitzung kann bestehen bleiben; „Trennen“
ist kein globales Abmelden aus anderen Microsoft-Apps.

Beim ersten Öffnen nach dem Update wird nur die bisherige Device-Code-
Anmeldeinformation aus dem Android-Geheimnisspeicher entfernt. Sie kann nicht
in MSAL übernommen werden; eine einmalige neue Anmeldung ist erforderlich.
Datenbankschema, Paketname und Signierschlüssel ändern sich nicht.

## Ordner für den Unterricht verbinden

Im Explorer den gewünschten Ordner öffnen und **Ordner verknüpfen** wählen. Schüler oder FLEX-Klasse, Fach und Abgleichrichtung festlegen. Bei **Einlesen** zeigt FLEX vor dem Bestätigen die Anzahl und eine Auswahl vorhandener Dateien. Unterordner übernehmen die Regel, bis eine eigene Verknüpfung beginnt.

Für die Scanablage **FLEX-App-Ordner** öffnen. Hier lassen sich Schülerordner anlegen und als Ziel für Hausübungen, Rückläufe oder Beobachtungen verbinden. Beim Speichern bleibt die fertige PDF oder das Foto mit dem Eintrag verbunden. Ohne Netz wartet die Ablage auf den nächsten Abgleich. Bei Entwürfen gilt die beim endgültigen Speichern bestätigte Schülerauswahl.

Der Abgleich läuft beim Öffnen und bei Rückkehr in die App. **Jetzt abgleichen** startet ihn sofort. Android plant zusätzliche Abgleiche bei bestehender Verbindung. Unter **OneDrive** erscheinen offene Übertragungen, unklare Zuordnungen und entfernte Quellen.

## Webvorschau

Im Browser bleibt die bisherige Anmeldung per Microsoft-Code. Die Client-ID
ist auch dort vorbelegt. Für diesen Weg müssen in Entra **öffentliche
Clientflows** erlaubt sein. Abweichende, früher manuell gespeicherte Client-IDs
bleiben im Browser erhalten und können im Anmeldedialog über **Einrichtung**
korrigiert werden. `FLEX_ONEDRIVE_CLIENT_ID` überschreibt nur den Web-/Device-Code-
Standard; die native Registrierung ist fest an die signierte Android-App gebunden.

## Berechtigungen und Registrierung

- Der Explorer verwendet die delegierte Microsoft-Graph-Berechtigung `Files.Read` für lesbare OneDrive-Ordner.
- Für die Ablage von Scans im FLEX-App-Ordner zusätzlich die delegierte Berechtigung `Files.ReadWrite.AppFolder` in Entra eintragen. FLEX fordert sie beim Einrichten dieses Ordners an. Die Freigaberegeln des Schulkontos gelten.
- MSAL ergänzt `openid`, `profile` und `offline_access`. Die Webvorschau fordert `offline_access` zusammen mit den Dateiberechtigungen an.
- Kein Client-Geheimnis. Die App enthält nur öffentliche Registrierungsdaten.

Android-Paket: `at.flowzym.flex_notizbuch`.

Microsoft-Signaturhash (SHA-1, Base64):
`O/s4RU8YApv43yNF9HMVr8OKo80=`.

Rückleitungsadresse:
`msauth://at.flowzym.flex_notizbuch/O%2Fs4RU8YApv43yNF9HMVr8OKo80%3D`.

Die [MSAL-Konfiguration](../../flutter_app/packages/flex_device/android/src/main/res/raw/flex_msal_config.json)
übernimmt die Entra-Angaben. Ergänzt sind Einzelkontobetrieb und deaktivierte
personenbezogene/Logcat-Protokolle. Brokerbetrieb ist bewusst deaktiviert;
die Anmeldung erfolgt über den normalen MSAL-Anmeldeagenten und verlangt
keine Authenticator-App. `DEFAULT` erlaubt den vom SDK unterstützten Browser-
oder WebView-Weg. Die Manifest-Rückleitung enthält den **nicht URL-kodierten**
Signaturhash als Pfad. Native Anmeldung ist für die permanente Release-Signatur
freigegeben; `.dev`-Installationen fangen die produktive Rückleitung nicht ab.

Der MSAL-Token-Cache bleibt in Android. Dart erhält pro Graph-Anfrage nur das
Zugriffstoken im Arbeitsspeicher; keine Refresh-Tokens werden kopiert oder in
FLEX-Sicherungen/Fehlerberichte aufgenommen. Native Cacheoperationen sind auch
über mehrere Flutter-Engines serialisiert: Abmelden wartet laufende Vorgänge ab.
Kontobindung und Sitzungszähler verwerfen verspätete Ergebnisse nach dem Trennen.
Datei- und Thumbnail-Downloads erhalten keinen Graph-Bearer-Header.

## Unterrichtsplanung aus einem bestehenden OneDrive-Ordner

Öffne **Material → OneDrive → Dateien durchsuchen** und navigiere zu deinem Planungsordner. Wähle **Ordner verknüpfen → Unterrichtsplanung → Vorschau prüfen**. Die Vorschau zählt die erkannten Verwendungen und Unterrichtstage. Nach dem Bestätigen liest FLEX die Dateiverweise ein. Scans lassen sich weiterhin über eine eigene Regel im FLEX-App-Ordner ablegen.

Ein Pfad wie `Planung/2026-27/KW48/Materialien/2026-11-24/Brüche MI01.pdf` legt das Blatt für den 24. November bereit. Ein Datumsordner hat Vorrang vor einem Datum im Dateinamen. Direkt im Wochenordner kann FLEX ein zur Woche passendes Dateidatum verwenden. Materialien mit reiner Wochenzuordnung findest du unter **Bereitgelegt → Wochenmaterial**. In der Bibliothek kannst du unabhängig nach Verwendung und Schüler filtern. Im Materialdetail lässt sich der Unterrichtseinsatz korrigieren.

Beim Anlegen oder Bearbeiten eines Schülers kannst du ein **Materialkürzel** pro Schuljahr bestätigen. `MI01` bezeichnet Material 01, `MI01L` die Lösung. Weitere bestätigte Schreibweisen gehören unter **Schuljahr und Dateinamen**. Vorhandene Treffer lassen sich einzeln oder gesammelt übernehmen. Unbekannte Kürzel findest du unter **Zuordnung prüfen → Nach Kürzel oder Schüler prüfen**. Neue eindeutige Treffer ordnet FLEX beim Abgleich zu. Eine geänderte oder archivierte Schülerzuordnung behält ihre bisher vergebenen Kürzel für das Schuljahr.

## Abnahme

Automatisierte Prüfungen decken Konfiguration, Kontoübernahme, Abbruch,
Wiederanmeldung, Token-Erneuerung nach HTTP 401, fehlende Zustimmung,
Sitzungswechsel und Abmelden während laufender Anfragen ab. Der vorhandene
Web-Anmeldeweg wird weiterhin separat getestet.

**Noch auf einem echten Android-Gerät mit dem eigenen Konto bestätigen:**
Anmeldung und Rückleitung, PDF/DOCX-Ordnerzugriff, erneutes Öffnen nach App-Neustart,
Erneuerung einer abgelaufenen Sitzung, Abbrechen und Trennen/Wiederverbinden.
Die bereitgestellte Konfiguration beweist allein noch keinen erfolgreichen
Kontozugriff; automatisierte Tests ersetzen diese Geräteabnahme nicht.

## Entwicklung

MSAL ist auf Version 8.7.0 festgelegt. Die transitive Bibliothek
`com.microsoft.device.display:display-mask:0.3.0` kommt aus Microsofts
[Duo-Paketfeed](https://pkgs.dev.azure.com/MicrosoftDeviceSDK/DuoSDK-Public/_packaging/Duo-SDK-Feed/maven/v1).
Das zusätzliche Gradle-Repository ist auf diese Paketgruppe begrenzt. MSAL
führt außerdem Android-Credential-/Passkey-Bibliotheken inklusive Google-Play-
Anbindung mit; der CameraX-Scanner bleibt davon unabhängig und verwendet kein ML Kit.
Die optionale PEM/X.509-Abhängigkeit von Nimbus JOSE wird mit
`bcpkix-jdk18on:1.87` ausdrücklich eingebunden, damit der optimierte Android-Build
keine fehlenden Kryptografieklassen durch Warnungsunterdrückung verdeckt.

Die [ältere Graph-Registrierungsvorlage](../../flutter_app/config/onedrive-public-client.json)
beschreibt einen öffentlichen Client, ist aber **keine MSAL-Konfigurationsdatei**
und ersetzt nicht das Manifest einer bestehenden Entra-Registrierung.

Offizielle Grundlagen: [MSAL Android](https://github.com/AzureAD/microsoft-authentication-library-for-android),
[MSAL-Konfiguration](https://learn.microsoft.com/en-us/entra/msal/android/msal-configuration),
[Einzelkontobetrieb](https://learn.microsoft.com/en-us/entra/msal/android/single-multi-account),
[Files.Read](https://learn.microsoft.com/en-us/graph/permissions-reference#filesread).
