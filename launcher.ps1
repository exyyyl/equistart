[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$LogPath = Join-Path $PSScriptRoot "EquiLauncher_Debug.log"
$AppVersion = [version]"1.3.2"
$ReleaseApiUrl = "https://api.github.com/repos/exyyyl/equistart/releases/latest"

function Test-LauncherUpdate {
    try {
        $Release = Invoke-RestMethod -Uri $ReleaseApiUrl -Headers @{ "User-Agent" = "EquiLauncher/$AppVersion" } -TimeoutSec 8
        $LatestText = ([string]$Release.tag_name).TrimStart("v")
        $LatestVersion = [version]$LatestText
        if ($LatestVersion -le $AppVersion) { return }

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
        $RestartFile = if (Test-Path (Join-Path $PSScriptRoot "EquiLauncher.bat")) { "EquiLauncher.bat" } else { "launcher.ps1" }
        @'
param($ParentPid, $Source, $Target, $RestartFile, $TempDir)
$ErrorActionPreference = "Stop"
try {
    Wait-Process -Id $ParentPid -ErrorAction SilentlyContinue
    Get-ChildItem -LiteralPath $Source -File | Copy-Item -Destination $Target -Force
    $RestartPath = Join-Path $Target $RestartFile
    if ($RestartFile -like "*.bat") { Start-Process -FilePath $RestartPath }
    else { Start-Process powershell.exe -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $RestartPath) }
}
catch {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("Не удалось установить обновление: $($_.Exception.Message)", "EquiLauncher") | Out-Null
}
finally { Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue }
'@ | Set-Content -LiteralPath $Updater -Encoding UTF8
        $UpdateArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$Updater`" $PID `"$ExtractDir`" `"$PSScriptRoot`" `"$RestartFile`" `"$TempDir`""
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
    $AppFolder = Get-ChildItem -Path "$env:LOCALAPPDATA\Discord\app-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not $AppFolder) { throw "Discord folder not found!" }

    $Index = Get-ChildItem -Path $AppFolder -Recurse -File -Filter "index.js" | Where-Object { $_.FullName -match "discord_desktop_core" } | Select-Object -First 1
    if (-not $Index) { throw "Could not find index.js in Discord modules." }

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
        
        & $Exe -install -branch stable
    }
    else {
        Write-Host "[+] Status: Patched & Ready" -ForegroundColor Green
    }

    if (-not ($NonDisruptive -and $DiscordWasRunning)) {
        Write-Host "[*] Launching Discord..." -ForegroundColor Blue
        Start-Process -FilePath "$env:LOCALAPPDATA\Discord\Update.exe" -ArgumentList "--processStart Discord.exe"
        Start-Sleep -Seconds 2
    }
}

function Install-Vencord {
    param([switch]$NonDisruptive)
    $DiscordWasRunning = [bool](Get-Process -Name "Discord" -ErrorAction SilentlyContinue)
    $AppFolder = Get-ChildItem -Path "$env:LOCALAPPDATA\Discord\app-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not $AppFolder) { throw "Discord folder not found!" }

    $Index = Get-ChildItem -Path $AppFolder -Recurse -File -Filter "index.js" | Where-Object { $_.FullName -match "discord_desktop_core" } | Select-Object -First 1
    if (-not $Index) { throw "Could not find index.js in Discord modules." }

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
        
        & $Exe -install -branch stable
    }
    else {
        Write-Host "[+] Status: Patched & Ready" -ForegroundColor Green
    }

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

if ($env:EQUILAUNCHER_SOURCE_ONLY -eq "true") {
    return
}

if ($args -contains "-Silent") {
    Run-Normal -Mod "Equicord" -NonDisruptive
    exit
}
elseif ($args -contains "-SilentVencord") {
    Run-Normal -Mod "Vencord" -NonDisruptive
    exit
}

Test-LauncherUpdate

while ($true) {
    Clear-Host
    Write-Host ""
    Write-Host "    EQUI" -NoNewline -ForegroundColor Yellow
    Write-Host "START" -NoNewline -ForegroundColor White
    Write-Host "   [ v$AppVersion ]" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    ─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    ЗАПУСТИТЬ" -ForegroundColor Cyan
    Write-Host "      1  Equicord" -NoNewline -ForegroundColor White
    Write-Host "              2  Vencord" -ForegroundColor White
    Write-Host ""
    Write-Host "    ДИАГНОСТИКА" -ForegroundColor Magenta
    Write-Host "      3  Equicord + лог" -NoNewline -ForegroundColor White
    Write-Host "        4  Vencord + лог" -ForegroundColor White
    Write-Host ""
    Write-Host "    ЗАПУСКАТЬ С СИСТЕМОЙ" -ForegroundColor Green
    Write-Host "      5  Equicord" -NoNewline -ForegroundColor White
    Write-Host "              6  Vencord" -ForegroundColor White
    Write-Host ""
    Write-Host "    0  Закрыть" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    ─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "    Команда  › " -NoNewline -ForegroundColor Cyan
    $choice = [Console]::ReadLine()
    
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
