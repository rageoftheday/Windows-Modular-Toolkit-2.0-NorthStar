$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
function Header($Title) {
    Clear-Host
    Write-Host "============================================================"
    Write-Host " $Title"
    Write-Host "============================================================"
    Write-Host ""
}
function Pause-Local { Write-Host ""; Read-Host "Press Enter to continue" | Out-Null }

Header "REPOSITORY STRUCTURE VALIDATOR"
Write-Host "Validates the current Repository Asset Framework folder layout."
Write-Host ""
$Paths = @(
    'Repository',
    'Incoming',
    'Downloads',
    'Repository\Software',
    'Repository\Packages',
    'Repository\Scripts',
    'Repository\Documents',
    'Repository\Archives',
    'Repository\Disk Images',
    'Repository\Custom'
)
foreach ($Rel in $Paths) {
    $Path = Join-Path $Root $Rel
    if (!(Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Host "[CREATED] $Rel"
    } else {
        Write-Host "[OK]      $Rel"
    }
}
Write-Host ""
$Legacy = @(
    'Repository\ISO',
    'Repository\EXE',
    'Repository\MSI',
    'Repository\MSIX',
    'Repository\ZIP',
    'Repository\Portable',
    'Repository\Updates',
    'Repository\Software\GitHub',
    'Repository\Software\ISO',
    'Repository\Software\Archives',
    'Repository\Software\Packages'
)
$Found = @()
foreach ($Rel in $Legacy) {
    $Path = Join-Path $Root $Rel
    if (Test-Path $Path) { $Found += $Rel }
}
if ($Found.Count -eq 0) {
    Write-Host "[PASS] No legacy repository folders found." -ForegroundColor Green
} else {
    Write-Host "[WARN] Legacy repository folders found:" -ForegroundColor Yellow
    foreach ($Rel in $Found) { Write-Host "  $Rel" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "Use Repository Manager cleanup/repair before release."
}
Pause-Local
