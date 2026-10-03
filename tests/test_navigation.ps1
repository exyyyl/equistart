$ErrorActionPreference = "Stop"
$RootDir = Split-Path $PSScriptRoot

foreach ($File in @("launcher.ps1", "EquiLauncher.bat")) {
    $Source = Get-Content (Join-Path $RootDir $File) -Raw -Encoding UTF8
    if ($File -like "*.bat") {
        $Source = ($Source -split [regex]::Escape('<# POWERSHELL_CODE #>'), 2)[1]
    }
    $ParseErrors = $null
    $Ast = [System.Management.Automation.Language.Parser]::ParseInput($Source, [ref]$null, [ref]$ParseErrors)
    if ($ParseErrors) { throw "$File has PowerShell syntax errors: $ParseErrors" }

    # Extract the real menu only. Installer functions and application initialization never run.
    $Menu = $Ast.Find({
        param($Node)
        $Node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Node.Name -eq "Run-Menu"
    }, $false)
    if (-not $Menu) { throw "Run-Menu not found in $File" }
    . ([scriptblock]::Create($Menu.Extent.Text))

    function Show-Page {
        param([string]$Title = "")
        $script:Pages.Add($Title)
    }
    function Read-MenuInput {
        if ($script:Inputs.Count -eq 0) { return $null }
        return $script:Inputs.Dequeue()
    }
    function Run-Normal {
        param([string]$Mod)
        $script:Actions.Add("launch:$Mod")
        throw "Simulated installer failure"
    }
    function Run-Debug {
        param([string]$Mod)
        $script:Actions.Add("debug:$Mod")
    }
    function Add-Startup {
        param([string]$Mod)
        $script:Actions.Add("startup:$Mod")
    }

    $script:Inputs = New-Object 'System.Collections.Generic.Queue[string]'
    $script:Actions = New-Object 'System.Collections.Generic.List[string]'
    $script:Pages = New-Object 'System.Collections.Generic.List[string]'
    foreach ($InputValue in @("1", "2", "", "2", "1", "", "3", "2", "", "0")) {
        $script:Inputs.Enqueue($InputValue)
    }
    Run-Menu
    if (($script:Actions -join ",") -ne "launch:Vencord,debug:Equicord,startup:Vencord") {
        throw "Menu did not continue after a failed action in $File"
    }
    if (@($script:Pages | Where-Object { $_ -eq "" }).Count -ne 4) {
        throw "Menu did not return home after each action in $File"
    }

    $script:Actions.Clear()
    $script:Pages.Clear()
    foreach ($InputValue in @("1", "9", "0", "0")) { $script:Inputs.Enqueue($InputValue) }
    Run-Menu
    if ($script:Actions.Count -ne 0) { throw "Back or invalid input triggered an action in $File" }
    Run-Menu # EOF must return instead of looping.
    Write-Host "Navigation tests passed: $File"
}
