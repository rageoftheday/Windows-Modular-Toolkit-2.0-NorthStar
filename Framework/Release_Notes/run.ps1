# ============================================================
# RELEASE NOTES
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "RELEASE NOTES" `
    -RequiresAdmin $false `
    -ScriptBlock {

    Show-ToolkitHeader "RELEASE NOTES"

    $Notes = Join-Path $Root "RELEASE_NOTES_v3_NEXT_LEVEL.txt"

    if (Test-Path $Notes) {
        Get-Content $Notes | ForEach-Object { Write-Host $_ }
    }
    else {
        Write-Host "Release notes file not found."
    }

    Write-Host ""
}
