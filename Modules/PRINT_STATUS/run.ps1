$Root = Resolve-Path "$PSScriptRoot\..\.."


. "$Root\core\bootstrap.ps1"
$Root = Resolve-Path "$PSScriptRoot\..\.."


. "$Root\core\bootstrap.ps1"
# ============================================================
# WINDOWS MODULAR TOOLKIT
# Print Status
# ============================================================

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "Shared Printers and Printer Status" -ForegroundColor Cyan
Write-Host "Lists installed printers, status, sharing, and pending jobs."
Write-Host ""

try {
    $Printers = @(Get-Printer -ErrorAction Stop)

    if ($Printers.Count -eq 0) {
        Write-Host "No printers found." -ForegroundColor Yellow
    }
    else {
        Write-Host "--- INSTALLED PRINTERS ---" -ForegroundColor Cyan
        $Printers |
            Select-Object Name, DriverName, PortName, Shared, ShareName, PrinterStatus, Default |
            Format-Table -AutoSize
    }

    Write-Host ""
    Write-Host "--- PRINT QUEUE (pending jobs) ---" -ForegroundColor Cyan

    $Jobs = foreach ($Printer in $Printers) {
        Get-PrintJob -PrinterName $Printer.Name -ErrorAction SilentlyContinue
    }

    if ($Jobs) {
        $Jobs | Select-Object Id, PrinterName, DocumentName, JobStatus, Size | Format-Table -AutoSize
    }
    else {
        Write-Host "No pending print jobs." -ForegroundColor Green
    }
}
catch {
    Write-Host "[ERROR] Could not read printer status." -ForegroundColor Red
    Write-Host $_.Exception.Message
}

Write-Host ""
Write-Host "Print status check complete."


