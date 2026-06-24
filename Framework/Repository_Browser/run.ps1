# ============================================================
# WINDOWS MODULAR TOOLKIT - REPOSITORY BROWSER
# Framework Edition 2.0
# ============================================================

$ErrorActionPreference = "Continue"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepositoryManager = Join-Path (Split-Path -Parent $ScriptRoot) "Repository_Manager\run.ps1"
if (Test-Path $RepositoryManager) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RepositoryManager -BrowseOnly
} else {
    Write-Host "Repository Manager not found." -ForegroundColor Yellow
    Read-Host "Press Enter to continue" | Out-Null
}
