$ErrorActionPreference = "Stop"
$Version = "1.2.0"
$ReleaseName = "equistart-v$Version"

Write-Host "[*] Creating release v$Version..." -ForegroundColor Cyan

function New-PlatformArchive {
    param([string]$Platform, [string[]]$Files)

    $ZipFile = "$ReleaseName-$Platform.zip"
    Write-Host "[*] Creating archive $ZipFile..."
    Compress-Archive -Path $Files -DestinationPath $ZipFile -Force
    Write-Host "[+] Created: $ZipFile" -ForegroundColor Green
}

New-PlatformArchive "windows" @("EquiLauncher.bat", "launcher.ps1", "Add-To-Startup.bat", "README.md")
New-PlatformArchive "macos" @("EquiLauncher.sh", "README.md")
New-PlatformArchive "linux" @("EquiLauncher.sh", "README.md")

Write-Host "[!] Done!" -ForegroundColor Cyan
