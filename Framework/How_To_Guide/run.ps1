# ============================================================
# HOW TO GUIDE
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"

function Show-GuideFile {
    param([string]$Title, [string]$RelativePath)
    Show-ToolkitHeader $Title
    $Guide = Join-Path $Root $RelativePath
    if (Test-Path $Guide) {
        Get-Content $Guide | ForEach-Object { Write-Host $_ }
    }
    else {
        Write-Host "Guide file not found:" -ForegroundColor Red
        Write-Host "  $RelativePath"
    }
    Write-Host ""
    Write-Host "[B] Back"
    do { $BackChoice = (Read-Host "Selection").Trim().ToUpperInvariant() } until ($BackChoice -eq "B")
}

Invoke-ToolkitModule `
    -ModuleName "HOW TO GUIDE" `
    -RequiresAdmin $false `
    -ScriptBlock {

    while ($true) {
        Show-ToolkitHeader "HOW TO GUIDE"
        Write-Host "Step-by-step guides for using, repairing, and extending the toolkit."
        Write-Host ""
        Write-Host "[1] Support Center Index"
        Write-Host "[2] Getting Started"
        Write-Host "[3] Repository Manager Guide"
        Write-Host "[4] GitHub Puller Guide"
        Write-Host "[5] Metadata Library Manager Guide"
        Write-Host "[6] How To Make A Module"
        Write-Host "[7] Search & Discovery Guide"
        Write-Host "[8] Validation & Health Guide"
        Write-Host "[9] Recovery & Reset Guide"
        Write-Host "[10] How The Framework Works"
        Write-Host "[11] Troubleshooting & FAQ"
        Write-Host "[12] Generated Menu Reference"
        Write-Host "[13] Repository Formats & Detection"
        Write-Host "[14] Help Center Guide"
        Write-Host "[15] Tool Manager Guide"
        Write-Host "[16] Workspace Center Guide"
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        switch ($Choice) {
            "1" { Show-GuideFile "SUPPORT CENTER INDEX" "Docs\User\00_SUPPORT_CENTER_INDEX.md" }
            "2" { Show-GuideFile "GETTING STARTED" "Docs\User\01_GETTING_STARTED.md" }
            "3" { Show-GuideFile "REPOSITORY MANAGER GUIDE" "Docs\User\02_REPOSITORY_MANAGER_GUIDE.md" }
            "4" { Show-GuideFile "GITHUB PULLER GUIDE" "Docs\User\03_GITHUB_PULLER_GUIDE.md" }
            "5" { Show-GuideFile "METADATA LIBRARY MANAGER GUIDE" "Docs\User\04_METADATA_LIBRARY_MANAGER_GUIDE.md" }
            "6" { Show-GuideFile "HOW TO MAKE A MODULE" "Docs\User\05_MODULE_CREATION_GUIDE.md" }
            "7" { Show-GuideFile "SEARCH & DISCOVERY GUIDE" "Docs\User\06_SEARCH_AND_DISCOVERY_GUIDE.md" }
            "8" { Show-GuideFile "VALIDATION & HEALTH GUIDE" "Docs\User\07_VALIDATION_HEALTH_GUIDE.md" }
            "9" { Show-GuideFile "RECOVERY & RESET GUIDE" "Docs\User\08_RECOVERY_AND_RESET_GUIDE.md" }
            "10" { Show-GuideFile "HOW THE FRAMEWORK WORKS" "Docs\User\09_HOW_THE_FRAMEWORK_WORKS.md" }
            "11" { Show-GuideFile "TROUBLESHOOTING & FAQ" "Docs\User\10_TROUBLESHOOTING_FAQ.md" }
            "12" { Show-GuideFile "GENERATED MENU REFERENCE" "Docs\User\11_MENU_REFERENCE_GENERATED.md" }
            "13" { Show-GuideFile "REPOSITORY FORMATS & DETECTION" "Docs\Software Deployment\Supported_Formats.txt" }
            "14" { Show-GuideFile "HELP CENTER GUIDE" "Docs\User\12_HELP_CENTER_GUIDE.md" }
            "15" { Show-GuideFile "TOOL MANAGER GUIDE" "Docs\User\13_TOOL_MANAGER_GUIDE.md" }
            "16" { Show-GuideFile "WORKSPACE CENTER GUIDE" "Docs\User\14_WORKSPACE_CENTER_GUIDE.md" }
            "B" { return }
            default { Show-ToolkitStatus "WARN" "Unknown selection: $Choice"; Start-Sleep -Milliseconds 700 }
        }
    }
}
