$ErrorActionPreference = "Continue"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$DownloadRoot = Join-Path $Root "Downloads\GitHub"
$IncomingRoot = Join-Path $Root "Incoming"
$ConfigRoot = Join-Path $Root "Config"
$LogRoot = Join-Path $Root "Logs"
$GitHubSourcesPath = Join-Path $ConfigRoot "github.sources.json"
$DetectionCorePath = Join-Path $ConfigRoot "detection.library.core.json"
$DetectionLibraryPath = Join-Path $ConfigRoot "detection.library.json"

function Header($Title) {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}
function Pause-Local { Write-Host ""; Read-Host "Press Enter to continue" | Out-Null }
function Ensure-Folder([string]$Path) { if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null } }
function Save-JsonFile($Path,$Object) { Ensure-Folder (Split-Path $Path -Parent); ($Object | ConvertTo-Json -Depth 12) | Set-Content -Path $Path -Encoding UTF8 }
function Load-JsonFile($Path,$Fallback) { try { if (Test-Path $Path) { return (Get-Content $Path -Raw | ConvertFrom-Json) } } catch {}; return $Fallback }
function Write-GitHubLog([string]$Message) { Ensure-Folder $LogRoot; Add-Content -Path (Join-Path $LogRoot "github_puller.log") -Value ("{0} | {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$Message) -Encoding UTF8 }

function Get-DetectionLibraryEntries {
    $Entries=@()
    foreach ($Path in @($DetectionCorePath,$DetectionLibraryPath)) {
        if (-not (Test-Path $Path)) { continue }
        try {
            $Data=Get-Content $Path -Raw | ConvertFrom-Json
            if ($Data.PSObject.Properties.Name -contains 'detections') { $Entries += @($Data.detections) }
            if ($Data.PSObject.Properties.Name -contains 'user_detections') { $Entries += @($Data.user_detections) }
        } catch { Write-GitHubLog "Detection library load failed: $($_.Exception.Message)" }
    }
    return @($Entries)
}
function Get-GitHubDetectionTokens([string]$Path) {
    $Tokens=New-Object System.Collections.Generic.List[string]
    function Add-TokenLocal([string]$Value) { if (-not [string]::IsNullOrWhiteSpace($Value)) { [void]$Tokens.Add($Value.ToLowerInvariant()) } }
    if (-not (Test-Path $Path)) { return @() }
    $Item=Get-Item -LiteralPath $Path -Force
    Add-TokenLocal $Item.Name
    if ($Item.PSIsContainer) {
        foreach ($Child in @(Get-ChildItem -LiteralPath $Item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue | Select-Object -First 500)) {
            Add-TokenLocal $Child.Name
            Add-TokenLocal ([System.IO.Path]::GetExtension($Child.Name))
        }
    } else {
        Add-TokenLocal ([System.IO.Path]::GetExtension($Item.Name))
    }
    return @($Tokens | Select-Object -Unique)
}
function Get-GitHubDetectionMatch([string]$Path) {
    $Tokens=@(Get-GitHubDetectionTokens $Path)
    foreach ($Rule in @(Get-DetectionLibraryEntries)) {
        $Indicators=@()
        if ($Rule.PSObject.Properties.Name -contains 'indicators') { $Indicators=@($Rule.indicators) }
        foreach ($Indicator in $Indicators) {
            $Needle=([string]$Indicator).Trim().ToLowerInvariant()
            foreach ($Token in $Tokens) {
                if ($Token -eq $Needle -or ($Needle.StartsWith('.') -and $Token.EndsWith($Needle))) { return $Rule }
            }
        }
    }
    return $null
}
function Show-GitHubDetectionResult([string]$Path) {
    $Rule=Get-GitHubDetectionMatch $Path
    if ($Rule) {
        Write-Host ""
        Write-Host "Detection Library:" -ForegroundColor Cyan
        Write-Host "  Detected : $($Rule.name)"
        Write-Host "  Category : $($Rule.category) / $($Rule.subcategory)"
        if ($Rule.description) { Write-Host "  Notes    : $($Rule.description)" }
    }
}

function Show-Examples {
    Write-Host "Examples:" -ForegroundColor DarkGray
    Write-Host "  Repository : https://github.com/owner/repo" -ForegroundColor DarkGray
    Write-Host "  Release    : https://github.com/owner/repo/releases" -ForegroundColor DarkGray
    Write-Host "  Release Tag: https://github.com/owner/repo/releases/tag/v1.0.0" -ForegroundColor DarkGray
    Write-Host "  Source ZIP : https://github.com/owner/repo/archive/refs/heads/main.zip" -ForegroundColor DarkGray
    Write-Host "  Git Clone  : https://github.com/owner/repo.git" -ForegroundColor DarkGray
}
function Parse-GitHubUrl {
    param([string]$Url)
    $Clean=$Url.Trim()
    if ($Clean -notmatch '^https?://github\.com/') { return $null }
    $Type='Repository'
    $Owner=''; $Repo=''; $Tag=''; $Asset=''
    if ($Clean -match 'github\.com/([^/]+)/([^/]+?)(?:\.git)?(?:/|$)') {
        $Owner=$Matches[1]
        $Repo=($Matches[2] -replace '\.git$','')
    } else { return $null }
    if ($Clean -match '/releases/download/([^/]+)/(.+)$') { $Type='Asset'; $Tag=$Matches[1]; $Asset=$Matches[2] }
    elseif ($Clean -match '/releases/tag/([^/?#]+)') { $Type='Release'; $Tag=$Matches[1] }
    elseif ($Clean -match '/releases/?$') { $Type='ReleaseList' }
    elseif ($Clean -match '/archive/refs/heads/([^/]+)\.zip') { $Type='SourceZip'; $Tag=$Matches[1] }
    elseif ($Clean -match '\.git$') { $Type='GitClone' }
    [PSCustomObject]@{ url=$Clean; owner=$Owner; repo=$Repo; type=$Type; tag=$Tag; asset=$Asset }
}
function Invoke-GitHubApi {
    param([string]$Uri)
    try { return Invoke-RestMethod -Uri $Uri -Headers @{ 'User-Agent'='Windows-Modular-Toolkit' } -ErrorAction Stop }
    catch { Write-GitHubLog "API failed $Uri : $($_.Exception.Message)"; return $null }
}
function Validate-GitHubUrl {
    param($Parsed)
    Header 'VALIDATING GITHUB URL'
    Write-Host "URL:"; Write-Host "  $($Parsed.url)"
    Write-Host ""
    Write-Host "Checking..."
    $RepoInfo = Invoke-GitHubApi "https://api.github.com/repos/$($Parsed.owner)/$($Parsed.repo)"
    if ($null -eq $RepoInfo) {
        Write-Host "[FAIL] Repository not found or not reachable." -ForegroundColor Red
        Write-Host ""
        Write-Host "Suggestions: check spelling, verify the repo exists, and verify it is public."
        Pause-Local
        return $null
    }
    $LatestRelease = Invoke-GitHubApi "https://api.github.com/repos/$($Parsed.owner)/$($Parsed.repo)/releases/latest"
    Write-Host "[OK] URL format valid" -ForegroundColor Green
    Write-Host "[OK] GitHub reachable" -ForegroundColor Green
    Write-Host "[OK] Repository exists" -ForegroundColor Green
    if (-not $RepoInfo.private) { Write-Host "[OK] Public repository" -ForegroundColor Green } else { Write-Host "[WARN] Private repository may require authentication" -ForegroundColor Yellow }
    if ($LatestRelease) { Write-Host "[OK] Latest release found: $($LatestRelease.tag_name)" -ForegroundColor Green } else { Write-Host "[WARN] No latest release found" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "Detected Type : $($Parsed.type)"
    Write-Host "Owner         : $($Parsed.owner)"
    Write-Host "Repository    : $($Parsed.repo)"
    [PSCustomObject]@{ parsed=$Parsed; repo_info=$RepoInfo; latest_release=$LatestRelease }
}
function Get-LatestRelease($Context) {
    if ($Context.latest_release) { return $Context.latest_release }
    return Invoke-GitHubApi "https://api.github.com/repos/$($Context.parsed.owner)/$($Context.parsed.repo)/releases/latest"
}
function Get-ReleaseByTag($Context,[string]$Tag) {
    if ([string]::IsNullOrWhiteSpace($Tag)) { return Get-LatestRelease $Context }
    return Invoke-GitHubApi "https://api.github.com/repos/$($Context.parsed.owner)/$($Context.parsed.repo)/releases/tags/$Tag"
}
function Get-SourceZipUrl($Context) {
    $Branch = $Context.repo_info.default_branch
    if ([string]::IsNullOrWhiteSpace($Branch)) { $Branch='main' }
    return "https://github.com/$($Context.parsed.owner)/$($Context.parsed.repo)/archive/refs/heads/$Branch.zip"
}
function Get-DefaultDownloadFileName($Url,$Fallback) {
    try { $Leaf = Split-Path ([uri]$Url).AbsolutePath -Leaf; if ($Leaf) { return $Leaf } } catch {}
    return $Fallback
}
function Select-FolderDialog([string]$Description) {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = $Description
        $dlg.ShowNewFolderButton = $true
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.SelectedPath }
    } catch {}
    return (Read-Host "Folder path")
}
function Choose-DownloadTarget {
    while ($true) {
        Header 'DOWNLOAD DESTINATION'
        Write-Host '[1] Downloads\GitHub'
        Write-Host '    Download only to toolkit staging.' -ForegroundColor DarkGray
        Write-Host '[2] Repository'
        Write-Host '    Download, then place the file in Incoming for repository import.' -ForegroundColor DarkGray
        Write-Host '[3] Repository + Module'
        Write-Host '    Download, place in Incoming, then open Repository Manager. Module creation defaults to Yes.' -ForegroundColor DarkGray
        Write-Host '[4] Save To Computer'
        Write-Host '    Choose any folder on this PC.' -ForegroundColor DarkGray
        Write-Host '[B] Back'
        $c=(Read-Host 'Selection').Trim().ToUpperInvariant()
        switch ($c) {
            '1' { return [PSCustomObject]@{ mode='downloads'; folder=$DownloadRoot } }
            '2' { return [PSCustomObject]@{ mode='repository'; folder=$DownloadRoot } }
            '3' { return [PSCustomObject]@{ mode='repository_module'; folder=$DownloadRoot } }
            '4' { $f=Select-FolderDialog 'Choose where to save the GitHub download'; if ($f) { return [PSCustomObject]@{ mode='computer'; folder=$f } } }
            'B' { return $null }
        }
    }
}
function Save-GitHubSourceRecord {
    param($Context,[string]$DownloadUrl,[string]$FilePath,[string]$Mode,[string]$Version)
    $Data = Load-JsonFile $GitHubSourcesPath ([ordered]@{ sources=@() })
    $Items=@($Data.sources)
    $Items += [ordered]@{
        owner=$Context.parsed.owner; repository=$Context.parsed.repo; url=$Context.parsed.url; version=$Version;
        download_url=$DownloadUrl; file_path=$FilePath; mode=$Mode; imported=(Get-Date).ToString('s')
    }
    $Data.sources=@($Items)
    Save-JsonFile $GitHubSourcesPath $Data
    $Sidecar = Join-Path (Split-Path $FilePath -Parent) 'source.github.json'
    Save-JsonFile $Sidecar $Items[-1]
}
function Invoke-RepositoryAfterDownload([string]$DownloadedPath,[string]$Mode) {
    if ($Mode -notin @('repository','repository_module')) { return }
    Ensure-Folder $IncomingRoot
    $Target = Join-Path $IncomingRoot (Split-Path $DownloadedPath -Leaf)
    Copy-Item -LiteralPath $DownloadedPath -Destination $Target -Force
    Write-Host "Copied to Incoming for Repository import:" -ForegroundColor Green
    Write-Host "  $Target"
    if ($Mode -eq 'repository_module') {
        Write-Host ""
        Write-Host "Opening Repository Manager. Import the item; module creation defaults to Yes." -ForegroundColor Yellow
        Pause-Local
        $RepoScript = Join-Path $Root 'Framework\Repository_Manager\run.ps1'
        if (Test-Path $RepoScript) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RepoScript }
    }
}
function Download-GitHubFile {
    param($Context,[string]$DownloadUrl,[string]$SuggestedName,[string]$Version='')
    $Target = Choose-DownloadTarget
    if ($null -eq $Target) { return }
    Ensure-Folder $Target.folder
    $FileName = Get-DefaultDownloadFileName $DownloadUrl $SuggestedName
    $OutFile = Join-Path $Target.folder $FileName
    Header 'DOWNLOADING GITHUB FILE'
    Write-Host "URL:"; Write-Host "  $DownloadUrl"
    Write-Host "Save To:"; Write-Host "  $OutFile"
    Write-Host ""
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $OutFile -UseBasicParsing -Headers @{ 'User-Agent'='Windows-Modular-Toolkit' } -ErrorAction Stop
        Write-Host "[OK] Download complete." -ForegroundColor Green
        Show-GitHubDetectionResult $OutFile
        Save-GitHubSourceRecord -Context $Context -DownloadUrl $DownloadUrl -FilePath $OutFile -Mode $Target.mode -Version $Version
        Invoke-RepositoryAfterDownload -DownloadedPath $OutFile -Mode $Target.mode
        if ($Target.mode -eq 'computer') { Start-Process -FilePath $Target.folder -ErrorAction SilentlyContinue }
    } catch {
        Write-Host "[FAIL] Download failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-GitHubLog "Download failed $DownloadUrl : $($_.Exception.Message)"
    }
    Pause-Local
}
function Show-ReleaseAssets {
    param($Context,[string]$Tag='')
    $Release = Get-ReleaseByTag $Context $Tag
    Header 'RELEASE ASSETS'
    if ($null -eq $Release) { Write-Host 'No release assets found.' -ForegroundColor Yellow; Pause-Local; return }
    Write-Host "Repository : $($Context.parsed.owner)/$($Context.parsed.repo)"
    Write-Host "Release    : $($Release.tag_name)"
    Write-Host ""
    $Assets=@($Release.assets)
    if ($Assets.Count -eq 0) { Write-Host 'No downloadable assets on this release.' -ForegroundColor Yellow; Pause-Local; return }
    $Map=@{}
    for ($i=0; $i -lt $Assets.Count; $i++) {
        $n=$i+1; $a=$Assets[$i]; $Map[[string]$n]=$a
        $Kind = if ($a.name -match '\.(exe|msi)$') {'Installer'} elseif ($a.name -match '\.(zip|7z|rar|tar|gz|xz)$') {'Archive'} elseif ($a.name -match '\.(msix|appx|msixbundle|appxbundle)$') {'Package'} elseif ($a.name -match 'sha|checksum') {'Checksum'} else {'Asset'}
        Write-Host ("[{0}] {1} ({2})" -f $n,$a.name,$Kind)
    }
    Write-Host "[A] Download All Assets"
    Write-Host "[B] Back"
    $c=(Read-Host 'Selection').Trim().ToUpperInvariant()
    if ($c -eq 'B') { return }
    if ($c -eq 'A') { foreach ($a in $Assets) { Download-GitHubFile -Context $Context -DownloadUrl $a.browser_download_url -SuggestedName $a.name -Version $Release.tag_name }; return }
    if ($Map.ContainsKey($c)) { $a=$Map[$c]; Download-GitHubFile -Context $Context -DownloadUrl $a.browser_download_url -SuggestedName $a.name -Version $Release.tag_name }
}
function Show-RepositoryInformation($Context) {
    Header 'GITHUB REPOSITORY INFORMATION'
    Write-Host "Owner      : $($Context.parsed.owner)"
    Write-Host "Repository : $($Context.parsed.repo)"
    Write-Host "URL        : $($Context.parsed.url)"
    if ($Context.repo_info.description) { Write-Host "Description: $($Context.repo_info.description)" }
    Write-Host "Default Branch : $($Context.repo_info.default_branch)"
    if ($Context.latest_release) { Write-Host "Latest Release : $($Context.latest_release.tag_name)" } else { Write-Host "Latest Release : None found" }
    Write-Host ""
    Write-Host "Source ZIP:"; Write-Host "  $(Get-SourceZipUrl $Context)"
    Write-Host "Git Clone:"; Write-Host "  https://github.com/$($Context.parsed.owner)/$($Context.parsed.repo).git"
    Pause-Local
}
function Invoke-CloneRepository($Context) {
    $Target = Choose-DownloadTarget
    if ($null -eq $Target) { return }
    Ensure-Folder $Target.folder
    $GitUrl = "https://github.com/$($Context.parsed.owner)/$($Context.parsed.repo).git"
    $OutFolder = Join-Path $Target.folder ("{0}-{1}" -f $Context.parsed.owner,$Context.parsed.repo)
    Header 'CLONE REPOSITORY'
    Write-Host "Git URL:"; Write-Host "  $GitUrl"
    Write-Host "Destination:"; Write-Host "  $OutFolder"
    Write-Host ""
    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) { Write-Host '[FAIL] Git is not installed or not in PATH.' -ForegroundColor Red; Pause-Local; return }
    try { git clone $GitUrl $OutFolder; Write-Host '[OK] Clone complete.' -ForegroundColor Green; Show-GitHubDetectionResult $OutFolder }
    catch { Write-Host "[FAIL] Clone failed: $($_.Exception.Message)" -ForegroundColor Red }
    Pause-Local
}
function Invoke-ImportRepository($Context) {
    $Release = Get-LatestRelease $Context
    if ($Release -and @($Release.assets).Count -gt 0) { Show-ReleaseAssets -Context $Context -Tag $Release.tag_name }
    else { Download-GitHubFile -Context $Context -DownloadUrl (Get-SourceZipUrl $Context) -SuggestedName ("{0}-{1}-source.zip" -f $Context.parsed.owner,$Context.parsed.repo) }
}

Ensure-Folder $DownloadRoot; Ensure-Folder $ConfigRoot
while ($true) {
    Header 'GITHUB PULLER 2.0'
    Write-Host 'Paste a GitHub URL. The toolkit validates the URL, detects its type, then lets you download or import it.'
    Write-Host ''
    Show-Examples
    Write-Host ''
    $Url = Read-Host 'GitHub URL (blank or B to cancel)'
    if ([string]::IsNullOrWhiteSpace($Url) -or $Url.Trim().ToUpperInvariant() -eq 'B') { return }
    $Parsed = Parse-GitHubUrl $Url
    if ($null -eq $Parsed) { Write-Host 'Not a recognized GitHub URL.' -ForegroundColor Red; Pause-Local; continue }
    $Context = Validate-GitHubUrl $Parsed
    if ($null -eq $Context) { continue }
    Pause-Local
    while ($true) {
        Header 'GITHUB REPOSITORY DETECTED'
        Write-Host "Owner      : $($Parsed.owner)"
        Write-Host "Repository : $($Parsed.repo)"
        Write-Host "URL Type   : $($Parsed.type)"
        if ($Parsed.tag) { Write-Host "Requested Tag : $($Parsed.tag)" }
        if ($Parsed.asset) { Write-Host "Requested Asset : $($Parsed.asset)" }
        if ($Context.latest_release) { Write-Host "Latest Release Found : $($Context.latest_release.tag_name)" }
        Write-Host '------------------------------------------------------------'

        if ($Parsed.type -eq 'Asset') {
            Write-Host '[1] Download This Asset'
            Write-Host '    Download the exact GitHub release file from the pasted URL.' -ForegroundColor DarkGray
            Write-Host '[2] Browse Release Assets'
            Write-Host '    Show all files attached to this release/tag.' -ForegroundColor DarkGray
            Write-Host '[3] Latest Source ZIP'
            Write-Host '    Download the repository source code as a ZIP archive.' -ForegroundColor DarkGray
            Write-Host '[4] Repository Information'
            Write-Host '    Show owner, repository name, release, source ZIP, and clone URL.' -ForegroundColor DarkGray
            Write-Host '[5] Import Repository'
            Write-Host '    Guided import using the latest release assets when available.' -ForegroundColor DarkGray
            Write-Host '[B] Back'
            $Choice=(Read-Host 'Selection').Trim().ToUpperInvariant()
            if ($Choice -eq 'B') { break }
            switch ($Choice) {
                '1' { Download-GitHubFile -Context $Context -DownloadUrl $Parsed.url -SuggestedName $Parsed.asset -Version $Parsed.tag }
                '2' { Show-ReleaseAssets -Context $Context -Tag $Parsed.tag }
                '3' { Download-GitHubFile -Context $Context -DownloadUrl (Get-SourceZipUrl $Context) -SuggestedName ("{0}-{1}-source.zip" -f $Parsed.owner,$Parsed.repo) }
                '4' { Show-RepositoryInformation $Context }
                '5' { Invoke-ImportRepository $Context }
                'B' { break }
            }
            continue
        }

        if ($Parsed.type -eq 'SourceZip') {
            Write-Host '[1] Download This Source ZIP'
            Write-Host '    Download the exact source ZIP from the pasted URL.' -ForegroundColor DarkGray
            Write-Host '[2] Latest Release Assets'
            Write-Host '    Download official release files such as EXE, MSI, ZIP, MSIX, or portable builds.' -ForegroundColor DarkGray
            Write-Host '[3] Clone Repository'
            Write-Host '    Clone the full Git repository if Git is installed.' -ForegroundColor DarkGray
            Write-Host '[4] Repository Information'
            Write-Host '    Show owner, repository name, release, source ZIP, and clone URL.' -ForegroundColor DarkGray
            Write-Host '[5] Import Repository'
            Write-Host '    Guided import using the latest release assets when available.' -ForegroundColor DarkGray
            Write-Host '[B] Back'
            $Choice=(Read-Host 'Selection').Trim().ToUpperInvariant()
            if ($Choice -eq 'B') { break }
            switch ($Choice) {
                '1' { Download-GitHubFile -Context $Context -DownloadUrl $Parsed.url -SuggestedName ("{0}-{1}-source.zip" -f $Parsed.owner,$Parsed.repo) -Version $Parsed.tag }
                '2' { Show-ReleaseAssets -Context $Context -Tag $Parsed.tag }
                '3' { Invoke-CloneRepository $Context }
                '4' { Show-RepositoryInformation $Context }
                '5' { Invoke-ImportRepository $Context }
                'B' { break }
            }
            continue
        }

        if ($Parsed.type -eq 'GitClone') {
            Write-Host '[1] Clone This Repository'
            Write-Host '    Clone the full Git repository if Git is installed.' -ForegroundColor DarkGray
            Write-Host '[2] Latest Release Assets'
            Write-Host '    Download official release files such as EXE, MSI, ZIP, MSIX, or portable builds.' -ForegroundColor DarkGray
            Write-Host '[3] Latest Source ZIP'
            Write-Host '    Download the repository source code as a ZIP archive.' -ForegroundColor DarkGray
            Write-Host '[4] Repository Information'
            Write-Host '    Show owner, repository name, release, source ZIP, and clone URL.' -ForegroundColor DarkGray
            Write-Host '[5] Import Repository'
            Write-Host '    Guided import using the latest release assets when available.' -ForegroundColor DarkGray
            Write-Host '[B] Back'
            $Choice=(Read-Host 'Selection').Trim().ToUpperInvariant()
            if ($Choice -eq 'B') { break }
            switch ($Choice) {
                '1' { Invoke-CloneRepository $Context }
                '2' { Show-ReleaseAssets -Context $Context -Tag $Parsed.tag }
                '3' { Download-GitHubFile -Context $Context -DownloadUrl (Get-SourceZipUrl $Context) -SuggestedName ("{0}-{1}-source.zip" -f $Parsed.owner,$Parsed.repo) }
                '4' { Show-RepositoryInformation $Context }
                '5' { Invoke-ImportRepository $Context }
                'B' { break }
            }
            continue
        }

        Write-Host '[1] Latest Release Assets'
        Write-Host '    Download official release files such as EXE, MSI, ZIP, MSIX, or portable builds.' -ForegroundColor DarkGray
        Write-Host '[2] Latest Source ZIP'
        Write-Host '    Download the repository source code as a ZIP archive.' -ForegroundColor DarkGray
        Write-Host '[3] Clone Repository'
        Write-Host '    Clone the full Git repository if Git is installed.' -ForegroundColor DarkGray
        Write-Host '[4] Repository Information'
        Write-Host '    Show owner, repository name, release, source ZIP, and clone URL.' -ForegroundColor DarkGray
        Write-Host '[5] Import Repository'
        Write-Host '    Guided import: download, classify, place in Incoming, then use Repository Manager.' -ForegroundColor DarkGray
        Write-Host '[B] Back'
        $Choice=(Read-Host 'Selection').Trim().ToUpperInvariant()
        if ($Choice -eq 'B') { break }
        switch ($Choice) {
            '1' { Show-ReleaseAssets -Context $Context -Tag $Parsed.tag }
            '2' { Download-GitHubFile -Context $Context -DownloadUrl (Get-SourceZipUrl $Context) -SuggestedName ("{0}-{1}-source.zip" -f $Parsed.owner,$Parsed.repo) }
            '3' { Invoke-CloneRepository $Context }
            '4' { Show-RepositoryInformation $Context }
            '5' { Invoke-ImportRepository $Context }
            'B' { break }
        }
    }
}
