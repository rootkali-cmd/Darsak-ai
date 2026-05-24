[Setup]
AppName=DarsakAI
AppVersion=1.1.1
AppPublisher=DarsakAI
DefaultDirName={autopf}\DarsakAI
DefaultGroupName=DarsakAI
OutputDir=..\build\installer
OutputBaseFilename=DarsakAI-Setup-1.1.0
Compression=lzma2/max
SolidCompression=yes
UninstallDisplayIcon={app}\darsak_desktop.exe

[Files]
Source: "..\build\windows\x64\runner\Release\darsak_desktop.exe"; DestDir: "{app}"
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\DarsakAI"; Filename: "{app}\darsak_desktop.exe"
Name: "{autodesktop}\DarsakAI"; Filename: "{app}\darsak_desktop.exe"

[Run]
Filename: "{app}\darsak_desktop.exe"; Description: "Run DarsakAI"; Flags: postinstall nowait skipifsilent shellexec
