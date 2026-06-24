$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
function Header($Title) {
    Clear-Host
    Write-Host "============================================================"
    Write-Host " $Title"
    Write-Host "============================================================"
    Write-Host ""
}
function Pause-Local { Write-Host ""; Read-Host "Press Enter to continue" | Out-Null }

Header "DOWNLOAD MANAGER"
Write-Host "Downloads software into the toolkit Downloads folder."
Write-Host ""
$Url = Read-Host "Download URL (blank or B to cancel)"
if ([string]::IsNullOrWhiteSpace($Url) -or $Url.Trim().ToUpperInvariant() -eq 'B') { Write-Host "Cancelled."; Pause-Local; return }
$Parsed = $null
if (-not [System.Uri]::TryCreate($Url, [System.UriKind]::Absolute, [ref]$Parsed) -or $Parsed.Scheme -notin @('http','https')) {
    Write-Host "[FAIL] Invalid URL. Enter a full http:// or https:// URL." -ForegroundColor Red
    Pause-Local
    return
}
$FileName = Split-Path $Parsed.AbsolutePath -Leaf
if ([string]::IsNullOrWhiteSpace($FileName)) { $FileName = Read-Host "File name" }
$OutDir = Join-Path $Root 'Downloads'
if (!(Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$OutFile = Join-Path $OutDir $FileName
try {
    Invoke-WebRequest -Uri $Parsed.AbsoluteUri -OutFile $OutFile -UseBasicParsing
    Write-Host "[PASS] Downloaded to $OutFile"
} catch {
    Write-Host "[FAIL] Download failed: $($_.Exception.Message)"
}
Pause-Local
