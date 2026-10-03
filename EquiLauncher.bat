@echo off
set "SCRIPT_PATH=%~f0"
set "SCRIPT_ARG=%~1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=Get-Content -LiteralPath $env:SCRIPT_PATH -Raw -Encoding UTF8; Invoke-Command -ScriptBlock ([scriptblock]::Create(($s -split ('<#' + ' POWERSHELL_CODE #>'))[1]))"
exit /b

<# POWERSHELL_CODE #>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$LogPath = Join-Path (Split-Path $env:SCRIPT_PATH) "EquiLauncher_Debug.log"
$AppVersion = [version]"1.3.4"
$ReleaseApiUrl = "https://api.github.com/repos/exyyyl/equistart/releases/latest"

function Test-LauncherUpdate {
    $LauncherDir = Split-Path $env:SCRIPT_PATH
    try {
        $Release = Invoke-RestMethod -Uri $ReleaseApiUrl -Headers @{ "User-Agent" = "EquiLauncher/$AppVersion" } -TimeoutSec 8
        $LatestText = ([string]$Release.tag_name).TrimStart("v")
        if ([version]$LatestText -le $AppVersion) { return }
        Add-Type -AssemblyName System.Windows.Forms
        $Answer = [System.Windows.Forms.MessageBox]::Show(
            "Доступна новая версия EquiLauncher v$LatestText (установлена v$AppVersion).`n`nОбновить сейчас?",
            "Обновление EquiLauncher",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Information,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button2
        )
        if ($Answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }

        $AssetName = "equistart-v$LatestText-windows.zip"
        $Asset = $Release.assets | Where-Object { $_.name -eq $AssetName } | Select-Object -First 1
        if (-not $Asset) { throw "В релизе отсутствует $AssetName" }
        $TempDir = Join-Path ([IO.Path]::GetTempPath()) ("EquiLauncherUpdate-" + [guid]::NewGuid().ToString("N"))
        $Archive = Join-Path $TempDir $AssetName
        $ExtractDir = Join-Path $TempDir "files"
        New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
        Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $Archive -UseBasicParsing -TimeoutSec 60
        Expand-Archive -LiteralPath $Archive -DestinationPath $ExtractDir -Force
        if (-not (Test-Path (Join-Path $ExtractDir "EquiLauncher.bat"))) { throw "Архив обновления повреждён" }
        $Updater = Join-Path $TempDir "update.ps1"
        @'
param($ParentPid, $Source, $Target, $TempDir)
$ErrorActionPreference = "Stop"
try {
    Wait-Process -Id $ParentPid -ErrorAction SilentlyContinue
    Get-ChildItem -LiteralPath $Source -File | Copy-Item -Destination $Target -Force
    Start-Process -FilePath (Join-Path $Target "EquiLauncher.bat")
}
catch {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("Не удалось установить обновление: $($_.Exception.Message)", "EquiLauncher") | Out-Null
}
finally { Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue }
'@ | Set-Content -LiteralPath $Updater -Encoding UTF8
        $UpdateArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$Updater`" $PID `"$ExtractDir`" `"$LauncherDir`" `"$TempDir`""
        Start-Process powershell.exe -ArgumentList $UpdateArgs
        exit
    }
    catch {
        Write-Host "[!] Не удалось проверить или установить обновление: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "[*] Запуск текущей версии..." -ForegroundColor Gray
    }
}

function Confirm-RestartForRepair {
    param([string]$Mod)
    Add-Type -AssemblyName System.Windows.Forms
    $Message = "Мод $Mod отключился после обновления Discord.`n`nПерезапустить Discord сейчас, чтобы восстановить мод?"
    $Result = [System.Windows.Forms.MessageBox]::Show(
        $Message,
        "EquiLauncher — требуется восстановление",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning,
        [System.Windows.Forms.MessageBoxDefaultButton]::Button2
    )
    return $Result -eq [System.Windows.Forms.DialogResult]::Yes
}

function Test-ModPatch {
    param([string]$AppFolder, [System.IO.FileInfo]$Index, [string]$LegacyMarker)

    # Current Vencord/Equilotl installers replace resources/app.asar and keep
    # the original as _app.asar. Older installers injected a named marker into index.js.
    $AsarBackup = Join-Path $AppFolder "resources\_app.asar"
    return (Test-Path -LiteralPath $AsarBackup -PathType Leaf) -or
        ((Get-Content $Index.FullName -Raw) -match [regex]::Escape($LegacyMarker))
}

function Install-Equicord {
    param([switch]$NonDisruptive)
    $DiscordWasRunning = [bool](Get-Process -Name "Discord" -ErrorAction SilentlyContinue)
    # 1. Поиск папки Дискорда
    $AppFolder = Get-ChildItem -Path "$env:LOCALAPPDATA\Discord\app-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not $AppFolder) { throw "Discord folder not found!" }

    # 2. Поиск index.js
    $Index = Get-ChildItem -Path $AppFolder -Recurse -File -Filter "index.js" | Where-Object { $_.FullName -match "discord_desktop_core" } | Select-Object -First 1
    if (-not $Index) { throw "Could not find index.js in Discord modules." }

    # 3. Проверка патча
    if (-not (Test-ModPatch -AppFolder $AppFolder -Index $Index -LegacyMarker "Equicord")) {
        Write-Host "[!] Patch missing. Recovering..." -ForegroundColor Magenta
        
        $WorkDir = Join-Path $env:LOCALAPPDATA "EquiLauncher"
        if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir | Out-Null }
        $Exe = Join-Path $WorkDir "EquilotlCli.exe"
        
        if (-not (Test-Path $Exe)) {
            Write-Host "[*] Downloading installer..." -ForegroundColor Cyan
            Start-BitsTransfer -Source "https://github.com/Equicord/Equilotl/releases/latest/download/EquilotlCli.exe" -Destination $Exe
        }

        if ($NonDisruptive -and $DiscordWasRunning) {
            if (-not (Confirm-RestartForRepair -Mod "Equicord")) {
                Write-Host "[!] Repair postponed by the user." -ForegroundColor Yellow
                return
            }
            Stop-Process -Name "Discord" -Force
            Start-Sleep 1
            $DiscordWasRunning = $false
        }
        elseif ($DiscordWasRunning) { Stop-Process -Name "Discord" -Force; Start-Sleep 1 }
        
        # Установка в текущем окне
        & $Exe -install -branch stable
    } else {
        Write-Host "[+] Status: Patched & Ready" -ForegroundColor Green
    }

    # 4. Запуск
    if (-not ($NonDisruptive -and $DiscordWasRunning)) {
        Write-Host "[*] Launching Discord..." -ForegroundColor Blue
        Start-Process -FilePath "$env:LOCALAPPDATA\Discord\Update.exe" -ArgumentList "--processStart Discord.exe"
        Start-Sleep -Seconds 2
    }
}

function Install-Vencord {
    param([switch]$NonDisruptive)
    $DiscordWasRunning = [bool](Get-Process -Name "Discord" -ErrorAction SilentlyContinue)
    # 1. Поиск папки Дискорда
    $AppFolder = Get-ChildItem -Path "$env:LOCALAPPDATA\Discord\app-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not $AppFolder) { throw "Discord folder not found!" }

    # 2. Поиск index.js
    $Index = Get-ChildItem -Path $AppFolder -Recurse -File -Filter "index.js" | Where-Object { $_.FullName -match "discord_desktop_core" } | Select-Object -First 1
    if (-not $Index) { throw "Could not find index.js in Discord modules." }

    # 3. Проверка патча
    if (-not (Test-ModPatch -AppFolder $AppFolder -Index $Index -LegacyMarker "Vencord")) {
        Write-Host "[!] Patch missing. Recovering..." -ForegroundColor Magenta
        
        $WorkDir = Join-Path $env:LOCALAPPDATA "EquiLauncher"
        if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir | Out-Null }
        $Exe = Join-Path $WorkDir "VencordInstallerCli.exe"
        
        if (-not (Test-Path $Exe)) {
            Write-Host "[*] Downloading installer..." -ForegroundColor Cyan
            Start-BitsTransfer -Source "https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli.exe" -Destination $Exe
        }

        if ($NonDisruptive -and $DiscordWasRunning) {
            if (-not (Confirm-RestartForRepair -Mod "Vencord")) {
                Write-Host "[!] Repair postponed by the user." -ForegroundColor Yellow
                return
            }
            Stop-Process -Name "Discord" -Force
            Start-Sleep 1
            $DiscordWasRunning = $false
        }
        elseif ($DiscordWasRunning) { Stop-Process -Name "Discord" -Force; Start-Sleep 1 }
        
        # Установка в текущем окне
        & $Exe -install -branch stable
    } else {
        Write-Host "[+] Status: Patched & Ready" -ForegroundColor Green
    }

    # 4. Запуск
    if (-not ($NonDisruptive -and $DiscordWasRunning)) {
        Write-Host "[*] Launching Discord..." -ForegroundColor Blue
        Start-Process -FilePath "$env:LOCALAPPDATA\Discord\Update.exe" -ArgumentList "--processStart Discord.exe"
        Start-Sleep -Seconds 2
    }
}

function Run-Normal {
    param([string]$Mod = "Equicord", [switch]$NonDisruptive)
    try {
        if ($Mod -eq "Vencord") { Install-Vencord -NonDisruptive:$NonDisruptive } else { Install-Equicord -NonDisruptive:$NonDisruptive }
    } catch {
        Write-Host "`n[FATAL ERROR]: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Run-Debug {
    param([string]$Mod = "Equicord")
    Write-Host "[*] Starting EquiLauncher in Debug Mode ($Mod)..."
    $ScriptBlock = {
        param($ModName)
        try {
            if ($ModName -eq "Vencord") { Install-Vencord } else { Install-Equicord }
        } catch {
            Write-Error $_
        }
    }
    Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $Mod *>&1 | Tee-Object -FilePath $LogPath
    Write-Host "`n[!] Debug log saved to: $LogPath" -ForegroundColor Yellow
}

function Add-Startup {
    param([string]$Mod = "Equicord")
    Write-Host "[*] Добавление $Mod в автозагрузку..." -ForegroundColor Cyan
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\EquiLauncher.lnk")
    $Shortcut.TargetPath = $env:SCRIPT_PATH
    if ($Mod -eq "Vencord") {
        $Shortcut.Arguments = "--silent-vencord"
    } else {
        $Shortcut.Arguments = "--silent"
    }
    $Shortcut.WindowStyle = 7 # Minimized
    $Shortcut.Save()
    Write-Host "[+] Готово! Ярлык добавлен." -ForegroundColor Green
}

function Show-Page {
    param([string]$Title = "")
    Clear-Host
    Write-Host ""
    Write-Host "    EQUI" -NoNewline -ForegroundColor Yellow
    Write-Host "START" -NoNewline -ForegroundColor White
    Write-Host "   [ v$AppVersion ]" -ForegroundColor DarkGray
    Write-Host ""
    $Breadcrumb = if ($Title) { "Главная / $Title" } else { "Главная" }
    Write-Host "    $Breadcrumb" -ForegroundColor Cyan
    Write-Host "    ─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
}

function Read-MenuInput {
    return [Console]::ReadLine()
}

function Run-Menu {
    $Page = "home"
    while ($true) {
        if ($Page -eq "home") {
            Show-Page
            Write-Host "    1  Запустить Discord"
            Write-Host "    2  Диагностика"
            Write-Host "    3  Автозагрузка"
            Write-Host ""
            Write-Host "    0  Закрыть лаунчер" -ForegroundColor DarkGray
        }
        else {
            $Title = switch ($Page) {
                "launch" { "Запуск" }
                "debug" { "Диагностика" }
                "startup" { "Автозагрузка" }
            }
            Show-Page -Title $Title
            Write-Host "    1  Equicord"
            Write-Host "    2  Vencord"
            Write-Host ""
            Write-Host "    0  Назад" -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host "    Команда  › " -NoNewline -ForegroundColor Cyan
        $Choice = Read-MenuInput
        if ($null -eq $Choice) { return }
        if ($Page -eq "home") {
            switch ($Choice) {
                "1" { $Page = "launch" }
                "2" { $Page = "debug" }
                "3" { $Page = "startup" }
                "0" { return }
            }
            continue
        }
        if ($Choice -eq "0") { $Page = "home"; continue }
        if ($Choice -notin @("1", "2")) { continue }
        $Mod = if ($Choice -eq "1") { "Equicord" } else { "Vencord" }
        Show-Page -Title "$Title / $Mod"
        try {
            switch ($Page) {
                "launch" { Run-Normal -Mod $Mod }
                "debug" { Run-Debug -Mod $Mod }
                "startup" { Add-Startup -Mod $Mod }
            }
        }
        catch {
            Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "    Нажмите Enter, чтобы вернуться на главную…" -NoNewline -ForegroundColor Cyan
        if ($null -eq (Read-MenuInput)) { return }
        $Page = "home"
    }
}

if ($env:EQUILAUNCHER_SOURCE_ONLY -eq "true") { return }

if ($env:SCRIPT_ARG -eq "--silent" -or $env:SCRIPT_ARG -eq "--startup") {
    Run-Normal -Mod "Equicord" -NonDisruptive
    exit
} elseif ($env:SCRIPT_ARG -eq "--silent-vencord") {
    Run-Normal -Mod "Vencord" -NonDisruptive
    exit
}

Test-LauncherUpdate

Run-Menu
