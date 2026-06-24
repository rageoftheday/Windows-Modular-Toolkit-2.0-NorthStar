# ============================================================
# BACKUP FILE CLEANUP
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "BACKUP FILE CLEANUP" `
    -RequiresAdmin $false `
    -ScriptBlock {

    Show-ToolkitHeader "BACKUP FILE CLEANUP"

    $Patterns = @(
        "*.legacy-wrapper.bak",
        "*.prepatch.bak"
    )

    $Files = @()

    foreach ($Pattern in $Patterns) {
        $Files += Get-ChildItem "$Root\modules" -Recurse -Filter $Pattern -ErrorAction SilentlyContinue
    }

    $Files = @($Files | Sort-Object FullName -Unique)

    if (!$Files -or $Files.Count -eq 0) {
        Write-Host "No backup files found."
        return
    }

    Write-Host "Backup files found: $($Files.Count)"
    Write-Host ""

    $Files | Select-Object FullName | Format-Table -AutoSize

    Write-Host ""
    Write-Host "[D] Delete backup files"
    Write-Host "[B] Back"
    Write-Host ""

    $Choice = Read-Host "Selection"

    if ($Choice.ToUpper() -ne "D") {
        Write-Host "Cancelled."
        return
    }

    foreach ($File in $Files) {
        Remove-Item $File.FullName -Force -ErrorAction SilentlyContinue
        Write-Host "[DELETED] $($File.FullName)" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Backup cleanup complete."
}
