[Setup]
AppName=DarsakAI
AppVersion=1.1.0
AppPublisher=DarsakAI
AppPublisherURL=https://darsak-ai.vercel.app
DefaultDirName={autopf}\DarsakAI
DefaultGroupName=DarsakAI
OutputDir=..\build\installer
OutputBaseFilename=DarsakAI-Setup-1.1.0
Compression=lzma2/max
SolidCompression=yes
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\darsak_desktop.exe
PrivilegesRequired=admin

[Languages]
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\build\windows\x64\runner\Release\darsak_desktop.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\DarsakAI"; Filename: "{app}\darsak_desktop.exe"
Name: "{autodesktop}\DarsakAI"; Filename: "{app}\darsak_desktop.exe"

[Run]
Filename: "{app}\darsak_desktop.exe"; Description: "تشغيل DarsakAI"; Flags: postinstall nowait skipifsilent shellexec

[UninstallRun]
Filename: "{cmd}"; Parameters: "/c taskkill /f /im darsak_desktop.exe"; Flags: runhidden
