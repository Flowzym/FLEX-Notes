# OneDrive mit privatem Microsoft-Konto

FLEX verwendet einen öffentlichen Microsoft-Client mit delegiertem Lesezugriff
(`offline_access Files.Read`), ohne Client-Geheimnis. Das Konto und seine Dateien
bleiben beim Benutzer. Der OneDrive-Connector dieses Chats ist eine eigene
Anwendung; seine Anmeldung kann nicht als FLEX-Anmeldung übernommen werden.

## Noch erforderlich

Eine eigene Microsoft-Entra-Appregistrierung. Dafür werden ein Entra-Verzeichnis
und Rechte zur Appregistrierung benötigt. Ein privates OneDrive-Konto allein ist
keine solche Registrierung. Die Bereitstellung eines Verzeichnisses oder eines
Azure-Abonnements ist ein separater Kontoschritt; FLEX aktiviert kein Abonnement.

1. Im [Entra-Portal](https://entra.microsoft.com/) zu **Appregistrierungen → Neue Registrierung** gehen.
2. Name **FLEX**, Kontotyp mit Unterstützung persönlicher Microsoft-Konten wählen.
3. Unter **Authentifizierung → Erweiterte Einstellungen** öffentliche Clientflows zulassen.
4. Unter **API-Berechtigungen** Microsoft Graph, **delegiert**, `Files.Read` verwenden.
5. Unter **Übersicht** die **Anwendungs-/Client-ID** kopieren.
6. In FLEX **Material → OneDrive → Einrichtung** die ID einfügen und verbinden.
7. Den angezeigten Code auf der Microsoft-Anmeldeseite bestätigen; zu FLEX zurückkehren.

Kein Client-Geheimnis und kein Kontopasswort in FLEX oder im Chat eingeben.
Die Client-ID ist öffentlich; Zugriff entsteht erst durch die Microsoft-Anmeldung
und Zustimmung des Kontoinhabers. Bei einer falschen ID lässt sie sich im Dialog
„OneDrive verbinden“ über „Einrichtung“ korrigieren.

Danach praktisch prüfen: Anmeldung mit dem privaten Konto, Ordner öffnen,
DOCX/PDF auswählen, Offlinekopie öffnen, Aufgabe aus der Tagesplanung zuordnen,
Verbindung trennen und erneut anmelden. Browser und Android separat abnehmen;
vor Vorliegen der Registrierung ist eine echte Anmeldung hier nicht verifiziert.

Offizielle Grundlagen:
[Appregistrierung](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app)
und [Device Authorization Grant](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code).
