@echo off
echo ========================================================
echo Downloading Microsoft Visual C++ 2015-2022 Redistributable (x64)
echo ========================================================
if not exist "%~dp0redist" mkdir "%~dp0redist"
curl -sL https://aka.ms/vs/17/release/vc_redist.x64.exe -o "%~dp0redist\vc_redist.x64.exe"
if %ERRORLEVEL% equ 0 (
    echo Successfully downloaded vc_redist.x64.exe to windows\redist\
) else (
    echo Failed to download vc_redist.x64.exe
)
