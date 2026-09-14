[Setup]
AppId=School Management System
AppName=Eduvia
AppVersion=1.0.18
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
; Bundled Visual C++ Redistributable installer (extracted to temp directory only if not already installed on target PC)
Source: "windows\redist\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall skipifsourcedoesntexist; Check: VCRedistNeedsInstall
; Application-local VC runtime DLLs if present in windows\redist
Source: "windows\redist\*.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{group}\Eduvia"; Filename: "{app}\eduvia.exe"
Name: "{commondesktop}\Eduvia"; Filename: "{app}\eduvia.exe"; Tasks: desktopicon

[Run]
; Silently install Microsoft Visual C++ 2015-2022 Redistributable if needed before launching application
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Microsoft Visual C++ 2015-2022 Runtime (required for Eduvia)..."; Flags: waituntilterminated; Check: VCRedistNeedsInstallAndBundled
Filename: "{app}\eduvia.exe"; Description: "{cm:LaunchProgram,Eduvia}"; Flags: nowait postinstall skipifsilent

[Code]
// Checks if Microsoft Visual C++ 2015-2022 Redistributable (x64) is already installed
function VCRedistNeedsInstall: Boolean;
var
  Installed: Cardinal;
  SysPath: String;
begin
  // 1. Check 64-bit Registry Hive (Primary check for VC 2015-2022 v14.x)
  if RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed) then
  begin
    if Installed = 1 then
    begin
      Log('VC Redist: Detected via HKLM64 VisualStudio 14.0 VC Runtimes x64 (Installed=1)');
      Result := False;
      Exit;
    end;
  end;

  // 2. Check 32-bit / WOW64 Registry Hive (Secondary check)
  if RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed) then
  begin
    if Installed = 1 then
    begin
      Log('VC Redist: Detected via HKLM VisualStudio 14.0 VC Runtimes x64 (Installed=1)');
      Result := False;
      Exit;
    end;
  end;

  // 3. Fallback check: check if essential runtime DLLs physically exist in System32
  SysPath := ExpandConstant('{sys}');
  if FileExists(SysPath + '\msvcp140.dll') and FileExists(SysPath + '\vcruntime140.dll') then
  begin
    Log('VC Redist: Detected msvcp140.dll and vcruntime140.dll in ' + SysPath);
    Result := False;
    Exit;
  end;

  Log('VC Redist: Not detected on this machine. Installation required.');
  Result := True;
end;

// Helper to check if VC Redist installer is present in {tmp}
function VCRedistNeedsInstallAndBundled: Boolean;
begin
  Result := VCRedistNeedsInstall and FileExists(ExpandConstant('{tmp}\vc_redist.x64.exe'));
end;

// Prepare step: If VC Redist is needed but wasn't bundled, download it on-the-fly
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
  TmpRedist: String;
  DownloadCmd: String;
begin
  Result := '';
  if VCRedistNeedsInstall then
  begin
    TmpRedist := ExpandConstant('{tmp}\vc_redist.x64.exe');
    if not FileExists(TmpRedist) then
    begin
      Log('VC Redist: Bundled installer not found in {tmp}, attempting on-the-fly download...');
      DownloadCmd := '/C curl.exe -sL "https://aka.ms/vs/17/release/vc_redist.x64.exe" -o "' + TmpRedist + '" || powershell -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile(''https://aka.ms/vs/17/release/vc_redist.x64.exe'', ''' + TmpRedist + ''')"';
      Exec('cmd.exe', DownloadCmd, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

      if FileExists(TmpRedist) then
      begin
        Log('VC Redist: Downloaded successfully, launching silent installation...');
        Exec(TmpRedist, '/install /quiet /norestart', '', SW_SHOW, ewWaitUntilTerminated, ResultCode);
      end
      else
      begin
        Log('VC Redist: Download failed or blocked by network.');
      end;
    end;
  end;
end;
