$Version = "1.0.0"
$ReleaseName = "equistart-v$Version"
$ZipFile = "$ReleaseName.zip"

Write-Host "[*] Creating release v$Version..." -ForegroundColor Cyan

# 1. Tagging in Git
if (Test-Path .git) {
    Write-Host "[*] Tagging v$Version in Git..."
    git tag -a "v$Version" -m "Release v$Version"
    Write-Host "[+] Tag created." -ForegroundColor Green
}

# 2. Creating Archive
$FilesToInclude = @(
    "EquiLauncher.bat",
    "launcher.ps1",
    "Add-To-Startup.bat",
    "README.md"
)

Write-Host "[*] Creating archive $ZipFile..."
Compress-Archive -Path $FilesToInclude -DestinationPath $ZipFile -Force

Write-Host "[+] Release archive created: $ZipFile" -ForegroundColor Green
Write-Host "[!] Done!" -ForegroundColor Cyan
