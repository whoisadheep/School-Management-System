[Setup]
AppId=School Management System
AppName=Eduvia
AppVersion=1.0.8
DefaultDirName={pf}\Eduvia
DefaultGroupName=Eduvia
OutputDir=build\windows\installer
OutputBaseFilename=Eduvia-Installer
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\eduvia.exe

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\eduvia.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Eduvia"; Filename: "{app}\eduvia.exe"
Name: "{commondesktop}\Eduvia"; Filename: "{app}\eduvia.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\eduvia.exe"; Description: "{cm:LaunchProgram,Eduvia}"; Flags: nowait postinstall skipifsilent
