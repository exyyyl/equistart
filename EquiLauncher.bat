<# :
@echo off
chcp 65001 > nul
set "SCRIPT_PATH=%~f0"

if "%1"=="--startup" goto :startup

powershell -NoProfile -ExecutionPolicy Bypass -Command "[System.IO.File]::ReadAllText($env:SCRIPT_PATH) | Out-String | Invoke-Expression"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Script failed to launch. 
    pause
)
exit /b

:startup
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\EquiLauncher.lnk');$s.TargetPath='%~f0';$s.WindowStyle=7;$s.Save()"
exit /b
#>

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    
    # Красивый логотип
    $logo = @"
    
    ███████╗ ██████╗ ██╗   ██╗██╗███████╗████████╗ █████╗ ██████╗ ████████╗
    ██╔════╝██╔═══██╗██║   ██║██║██╔════╝╚══██╔══╝██╔══██╗██╔══██╗╚══██╔══╝
    █████╗  ██║   ██║██║   ██║██║███████╗   ██║   ███████║██████╔╝   ██║   
    ██╔══╝  ██║▄▄ ██║██║   ██║██║╚════██║   ██║   ██╔══██║██╔══██╗   ██║   
    ███████╗╚██████╔╝╚██████╔╝██║███████║   ██║   ██║  ██║██║  ██║   ██║   
    ╚══════╝ ╚══▀▀═╝  ╚═════╝ ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   
"@
    Write-Host $logo -ForegroundColor Yellow
    Write-Host "`n--- Professional Equicord Launcher ---`n" -ForegroundColor Gray

    # 1. Поиск папки (более гибкий)
    $AppFolder = Get-ChildItem -Path "$env:LOCALAPPDATA\Discord\app-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not $AppFolder) { throw "Discord folder not found! Please make sure Discord is installed." }

    # 2. Определение пути к ядру
    $PossiblePaths = @(
        "modules\discord_desktop_core-1\discord_desktop_core\index.js",
        "modules\discord_desktop_core\discord_desktop_core\index.js"
    )
    
    $IndexPath = $null
    foreach ($P in $PossiblePaths) {
        $Full = Join-Path $AppFolder $P
        if (Test-Path $Full) { $IndexPath = $Full; break }
    }
    if (-not $IndexPath) { throw "Could not find index.js. Try running Discord once and then this script." }

    # 3. Проверка и патч
    if ((Get-Content $IndexPath -Raw) -notmatch "Equicord|Vencord") {
        Write-Host "[!] Patch missing. Starting recovery..." -ForegroundColor Magenta
        
        $WorkDir = Join-Path $env:LOCALAPPDATA "EquiLauncher"
        if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir | Out-Null }
        $Exe = Join-Path $WorkDir "VencordInstallerCli.exe"
        
        if (-not (Test-Path $Exe)) {
            Write-Host "[*] Downloading engine via curl..." -ForegroundColor Cyan
            # Используем curl.exe, так как он есть везде в Win10/11 и работает стабильнее
            curl.exe -L "https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli.exe" -o $Exe
        }

        Write-Host "[*] Patching Discord... (In this window)" -ForegroundColor Cyan
        if (Get-Process -Name "Discord" -ErrorAction SilentlyContinue) { Stop-Process -Name "Discord" -Force; Start-Sleep 1 }
        
        & $Exe install -branch stable -type equicord -location "$AppFolder" -no-confirm
        
        if ($LASTEXITCODE -ne 0) { throw "Installer failed with code $LASTEXITCODE" }
    } else {
        Write-Host "[+] Patch status: OK" -ForegroundColor Green
    }

    # 4. Запуск
    Write-Host "[*] Starting Discord..." -ForegroundColor Blue
    Start-Process -FilePath "$env:LOCALAPPDATA\Discord\Update.exe" -ArgumentList "--processStart Discord.exe"
    Write-Host "[+] All systems go!" -ForegroundColor Green
    Start-Sleep -Seconds 2

} catch {
    Write-Host "`n[FATAL ERROR]: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    [Console]::ReadKey() | Out-Null
}
