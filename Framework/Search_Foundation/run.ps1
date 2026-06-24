# Windows Modular Toolkit - Search Foundation
# Framework 2.0 Phase 36

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$FrameworkDir = Split-Path -Parent $ScriptDir
$ToolkitRoot = Split-Path -Parent $FrameworkDir
$SearchEngine = Join-Path $FrameworkDir 'Foundation\Search\Search.Engine.ps1'
$LogPath = Join-Path $ToolkitRoot 'Logs\framework_test.log'

if (Test-Path $SearchEngine) { . $SearchEngine }

function Write-SearchLog {
    param([string]$Result,[string]$Action,[string]$Details)
    try {
        $Dir = Split-Path -Parent $LogPath
        if (!(Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
        $Line = "{0} | {1} | Search | {2} | {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'),$Result,$Action,$Details
        Add-Content -Path $LogPath -Value $Line -Encoding UTF8
    } catch {}
}

function Show-Header {
    param([string]$Title)
    Clear-Host
    Write-Host '============================================================'
    Write-Host " $Title"
    Write-Host '============================================================'
    Write-Host ''
}

function Pause-Search { Write-Host ''; Read-Host 'Press Enter to continue' | Out-Null }

function Get-SearchTargetPath {
    param($Result)
    $Path = [string]$Result.path
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    try {
        if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
        return (Join-Path $ToolkitRoot $Path)
    } catch { return $Path }
}

function Open-SearchResultTarget {
    param($Result)
    $Path = Get-SearchTargetPath $Result
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Host "No path stored for this result." -ForegroundColor Yellow
        Pause-Search
        return
    }
    if (Test-Path $Path) {
        try { Invoke-Item $Path }
        catch { Write-Host "Could not open result: $($_.Exception.Message)" -ForegroundColor Red; Pause-Search }
    } else {
        Write-Host "Path not found:" -ForegroundColor Yellow
        Write-Host "  $Path"
        Pause-Search
    }
}

function Open-SearchResultFolder {
    param($Result)
    $Path = Get-SearchTargetPath $Result
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Host "No path stored for this result." -ForegroundColor Yellow
        Pause-Search
        return
    }
    $Folder = $Path
    if (Test-Path $Path -PathType Leaf) { $Folder = Split-Path -Parent $Path }
    if (Test-Path $Folder) {
        try { Invoke-Item $Folder }
        catch { Write-Host "Could not open folder: $($_.Exception.Message)" -ForegroundColor Red; Pause-Search }
    } else {
        Write-Host "Folder not found:" -ForegroundColor Yellow
        Write-Host "  $Folder"
        Pause-Search
    }
}

function Show-SearchResultDetails {
    param($Result)
    while ($true) {
        Show-Header 'SEARCH RESULT DETAILS'
        Write-Host "Name       : $($Result.name)"
        Write-Host "Type       : $($Result.type)"
        Write-Host "Category   : $($Result.category)"
        Write-Host "Source     : $($Result.source)"
        Write-Host "Path       : $($Result.path)"
        Write-Host "Keywords   : $(@($Result.keywords) -join ', ')"
        Write-Host ''
        if (-not [string]::IsNullOrWhiteSpace([string]$Result.description)) { Write-Host $Result.description }
        Write-Host ''
        Write-Host '[O] Open Item'
        Write-Host '[F] Open Folder'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = (Read-Host 'Selection').Trim().ToUpperInvariant()
        switch ($Choice) {
            'O' { Open-SearchResultTarget $Result }
            'F' { Open-SearchResultFolder $Result }
            'B' { return }
        }
    }
}


function Show-PagedResults {
    param([array]$Results,[string]$Query)
    $PageSize = 25
    $Page = 0
    if ($null -eq $Results) { $Results = @() }
    $Total = @($Results).Count
    if ($Total -eq 0) {
        Show-Header 'SEARCH RESULTS'
        Write-Host "Search: $Query"
        Write-Host ''
        Write-Host 'No results found.' -ForegroundColor Yellow
        Write-Host ''
        Write-Host '[S] New Search'
        Write-Host '[B] Back'
        $Choice = Read-Host 'Selection'
        if ($Choice.ToUpper() -eq 'S') { return 'search' }
        return 'back'
    }

    while ($true) {
        $TotalPages = [Math]::Ceiling($Total / $PageSize)
        if ($TotalPages -lt 1) { $TotalPages = 1 }
        if ($Page -lt 0) { $Page = 0 }
        if ($Page -ge $TotalPages) { $Page = $TotalPages - 1 }
        $Start = $Page * $PageSize
        $End = [Math]::Min($Start + $PageSize - 1, $Total - 1)
        $DisplayStart = $Start + 1
        $DisplayEnd = $End + 1

        Show-Header 'SEARCH RESULTS'
        Write-Host "Search: $Query"
        Write-Host "Results Found: $Total"
        Write-Host ''

        for ($i = $Start; $i -le $End; $i++) {
            $R = $Results[$i]
            $Number = $i + 1
            Write-Host "[$Number] $($R.name)"
            Write-Host "    Type: $($R.type) | Category: $($R.category) | Source: $($R.source)" -ForegroundColor DarkGray
            if (-not [string]::IsNullOrWhiteSpace([string]$R.description)) {
                $Desc = [string]$R.description
                if ($Desc.Length -gt 120) { $Desc = $Desc.Substring(0,117) + '...' }
                Write-Host "    $Desc" -ForegroundColor DarkGray
            }
            Write-Host ''
        }

        Write-Host "Showing $DisplayStart-$DisplayEnd of $Total"
        Write-Host "Page $($Page + 1) of $TotalPages"
        Write-Host ''
        if ($Page -lt ($TotalPages - 1)) { Write-Host '[N] Next Page' }
        if ($Page -gt 0) { Write-Host '[P] Previous Page' }
        Write-Host '[J] Jump To Page'
        Write-Host '[S] New Search'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        switch ($Choice.ToUpper()) {
            'N' { if ($Page -lt ($TotalPages - 1)) { $Page++ } }
            'P' { if ($Page -gt 0) { $Page-- } }
            'J' {
                $Target = Read-Host "Jump to page 1-$TotalPages"
                $N = 0
                if ([int]::TryParse($Target,[ref]$N)) {
                    if ($N -ge 1 -and $N -le $TotalPages) { $Page = $N - 1 }
                }
            }
            'S' { return 'search' }
            'B' { return 'back' }
            default {
                $N = 0
                if ([int]::TryParse($Choice,[ref]$N)) {
                    if ($N -ge 1 -and $N -le $Total) {
                        $R = $Results[$N-1]
                        Show-SearchResultDetails $R
                    }
                }
            }
        }
    }
}

function Invoke-Search {
    while ($true) {
        Show-Header 'SEARCH FOUNDATION'
        Write-Host 'Search across modules, workspace items, repository records, documentation, and metadata.'
        Write-Host ''
        Write-Host 'Examples:' -ForegroundColor DarkGray
        Write-Host 'dns, printer, chrome, crowdstrike, repair, google, workspace' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '[B] Back'
        Write-Host ''
        $Query = Read-Host 'Search'
        if ($Query.ToUpper() -eq 'B') { return }
        if ([string]::IsNullOrWhiteSpace($Query)) { continue }

        try {
            $Index = @(Get-WmtSearchIndex -ToolkitRoot $ToolkitRoot)
            [void](Save-WmtSearchIndex -ToolkitRoot $ToolkitRoot -Index $Index)
            $Results = @(Search-WmtIndex -Index $Index -Query $Query)
            Write-SearchLog 'PASS' 'Search' "$Query -> $($Results.Count) results from $($Index.Count) indexed objects"
            $Action = Show-PagedResults -Results $Results -Query $Query
            if ($Action -eq 'back') { return }
        } catch {
            Write-Host "[FAIL] Search failed." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-SearchLog 'FAIL' 'Search' $_.Exception.Message
            Pause-Search
        }
    }
}

Invoke-Search
