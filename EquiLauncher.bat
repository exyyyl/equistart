@echo off
set "SCRIPT_PATH=%~f0"
set "SCRIPT_ARG=%~1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=Get-Content -LiteralPath $env:SCRIPT_PATH -Raw -Encoding UTF8; Invoke-Command -ScriptBlock ([scriptblock]::Create(($s -split ('<#' + ' POWERSHELL_CODE #>'))[1]))"
exit /b

<# POWERSHELL_CODE #>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$LogPath = Join-Path (Split-Path $env:SCRIPT_PATH) "EquiLauncher_Debug.log"

function Install-Equicord {
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
}

function Run-Normal {
    try {
        Install-Equicord
    } catch {
        Write-Host "`n[FATAL ERROR]: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Press any key to close..."
        [Console]::ReadKey() | Out-Null
    }
}

function Run-Debug {
    Write-Host "[*] Starting EquiLauncher in Debug Mode..."
    $ScriptBlock = {
        try {
            Install-Equicord
        } catch {
            Write-Error $_
        }
    }
    Invoke-Command -ScriptBlock $ScriptBlock *>&1 | Tee-Object -FilePath $LogPath
    Write-Host "`n[!] Debug log saved to: $LogPath" -ForegroundColor Yellow
    Write-Host "Press any key to close..."
    [Console]::ReadKey() | Out-Null
}

function Add-Startup {
    Write-Host "[*] Добавление EquiLauncher в автозагрузку..." -ForegroundColor Cyan
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\EquiLauncher.lnk")
    $Shortcut.TargetPath = $env:SCRIPT_PATH
    $Shortcut.Arguments = "--silent"
    $Shortcut.WindowStyle = 7 # Minimized
    $Shortcut.Save()
    Write-Host "[+] Готово! Ярлык добавлен." -ForegroundColor Green
    Write-Host "Нажмите любую клавишу для возврата в меню..."
    [Console]::ReadKey() | Out-Null
}

if ($env:SCRIPT_ARG -eq "--silent" -or $env:SCRIPT_ARG -eq "--startup") {
    Run-Normal
    exit
}

while ($true) {
    Clear-Host
    $logo = @(
        ' ',
        ' _____ ____  _   _ _____  _____ _______       _____ _______ ',
        '|  ____/ __ \| | | |_   _|/ ____|__   __|/\   |  __ \__   __|',
        '| |__ | |  | | | | | | | | (___    | |  /  \  | |__) | | |   ',
        '|  __|| |  | | | | | | |  \___ \   | | / /\ \ |  _  /  | |   ',
        '| |___| |__| | |_| |_| |_ ____) |  | |/ ____ \| | \ \  | |   ',
        '|______\___\_\\___/|_____|_____/   |_/_/    \_\_|  \_\ |_|   '
    ) -join "`n"
    Write-Host $logo -ForegroundColor Yellow
    
    Write-Host "========================================="
    Write-Host "        Equicord Launcher Menu"
    Write-Host "========================================="
    Write-Host "1. Запустить Equicord"
    Write-Host "2. Запустить в режиме отладки (с созданием лога)"
    Write-Host "3. Добавить в автозагрузку (запуск при старте ПК)"
    Write-Host "4. Выход"
    Write-Host "========================================="
    
    $choice = Read-Host "Выберите действие (1-4)"
    
    switch ($choice) {
        "1" { Run-Normal; exit }
        "2" { Run-Debug; exit }
        "3" { Add-Startup }
        "4" { exit }
    }
}
