[Setup]
AppName=School Management System
AppVersion=1.0.0
DefaultDirName={pf}\School Management System
DefaultGroupName=School Management System
OutputDir=build\windows\installer
OutputBaseFilename=SchoolManagementSystem-Installer
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\school_management_system.exe

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\school_management_system.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\School Management System"; Filename: "{app}\school_management_system.exe"
Name: "{commondesktop}\School Management System"; Filename: "{app}\school_management_system.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\school_management_system.exe"; Description: "{cm:LaunchProgram,School Management System}"; Flags: nowait postinstall skipifsilent
