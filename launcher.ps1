[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "`n--- Equicord Professional Launcher (v25) ---`n" -ForegroundColor Yellow

$AppFolder = Get-ChildItem -Path "$env:LOCALAPPDATA\Discord\app-*" | Select-Object -First 1 -ExpandProperty FullName
if (-not $AppFolder) { Write-Host "[!] Discord folder not found."; pause; exit }
Write-Host "[*] Target: $AppFolder" -ForegroundColor Gray

$IndexFiles = Get-ChildItem -Path $AppFolder -Recurse -File -Filter "index.js" | Where-Object { $_.FullName -match "discord_desktop_core" }
foreach ($F in $IndexFiles) {
    Write-Host "[*] Cleaning: $($F.FullName)" -ForegroundColor Gray
    [System.IO.File]::WriteAllText($F.FullName, "module.exports = require('./core.asar');")
}

$InstallerPath = Join-Path $env:USERPROFILE "Downloads\VencordInstallerCli.exe"
if (-not (Test-Path $InstallerPath)) {
    Write-Host "[*] Downloading installer engine..." -ForegroundColor Cyan
    $url = "https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli.exe"
    Invoke-WebRequest -Uri $url -OutFile $InstallerPath
}

if (Get-Process -Name "Discord" -ErrorAction SilentlyContinue) {
    Stop-Process -Name "Discord" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}
Write-Host "[!] Installing Equicord... Please wait..." -ForegroundColor Magenta
& $InstallerPath install -branch stable -type equicord -location $AppFolder

Write-Host "[*] Launching Discord..." -ForegroundColor Blue
Start-Process -FilePath "$env:LOCALAPPDATA\Discord\Update.exe" -ArgumentList "--processStart Discord.exe"

Write-Host "[+] Done! If it still asks questions, run debug.bat one more time.`n" -ForegroundColor Green
Start-Sleep -Seconds 2
