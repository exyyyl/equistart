@echo off
:: --- EquiLauncher: All-in-One Discord + Equicord Automator ---
:: This file combines the batch wrapper and PowerShell logic into one.
:: Usage: Double-click to run. Run with --startup to add to Windows Startup.

chcp 65001 > nul
set "SELF=%~f0"

if "%1"=="--startup" (
    powershell -ExecutionPolicy Bypass -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\EquiLauncher.lnk');$s.TargetPath='%SELF%';$s.WindowStyle=7;$s.Save(); Write-Host 'Added to Startup! (Minimized)' -ForegroundColor Green; Start-Sleep -s 2"
    exit /b
)

powershell -ExecutionPolicy Bypass -WindowStyle Hidden -Command ^
    "$ErrorActionPreference = 'SilentlyContinue';" ^
    "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8;" ^
    "$AppFolder = Get-ChildItem -Path \"$env:LOCALAPPDATA\Discord\app-*\" | Select-Object -First 1 -ExpandProperty FullName;" ^
    "if (-not $AppFolder) { exit };" ^
    "$IndexFiles = Get-ChildItem -Path $AppFolder -Recurse -File -Filter 'index.js' | Where-Object { $_.FullName -match 'discord_desktop_core' };" ^
    "foreach ($F in $IndexFiles) { [System.IO.File]::WriteAllText($F.FullName, 'module.exports = require(''./core.asar'');') };" ^
    "$WorkDir = Join-Path $env:LOCALAPPDATA 'EquiLauncher';" ^
    "if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir };" ^
    "$InstallerPath = Join-Path $WorkDir 'VencordInstallerCli.exe';" ^
    "if (-not (Test-Path $InstallerPath)) { $url = 'https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli.exe'; Invoke-WebRequest -Uri $url -OutFile $InstallerPath };" ^
    "if (Get-Process -Name 'Discord') { Stop-Process -Name 'Discord' -Force; Start-Sleep -Seconds 1 };" ^
    "Start-Process -FilePath $InstallerPath -ArgumentList \"install -branch stable -type equicord -location \`\"$AppFolder\`\"\" -Wait -WindowStyle Hidden;" ^
    "Start-Process -FilePath \"$env:LOCALAPPDATA\Discord\Update.exe\" -ArgumentList '--processStart Discord.exe';"

exit /b
