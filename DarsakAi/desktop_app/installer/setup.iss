[Setup]
AppName=DarsakAI
AppVersion=1.3.0
AppPublisher=DarsakAI
AppPublisherURL=https://enjaz.one
AppSupportURL=https://enjaz.one
AppUpdatesURL=https://enjaz.one
AppCopyright=Copyright (C) 2026 DarsakAI. All rights reserved.
DefaultDirName={autopf}\DarsakAI
DefaultGroupName=DarsakAI
OutputDir=..\build\installer
OutputBaseFilename=DarsakAI-Setup
Compression=lzma2/max
SolidCompression=yes
UninstallDisplayIcon={app}\darsak_desktop.exe
UninstallDisplayName=DarsakAI
AppContact=support@darsakai.com
VersionInfoCompany=DarsakAI
VersionInfoDescription=DarsakAI Desktop - Teacher Dashboard
VersionInfoCopyright=Copyright (C) 2026 DarsakAI
VersionInfoProductName=DarsakAI
VersionInfoProductTextVersion=1.3.0
VersionInfoVersion=1.3.0.0
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
SetupIconFile=..\windows\runner\resources\app_icon.ico

[Files]
Source: "..\build\windows\x64\runner\Release\darsak_desktop.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\DarsakAI"; Filename: "{app}\darsak_desktop.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\DarsakAI"; Filename: "{app}\darsak_desktop.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\darsak_desktop.exe"; Description: "Run DarsakAI"; Flags: postinstall nowait skipifsilent shellexec
