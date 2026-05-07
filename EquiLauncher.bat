@echo off
title EquiLauncher
chcp 65001 > nul
set "SCRIPT_PATH=%~f0"
set "LOG_PATH=%~dp0EquiLauncher_Debug.log"

if "%1"=="--silent" goto RUN_NORMAL
if "%1"=="--startup" goto ADD_STARTUP_ARG

:MENU
cls
echo =========================================
echo         Equicord Launcher Menu
echo =========================================
echo 1. Запустить Equicord
echo 2. Запустить в режиме отладки (с созданием лога)
echo 3. Добавить в автозагрузку (запуск при старте ПК)
echo 4. Выход
echo =========================================
set /p choice="Выберите действие (1-4): "

if "%choice%"=="1" goto RUN_NORMAL
if "%choice%"=="2" goto RUN_DEBUG
if "%choice%"=="3" goto ADD_STARTUP
if "%choice%"=="4" exit /b
goto MENU

:ADD_STARTUP_ARG
echo [*] Добавление EquiLauncher в автозагрузку...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\EquiLauncher.lnk');$s.TargetPath='%~f0';$s.Arguments='--silent';$s.WindowStyle=7;$s.Save()"
echo [+] Готово!
timeout /t 3 > nul
exit /b

:ADD_STARTUP
echo [*] Добавление EquiLauncher в автозагрузку...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\EquiLauncher.lnk');$s.TargetPath='%~f0';$s.Arguments='--silent';$s.WindowStyle=7;$s.Save()"
echo [+] Готово! Ярлык добавлен. При следующем запуске ПК Equicord запустится автоматически.
pause
goto MENU

:RUN_NORMAL
cls
echo [*] Запуск Equicord...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$script = Get-Content -LiteralPath $env:SCRIPT_PATH -Raw; $code = ($script -split '<# POWERSHELL_CODE #>')[1]; Invoke-Command -ScriptBlock ([scriptblock]::Create($code))"
if %errorlevel% neq 0 pause
exit /b

:RUN_DEBUG
cls
echo [*] Запуск в режиме отладки...
echo [*] Starting EquiLauncher > "%LOG_PATH%"
echo [*] Script Path: %SCRIPT_PATH% >> "%LOG_PATH%"
echo [*] Date: %DATE% %TIME% >> "%LOG_PATH%"
echo [*] Launching PowerShell Engine... >> "%LOG_PATH%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$script = Get-Content -LiteralPath $env:SCRIPT_PATH -Raw; $code = ($script -split '<# POWERSHELL_CODE #>')[1]; Invoke-Command -ScriptBlock ([scriptblock]::Create($code)) *>&1 | Tee-Object -FilePath $env:LOG_PATH -Append"
if %errorlevel% neq 0 (
    echo.
    echo [!] Ошибка! Подробности сохранены в %LOG_PATH%
    pause
)
exit /b

<# POWERSHELL_CODE #>
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    
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

    # 2. Поиск index.js
    $Index = Get-ChildItem -Path $AppFolder -Recurse -File -Filter "index.js" | Where-Object { $_.FullName -match "discord_desktop_core" } | Select-Object -First 1
    if (-not $Index) { throw "Could not find index.js in Discord modules." }

    # 3. Проверка патча
    if ((Get-Content $Index.FullName -Raw) -notmatch "Equicord|Vencord") {
        Write-Host "[!] Patch missing. Recovering..." -ForegroundColor Magenta
        
        $WorkDir = Join-Path $env:LOCALAPPDATA "EquiLauncher"
        if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir | Out-Null }
        $Exe = Join-Path $WorkDir "VencordInstallerCli.exe"
        
        if (-not (Test-Path $Exe)) {
            Write-Host "[*] Downloading installer..." -ForegroundColor Cyan
            Start-BitsTransfer -Source "https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli.exe" -Destination $Exe
        }

        if (Get-Process -Name "Discord" -ErrorAction SilentlyContinue) { Stop-Process -Name "Discord" -Force; Start-Sleep 1 }
        
        # Установка в текущем окне
        & $Exe install -branch stable -type equicord -location "$AppFolder" -no-confirm
    } else {
        Write-Host "[+] Status: Patched & Ready" -ForegroundColor Green
    }

    # 4. Запуск
    Write-Host "[*] Launching Discord..." -ForegroundColor Blue
    Start-Process -FilePath "$env:LOCALAPPDATA\Discord\Update.exe" -ArgumentList "--processStart Discord.exe"
    Start-Sleep -Seconds 2

} catch {
    Write-Host "`n[FATAL ERROR]: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Press any key to close..."
    [Console]::ReadKey() | Out-Null
}
