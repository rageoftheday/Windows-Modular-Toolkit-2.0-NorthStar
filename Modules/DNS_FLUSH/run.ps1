$Root = Resolve-Path "$PSScriptRoot\..\.."


. "$Root\core\bootstrap.ps1"
$Root = Resolve-Path "$PSScriptRoot\..\.."


. "$Root\core\bootstrap.ps1"
# ============================================================
# WINDOWS MODULAR TOOLKIT
# DNS Flush
# ============================================================

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "Flushing DNS Cache..." -ForegroundColor Cyan
Write-Host "This clears the local cache of website name-to-IP mappings."
Write-Host ""

try {
    ipconfig /flushdns
}
catch {
    Write-Host "[WARN] ipconfig flush failed:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message
}

try {
    Clear-DnsClientCache -ErrorAction Stop
    Write-Host "[OK] PowerShell DNS cache cleared." -ForegroundColor Green
}
catch {
    Write-Host "[WARN] Clear-DnsClientCache was not available or failed." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "DNS flush complete." -ForegroundColor Green


