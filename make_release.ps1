$ErrorActionPreference = "Stop"
$Version = "1.3.0"
$ReleaseName = "equistart-v$Version"

Write-Host "[*] Creating release v$Version..." -ForegroundColor Cyan

function New-PlatformArchive {
    param([string]$Platform, [string[]]$Files, [string]$Guide)

    $ZipFile = "$ReleaseName-$Platform.zip"
    $StageDir = Join-Path ([IO.Path]::GetTempPath()) ("equistart-release-" + [guid]::NewGuid().ToString("N"))
    Write-Host "[*] Creating archive $ZipFile..."
    try {
        New-Item -ItemType Directory -Path $StageDir | Out-Null
        foreach ($File in $Files) { Copy-Item -LiteralPath $File -Destination $StageDir }
        Copy-Item -LiteralPath $Guide -Destination (Join-Path $StageDir "README.md")
        Compress-Archive -Path (Join-Path $StageDir "*") -DestinationPath $ZipFile -Force
        Write-Host "[+] Created: $ZipFile" -ForegroundColor Green
    }
    finally {
        Remove-Item -LiteralPath $StageDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

New-PlatformArchive "windows" @("EquiLauncher.bat", "launcher.ps1", "Add-To-Startup.bat") "release-guides/README.windows.md"
New-PlatformArchive "macos" @("EquiLauncher.sh") "release-guides/README.macos.md"
New-PlatformArchive "linux" @("EquiLauncher.sh") "release-guides/README.linux.md"

Write-Host "[!] Done!" -ForegroundColor Cyan
