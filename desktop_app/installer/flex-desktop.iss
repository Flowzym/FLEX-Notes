#define AppName "FLEX Desktop"
#define AppVersion "1.1.0"
[Setup]
AppId={{E8D09B86-DA04-42CF-8E4B-21C0BBEB4613}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Flowzym
DefaultDirName={localappdata}\Programs\FLEX Desktop
DefaultGroupName=FLEX Desktop
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\build\installer
OutputBaseFilename=FLEX-Desktop-{#AppVersion}-Windows-x64-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\flex_desktop.exe
CloseApplications=yes
[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\FLEX Desktop"; Filename: "{app}\flex_desktop.exe"
Name: "{autodesktop}\FLEX Desktop"; Filename: "{app}\flex_desktop.exe"; Tasks: desktopicon
[Tasks]
Name: "desktopicon"; Description: "Desktop-Verknüpfung erstellen"; Flags: unchecked
[Run]
Filename: "{app}\flex_desktop.exe"; Description: "FLEX Desktop starten"; Flags: nowait postinstall skipifsilent
; User data lives outside {app}; uninstall deliberately retains the workspace.
