<# :
@echo off
title EquiLauncher
chcp 65001 > nul
set "SCRIPT_PATH=%~f0"

if "%1"=="--startup" (
    echo [*] Adding EquiLauncher to Windows Startup...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\EquiLauncher.lnk');$s.TargetPath='%~f0';$s.WindowStyle=7;$s.Save()"
    echo [+] Done! Shortcut created.
    timeout /t 3
    exit /b
)

echo [*] Starting engine...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f=[System.IO.File]::ReadAllText($env:SCRIPT_PATH); Invoke-Expression $f"

if %errorlevel% neq 0 (
    echo.
    echo [!] Critical Error: PowerShell could not start or was blocked.
    echo [!] Check your Antivirus or Execution Policy settings.
    pause
)
exit /b
#>

# --- ВЫПОЛНЯЕМЫЙ КОД POWERSHELL ---
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    
    # Логотип (стандартные символы для 100% совместимости)
    $logo = @"
    
     _____ ____  _   _ _____  _____ _______       _____ _______ 
    |  ____/ __ \| | | |_   _|/ ____|__   __|/\   |  __ \__   __|
    | |__ | |  | | | | | | | | (___    | |  /  \  | |__) | | |   
    |  __|| |  | | | | | | |  \___ \   | | / /\ \ |  _  /  | |   
    | |___| |__| | |_| |_| |_ ____) |  | |/ ____ \| | \ \  | |   
    |______\___\_\\___/|_____|_____/   |_/_/    \_\_|  \_\ |_|   
"@
    Write-Host $logo -ForegroundColor Yellow
    Write-Host "`n--- Professional Equicord Launcher ---`n" -ForegroundColor Gray

    # 1. Поиск папки Дискорда
    $AppFolder = Get-ChildItem -Path "$env:LOCALAPPDATA\Discord\app-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not $AppFolder) { throw "Discord folder not found!" }

    # 2. Поиск файла index.js для патча
    $Index = Get-ChildItem -Path $AppFolder -Recurse -File -Filter "index.js" | Where-Object { $_.FullName -match "discord_desktop_core" } | Select-Object -First 1
    if (-not $Index) { throw "Could not find Discord Core modules (index.js)." }

    # 3. Проверка и применение патча
    if ((Get-Content $Index.FullName -Raw) -notmatch "Equicord|Vencord") {
        Write-Host "[!] Patch missing. Starting recovery..." -ForegroundColor Magenta
        
        $WorkDir = Join-Path $env:LOCALAPPDATA "EquiLauncher"
        if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir | Out-Null }
        $Exe = Join-Path $WorkDir "VencordInstallerCli.exe"
        
        if (-not (Test-Path $Exe)) {
            Write-Host "[*] Downloading installer engine..." -ForegroundColor Cyan
            # BITS - самый надежный способ скачивания в Windows
            Start-BitsTransfer -Source "https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli.exe" -Destination $Exe
        }

        Write-Host "[*] Patching Discord... (Please wait)" -ForegroundColor Cyan
        if (Get-Process -Name "Discord" -ErrorAction SilentlyContinue) { Stop-Process -Name "Discord" -Force; Start-Sleep 1 }
        
        # Запускаем установку в этом же окне
        & $Exe install -branch stable -type equicord -location "$AppFolder" -no-confirm
        
        if ($LASTEXITCODE -ne 0) { throw "Installer failed with code $LASTEXITCODE" }
    } else {
        Write-Host "[+] Status: Patched & Ready" -ForegroundColor Green
    }

    # 4. Финальный запуск
    Write-Host "[*] Launching Discord..." -ForegroundColor Blue
    Start-Process -FilePath "$env:LOCALAPPDATA\Discord\Update.exe" -ArgumentList "--processStart Discord.exe"
    Write-Host "[+] All systems go!" -ForegroundColor Green
    Start-Sleep -Seconds 2

} catch {
    Write-Host "`n[FATAL ERROR]: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Press any key to close..."
    [Console]::ReadKey() | Out-Null
}
