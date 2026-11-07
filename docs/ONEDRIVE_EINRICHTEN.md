# OneDrive für FLEX registrieren

FLEX enthält die Verbindung, aber weiterhin **keine Microsoft-Client-ID**. Eine direkte
Anmeldung ist deshalb ohne eigene Registrierung nicht aktiv. OneDrive-Links und der Android-
Dateiauswahldialog funktionieren unabhängig davon; der Systemdialog kann auch
Dateien eines installierten OneDrive-Dokumentanbieters anbieten.

## Azure-Testangebot und Appregistrierung

Das Azure-Angebot mit 200 USD Guthaben für 30 Tage ist ein zeitlich begrenztes
Cloud-Testangebot. FLEX selbst benötigt kein Azure-Hosting und kann ohne direkte
OneDrive-Anmeldung verwendet werden.

Für die Appregistrierung nennt Microsoft ein aktives Azure-Konto und ein Entra-
Verzeichnis mit passenden Rechten als Voraussetzung. Der separate Abrechnungseintrag
„Microsoft Entra ID Free“ verursacht laut Microsoft keine Produktgebühren; andere
gebuchte Azure-Dienste oder Lizenzen können dagegen kostenpflichtig sein. Das ist
keine Zusage, dass jede Konto-Einrichtung ohne Zahlungsdaten möglich ist.

Quellen (geprüft am 7. November 2026):
[Appregistrierung](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app),
[Entra ID Free](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/microsoft-entra-id-free).

## Einmalige Registrierung

1. Im [Microsoft Entra Admin Center](https://entra.microsoft.com/) unter
   **App-Registrierungen → Neue Registrierung** eine eigene Anwendung „FLEX“ anlegen.
2. Als unterstützte Konten Organisationskonten und persönliche Microsoft-Konten
   wählen, wenn beide genutzt werden sollen. Der Client verwendet den `common`-Endpunkt.
3. Unter **Authentifizierung → Erweiterte Einstellungen** die **öffentlichen
   Clientflows** erlauben. FLEX nutzt den Gerätecodeflow; ein Redirect-URI ist dafür
   nicht erforderlich.
4. Delegierte Microsoft-Graph-Berechtigung **Files.Read** verwenden. FLEX fordert
   `offline_access Files.Read` an: Lesen der gewählten Dateien sowie Erneuerung der
   Anmeldung. Es schreibt keine Materialien nach OneDrive zurück.
5. Die öffentliche **Anwendungs-ID (Client-ID)** kopieren. **Kein Clientgeheimnis
   erstellen oder versenden.** Die Client-ID allein ist kein Passwort.

Mit dieser öffentlichen ID die Testapp erneut bauen:

```sh
flutter build apk --release --dart-define=FLEX_ONEDRIVE_CLIENT_ID=DEINE-CLIENT-ID
```

Denselben Test-Signaturschlüssel und dieselbe Paketkennung verwenden und die
Versionsnummer erhöhen, damit das Update über die bestehende App installiert werden kann.
Keystore, Tokens und Kontodaten gehören nicht ins Repository. Die CI benötigt für
Kompilierung und Tests keine echte Anmeldung und keine Microsoft-Geheimnisse.

## Verbindung verwenden

Unter **Materialien → OneDrive verbinden** den angezeigten Code auf der angegebenen
Microsoft-Seite eingeben, Konto wählen und Lesezugriff bestätigen. Danach Ordner öffnen,
bei Bedarf merken und DOCX/PDF-Dateien der Ablage hinzufügen. Eine Schulorganisation kann
öffentliche Clientflows oder Einwilligungen administrativ einschränken; dafür gelten ihre
Microsoft-Kontoeinstellungen.

PDFs werden auf Android in FLEX angezeigt; DOCX-Dateien öffnen sich extern. Online-PDFs
werden beim Öffnen auf einen neuen Dateistand geprüft. Die Offlinekopie bleibt bei einem
fehlgeschlagenen Download erhalten. Ein sichtbarer Offlinehinweis kennzeichnet diesen Fall.
„Offline-Kopie entfernen“ entfernt nur die lokale Kopie einer erneut abrufbaren Datei.
Ein nur lokal importiertes Original lässt sich damit nicht versehentlich entfernen.

„Verbindung trennen“ entfernt die gespeicherten Tokens. Bereits importierte Dateiverweise
und Offlinekopien bleiben erhalten. Die Microsoft-Kontoberechtigung kann zusätzlich in
Microsofts Kontoeinstellungen widerrufen werden.

## Technische Grenzen und Abnahme

- Tokens liegen im geschützten Android-Speicher und fehlen in FLEX-Sicherungen.
- Einzeldokumente: höchstens 20 MB. Materialpakete: höchstens 40 MB Dateidaten.
- Materialsicherungen sind getrennte, passwortverschlüsselte `.flexmaterials`-Dateien;
  die normale Notizbuchsicherung enthält nur Metadaten und Verknüpfungen.
- Gerätecode-Anmeldung, Refresh, Abbruch, Abmeldung und Download-Header sind mit
  HTTP-Testantworten geprüft. **Eine echte Microsoft-Anmeldung ist noch nicht geprüft.**
- Nach Registrierung am Gerät prüfen: privates Microsoft-/gewünschtes Schulkonto,
  Ordnernavigation, DOCX-Aufruf, PDF-Anzeige, Flugmodus, Dateiversionswechsel, Abmeldung.

Microsoft-Dokumentation:
[Gerätecodeflow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code),
[App registrieren](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app),
[Files.Read](https://learn.microsoft.com/en-us/graph/permissions-reference#filesread).
