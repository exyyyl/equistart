[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$LogPath = Join-Path $PSScriptRoot "EquiLauncher_Debug.log"

function Install-Equicord {
    $AppFolder = Get-ChildItem -Path "$env:LOCALAPPDATA\Discord\app-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not $AppFolder) { throw "Discord folder not found!" }

    $Index = Get-ChildItem -Path $AppFolder -Recurse -File -Filter "index.js" | Where-Object { $_.FullName -match "discord_desktop_core" } | Select-Object -First 1
    if (-not $Index) { throw "Could not find index.js in Discord modules." }

    if ((Get-Content $Index.FullName -Raw) -notmatch "Equicord") {
        Write-Host "[!] Patch missing. Recovering..." -ForegroundColor Magenta
        
        $WorkDir = Join-Path $env:LOCALAPPDATA "EquiLauncher"
        if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir | Out-Null }
        $Exe = Join-Path $WorkDir "EquilotlCli.exe"
        
        if (-not (Test-Path $Exe)) {
            Write-Host "[*] Downloading installer..." -ForegroundColor Cyan
            Start-BitsTransfer -Source "https://github.com/Equicord/Equilotl/releases/latest/download/EquilotlCli.exe" -Destination $Exe
        }

        if (Get-Process -Name "Discord" -ErrorAction SilentlyContinue) { Stop-Process -Name "Discord" -Force; Start-Sleep 1 }
        
        & $Exe -install -branch stable
    }
    else {
        Write-Host "[+] Status: Patched & Ready" -ForegroundColor Green
    }

    Write-Host "[*] Launching Discord..." -ForegroundColor Blue
    Start-Process -FilePath "$env:LOCALAPPDATA\Discord\Update.exe" -ArgumentList "--processStart Discord.exe"
    Start-Sleep -Seconds 2
}

function Install-Vencord {
    $AppFolder = Get-ChildItem -Path "$env:LOCALAPPDATA\Discord\app-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not $AppFolder) { throw "Discord folder not found!" }

    $Index = Get-ChildItem -Path $AppFolder -Recurse -File -Filter "index.js" | Where-Object { $_.FullName -match "discord_desktop_core" } | Select-Object -First 1
    if (-not $Index) { throw "Could not find index.js in Discord modules." }

    if ((Get-Content $Index.FullName -Raw) -notmatch "Vencord") {
        Write-Host "[!] Patch missing. Recovering..." -ForegroundColor Magenta
        
        $WorkDir = Join-Path $env:LOCALAPPDATA "EquiLauncher"
        if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir | Out-Null }
        $Exe = Join-Path $WorkDir "VencordInstallerCli.exe"
        
        if (-not (Test-Path $Exe)) {
            Write-Host "[*] Downloading installer..." -ForegroundColor Cyan
            Start-BitsTransfer -Source "https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli.exe" -Destination $Exe
        }

        if (Get-Process -Name "Discord" -ErrorAction SilentlyContinue) { Stop-Process -Name "Discord" -Force; Start-Sleep 1 }
        
        & $Exe -install -branch stable
    }
    else {
        Write-Host "[+] Status: Patched & Ready" -ForegroundColor Green
    }

    Write-Host "[*] Launching Discord..." -ForegroundColor Blue
    Start-Process -FilePath "$env:LOCALAPPDATA\Discord\Update.exe" -ArgumentList "--processStart Discord.exe"
    Start-Sleep -Seconds 2
}

function Run-Normal {
    param([string]$Mod = "Equicord")
    try {
        if ($Mod -eq "Vencord") { Install-Vencord } else { Install-Equicord }
    }
    catch {
        Write-Host "`n[FATAL ERROR]: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Press any key to close..."
        [Console]::ReadKey() | Out-Null
    }
}

function Run-Debug {
    param([string]$Mod = "Equicord")
    Write-Host "[*] Starting EquiLauncher in Debug Mode ($Mod)..."
    $ScriptBlock = {
        param($ModName)
        try {
            if ($ModName -eq "Vencord") { Install-Vencord } else { Install-Equicord }
        }
        catch {
            Write-Error $_
        }
    }
    Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $Mod *>&1 | Tee-Object -FilePath $LogPath
    Write-Host "`n[!] Debug log saved to: $LogPath" -ForegroundColor Yellow
    Write-Host "Press any key to close..."
    [Console]::ReadKey() | Out-Null
}

function Add-Startup {
    param([string]$Mod = "Equicord")
    Write-Host "[*] Добавление $Mod в автозагрузку..." -ForegroundColor Cyan
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\EquiLauncher.lnk")
    
    $BatPath = Join-Path $PSScriptRoot "EquiLauncher.bat"
    if (Test-Path $BatPath) {
        $Shortcut.TargetPath = $BatPath
        if ($Mod -eq "Vencord") {
            $Shortcut.Arguments = "--silent-vencord"
        }
        else {
            $Shortcut.Arguments = "--silent"
        }
    }
    else {
        $Shortcut.TargetPath = "powershell.exe"
        if ($Mod -eq "Vencord") {
            $Shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -SilentVencord"
        }
        else {
            $Shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Silent"
        }
    }
    
    $Shortcut.WindowStyle = 7
    $Shortcut.Save()
    Write-Host "[+] Готово! Ярлык добавлен." -ForegroundColor Green
    Write-Host "Нажмите любую клавишу для возврата в меню..."
    [Console]::ReadKey() | Out-Null
}

if ($args -contains "-Silent") {
    Run-Normal -Mod "Equicord"
    exit
}
elseif ($args -contains "-SilentVencord") {
    Run-Normal -Mod "Vencord"
    exit
}

while ($true) {
    Clear-Host
    $logo = @(
        " ",
        " _____ ____  _   _ _____  _____ _______       _____ _______ ",
        "|  ____/ __ \| | | |_   _|/ ____|__   __|/\   |  __ \__   __|",
        "| |__ | |  | | | | | | | | (___    | |  /  \  | |__) | | |   ",
        "|  __|| |  | | | | | | |  \___ \   | | / /\ \ |  _  /  | |   ",
        "| |___| |__| | |_| |_| |_ ____) |  | |/ ____ \| | \ \  | |   ",
        "|______\___\_\\___/|_____|_____/   |_/_/    \_\_|  \_\ |_|   "
    ) -join "`n"
    Write-Host $logo -ForegroundColor Yellow
    
    Write-Host "========================================="
    Write-Host "--- Запуск ---" -ForegroundColor Cyan
    Write-Host "1. Запустить Equicord"
    Write-Host "2. Запустить Vencord"
    Write-Host ""
    Write-Host "--- Отладка ---" -ForegroundColor Yellow
    Write-Host "3. Запустить в режиме отладки (Equicord)"
    Write-Host "4. Запустить в режиме отладки (Vencord)"
    Write-Host ""
    Write-Host "--- Автозагрузка ---" -ForegroundColor Green
    Write-Host "5. Добавить в автозагрузку (Equicord)"
    Write-Host "6. Добавить в автозагрузку (Vencord)"
    Write-Host ""
    Write-Host "0. Выход" -ForegroundColor Gray
    Write-Host "========================================="
    
    $choice = Read-Host "Выберите действие"
    
    switch ($choice) {
        "1" { Run-Normal -Mod "Equicord"; exit }
        "2" { Run-Normal -Mod "Vencord"; exit }
        "3" { Run-Debug -Mod "Equicord"; exit }
        "4" { Run-Debug -Mod "Vencord"; exit }
        "5" { Add-Startup -Mod "Equicord" }
        "6" { Add-Startup -Mod "Vencord" }
        "0" { exit }
    }
}
