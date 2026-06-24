$ErrorActionPreference = "Continue"
$ToolkitRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$CorePath = Join-Path $ToolkitRoot "Config\metadata.core.json"
if (-not (Test-Path $CorePath)) { $CorePath = Join-Path $ToolkitRoot "Core\metadata.defaults.json" }
$LibraryPath = Join-Path $ToolkitRoot "Config\metadata.library.json"
$BackupRoot = Join-Path $ToolkitRoot "Config\Backups"
$RepositoryFormatsCorePath = Join-Path $ToolkitRoot "Config\repository.formats.core.json"
$RepositoryFormatsLibraryPath = Join-Path $ToolkitRoot "Config\repository.formats.library.json"
$DetectionCorePath = Join-Path $ToolkitRoot "Config\detection.library.core.json"
$DetectionLibraryPath = Join-Path $ToolkitRoot "Config\detection.library.json"

function Show-Header {
    param([string]$Title)
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}
function Pause-Return { Read-Host "Press Enter to continue" | Out-Null }
function New-EmptyLibraryObject {
    [ordered]@{
        categories = @()
        subcategories = [ordered]@{}
        keywords = @()
        dependencies = @()
        description_templates = @()
        workspace_layouts = [ordered]@{}
        installer_arguments = @()
    }
}
function Load-JsonFile {
    param([string]$Path,$Fallback)
    try {
        if (Test-Path $Path) { return (Get-Content $Path -Raw | ConvertFrom-Json) }
    } catch {}
    return $Fallback
}
function Save-JsonFile {
    param([string]$Path,$Object)
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    ($Object | ConvertTo-Json -Depth 16) | Set-Content -Path $Path -Encoding UTF8
}
function Backup-JsonLibrary {
    param([string]$Path,[string]$BaseName)
    if (-not (Test-Path $BackupRoot)) { New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null }
    if (-not (Test-Path $Path)) { return }
    $Bak1 = Join-Path $BackupRoot ("{0}.bak1" -f $BaseName)
    $Bak2 = Join-Path $BackupRoot ("{0}.bak2" -f $BaseName)
    if (Test-Path $Bak1) { Copy-Item $Bak1 $Bak2 -Force }
    Copy-Item $Path $Bak1 -Force
}
function Save-JsonLibraryWithBackup {
    param([string]$Path,$Object,[string]$BaseName)
    Backup-JsonLibrary -Path $Path -BaseName $BaseName
    Save-JsonFile -Path $Path -Object $Object
}
function ConvertTo-Array {
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [array]) { return @($Value) }
    return @($Value)
}
function Normalize-MetadataValue {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    $v = ($Value -replace '\s+',' ').Trim()
    $known = @{
        'dns'='DNS'; 'dhcp'='DHCP'; 'ip'='IP'; 'vpn'='VPN'; 'wifi'='WiFi'; 'wi-fi'='Wi-Fi'
        'sfc'='SFC'; 'dism'='DISM'; 'rsat'='RSAT'; 'winget'='Winget'; 'importexcel'='ImportExcel'
        'azure'='Azure'; 'intune'='Intune'; 'autopilot'='Autopilot'; 'entra'='Entra'; 'm365'='M365'
        'it'='IT'; 'aio'='AIO'; 'flextg'='FlexTG'; 'edmo'='EDMO'
    }
    $key = $v.ToLowerInvariant()
    if ($known.ContainsKey($key)) { return $known[$key] }
    $parts = @($v -split ' ' | Where-Object { $_ })
    $fixed = foreach ($p in $parts) {
        $lk = $p.ToLowerInvariant()
        if ($known.ContainsKey($lk)) { $known[$lk] }
        elseif ($p.Length -le 1) { $p.ToUpperInvariant() }
        else { $p.Substring(0,1).ToUpperInvariant() + $p.Substring(1).ToLowerInvariant() }
    }
    return ($fixed -join ' ')
}
function Ensure-Library {
    if (-not (Test-Path $LibraryPath)) { Save-JsonFile $LibraryPath (New-EmptyLibraryObject) }
    if (-not (Test-Path $BackupRoot)) { New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null }
    foreach ($b in @('metadata.library.bak','metadata.library.previous.bak')) {
        $p = Join-Path $BackupRoot $b
        if (-not (Test-Path $p)) { Copy-Item $LibraryPath $p -Force }
    }
}
function Backup-Library {
    Ensure-Library
    $bak = Join-Path $BackupRoot 'metadata.library.bak'
    $prev = Join-Path $BackupRoot 'metadata.library.previous.bak'
    if (Test-Path $bak) { Copy-Item $bak $prev -Force }
    Copy-Item $LibraryPath $bak -Force
}

function Create-ManualBackup {
    Show-Header 'CREATE MANUAL METADATA BACKUP'
    Ensure-Library
    $bak = Join-Path $BackupRoot 'metadata.library.bak'
    $prev = Join-Path $BackupRoot 'metadata.library.previous.bak'
    Write-Host "This saves the current editable metadata library as the newest backup." -ForegroundColor Yellow
    Write-Host "The current backup will move to the older backup slot."
    Write-Host ""
    if (Test-Path $bak) { Write-Host "Current Backup : $((Get-Item $bak).LastWriteTime)" }
    if (Test-Path $prev) { Write-Host "Older Backup   : $((Get-Item $prev).LastWriteTime)" }
    Write-Host ""
    $ok = (Read-Host "Create manual backup now? Y/N").Trim().ToUpper()
    if ($ok -in @('Y','YES')) {
        Backup-Library
        Write-Host "[OK] Manual backup created." -ForegroundColor Green
        Write-Host "Backup folder: $BackupRoot" -ForegroundColor DarkGray
    }
    Pause-Return
}
function Save-Library {
    param($Library)
    Backup-Library
    Save-JsonFile $LibraryPath $Library
}
function Get-Library { Ensure-Library; return (Load-JsonFile $LibraryPath (New-EmptyLibraryObject)) }
function Get-Core { return (Load-JsonFile $CorePath (New-EmptyLibraryObject)) }
function Is-CoreValue {
    param([string]$Section,[string]$Value,[string]$Parent='')
    $core = Get-Core
    $clean = Normalize-MetadataValue $Value
    try {
        if ($Section -eq 'subcategories') {
            if ($core.subcategories.PSObject.Properties.Name -contains $Parent) {
                return @(ConvertTo-Array $core.subcategories.$Parent | Where-Object { $_.ToString().Trim().ToLowerInvariant() -eq $clean.ToLowerInvariant() }).Count -gt 0
            }
        }
        elseif ($core.PSObject.Properties.Name -contains $Section) {
            return @(ConvertTo-Array $core.$Section | Where-Object { $_.ToString().Trim().ToLowerInvariant() -eq $clean.ToLowerInvariant() }).Count -gt 0
        }
    } catch {}
    return $false
}
function Add-LibraryValue {
    param([string]$Section,[string]$Value,[string]$Parent='')
    $clean = Normalize-MetadataValue $Value
    if ([string]::IsNullOrWhiteSpace($clean)) { return }
    if (Is-CoreValue $Section $clean $Parent) {
        Write-Host "Already exists as a protected Core default: $clean" -ForegroundColor Yellow
        Pause-Return
        return
    }
    $lib = Get-Library
    if ($Section -eq 'subcategories') {
        if ([string]::IsNullOrWhiteSpace($Parent)) { return }
        $Parent = Normalize-MetadataValue $Parent
        if ($lib.subcategories.PSObject.Properties.Name -notcontains $Parent) { $lib.subcategories | Add-Member NoteProperty $Parent @() -Force }
        $existing = @(ConvertTo-Array $lib.subcategories.$Parent)
        if (-not ($existing | Where-Object { $_.ToString().Trim().ToLowerInvariant() -eq $clean.ToLowerInvariant() })) {
            $lib.subcategories.$Parent = @($existing + $clean | Sort-Object -Unique)
            Save-Library $lib
        }
    }
    else {
        if ($lib.PSObject.Properties.Name -notcontains $Section) { $lib | Add-Member NoteProperty $Section @() -Force }
        $existing = @(ConvertTo-Array $lib.$Section)
        if (-not ($existing | Where-Object { $_.ToString().Trim().ToLowerInvariant() -eq $clean.ToLowerInvariant() })) {
            $lib.$Section = @($existing + $clean | Sort-Object -Unique)
            Save-Library $lib
        }
    }
}
function Remove-LibraryValue {
    param([string]$Section,[int]$Index,[string]$Parent='')
    $lib = Get-Library
    if ($Section -eq 'subcategories') {
        $vals = @(ConvertTo-Array $lib.subcategories.$Parent)
        if ($Index -lt 0 -or $Index -ge $vals.Count) { return }
        $new = @()
        for ($i=0; $i -lt $vals.Count; $i++) { if ($i -ne $Index) { $new += $vals[$i] } }
        $lib.subcategories.$Parent = $new
        Save-Library $lib
    }
    else {
        $vals = @(ConvertTo-Array $lib.$Section)
        if ($Index -lt 0 -or $Index -ge $vals.Count) { return }
        $new = @()
        for ($i=0; $i -lt $vals.Count; $i++) { if ($i -ne $Index) { $new += $vals[$i] } }
        $lib.$Section = $new
        Save-Library $lib
    }
}
function Show-CoreList {
    param([string]$Section,[string]$Title)
    while ($true) {
        Show-Header "CORE $Title (READ ONLY)"
        $core = Get-Core
        $vals = @()
        if ($core.PSObject.Properties.Name -contains $Section) { $vals = @(ConvertTo-Array $core.$Section) }
        if ($vals.Count -eq 0) { Write-Host "No Core defaults found for this section." -ForegroundColor Yellow }
        else { for ($i=0; $i -lt $vals.Count; $i++) { Write-Host "[$($i+1)] $($vals[$i])" } }
        Write-Host ""
        Write-Host "Core entries are protected and cannot be edited here." -ForegroundColor DarkGray
        Write-Host "[B] Back"
        $c = (Read-Host "Selection").Trim().ToUpper()
        if ($c -eq 'B') { return }
    }
}
function Show-UserList {
    param([string]$Section,[string]$Title)
    while ($true) {
        Show-Header "USER $Title (EDITABLE)"
        $lib = Get-Library
        $vals = @()
        if ($lib.PSObject.Properties.Name -contains $Section) { $vals = @(ConvertTo-Array $lib.$Section) }
        if ($vals.Count -eq 0) { Write-Host "No editable/custom entries." -ForegroundColor DarkGray }
        else { for ($i=0; $i -lt $vals.Count; $i++) { Write-Host "[$($i+1)] $($vals[$i])" } }
        Write-Host ""
        Write-Host "[A] Add"
        Write-Host "[D] Delete"
        Write-Host "[B] Back"
        $c = (Read-Host "Selection").Trim().ToUpper()
        if ($c -eq 'B') { return }
        if ($c -eq 'A') { Add-LibraryValue $Section (Read-Host "Value") }
        if ($c -eq 'D') {
            $n = 0
            if ([int]::TryParse((Read-Host "Entry number"),[ref]$n)) { Remove-LibraryValue $Section ($n-1) }
        }
    }
}
function Show-CoreSubcategories {
    while ($true) {
        Show-Header 'CORE SUBCATEGORIES (READ ONLY)'
        $core = Get-Core
        $pairs = @()
        try { foreach ($p in $core.subcategories.PSObject.Properties) { foreach ($v in @(ConvertTo-Array $p.Value)) { $pairs += [pscustomobject]@{Category=$p.Name; Value=$v} } } } catch {}
        if ($pairs.Count -eq 0) { Write-Host "No Core subcategories found." -ForegroundColor Yellow }
        else { for ($i=0; $i -lt $pairs.Count; $i++) { Write-Host "[$($i+1)] $($pairs[$i].Category) -> $($pairs[$i].Value)" } }
        Write-Host ""
        Write-Host "Core entries are protected and cannot be edited here." -ForegroundColor DarkGray
        Write-Host "[B] Back"
        if ((Read-Host "Selection").Trim().ToUpper() -eq 'B') { return }
    }
}
function Show-UserSubcategories {
    while ($true) {
        Show-Header 'USER SUBCATEGORIES (EDITABLE)'
        $lib = Get-Library
        $pairs = @()
        try { foreach ($p in $lib.subcategories.PSObject.Properties) { foreach ($v in @(ConvertTo-Array $p.Value)) { $pairs += [pscustomobject]@{Category=$p.Name; Value=$v} } } } catch {}
        if ($pairs.Count -eq 0) { Write-Host "No editable/custom subcategories." -ForegroundColor DarkGray }
        else { for ($i=0; $i -lt $pairs.Count; $i++) { Write-Host "[$($i+1)] $($pairs[$i].Category) -> $($pairs[$i].Value)" } }
        Write-Host ""
        Write-Host "[A] Add"
        Write-Host "[D] Delete"
        Write-Host "[B] Back"
        $c = (Read-Host "Selection").Trim().ToUpper()
        if ($c -eq 'B') { return }
        if ($c -eq 'A') {
            $cat = Normalize-MetadataValue (Read-Host "Parent category")
            $val = Read-Host "Subcategory"
            Add-LibraryValue 'subcategories' $val $cat
        }
        if ($c -eq 'D') {
            $n = 0
            if ([int]::TryParse((Read-Host "Entry number"),[ref]$n) -and $n -ge 1 -and $n -le $pairs.Count) {
                Remove-LibraryValue 'subcategories' ($n-1) $pairs[$n-1].Category
            }
        }
    }
}
function Show-SplitManager {
    param([string]$Section,[string]$Title)
    while ($true) {
        Show-Header $Title
        Write-Host "[C] Core (Read Only)"
        Write-Host "[U] User (Editable)"
        Write-Host "[B] Back"
        $c = (Read-Host "Selection").Trim().ToUpper()
        switch ($c) {
            'C' { if ($Section -eq 'subcategories') { Show-CoreSubcategories } else { Show-CoreList $Section $Title } }
            'U' { if ($Section -eq 'subcategories') { Show-UserSubcategories } else { Show-UserList $Section $Title } }
            'B' { return }
        }
    }
}

function New-RepositoryFormatCore {
    [ordered]@{
        types = @(
            [ordered]@{ type='Software'; formats=@('EXE','MSI'); extensions=@('.exe','.msi') },
            [ordered]@{ type='Packages'; formats=@('APPX','APPXBUNDLE','MSIX','MSIXBUNDLE'); extensions=@('.appx','.appxbundle','.msix','.msixbundle') },
            [ordered]@{ type='Scripts'; formats=@('PS1'); extensions=@('.ps1') },
            [ordered]@{ type='Documents'; formats=@('TXT','MD','PDF','RTF','DOC','DOCX','DOT','DOTX','XLS','XLSX','XLSM','XLTX','CSV','TSV','ODS','PPT','PPTX','PPTM','POTX'); extensions=@('.txt','.md','.pdf','.rtf','.doc','.docx','.dot','.dotx','.xls','.xlsx','.xlsm','.xltx','.csv','.tsv','.ods','.ppt','.pptx','.pptm','.potx') },
            [ordered]@{ type='Archives'; formats=@('ZIP','7Z','RAR','CAB','TAR','GZ','BZ2','XZ','TGZ','TBZ','TXZ','TAR.GZ','TAR.BZ2','TAR.XZ'); extensions=@('.zip','.7z','.rar','.cab','.tar','.gz','.bz2','.xz','.tgz','.tbz','.txz','.tar.gz','.tar.bz2','.tar.xz') },
            [ordered]@{ type='Disk Images'; formats=@('ISO','IMG','WIM','ESD','FFU','VHD','VHDX'); extensions=@('.iso','.img','.wim','.esd','.ffu','.vhd','.vhdx') }
        )
    }
}
function New-RepositoryFormatLibrary { [ordered]@{ learned_formats=@() } }
function Ensure-RepositoryFormatLibraries {
    if (-not (Test-Path $RepositoryFormatsCorePath)) { Save-JsonFile $RepositoryFormatsCorePath (New-RepositoryFormatCore) }
    if (-not (Test-Path $RepositoryFormatsLibraryPath)) { Save-JsonFile $RepositoryFormatsLibraryPath (New-RepositoryFormatLibrary) }
}
function Normalize-ExtensionValue {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $v = $Value.Trim().ToLowerInvariant()
    if (-not $v.StartsWith('.')) { $v = ".$v" }
    return $v
}
function Show-RepositoryFormats {
    Ensure-RepositoryFormatLibraries
    while ($true) {
        Show-Header 'REPOSITORY FORMATS'
        Write-Host 'Core formats are protected. User formats are learned/custom.' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host 'Type            Formats'
        Write-Host '----            --------------------------'
        Write-Host 'Software        EXE, MSI'
        Write-Host 'Packages        APPX, APPXBUNDLE, MSIX, MSIXBUNDLE'
        Write-Host 'Scripts         PS1'
        Write-Host 'Documents       TXT, MD, PDF, RTF, DOC, DOCX, XLSX, PPTX...'
        Write-Host 'Archives        ZIP, 7Z, RAR, CAB, TAR, GZ, BZ2, XZ...'
        Write-Host 'Disk Images     ISO, IMG, WIM, ESD, FFU, VHD, VHDX'
        Write-Host ''
        Write-Host '[C] Core Formats (Read Only)'
        Write-Host '[U] User Learned Formats'
        Write-Host '[A] Add Learned Format'
        Write-Host '[D] Delete Learned Format'
        Write-Host '[B] Back'
        $c=(Read-Host 'Selection').Trim().ToUpper()
        switch ($c) {
            'C' { Show-CoreRepositoryFormats }
            'U' { Show-UserRepositoryFormats }
            'A' { Add-UserRepositoryFormat }
            'D' { Delete-UserRepositoryFormat }
            'B' { return }
        }
    }
}
function Show-CoreRepositoryFormats {
    Ensure-RepositoryFormatLibraries
    Show-Header 'CORE REPOSITORY FORMATS (READ ONLY)'
    $Core = Load-JsonFile $RepositoryFormatsCorePath (New-RepositoryFormatCore)
    foreach ($T in @($Core.types)) { Write-Host ("{0,-15} {1}" -f $T.type, (@($T.formats) -join ', ')) }
    Write-Host ''
    Write-Host 'Core formats cannot be deleted here.' -ForegroundColor DarkGray
    Pause-Return
}
function Show-UserRepositoryFormats {
    Ensure-RepositoryFormatLibraries
    Show-Header 'USER LEARNED REPOSITORY FORMATS'
    $Lib = Load-JsonFile $RepositoryFormatsLibraryPath (New-RepositoryFormatLibrary)
    $Items=@($Lib.learned_formats)
    if ($Items.Count -eq 0) { Write-Host 'No learned/custom formats yet.' -ForegroundColor DarkGray }
    else { for ($i=0; $i -lt $Items.Count; $i++) { Write-Host "[$($i+1)] $($Items[$i].extension) -> $($Items[$i].type) ($($Items[$i].format))" } }
    Pause-Return
}
function Add-UserRepositoryFormat {
    Ensure-RepositoryFormatLibraries
    Show-Header 'ADD USER REPOSITORY FORMAT'
    $Ext = Normalize-ExtensionValue (Read-Host 'Extension, example .foo or foo')
    if ([string]::IsNullOrWhiteSpace($Ext)) { return }
    Write-Host ''
    Write-Host '[1] Software'
    Write-Host '[2] Packages'
    Write-Host '[3] Scripts'
    Write-Host '[4] Documents'
    Write-Host '[5] Archives'
    Write-Host '[6] Disk Images'
    Write-Host '[7] Custom'
    $Choice=(Read-Host 'Treat as').Trim()
    $Type = switch ($Choice) { '1' {'Software'} '2' {'Packages'} '3' {'Scripts'} '4' {'Documents'} '5' {'Archives'} '6' {'Disk Images'} '7' {(Read-Host 'Custom type')} default {'Documents'} }
    $Format = (Read-Host 'Format label, example FOO').Trim().ToUpperInvariant()
    if ([string]::IsNullOrWhiteSpace($Format)) { $Format = $Ext.TrimStart('.').ToUpperInvariant() }
    $Lib = Load-JsonFile $RepositoryFormatsLibraryPath (New-RepositoryFormatLibrary)
    $Items=@($Lib.learned_formats | Where-Object { $_.extension -ne $Ext })
    $Items += [ordered]@{ extension=$Ext; type=$Type; folder=$Type; format=$Format; learned=(Get-Date).ToString('s') }
    $Lib.learned_formats=@($Items)
    Save-JsonFile $RepositoryFormatsLibraryPath $Lib
    Write-Host 'Learned repository format saved.' -ForegroundColor Green
    Pause-Return
}
function Delete-UserRepositoryFormat {
    Ensure-RepositoryFormatLibraries
    while ($true) {
        Show-Header 'DELETE LEARNED REPOSITORY FORMAT'
        $Lib = Load-JsonFile $RepositoryFormatsLibraryPath (New-RepositoryFormatLibrary)
        $Items = @($Lib.learned_formats)
        if ($Items.Count -eq 0) {
            Write-Host 'No learned/custom formats to delete.' -ForegroundColor DarkGray
            Pause-Return
            return
        }
        $Map=@{}
        for ($i=0; $i -lt $Items.Count; $i++) {
            $n=$i+1
            Write-Host "[$n] $($Items[$i].extension) -> $($Items[$i].type) ($($Items[$i].format))"
            $Map[[string]$n]=$Items[$i]
        }
        Write-Host ''
        Write-Host '[B] Back'
        $Choice=(Read-Host 'Select learned format to delete').Trim().ToUpperInvariant()
        if ($Choice -eq 'B') { return }
        if (-not $Map.ContainsKey($Choice)) { continue }
        $Target=$Map[$Choice]
        $Ok=(Read-Host "Delete $($Target.extension) -> $($Target.type)? Y/N").Trim().ToUpperInvariant()
        if ($Ok -notin @('Y','YES')) { continue }
        $Lib.learned_formats = @($Items | Where-Object { $_.extension -ne $Target.extension })
        Save-JsonFile $RepositoryFormatsLibraryPath $Lib
        Write-Host 'Learned format deleted.' -ForegroundColor Green
        Pause-Return
        return
    }
}


function New-DetectionLibrary {
    [ordered]@{ user_detections = @() }
}
function Ensure-DetectionLibraries {
    if (-not (Test-Path $DetectionCorePath)) {
        $Core = [ordered]@{ detections = @(
            [ordered]@{ name='.NET Project'; indicators=@('.sln','.csproj','.vbproj','.fsproj'); category='Development Tools'; subcategory='.NET'; description='Detects Microsoft .NET and Visual Studio projects.' },
            [ordered]@{ name='Python Project'; indicators=@('pyproject.toml','setup.py','requirements.txt','Pipfile'); category='Development Tools'; subcategory='Python'; description='Detects Python projects.' },
            [ordered]@{ name='NodeJS Project'; indicators=@('package.json','package-lock.json','yarn.lock','pnpm-lock.yaml'); category='Development Tools'; subcategory='NodeJS'; description='Detects NodeJS and JavaScript projects.' },
            [ordered]@{ name='PowerShell Project'; indicators=@('.ps1','.psm1','.psd1'); category='Development Tools'; subcategory='PowerShell'; description='Detects PowerShell scripts and modules.' },
            [ordered]@{ name='Photoshop Project'; indicators=@('.psd','.psb'); category='Development Tools'; subcategory='Photoshop'; description='Detects Photoshop design files.' },
            [ordered]@{ name='Blender Project'; indicators=@('.blend'); category='Development Tools'; subcategory='Blender'; description='Detects Blender 3D project files.' },
            [ordered]@{ name='CAD / 3D Project'; indicators=@('.dwg','.dxf','.stl','.3mf'); category='Development Tools'; subcategory='CAD / 3D'; description='Detects CAD and 3D model files.' }
        ) }
        Save-JsonFile $DetectionCorePath $Core
    }
    if (-not (Test-Path $DetectionLibraryPath)) { Save-JsonFile $DetectionLibraryPath (New-DetectionLibrary) }
}
function Show-CoreDetections {
    Ensure-DetectionLibraries
    Show-Header 'CORE DETECTIONS (READ ONLY)'
    $Core = Load-JsonFile $DetectionCorePath ([ordered]@{detections=@()})
    $Items = @($Core.detections)
    if ($Items.Count -eq 0) { Write-Host 'No core detections found.' -ForegroundColor Yellow }
    foreach ($Item in $Items) {
        Write-Host $Item.name -ForegroundColor Cyan
        Write-Host ("  Indicators : {0}" -f (@($Item.indicators) -join ', '))
        Write-Host ("  Category   : {0} / {1}" -f $Item.category,$Item.subcategory)
        if ($Item.description) { Write-Host ("  Notes      : {0}" -f $Item.description) }
        Write-Host ''
    }
    Pause-Return
}
function Show-UserDetections {
    Ensure-DetectionLibraries
    Show-Header 'USER LEARNED DETECTIONS'
    $Lib = Load-JsonFile $DetectionLibraryPath (New-DetectionLibrary)
    $Items = @($Lib.user_detections)
    if ($Items.Count -eq 0) { Write-Host 'No user detections yet.' -ForegroundColor DarkGray }
    for ($i=0; $i -lt $Items.Count; $i++) {
        $Item=$Items[$i]
        Write-Host ("[{0}] {1}" -f ($i+1),$Item.name) -ForegroundColor Cyan
        Write-Host ("    Indicators : {0}" -f (@($Item.indicators) -join ', '))
        Write-Host ("    Category   : {0} / {1}" -f $Item.category,$Item.subcategory)
    }
    Pause-Return
}
function Add-UserDetection {
    Ensure-DetectionLibraries
    Show-Header 'ADD DETECTION RULE'
    Write-Host 'Detection rules identify what an item represents using file names, extensions, or marker files.' -ForegroundColor DarkGray
    Write-Host 'Examples: Photoshop Project = .psd, .psb | Python Project = pyproject.toml, setup.py'
    Write-Host ''
    $Name = (Read-Host 'Detection name').Trim()
    if ([string]::IsNullOrWhiteSpace($Name)) { return }
    $IndicatorsRaw = (Read-Host 'Indicators, comma-separated').Trim()
    $Indicators = @($IndicatorsRaw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($Indicators.Count -eq 0) { Write-Host 'At least one indicator is required.' -ForegroundColor Yellow; Pause-Return; return }
    $Category = (Read-Host 'Suggested category').Trim()
    if ([string]::IsNullOrWhiteSpace($Category)) { $Category='Custom' }
    $Subcategory = (Read-Host 'Suggested subcategory').Trim()
    if ([string]::IsNullOrWhiteSpace($Subcategory)) { $Subcategory=$Name }
    $Description = (Read-Host 'Description').Trim()
    $Lib = Load-JsonFile $DetectionLibraryPath (New-DetectionLibrary)
    $Items = @($Lib.user_detections | Where-Object { $_.name -ne $Name })
    $Items += [ordered]@{ name=$Name; indicators=@($Indicators); category=$Category; subcategory=$Subcategory; description=$Description; learned=(Get-Date).ToString('s') }
    $Lib.user_detections = @($Items)
    Save-JsonLibraryWithBackup -Path $DetectionLibraryPath -Object $Lib -BaseName 'detection.library.json'
    Write-Host 'Detection rule saved.' -ForegroundColor Green
    Pause-Return
}
function Edit-UserDetection {
    Ensure-DetectionLibraries
    $Lib = Load-JsonFile $DetectionLibraryPath (New-DetectionLibrary)
    $Items = @($Lib.user_detections)
    Show-Header 'EDIT DETECTION RULE'
    if ($Items.Count -eq 0) { Write-Host 'No user detections to edit.' -ForegroundColor DarkGray; Pause-Return; return }
    $Map=@{}
    for ($i=0; $i -lt $Items.Count; $i++) { $n=$i+1; $Map[[string]$n]=$Items[$i]; Write-Host "[$n] $($Items[$i].name)" }
    Write-Host '[B] Back'
    $Choice=(Read-Host 'Selection').Trim().ToUpperInvariant()
    if ($Choice -eq 'B' -or -not $Map.ContainsKey($Choice)) { return }
    $Old=$Map[$Choice]
    $Name=(Read-Host "Name [$($Old.name)]").Trim(); if ([string]::IsNullOrWhiteSpace($Name)) { $Name=$Old.name }
    $IndicatorsRaw=(Read-Host "Indicators [$(@($Old.indicators) -join ', ')]").Trim()
    $Indicators=if ([string]::IsNullOrWhiteSpace($IndicatorsRaw)) { @($Old.indicators) } else { @($IndicatorsRaw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    $Category=(Read-Host "Category [$($Old.category)]").Trim(); if ([string]::IsNullOrWhiteSpace($Category)) { $Category=$Old.category }
    $Subcategory=(Read-Host "Subcategory [$($Old.subcategory)]").Trim(); if ([string]::IsNullOrWhiteSpace($Subcategory)) { $Subcategory=$Old.subcategory }
    $Description=(Read-Host "Description [$($Old.description)]").Trim(); if ([string]::IsNullOrWhiteSpace($Description)) { $Description=$Old.description }
    $NewItems=@($Items | Where-Object { $_.name -ne $Old.name })
    $NewItems += [ordered]@{ name=$Name; indicators=@($Indicators); category=$Category; subcategory=$Subcategory; description=$Description; learned=$Old.learned; modified=(Get-Date).ToString('s') }
    $Lib.user_detections=@($NewItems)
    Save-JsonLibraryWithBackup -Path $DetectionLibraryPath -Object $Lib -BaseName 'detection.library.json'
    Write-Host 'Detection rule updated.' -ForegroundColor Green
    Pause-Return
}
function Delete-UserDetection {
    Ensure-DetectionLibraries
    while ($true) {
        Show-Header 'DELETE LEARNED DETECTION'
        $Lib = Load-JsonFile $DetectionLibraryPath (New-DetectionLibrary)
        $Items = @($Lib.user_detections)
        if ($Items.Count -eq 0) { Write-Host 'No learned detections to delete.' -ForegroundColor DarkGray; Pause-Return; return }
        $Map=@{}
        for ($i=0; $i -lt $Items.Count; $i++) { $n=$i+1; $Map[[string]$n]=$Items[$i]; Write-Host "[$n] $($Items[$i].name)" }
        Write-Host '[B] Back'
        $Choice=(Read-Host 'Selection').Trim().ToUpperInvariant()
        if ($Choice -eq 'B') { return }
        if (-not $Map.ContainsKey($Choice)) { continue }
        $Target=$Map[$Choice]
        $Ok=(Read-Host "Delete $($Target.name)? Y/N").Trim().ToUpperInvariant()
        if ($Ok -notin @('Y','YES')) { continue }
        $Lib.user_detections=@($Items | Where-Object { $_.name -ne $Target.name })
        Save-JsonLibraryWithBackup -Path $DetectionLibraryPath -Object $Lib -BaseName 'detection.library.json'
        Write-Host 'Detection rule deleted.' -ForegroundColor Green
        Pause-Return
        return
    }
}
function Show-DetectionLibrary {
    Ensure-DetectionLibraries
    while ($true) {
        Show-Header 'DETECTION LIBRARY'
        Write-Host 'Detects what an item represents using extensions, marker files, or folder contents.' -ForegroundColor DarkGray
        Write-Host 'Used by Repository Scanner, GitHub Puller, Search, Reports, and future tools.' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '[C] Core Detections (Read Only)'
        Write-Host '[U] User Learned Detections'
        Write-Host '[A] Add Detection Rule'
        Write-Host '[E] Edit Learned Detection'
        Write-Host '[D] Delete Learned Detection'
        Write-Host '[B] Back'
        $c=(Read-Host 'Selection').Trim().ToUpperInvariant()
        switch ($c) {
            'C' { Show-CoreDetections }
            'U' { Show-UserDetections }
            'A' { Add-UserDetection }
            'E' { Edit-UserDetection }
            'D' { Delete-UserDetection }
            'B' { return }
        }
    }
}

function Restore-FromPath {
    param([string]$Path,[string]$Name)
    if (-not (Test-Path $Path)) {
        Show-Header 'RESTORE LIBRARY'
        Write-Host "$Name not found." -ForegroundColor Yellow
        Pause-Return
        return
    }
    Show-Header 'RESTORE LIBRARY'
    Write-Host "Restore from: $Name" -ForegroundColor Yellow
    Write-Host "Current library will be backed up first."
    $ok = (Read-Host "Continue? Y/N").Trim().ToUpper()
    if ($ok -in @('Y','YES')) {
        Backup-Library
        Copy-Item $Path $LibraryPath -Force
        Write-Host "Restored." -ForegroundColor Green
        Pause-Return
    }
}
function Restore-FrameworkDefaults {
    Show-Header 'RESTORE FRAMEWORK DEFAULTS'
    Write-Host "This resets the editable user metadata library." -ForegroundColor Yellow
    Write-Host "Core defaults remain protected in metadata.core.json."
    Write-Host "Builders will still show Core defaults plus any future User entries."
    Write-Host ""
    Write-Host "User learned categories, keywords, dependencies, and templates will be cleared."
    $ok = (Read-Host "Continue? Y/N").Trim().ToUpper()
    if ($ok -in @('Y','YES')) {
        Backup-Library
        Save-JsonFile $LibraryPath (New-EmptyLibraryObject)
        Write-Host "Editable metadata library reset to empty defaults." -ForegroundColor Green
        Pause-Return
    }
}
function Show-Recovery {
    while ($true) {
        Show-Header 'LIBRARY RECOVERY'
        Ensure-Library
        $bak = Join-Path $BackupRoot 'metadata.library.bak'
        $prev = Join-Path $BackupRoot 'metadata.library.previous.bak'
        Write-Host "Current : $LibraryPath"
        if (Test-Path $bak) { Write-Host "Backup  : $((Get-Item $bak).LastWriteTime)" } else { Write-Host "Backup  : Missing" -ForegroundColor Yellow }
        if (Test-Path $prev) { Write-Host "Older   : $((Get-Item $prev).LastWriteTime)" } else { Write-Host "Older   : Missing" -ForegroundColor Yellow }
        Write-Host ""
        Write-Host "[1] Restore Previous Backup"
        Write-Host "[2] Restore Older Backup"
        Write-Host "[3] Restore Framework Defaults"
        Write-Host "[4] Create Manual Backup"
        Write-Host "[B] Back"
        $c = (Read-Host "Selection").Trim().ToUpper()
        switch ($c) {
            '1' { Restore-FromPath $bak 'Previous Backup' }
            '2' { Restore-FromPath $prev 'Older Backup' }
            '3' { Restore-FrameworkDefaults }
            '4' { Create-ManualBackup }
            'B' { return }
        }
    }
}

Ensure-Library
while ($true) {
    Show-Header 'METADATA LIBRARY MANAGER'
    Write-Host 'Core defaults are read-only. User entries are editable.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '[1] Categories'
    Write-Host '[2] Subcategories'
    Write-Host '[3] Keywords'
    Write-Host '[4] Dependencies'
    Write-Host '[5] Description Templates'
    Write-Host '------------------------------------------------------------'
    Write-Host '[6] Repository Formats'
    Write-Host '    File format detection and repository sorting.' -ForegroundColor DarkGray
    Write-Host '[7] Detection Library'
    Write-Host '    Detects projects, content, source folders, and custom asset types.' -ForegroundColor DarkGray
    Write-Host '[8] Library Recovery'
    Write-Host '    Recover editable metadata, repository formats, and detection libraries.' -ForegroundColor DarkGray
    Write-Host '[B] Back'
    $choice = (Read-Host 'Selection').Trim().ToUpper()
    switch ($choice) {
        '1' { Show-SplitManager 'categories' 'CATEGORIES' }
        '2' { Show-SplitManager 'subcategories' 'SUBCATEGORIES' }
        '3' { Show-SplitManager 'keywords' 'KEYWORDS' }
        '4' { Show-SplitManager 'dependencies' 'DEPENDENCIES' }
        '5' { Show-SplitManager 'description_templates' 'DESCRIPTION TEMPLATES' }
        '6' { Show-RepositoryFormats }
        '7' { Show-DetectionLibrary }
        '8' { Show-Recovery }
        'B' { return }
    }
}
