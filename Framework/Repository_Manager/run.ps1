# ============================================================
# WINDOWS MODULAR TOOLKIT - REPOSITORY MANAGER
# Framework Edition 2.0 - Build 42B.2
# ============================================================

param(
    [switch]$HelpOnly,
    [switch]$BrowseOnly
)

$ErrorActionPreference = "Continue"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolkitRoot = Resolve-Path (Join-Path $ScriptRoot "..\..")
$ToolkitRoot = $ToolkitRoot.Path

$IncomingRoot = Join-Path $ToolkitRoot "Incoming"
$RepositoryRoot = Join-Path $ToolkitRoot "Repository"
$SoftwareRoot = Join-Path $RepositoryRoot "Software"
$ScriptsRoot = Join-Path $RepositoryRoot "Scripts"
$DocumentsRoot = Join-Path $RepositoryRoot "Documents"
$PackagesRoot = Join-Path $RepositoryRoot "Packages"
$ArchivesRoot = Join-Path $RepositoryRoot "Archives"
$DiskImagesRoot = Join-Path $RepositoryRoot "Disk Images"
$CustomRoot = Join-Path $RepositoryRoot "Custom"
$ConfigRoot = Join-Path $ToolkitRoot "Config"
$LogsRoot = Join-Path $ToolkitRoot "Logs"
$ModulesRoot = Join-Path $ToolkitRoot "Modules"
$DocsRoot = Join-Path $ToolkitRoot "Docs"

$SoftwareCorePath = Join-Path $ConfigRoot "software.core.json"
$SoftwareLibraryPath = Join-Path $ConfigRoot "software.library.json"
$SoftwareRecordsPath = Join-Path $ConfigRoot "software.records.json"
$ScriptRecordsPath = Join-Path $ConfigRoot "script.records.json"
$DocumentRecordsPath = Join-Path $ConfigRoot "document.records.json"
$PackageRecordsPath = Join-Path $ConfigRoot "package.records.json"
$ArchiveRecordsPath = Join-Path $ConfigRoot "archive.records.json"
$DiskImageRecordsPath = Join-Path $ConfigRoot "diskimage.records.json"
$CustomRecordsPath = Join-Path $ConfigRoot "custom.records.json"
$RepositoryFormatsCorePath = Join-Path $ConfigRoot "repository.formats.core.json"
$RepositoryFormatsLibraryPath = Join-Path $ConfigRoot "repository.formats.library.json"
$SoftwareLogPath = Join-Path $LogsRoot "software_deployment_manager.log"
$RepositoryLogPath = Join-Path $LogsRoot "repository.log"
$RepositoryErrorLogPath = Join-Path $LogsRoot "errors.log"

function Show-LocalHeader {
    param([string]$Title)
    Clear-Host
    Write-Host ""
    Write-Host "============================================================"
    Write-Host " $Title"
    Write-Host "============================================================"
    Write-Host ""
}

function Show-RepoContextHeader {
    param($Context)
    if ($null -eq $Context) { return }
    $script:RepoContextPrinted = $false
    function Write-ContextLine([string]$Label, [object]$Value) {
        if ($null -eq $Value) { return }
        $Text = [string]$Value
        if ([string]::IsNullOrWhiteSpace($Text)) { return }
        Write-Host ("{0}:" -f $Label) -ForegroundColor DarkGray
        Write-Host ("  {0}" -f $Text)
        $script:RepoContextPrinted = $true
    }
    $Name = $null; $Detection = $null; $Type = $null; $Category = $null; $Subcategory = $null; $Suggested = $null; $Source = $null
    if ($Context -is [hashtable]) {
        if ($Context.ContainsKey('Name')) { $Name = $Context['Name'] }
        if ($Context.ContainsKey('Detection')) { $Detection = $Context['Detection'] }
        if ($Context.ContainsKey('Type')) { $Type = $Context['Type'] }
        if ($Context.ContainsKey('Category')) { $Category = $Context['Category'] }
        if ($Context.ContainsKey('Subcategory')) { $Subcategory = $Context['Subcategory'] }
        if ($Context.ContainsKey('Suggested')) { $Suggested = $Context['Suggested'] }
        if ($Context.ContainsKey('Source')) { $Source = $Context['Source'] }
    } else {
        if ($Context.PSObject.Properties.Name -contains 'Name') { $Name = $Context.Name }
        if ($Context.PSObject.Properties.Name -contains 'Detection') { $Detection = $Context.Detection }
        if ($Context.PSObject.Properties.Name -contains 'Type') { $Type = $Context.Type }
        if ($Context.PSObject.Properties.Name -contains 'Category') { $Category = $Context.Category }
        if ($Context.PSObject.Properties.Name -contains 'Subcategory') { $Subcategory = $Context.Subcategory }
        if ($Context.PSObject.Properties.Name -contains 'Suggested') { $Suggested = $Context.Suggested }
        if ($Context.PSObject.Properties.Name -contains 'Source') { $Source = $Context.Source }
    }
    Write-ContextLine "Current Item" $Name
    Write-ContextLine "Detection" $Detection
    Write-ContextLine "Type" $Type
    if (-not [string]::IsNullOrWhiteSpace([string]$Category) -and -not [string]::IsNullOrWhiteSpace([string]$Subcategory)) {
        Write-ContextLine "Category" ("{0} / {1}" -f $Category,$Subcategory)
    } elseif (-not [string]::IsNullOrWhiteSpace([string]$Category)) {
        Write-ContextLine "Category" $Category
    }
    Write-ContextLine "Suggested" $Suggested
    Write-ContextLine "Source" $Source
    if ($script:RepoContextPrinted) {
        Write-Host ""
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host ""
    }
}

function New-RepoContextFromRecord {
    param($Record, [string]$FallbackName = "")
    $Name = $FallbackName
    if ($Record -and $Record.PSObject.Properties.Name -contains 'name' -and -not [string]::IsNullOrWhiteSpace([string]$Record.name)) { $Name = [string]$Record.name }
    $Detection = ""
    if ($Record -and $Record.PSObject.Properties.Name -contains 'detection_name') { $Detection = [string]$Record.detection_name }
    $Type = ""
    if ($Record -and $Record.PSObject.Properties.Name -contains 'type') { $Type = [string]$Record.type }
    $Category = ""
    if ($Record -and $Record.PSObject.Properties.Name -contains 'detection_category') { $Category = [string]$Record.detection_category }
    $Subcategory = ""
    if ($Record -and $Record.PSObject.Properties.Name -contains 'detection_subcategory') { $Subcategory = [string]$Record.detection_subcategory }
    $Suggested = ""
    if (-not [string]::IsNullOrWhiteSpace($Category) -and -not [string]::IsNullOrWhiteSpace($Subcategory)) { $Suggested = "$Category / $Subcategory" }
    elseif (-not [string]::IsNullOrWhiteSpace($Category)) { $Suggested = $Category }
    return @{ Name=$Name; Detection=$Detection; Type=$Type; Category=$Category; Subcategory=$Subcategory; Suggested=$Suggested }
}

function Pause-Local {
    Write-Host ""
    Read-Host "Press Enter to continue" | Out-Null
}

function Write-SoftwareLog {
    param([string]$Message)
    if (-not (Test-Path $LogsRoot)) { New-Item -ItemType Directory -Path $LogsRoot -Force | Out-Null }
    Add-Content -Path $SoftwareLogPath -Value ("{0} | {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message) -Encoding UTF8
}

function Write-RepositoryLog {
    param([string]$Message)
    if (-not (Test-Path $LogsRoot)) { New-Item -ItemType Directory -Path $LogsRoot -Force | Out-Null }
    Add-Content -Path $RepositoryLogPath -Value ("{0} | {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message) -Encoding UTF8
}

function Write-RepositoryError {
    param([string]$Context,[string]$Message)
    if (-not (Test-Path $LogsRoot)) { New-Item -ItemType Directory -Path $LogsRoot -Force | Out-Null }
    Add-Content -Path $RepositoryErrorLogPath -Value ("{0} | {1} | {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Context, $Message) -Encoding UTF8
}


function Write-RepositoryImportDebug {
    param([string]$Message)
    if (-not (Test-Path $LogsRoot)) { New-Item -ItemType Directory -Path $LogsRoot -Force | Out-Null }
    $Path = Join-Path $LogsRoot "repository_import_debug.log"
    Add-Content -Path $Path -Value ("{0} | {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message) -Encoding UTF8
}

function Start-RepositoryQaTranscript {
    if (-not (Test-Path $LogsRoot)) { New-Item -ItemType Directory -Path $LogsRoot -Force | Out-Null }
    $Path = Join-Path $LogsRoot "transcript.log"
    try {
        Start-Transcript -Path $Path -Append -ErrorAction Stop | Out-Null
        Write-RepositoryImportDebug "QA transcript started: $Path"
        return $true
    } catch {
        Write-RepositoryError "TRANSCRIPT START" $_.Exception.Message
        return $false
    }
}

function Stop-RepositoryQaTranscript {
    param([bool]$Started)
    if (-not $Started) { return }
    try {
        Stop-Transcript -ErrorAction Stop | Out-Null
        Write-RepositoryImportDebug "QA transcript stopped"
    } catch {
        Write-RepositoryError "TRANSCRIPT STOP" $_.Exception.Message
    }
}

function Write-RepositoryImportException {
    param($Detection, $ErrorRecord)
    $Name = "Unknown Item"
    $SourceName = ""
    $Type = ""
    $Destination = ""
    if ($Detection) {
        if ($Detection.PSObject.Properties.Name -contains 'name') { $Name = $Detection.name }
        if ($Detection.PSObject.Properties.Name -contains 'source_name') { $SourceName = $Detection.source_name }
        if ($Detection.PSObject.Properties.Name -contains 'type') { $Type = $Detection.type }
        if ($Detection.PSObject.Properties.Name -contains 'repository_kind') { $Type = $Detection.repository_kind }
        if ($Detection.PSObject.Properties.Name -contains 'destination') { $Destination = $Detection.destination }
        if ($Detection.PSObject.Properties.Name -contains 'folder') { $Destination = $Detection.folder }
    }
    Write-RepositoryError "IMPORT ERROR" ("Name={0}; Source={1}; Type={2}; Destination={3}; Message={4}" -f $Name,$SourceName,$Type,$Destination,$ErrorRecord.Exception.Message)
    if ($ErrorRecord.ScriptStackTrace) { Write-RepositoryError "IMPORT STACK" $ErrorRecord.ScriptStackTrace }
    Write-Host ""
    Write-Host "[IMPORT ERROR CAPTURED]" -ForegroundColor Red
    Write-Host ("Item: {0}" -f $Name) -ForegroundColor Red
    if ($SourceName) { Write-Host ("Source: {0}" -f $SourceName) -ForegroundColor Red }
    Write-Host $ErrorRecord.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Details saved to Logs\errors.log and Logs\transcript.log" -ForegroundColor Yellow
    Pause-Local
}

function Read-JsonFile {
    param([string]$Path, $Default)
    if (-not (Test-Path $Path)) { return $Default }
    try {
        $Raw = Get-Content -Path $Path -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($Raw)) { return $Default }
        $Data = $Raw | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $Data) { return $Default }
        return $Data
    } catch {
        Write-SoftwareLog "JSON read failed path=$Path error=$($_.Exception.Message)"
        return $Default
    }
}

function Save-JsonFile {
    param([string]$Path, $Data)
    $Folder = Split-Path -Parent $Path
    if (-not (Test-Path $Folder)) { New-Item -ItemType Directory -Path $Folder -Force | Out-Null }
    $Data | ConvertTo-Json -Depth 20 | Set-Content -Path $Path -Encoding UTF8
}

function Get-CoreSoftwareDefaults {
    return [PSCustomObject]@{
        destinations = @("Installers","Portable","Security","Browsers","Utilities","Drivers","Office","Networking","Custom")
        supported_extensions = @(".exe",".msi",".msp",".msu")
        software_types = @("Installer","Bootstrap Installer","MSI Package","Windows Update Package","Portable EXE","Portable Folder","PortableApps Package","Unknown")
        silent_arguments = @(
            [PSCustomObject]@{ name="Quiet install"; value="/quiet /norestart"; description="Common quiet install with no restart" },
            [PSCustomObject]@{ name="Silent install"; value="/silent"; description="Common silent installer switch" },
            [PSCustomObject]@{ name="NSIS silent"; value="/S"; description="Common NSIS silent switch" },
            [PSCustomObject]@{ name="Inno very silent"; value="/VERYSILENT /NORESTART"; description="Common Inno Setup silent switch" },
            [PSCustomObject]@{ name="MSI quiet"; value="/qn /norestart"; description="MSI quiet install" },
            [PSCustomObject]@{ name="MSI basic UI"; value="/qb /norestart"; description="MSI basic UI with no restart" },
            [PSCustomObject]@{ name="MSI verbose log"; value="/qn /norestart /L*v install.log"; description="MSI quiet install with verbose log" }
        )
        name_patterns = @(
            [PSCustomObject]@{ pattern="^7z(?<version>\d{4})-.*\.exe$"; product="7-Zip"; type="Installer"; destination="Utilities" },
            [PSCustomObject]@{ pattern="ChromeSetup.*\.exe$"; product="Google Chrome"; type="Bootstrap Installer"; destination="Browsers" },
            [PSCustomObject]@{ pattern="(?<name>.+)Portable_(?<version>[0-9\.]+)\.paf\.exe$"; product="{name} Portable"; type="PortableApps Package"; destination="Portable" },
            [PSCustomObject]@{ pattern="(?<name>.+)Portable.*\.exe$"; product="{name} Portable"; type="Portable EXE"; destination="Portable" }
        )
    }
}


function Get-CoreRepositoryFormats {
    return [PSCustomObject]@{
        types = @(
            [PSCustomObject]@{ type="Software"; folder="Software"; formats=@("EXE","MSI"); extensions=@(".exe",".msi") },
            [PSCustomObject]@{ type="Packages"; folder="Packages"; formats=@("APPX","APPXBUNDLE","MSIX","MSIXBUNDLE"); extensions=@(".appx",".appxbundle",".msix",".msixbundle") },
            [PSCustomObject]@{ type="Scripts"; folder="Scripts"; formats=@("PS1"); extensions=@(".ps1") },
            [PSCustomObject]@{ type="Documents"; folder="Documents"; formats=@("TXT","MD","PDF","RTF","DOC","DOCX","DOT","DOTX","XLS","XLSX","XLSM","XLTX","CSV","TSV","ODS","PPT","PPTX","PPTM","POTX"); extensions=@(".txt",".md",".pdf",".rtf",".doc",".docx",".dot",".dotx",".xls",".xlsx",".xlsm",".xltx",".csv",".tsv",".ods",".ppt",".pptx",".pptm",".potx") },
            [PSCustomObject]@{ type="Archives"; folder="Archives"; formats=@("ZIP","7Z","RAR","CAB","TAR","GZ","BZ2","XZ","TGZ","TBZ","TXZ","TAR.GZ","TAR.BZ2","TAR.XZ"); extensions=@(".zip",".7z",".rar",".cab",".tar",".gz",".bz2",".xz",".tgz",".tbz",".txz",".tar.gz",".tar.bz2",".tar.xz") },
            [PSCustomObject]@{ type="Disk Images"; folder="Disk Images"; formats=@("ISO","IMG","WIM","ESD","FFU","VHD","VHDX"); extensions=@(".iso",".img",".wim",".esd",".ffu",".vhd",".vhdx") }
        )
    }
}

function Get-RepositoryFormatsLibraryDefault {
    return [PSCustomObject]@{ learned_formats=@() }
}

function Get-RepositoryExtension {
    param([string]$Path)
    $Name = [System.IO.Path]::GetFileName($Path).ToLowerInvariant()
    foreach ($Compound in @('.tar.gz','.tar.bz2','.tar.xz')) {
        if ($Name.EndsWith($Compound)) { return $Compound }
    }
    return ([System.IO.Path]::GetExtension($Path).ToLowerInvariant())
}

function Get-RepositoryFormatEntry {
    param([string]$Extension)
    if ([string]::IsNullOrWhiteSpace($Extension)) { return $null }
    $Ext = $Extension.ToLowerInvariant()
    $Core = Read-JsonFile $RepositoryFormatsCorePath (Get-CoreRepositoryFormats)
    foreach ($T in @($Core.types)) {
        foreach ($E in @($T.extensions)) {
            if ([string]$E -eq $Ext) {
                return [PSCustomObject]@{ type=[string]$T.type; folder=[string]$T.folder; format=($Ext.TrimStart('.')).ToUpperInvariant(); extension=$Ext; source='Core' }
            }
        }
    }
    $Library = Read-JsonFile $RepositoryFormatsLibraryPath (Get-RepositoryFormatsLibraryDefault)
    foreach ($F in @($Library.learned_formats)) {
        if ([string]$F.extension -eq $Ext) {
            return [PSCustomObject]@{ type=[string]$F.type; folder=[string]$F.folder; format=[string]$F.format; extension=$Ext; source='User' }
        }
    }
    return $null
}

function Add-LearnedRepositoryFormat {
    param([string]$Extension,[string]$Type,[string]$Folder,[string]$Format)
    if ([string]::IsNullOrWhiteSpace($Extension)) { return }
    $Ext = $Extension.ToLowerInvariant()
    if (-not $Ext.StartsWith('.')) { $Ext = ".$Ext" }
    if (Get-RepositoryFormatEntry $Ext) { return }
    $Lib = Read-JsonFile $RepositoryFormatsLibraryPath (Get-RepositoryFormatsLibraryDefault)
    $Existing = @($Lib.learned_formats)
    $Existing += [PSCustomObject]@{ extension=$Ext; type=$Type; folder=$Folder; format=$Format.ToUpperInvariant(); learned=(Get-Date).ToString('s') }
    $Lib.learned_formats = @($Existing)
    Save-JsonFile $RepositoryFormatsLibraryPath $Lib
}

function Get-StandardRepositoryTypeNames {
    return @('Software','Packages','Scripts','Documents','Archives','Disk Images','Custom')
}

function Get-LearnedCustomRepositoryTypes {
    $Standard = @(Get-StandardRepositoryTypeNames)
    $Lib = Read-JsonFile $RepositoryFormatsLibraryPath (Get-RepositoryFormatsLibraryDefault)
    $Types = @()
    foreach ($F in @($Lib.learned_formats)) {
        $T = [string]$F.type
        if (-not [string]::IsNullOrWhiteSpace($T) -and ($Standard -notcontains $T)) { $Types += $T }
    }
    return @($Types | Sort-Object -Unique)
}

function Select-CustomRepositoryType {
    while ($true) {
        Show-LocalHeader "CHOOSE CUSTOM REPOSITORY TYPE"
        Write-Host "Use Custom only for asset types that do not fit the protected repository types."
        Write-Host "Protected types already available: Software, Packages, Scripts, Documents, Archives, Disk Images."
        Write-Host ""
        $Types = @(Get-LearnedCustomRepositoryTypes)
        $Map = @{}
        if ($Types.Count -gt 0) {
            Write-Host "Existing Custom Types"
            $I = 1
            foreach ($T in $Types) {
                Write-Host ("[{0}] {1}" -f $I, $T)
                $Map[[string]$I] = $T
                $I++
            }
            Write-Host ""
        } else {
            Write-Host "No learned custom types yet." -ForegroundColor DarkGray
            Write-Host ""
        }
        Write-Host "[N] New Custom Type"
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        if ($Choice -eq 'B') { return $null }
        if ($Map.ContainsKey($Choice)) { return $Map[$Choice] }
        if ($Choice -eq 'N') {
            $New = (Read-Host "New custom type name").Trim()
            if ([string]::IsNullOrWhiteSpace($New)) { continue }
            $Standard = @(Get-StandardRepositoryTypeNames)
            $Conflict = $false
            foreach ($S in $Standard) { if ($S -ieq $New) { $Conflict = $true } }
            if ($Conflict) {
                Write-Host "That is already a protected repository type. Choose it from the main list instead." -ForegroundColor Yellow
                Pause-Local
                continue
            }
            return $New
        }
    }
}

function Select-RepositoryFormatTypeForUnknown {
    param([string]$Extension)
    Show-LocalHeader "ADD LEARNED REPOSITORY FORMAT"
    Write-Host "Unknown extension detected: $Extension" -ForegroundColor Yellow
    Write-Host "Choose how this extension should be treated everywhere in the toolkit."
    Write-Host ""
    Write-Host "[1] Software"
    Write-Host "[2] Packages"
    Write-Host "[3] Scripts"
    Write-Host "[4] Documents"
    Write-Host "[5] Archives"
    Write-Host "[6] Disk Images"
    Write-Host "[7] Custom"
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = (Read-Host "Treat as").Trim().ToUpperInvariant()
    if ($Choice -eq 'B') { return $null }
    $Type = switch ($Choice) {
        '1' { 'Software' }
        '2' { 'Packages' }
        '3' { 'Scripts' }
        '4' { 'Documents' }
        '5' { 'Archives' }
        '6' { 'Disk Images' }
        '7' { Select-CustomRepositoryType }
        default { '' }
    }
    if ([string]::IsNullOrWhiteSpace($Type)) { return $null }
    $Folder = $Type
    $Format = (Read-Host "Format label [$($Extension.TrimStart('.').ToUpperInvariant())]").Trim().ToUpperInvariant()
    if ([string]::IsNullOrWhiteSpace($Format)) { $Format = $Extension.TrimStart('.').ToUpperInvariant() }
    Add-LearnedRepositoryFormat -Extension $Extension -Type $Type -Folder $Folder -Format $Format
    return (Get-RepositoryFormatEntry $Extension)
}

function Get-DetectionFromRepositoryFormatEntry {
    param([System.IO.FileSystemInfo]$Item,$Entry)
    if (-not $Entry) { return $null }
    switch ([string]$Entry.type) {
        'Software' {
            $D = Get-SoftwareDetection $Item
            if ($Entry.source -eq 'User') {
                $D.type = [string]$Entry.format
                $D.destination = 'Software'
                $D | Add-Member -NotePropertyName learned_format -NotePropertyValue $true -Force
                $D | Add-Member -NotePropertyName format -NotePropertyValue ([string]$Entry.format) -Force
            }
            return $D
        }
        'Scripts' { return (Get-ScriptDetection $Item) }
        'Documents' { return (Get-DocumentDetection $Item) }
        'Packages' { return (Get-GenericAssetDetection $Item 'Package') }
        'Archives' { return (Get-GenericAssetDetection $Item 'Archive') }
        'Disk Images' { return (Get-GenericAssetDetection $Item 'Disk Image') }
        default {
            $D = Get-GenericAssetDetection $Item 'Custom'
            $D.type = [string]$Entry.type
            $D.repository_kind = 'Custom'
            $D | Add-Member -NotePropertyName custom_type -NotePropertyValue ([string]$Entry.type) -Force
            $D.folder = [string]$Entry.type
            $D.format = [string]$Entry.format
            return $D
        }
    }
}

function Show-UnknownRepositoryFormatPrompt {
    param([System.IO.FileSystemInfo]$Item)
    if ($Item.PSIsContainer) { return $null }
    $Ext = Get-RepositoryExtension $Item.FullName
    if ([string]::IsNullOrWhiteSpace($Ext)) { return $null }
    Write-Host ("[-] {0}" -f $Item.Name)
    Write-Host ("     Unknown extension detected: {0}" -f $Ext) -ForegroundColor Yellow
    Write-Host "     [A] Add learned format and process this file" -ForegroundColor DarkGray
    Write-Host "     [I] Ignore this file" -ForegroundColor DarkGray
    $Choice = (Read-Host "     Selection [I]").Trim().ToUpperInvariant()
    if ($Choice -ne 'A') { return $null }
    $Entry = Select-RepositoryFormatTypeForUnknown -Extension $Ext
    if (-not $Entry) { return $null }
    Write-Host ("     Learned: {0} -> {1}" -f $Entry.extension, $Entry.type) -ForegroundColor Green
    return (Get-DetectionFromRepositoryFormatEntry -Item $Item -Entry $Entry)
}


function Get-DetectionLibraryEntries {
    $Entries = @()
    foreach ($Path in @((Join-Path $ConfigRoot 'detection.library.core.json'), (Join-Path $ConfigRoot 'detection.library.json'))) {
        if (-not (Test-Path $Path)) { continue }
        try {
            $Data = Get-Content $Path -Raw | ConvertFrom-Json
            if ($Data.PSObject.Properties.Name -contains 'detections') { $Entries += @($Data.detections) }
            if ($Data.PSObject.Properties.Name -contains 'user_detections') { $Entries += @($Data.user_detections) }
        } catch {
            Write-RepositoryError -Context 'Detection Library Load' -Message $_.Exception.Message
        }
    }
    return @($Entries)
}

function Get-ItemDetectionTokens {
    param([System.IO.FileSystemInfo]$Item)
    $Tokens = New-Object System.Collections.Generic.List[string]
    function Add-TokenLocal([string]$Value) {
        if (-not [string]::IsNullOrWhiteSpace($Value)) { [void]$Tokens.Add($Value.ToLowerInvariant()) }
    }
    Add-TokenLocal $Item.Name
    if (-not $Item.PSIsContainer) {
        Add-TokenLocal (Get-RepositoryExtension $Item.FullName)
        Add-TokenLocal ([System.IO.Path]::GetExtension($Item.Name))
    } else {
        foreach ($Child in @(Get-ChildItem -LiteralPath $Item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue | Select-Object -First 500)) {
            Add-TokenLocal $Child.Name
            Add-TokenLocal (Get-RepositoryExtension $Child.FullName)
            Add-TokenLocal ([System.IO.Path]::GetExtension($Child.Name))
        }
    }
    return @($Tokens | Select-Object -Unique)
}

function Test-DetectionIndicatorMatch {
    param([string[]]$Tokens,[string]$Indicator)
    if ([string]::IsNullOrWhiteSpace($Indicator)) { return $false }
    $Needle = $Indicator.Trim().ToLowerInvariant()
    foreach ($Token in $Tokens) {
        if ($Token -eq $Needle) { return $true }
        if ($Needle.StartsWith('.') -and $Token.EndsWith($Needle)) { return $true }
    }
    return $false
}

function Get-DetectionLibraryMatch {
    param([System.IO.FileSystemInfo]$Item)
    $Tokens = @(Get-ItemDetectionTokens $Item)
    foreach ($Rule in @(Get-DetectionLibraryEntries)) {
        $Indicators = @()
        if ($Rule.PSObject.Properties.Name -contains 'indicators') { $Indicators = @($Rule.indicators) }
        foreach ($Indicator in $Indicators) {
            if (Test-DetectionIndicatorMatch -Tokens $Tokens -Indicator ([string]$Indicator)) { return $Rule }
        }
    }
    return $null
}

function Get-DetectionLibraryAssetDetection {
    param([System.IO.FileSystemInfo]$Item,$Rule)
    if (-not $Rule) { return $null }
    $BaseName = if ($Item.PSIsContainer) { $Item.Name } else { [System.IO.Path]::GetFileNameWithoutExtension($Item.Name) }
    $Ext = if ($Item.PSIsContainer) { '<folder>' } else { Get-RepositoryExtension $Item.FullName }
    $Format = 'DETECTION'
    if (-not $Item.PSIsContainer -and -not [string]::IsNullOrWhiteSpace($Ext)) { $Format = $Ext.TrimStart('.').ToUpperInvariant() }
    $DetectionName = [string]$Rule.name
    return [PSCustomObject]@{
        name=(ConvertTo-TitleName $BaseName)
        repository_name=(Get-SafeRepositoryItemName $BaseName)
        type=$DetectionName
        repository_kind='Custom'
        source_path=$Item.FullName
        source_name=$Item.Name
        extension=$Ext
        format=$Format
        folder=$DetectionName
        custom_type=$DetectionName
        detection_name=$DetectionName
        detection_category=([string]$Rule.category)
        detection_subcategory=([string]$Rule.subcategory)
        detection_description=([string]$Rule.description)
        is_folder=$Item.PSIsContainer
        imported=''
    }
}

function Write-DetectionLibraryScanResult {
    param([int]$Index,[System.IO.FileSystemInfo]$Item,$Detection)
    Write-Host ("[{0}] {1}" -f $Index, $Item.Name)
    Write-Host ("     Detection : {0}" -f $Detection.type) -ForegroundColor DarkGray
    if ($Detection.detection_category -or $Detection.detection_subcategory) {
        Write-Host ("     Category  : {0} / {1}" -f $Detection.detection_category,$Detection.detection_subcategory) -ForegroundColor DarkGray
    }
    Write-Host ("     Suggest   : Custom\{0}" -f $Detection.custom_type) -ForegroundColor DarkGray
}


function Test-FolderOnlyKeepFiles {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $true }
    $Items = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue)
    foreach ($Item in $Items) {
        if ($Item.PSIsContainer) { return $false }
        if ($Item.Name -ne '.keep') { return $false }
    }
    return $true
}

function Invoke-RepositoryStructureCleanup {
    # 42D.1: retire legacy ISO repository paths now that ISO is a Disk Image format.
    $LegacyRoots = @(
        (Join-Path $RepositoryRoot 'ISO'),
        (Join-Path $SoftwareRoot 'ISO'),
        (Join-Path $SoftwareRoot 'Archives'),
        (Join-Path $SoftwareRoot 'Packages')
    )
    foreach ($Legacy in $LegacyRoots) {
        if (Test-Path $Legacy) {
            if (Test-FolderOnlyKeepFiles $Legacy) {
                try { Remove-Item -LiteralPath $Legacy -Recurse -Force -ErrorAction Stop } catch { Write-SoftwareLog "Legacy repository cleanup failed path=$Legacy error=$($_.Exception.Message)" }
            }
        }
    }
    # Remove empty pre-created software category folders. Software imports create folders when needed.
    if (Test-Path $SoftwareRoot) {
        foreach ($Child in @(Get-ChildItem -LiteralPath $SoftwareRoot -Directory -Force -ErrorAction SilentlyContinue)) {
            if (Test-FolderOnlyKeepFiles $Child.FullName) {
                try { Remove-Item -LiteralPath $Child.FullName -Recurse -Force -ErrorAction Stop } catch { Write-SoftwareLog "Software folder cleanup failed path=$($Child.FullName) error=$($_.Exception.Message)" }
            }
        }
    }
    foreach ($KeepRoot in @($RepositoryRoot,$SoftwareRoot,$PackagesRoot,$ArchivesRoot,$DiskImagesRoot,$DocumentsRoot,$ScriptsRoot)) {
        if (Test-Path $KeepRoot) {
            $KeepPath = Join-Path $KeepRoot '.keep'
            if (-not (Test-Path $KeepPath)) { New-Item -ItemType File -Path $KeepPath -Force | Out-Null }
        }
    }
}

function Ensure-SoftwareSystem {
    foreach ($Path in @($IncomingRoot,$RepositoryRoot,$SoftwareRoot,$ScriptsRoot,$DocumentsRoot,$PackagesRoot,$ArchivesRoot,$DiskImagesRoot,$ConfigRoot,$LogsRoot,$ModulesRoot,$DocsRoot)) {
        if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    }
    $Core = Get-CoreSoftwareDefaults
    if (-not (Test-Path $SoftwareCorePath)) { Save-JsonFile $SoftwareCorePath $Core }
    if (-not (Test-Path $SoftwareLibraryPath)) { Save-JsonFile $SoftwareLibraryPath ([PSCustomObject]@{ destinations=@(); name_patterns=@(); notes=@() }) }
    if (-not (Test-Path $SoftwareRecordsPath)) { Save-JsonFile $SoftwareRecordsPath @() }
    if (-not (Test-Path $ScriptRecordsPath)) { Save-JsonFile $ScriptRecordsPath @() }
    if (-not (Test-Path $DocumentRecordsPath)) { Save-JsonFile $DocumentRecordsPath @() }
    if (-not (Test-Path $PackageRecordsPath)) { Save-JsonFile $PackageRecordsPath @() }
    if (-not (Test-Path $ArchiveRecordsPath)) { Save-JsonFile $ArchiveRecordsPath @() }
    if (-not (Test-Path $DiskImageRecordsPath)) { Save-JsonFile $DiskImageRecordsPath @() }
    if (-not (Test-Path $RepositoryFormatsCorePath)) { Save-JsonFile $RepositoryFormatsCorePath (Get-CoreRepositoryFormats) }
    if (-not (Test-Path $RepositoryFormatsLibraryPath)) { Save-JsonFile $RepositoryFormatsLibraryPath (Get-RepositoryFormatsLibraryDefault) }
    Invoke-RepositoryStructureCleanup
    Ensure-OfflineDeploymentDocs
}

function Ensure-OfflineDeploymentDocs {
    $DeployDocs = Join-Path $DocsRoot "Software Deployment"
    if (-not (Test-Path $DeployDocs)) { New-Item -ItemType Directory -Path $DeployDocs -Force | Out-Null }
    $Guide = Join-Path $DeployDocs "Software_Deployment_Guide.txt"
    if (-not (Test-Path $Guide)) {
@"
REPOSITORY AND SOFTWARE DEPLOYMENT GUIDE - OFFLINE

Internet is an enhancement. Offline use is a requirement.

Incoming:
  Incoming\

Repository:
  Repository\

Permanent software repository:
  Repository\Software\<Destination>\<Application Name>\

Typical software destinations:
  Installers, Portable, Security, Browsers, Utilities, Drivers, Office, Networking, Custom

Workflow:
  1. Place files or folders in Incoming\.
  2. Open Repository Manager.
  3. Scan Incoming.
  4. Accept the recommendation, choose another destination, or create a custom destination.
  5. Move/import completes before the toolkit continues.
  6. Optionally create a launch/deployment module.

Supported source types:
  EXE, MSI, MSIX, APPX, ISO, IMG, ZIP, 7Z, RAR, TAR, GZ, Portable EXE, Portable Folder, PortableApps Package.

Winget:
  Winget is a remote software source. It does not store software in the local Repository.
  Common commands:
    winget search <name>
    winget list
    winget list --name <name>
    winget install --id <package.id> -e --accept-source-agreements --accept-package-agreements
"@ | Set-Content -Path $Guide -Encoding UTF8
    }
    $Formats = Join-Path $DeployDocs "Supported_Formats.txt"
    if (-not (Test-Path $Formats)) {
@"
SUPPORTED SOFTWARE FORMATS - OFFLINE

Local files:
  .exe, .msi, .msix, .appx, .msixbundle, .appxbundle, .msp, .msu

Disk images:
  .iso, .img

Archives:
  .zip, .7z, .rar, .tar, .gz

Portable applications:
  Single portable EXE
  Extracted portable app folder
  PortableApps .paf.exe package

PowerShell scripts are handled by Module Tool Manager. Batch/CMD scripts can be saved as reference scripts or manually converted:
  .ps1, .bat, .cmd
"@ | Set-Content -Path $Formats -Encoding UTF8
    }
}

function Get-SoftwareCore {
    $Default = Get-CoreSoftwareDefaults
    return (Read-JsonFile $SoftwareCorePath $Default)
}

function Get-SoftwareLibrary {
    return (Read-JsonFile $SoftwareLibraryPath ([PSCustomObject]@{ destinations=@(); name_patterns=@(); notes=@() }))
}

function Save-SoftwareLibrary {
    param($Library)
    Save-JsonFile $SoftwareLibraryPath $Library
}

function Get-SoftwareRecords {
    return @(Read-JsonFile $SoftwareRecordsPath @())
}

function Save-SoftwareRecords {
    param([array]$Records)
    Save-JsonFile $SoftwareRecordsPath @($Records)
}

function Get-ScriptRecords {
    # Script Repository should reflect the live Repository\Scripts folder, not only old imported records.
    # This makes Browse Scripts and Create Module From Script work after manual sorting or Repository Manager processing.
    $SavedRecords = @(Read-JsonFile $ScriptRecordsPath @())
    $Merged = @()
    $Seen = @{}

    foreach ($Record in $SavedRecords) {
        if ($null -eq $Record) { continue }
        $PathValue = ""
        if ($Record.PSObject.Properties.Name -contains 'path') { $PathValue = [string]$Record.path }
        if (-not [string]::IsNullOrWhiteSpace($PathValue)) {
            $Key = $PathValue.Replace('/','\').ToLowerInvariant()
            if (-not $Seen.ContainsKey($Key)) {
                $Seen[$Key] = $true
                $Merged += $Record
            }
        }
    }

    if (Test-Path $ScriptsRoot) {
        $LiveScripts = @(Get-ChildItem -Path $ScriptsRoot -Recurse -File -Filter *.ps1 -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne '.keep' })
        foreach ($File in $LiveScripts) {
            $Rel = $File.FullName.Replace($ToolkitRoot,'').TrimStart('\','/')
            $Key = $Rel.Replace('/','\').ToLowerInvariant()
            if ($Seen.ContainsKey($Key)) { continue }
            $Merged += [PSCustomObject]@{
                name        = ConvertTo-TitleName ([System.IO.Path]::GetFileNameWithoutExtension($File.Name))
                type        = "PowerShell Script"
                path        = $Rel
                source_name = $File.Name
                imported    = "Live Repository Scan"
            }
            $Seen[$Key] = $true
        }
    }

    return @($Merged | Sort-Object name, path)
}

function Save-ScriptRecords {
    param([array]$Records)
    Save-JsonFile $ScriptRecordsPath @($Records)
}

function Get-DocumentRecords {
    return @(Read-JsonFile $DocumentRecordsPath @())
}

function Save-DocumentRecords {
    param([array]$Records)
    Save-JsonFile $DocumentRecordsPath @($Records)
}

function Get-PackageRecords { return @(Read-JsonFile $PackageRecordsPath @()) }
function Save-PackageRecords { param([array]$Records) Save-JsonFile $PackageRecordsPath @($Records) }
function Get-ArchiveRecords { return @(Read-JsonFile $ArchiveRecordsPath @()) }
function Save-ArchiveRecords { param([array]$Records) Save-JsonFile $ArchiveRecordsPath @($Records) }
function Get-DiskImageRecords { return @(Read-JsonFile $DiskImageRecordsPath @()) }
function Save-DiskImageRecords { param([array]$Records) Save-JsonFile $DiskImageRecordsPath @($Records) }
function Get-CustomRecords { return @(Read-JsonFile $CustomRecordsPath @()) }
function Save-CustomRecords { param([array]$Records) Save-JsonFile $CustomRecordsPath @($Records) }


# ============================================================
# MODULE METADATA WIZARD HELPERS
# Used when Script Repository creates a runnable module from a stored script.
# Keeps Script Repository module creation aligned with Add Module Builder behavior.
# ============================================================
$MetadataCorePath = Join-Path $ConfigRoot "metadata.core.json"
$MetadataLibraryPath = Join-Path $ConfigRoot "metadata.library.json"

function Get-DefaultMetadataCore {
    return [PSCustomObject]@{
        categories=@("Diagnostics","Network Tools","Windows Repair","Setup and Install","Printer Tools","Security","Backup and Recovery","User Accounts","Drivers","Software","System Information","Microsoft 365","Custom Tools","Toolkit Management")
        subcategories=[PSCustomObject]@{}
        keywords=@("script","powershell","diagnostic","repair","toolkit","support","automation","report","audit")
        dependencies=@("PowerShell 5.1","PowerShell 7","Administrator Rights","Local Admin Rights","Network Access","Internet Connection","RSAT","Active Directory")
        description_templates=@()
    }
}

function Ensure-MetadataLibraryFiles {
    if (-not (Test-Path $MetadataCorePath)) { Save-JsonFile $MetadataCorePath (Get-DefaultMetadataCore) }
    if (-not (Test-Path $MetadataLibraryPath)) {
        Save-JsonFile $MetadataLibraryPath ([PSCustomObject]@{ categories=@(); subcategories=[PSCustomObject]@{}; keywords=@(); dependencies=@(); description_templates=@() })
    }
}

function Get-MetadataCore {
    Ensure-MetadataLibraryFiles
    return (Read-JsonFile $MetadataCorePath (Get-DefaultMetadataCore))
}

function Get-MetadataLibrary {
    Ensure-MetadataLibraryFiles
    return (Read-JsonFile $MetadataLibraryPath ([PSCustomObject]@{ categories=@(); subcategories=[PSCustomObject]@{}; keywords=@(); dependencies=@(); description_templates=@() }))
}

function Save-MetadataLibrary {
    param($Library)
    Save-JsonFile $MetadataLibraryPath $Library
}

function Normalize-RepoMetadataValue {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    $parts = @()
    foreach ($p in ($Value.Trim() -split '\\s+')) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if ($p -match '^[A-Z0-9]{2,}$') { $parts += $p }
        elseif ($p.Length -le 2) { $parts += $p.ToUpperInvariant() }
        else { $parts += ($p.Substring(0,1).ToUpperInvariant() + $p.Substring(1).ToLowerInvariant()) }
    }
    return ($parts -join ' ')
}

function Add-RepoMetadataValue {
    param([string]$Section, [string]$Value, [string]$Parent = "")
    $Value = Normalize-RepoMetadataValue $Value
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    $Library = Get-MetadataLibrary
    if ($Section -eq "subcategories") {
        if ([string]::IsNullOrWhiteSpace($Parent)) { $Parent = "Custom Tools" }
        if (-not ($Library.PSObject.Properties.Name -contains 'subcategories') -or $null -eq $Library.subcategories) { $Library | Add-Member -NotePropertyName subcategories -NotePropertyValue ([PSCustomObject]@{}) -Force }
        if (-not ($Library.subcategories.PSObject.Properties.Name -contains $Parent)) { $Library.subcategories | Add-Member -NotePropertyName $Parent -NotePropertyValue @() -Force }
        $Current = @($Library.subcategories.$Parent)
        if (($Current | ForEach-Object { $_.ToString().ToLowerInvariant() }) -notcontains $Value.ToLowerInvariant()) { $Library.subcategories.$Parent = @($Current + $Value | Sort-Object -Unique) }
    } else {
        if (-not ($Library.PSObject.Properties.Name -contains $Section) -or $null -eq $Library.$Section) { $Library | Add-Member -NotePropertyName $Section -NotePropertyValue @() -Force }
        $Current = @($Library.$Section)
        if (($Current | ForEach-Object { $_.ToString().ToLowerInvariant() }) -notcontains $Value.ToLowerInvariant()) { $Library.$Section = @($Current + $Value | Sort-Object -Unique) }
    }
    Save-MetadataLibrary $Library
}

function Get-RepoSectionValues {
    param([string]$Section, [string]$Parent = "")
    $Core = Get-MetadataCore
    $Library = Get-MetadataLibrary
    $CoreValues = @()
    $UserValues = @()
    if ($Section -eq "subcategories") {
        if ($Core.subcategories -and $Core.subcategories.PSObject.Properties.Name -contains $Parent) { $CoreValues = @($Core.subcategories.$Parent) }
        if ($Library.subcategories -and $Library.subcategories.PSObject.Properties.Name -contains $Parent) { $UserValues = @($Library.subcategories.$Parent) }
    } else {
        if ($Core.PSObject.Properties.Name -contains $Section) { $CoreValues = @($Core.$Section) }
        if ($Library.PSObject.Properties.Name -contains $Section) { $UserValues = @($Library.$Section) }
    }
    return [PSCustomObject]@{ Core=@($CoreValues | Where-Object { $_ } | Sort-Object -Unique); User=@($UserValues | Where-Object { $_ } | Sort-Object -Unique) }
}

function Read-RepoRequired {
    param([string]$Prompt, [string]$Default = "")
    while ($true) {
        if ([string]::IsNullOrWhiteSpace($Default)) { $value = Read-Host $Prompt }
        else { $value = Read-Host "$Prompt [$Default]"; if ([string]::IsNullOrWhiteSpace($value)) { $value = $Default } }
        if (-not [string]::IsNullOrWhiteSpace($value)) { return $value.Trim() }
        Write-Host "Value required." -ForegroundColor Yellow
    }
}

function Read-RepoYN {
    param([string]$Prompt, [bool]$Default = $false)
    $suffix = if ($Default) { "[Y]" } else { "[N]" }
    while ($true) {
        $raw = (Read-Host "$Prompt (Y/N) $suffix").Trim().ToUpperInvariant()
        if ([string]::IsNullOrWhiteSpace($raw)) { return $Default }
        if ($raw -eq "Y") { return $true }
        if ($raw -eq "N") { return $false }
        Write-Host "Choose Y or N." -ForegroundColor Yellow
    }
}

function Select-RepoMetadataSingleChoice {
    param([string]$Title, [string]$Section, [string]$Parent = "", [string]$Default = "", [switch]$AllowNone, $Context = $null)
    while ($true) {
        Show-LocalHeader $Title
        Show-RepoContextHeader $Context
        if ($Parent) { Write-Host "Category: $Parent" }
        Write-Host "Core defaults are protected. User entries are learned/custom."
        Write-Host ""
        $Values = Get-RepoSectionValues -Section $Section -Parent $Parent
        $Map = @{}
        $Index = 1
        Write-Host "Core choices:"
        if ($Values.Core.Count -eq 0) { Write-Host "  none" -ForegroundColor DarkGray }
        foreach ($v in $Values.Core) { Write-Host ("[{0}] {1}" -f $Index, $v); $Map[[string]$Index] = [string]$v; $Index++ }
        Write-Host ""
        Write-Host "User learned choices:"
        if ($Values.User.Count -eq 0) { Write-Host "  none yet" -ForegroundColor DarkGray }
        foreach ($v in $Values.User) { Write-Host ("[{0}] {1}" -f $Index, $v); $Map[[string]$Index] = [string]$v; $Index++ }
        Write-Host ""
        if ($AllowNone) { Write-Host "[N] None" }
        Write-Host "[C] Custom"
        if ($Default) { Write-Host ("[Enter] {0}" -f $Default) }
        Write-Host "[B] Back"
        $raw = (Read-Host "Selection").Trim()
        if ([string]::IsNullOrWhiteSpace($raw) -and $Default) { return $Default }
        $upper = $raw.ToUpperInvariant()
        if ($upper -eq "B") { return $null }
        if ($AllowNone -and $upper -eq "N") { return "" }
        if ($upper -eq "C") { return (Normalize-RepoMetadataValue (Read-RepoRequired "Custom value")) }
        if ($Map.ContainsKey($raw)) { return $Map[$raw] }
        Write-Host "Invalid selection." -ForegroundColor Yellow
        Pause-Local
    }
}

function Select-RepoMetadataMultipleChoice {
    param([string]$Title, [string]$Section, [array]$Default = @(), [switch]$AllowNone, $Context = $null)
    while ($true) {
        Show-LocalHeader $Title
        Show-RepoContextHeader $Context
        Write-Host "Example: 1,6,13"
        Write-Host "Core defaults are protected. User entries are learned/custom."
        Write-Host ""
        $Values = Get-RepoSectionValues -Section $Section
        $All = @($Values.Core + $Values.User | Where-Object { $_ } | Sort-Object -Unique)
        $Map = @{}
        $Index = 1
        foreach ($v in $All) { Write-Host ("[{0}] {1}" -f $Index, $v); $Map[[string]$Index] = [string]$v; $Index++ }
        if ($All.Count -eq 0) { Write-Host "No known values yet." -ForegroundColor DarkGray }
        Write-Host ""
        if ($AllowNone) { Write-Host "[N] None" }
        Write-Host "[C] Custom"
        if ($Default.Count -gt 0) { Write-Host ("[Enter] Accept suggested: {0}" -f (($Default -join ', '))) }
        Write-Host "[B] Back"
        $raw = (Read-Host "Selection").Trim()
        if ([string]::IsNullOrWhiteSpace($raw) -and $Default.Count -gt 0) { return @($Default) }
        $upper = $raw.ToUpperInvariant()
        if ($upper -eq "B") { return @() }
        if ($AllowNone -and $upper -eq "N") { return @() }
        if ($upper -eq "C") {
            $custom = Read-RepoRequired "Custom values comma-separated"
            return @($custom -split ',' | ForEach-Object { Normalize-RepoMetadataValue $_ } | Where-Object { $_ })
        }
        $chosen = @()
        foreach ($part in ($raw -split ',')) {
            $p = $part.Trim()
            if ($Map.ContainsKey($p)) { $chosen += $Map[$p] }
        }
        if ($chosen.Count -gt 0) { return @($chosen | Sort-Object -Unique) }
        Write-Host "No valid selections." -ForegroundColor Yellow
        Pause-Local
    }
}

function Get-RepoAutoKeywords {
    param([string]$Name, [string]$Description, [string]$Category, [string]$Subcategory)
    $words = @()
    foreach ($part in @($Name,$Description,$Category,$Subcategory,"script","powershell")) {
        foreach ($w in ($part -split '[^a-zA-Z0-9]+')) {
            $lw = $w.Trim().ToLowerInvariant()
            if ($lw.Length -ge 3 -and $lw -notin @('the','and','for','with','this','that','runs','module','tool')) { $words += (Normalize-RepoMetadataValue $lw) }
        }
    }
    return @($words | Sort-Object -Unique | Select-Object -First 10)
}

function Read-ScriptModuleDetails {
    param([string]$SuggestedName, [string]$Header = "SCRIPT MODULE DETAILS", [string]$Intro = "Create a module from the repository script.", $Context = $null)
    if ($null -eq $Context) { $Context = @{ Name=$SuggestedName } }
    elseif ($Context -is [hashtable]) { if (-not $Context.ContainsKey('Name') -or [string]::IsNullOrWhiteSpace([string]$Context['Name'])) { $Context['Name'] = $SuggestedName } }
    Show-LocalHeader $Header
    Show-RepoContextHeader $Context
    Write-Host $Intro
    Write-Host "Framework suggests values where possible. User decides final values."
    Write-Host ""
    $DisplayName = Read-RepoRequired "Module display name" $SuggestedName
    if ($Context -is [hashtable]) { $Context['Name'] = $DisplayName }
    $SuggestedCategory = "Custom Tools"
    if ($Context -is [hashtable] -and $Context.ContainsKey('Category') -and -not [string]::IsNullOrWhiteSpace([string]$Context['Category'])) { $SuggestedCategory = [string]$Context['Category'] }
    $Category = Select-RepoMetadataSingleChoice -Title "Choose Category" -Section "categories" -Default $SuggestedCategory -Context $Context
    if ($null -eq $Category) { return $null }
    Add-RepoMetadataValue -Section "categories" -Value $Category
    if ($Context -is [hashtable]) { $Context['Category'] = $Category }
    $SuggestedSubcategory = ""
    if ($Context -is [hashtable] -and $Context.ContainsKey('Subcategory') -and -not [string]::IsNullOrWhiteSpace([string]$Context['Subcategory'])) { $SuggestedSubcategory = [string]$Context['Subcategory'] }
    $Subcategory = Select-RepoMetadataSingleChoice -Title "Choose Subcategory" -Section "subcategories" -Parent $Category -Default $SuggestedSubcategory -AllowNone -Context $Context
    if ($null -eq $Subcategory) { return $null }
    if ($Subcategory) { Add-RepoMetadataValue -Section "subcategories" -Parent $Category -Value $Subcategory }
    if ($Context -is [hashtable]) { $Context['Subcategory'] = $Subcategory; if ($Subcategory) { $Context['Suggested'] = "$Category / $Subcategory" } else { $Context['Suggested'] = $Category } }
    $SuggestedDescription = "Runs the $DisplayName module."
    Write-Host ""
    Write-Host "Suggested description:" -ForegroundColor Yellow
    Write-Host "  $SuggestedDescription"
    $descChoice = (Read-Host "Press Enter to accept, or C for custom").Trim().ToUpperInvariant()
    if ($descChoice -eq "C") { $Description = Read-RepoRequired "Custom description" } else { $Description = $SuggestedDescription }
    Add-RepoMetadataValue -Section "description_templates" -Value $Description
    while ($true) {
        $riskRaw = (Read-Host "Risk [S] Safe  [M] Moderate  [D] Dangerous").Trim().ToUpperInvariant()
        if ([string]::IsNullOrWhiteSpace($riskRaw)) { $riskRaw = "M" }
        if ($riskRaw -eq "S") { $Risk = "Safe"; break }
        if ($riskRaw -eq "M") { $Risk = "Moderate"; break }
        if ($riskRaw -eq "D") { $Risk = "Dangerous"; break }
        Write-Host "Choose S, M, or D." -ForegroundColor Yellow
    }
    $Admin = Read-RepoYN "Requires admin" $false
    $SupportsLogs = Read-RepoYN "Supports logs" $false
    $SupportsExport = Read-RepoYN "Supports export" $false
    $KeywordDefault = Get-RepoAutoKeywords -Name $DisplayName -Description $Description -Category $Category -Subcategory $Subcategory
    $Keywords = Select-RepoMetadataMultipleChoice -Title "Choose Common Keywords" -Section "keywords" -Default $KeywordDefault -Context $Context
    foreach ($kw in $Keywords) { Add-RepoMetadataValue -Section "keywords" -Value $kw }
    $Dependencies = Select-RepoMetadataMultipleChoice -Title "Choose Dependencies" -Section "dependencies" -Default @("PowerShell 5.1") -AllowNone -Context $Context
    foreach ($dep in $Dependencies) { Add-RepoMetadataValue -Section "dependencies" -Value $dep }
    return [PSCustomObject]@{
        DisplayName=$DisplayName
        FolderName=(New-ModuleNameSafe $DisplayName)
        Category=$Category
        Subcategory=$Subcategory
        Description=$Description
        Risk=$Risk
        RequiresAdmin=$Admin
        SupportsLogs=$SupportsLogs
        SupportsExport=$SupportsExport
        Keywords=@($Keywords)
        Dependencies=@($Dependencies)
    }
}

function Test-IsScriptCandidate {
    param([System.IO.FileSystemInfo]$Item)
    if ($Item.PSIsContainer) { return $false }
    $Ext = Get-RepositoryExtension $Item.FullName
    if ($Ext -eq ".ps1") { return $true }
    $Entry = Get-RepositoryFormatEntry $Ext
    return ($Entry -and $Entry.type -eq "Scripts")
}

function Get-IncomingScriptItems {
    Ensure-SoftwareSystem
    if (-not (Test-Path $IncomingRoot)) { return @() }
    return @(Get-ChildItem -Path $IncomingRoot -Recurse -File -Filter *.ps1 -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne '.keep' -and $_.Name -notlike '*.json' } |
        Sort-Object FullName -Unique)
}

function Test-IsReferenceScriptCandidate {
    param([System.IO.FileSystemInfo]$Item)
    if ($Item.PSIsContainer) { return $false }
    $Ext = [System.IO.Path]::GetExtension($Item.FullName).ToLowerInvariant()
    return ($Ext -eq ".bat" -or $Ext -eq ".cmd")
}

function Get-ScriptDetection {
    param([System.IO.FileSystemInfo]$Item)
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($Item.FullName)

    # Display names may be friendly, but repository folder names should stay stable.
    # Example:
    #   UpdateCustomset.ps1
    #   Display suggestion: Update Customset
    #   Repository folder:  UpdateCustomset
    $Name = ConvertTo-TitleName $BaseName
    $RepositoryName = Get-SafeRepositoryItemName $BaseName

    return [PSCustomObject]@{
        name=$Name
        repository_name=$RepositoryName
        type="PowerShell Script"
        source_path=$Item.FullName
        source_name=$Item.Name
        extension=[System.IO.Path]::GetExtension($Item.FullName).ToLowerInvariant()
        imported=""
    }
}

function Import-DetectedScript {
    param($Detection)
    $SafeName = Get-SafeFolderName $Detection.repository_name
    $TargetFolder = Join-Path $ScriptsRoot $SafeName
    $TargetPath = Join-Path $TargetFolder $Detection.source_name
    Show-LocalHeader "IMPORT SCRIPT"
    Write-Host "Script:"
    Write-Host "  $($Detection.name)"
    Write-Host "Source:"
    Write-Host "  $($Detection.source_path)"
    Write-Host "Destination:"
    Write-Host "  $TargetPath"
    Write-Host ""
    Write-Host "[A] Import Script"
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
    if ($Choice -ne "A") { return $null }
    try {
        if (-not (Test-Path $TargetFolder)) { New-Item -ItemType Directory -Path $TargetFolder -Force | Out-Null }
        Move-Item -LiteralPath $Detection.source_path -Destination $TargetPath -Force
    } catch {
        Write-Host "[ERROR] Script import failed: $($_.Exception.Message)" -ForegroundColor Red
        Pause-Local
        return $null
    }
    $Record = [PSCustomObject]@{
        name=$Detection.name
        type=$Detection.type
        path=$TargetPath.Replace($ToolkitRoot,'').TrimStart('\','/')
        source_name=$Detection.source_name
        imported=(Get-Date).ToString("s")
    }
    $Records = @(Get-ScriptRecords)
    $Records += $Record
    Save-ScriptRecords $Records
    Show-LocalHeader "SCRIPT IMPORT COMPLETE"
    Write-Host "Script:"
    Write-Host "  $($Detection.name)"
    Write-Host "Source:"
    Write-Host "  $($Detection.source_path)"
    Write-Host "Repository Path:"
    Write-Host "  $($Record.path)"
    Write-Host "Action:"
    Write-Host "  Imported successfully"
    return $Record
}

function Create-ModuleFromScriptRecord {
    param($Record)
    if ($null -eq $Record) { return }

    $Context = New-RepoContextFromRecord -Record $Record -FallbackName $Record.name
    $Details = Read-ScriptModuleDetails -SuggestedName $Record.name -Context $Context
    if ($null -eq $Details) { return }

    $ModuleName = $Details.DisplayName
    $FolderName = $Details.FolderName
    $ModulePath = Join-Path $ModulesRoot $FolderName
    if (-not (Test-Path $ModulePath)) { New-Item -ItemType Directory -Path $ModulePath -Force | Out-Null }

    $PSPath = Join-Path $ModulePath "run.ps1"
    $BatPath = Join-Path $ModulePath "run.bat"
    $JsonPath = Join-Path $ModulePath "tool.json"
    $RelativeScriptPath = $Record.path

@"
# ============================================================
# WINDOWS MODULAR TOOLKIT
# $ModuleName
# Repository-linked script module
# ============================================================

`$ToolkitRoot = Resolve-Path "`$PSScriptRoot\..\.."
`$RepositoryScript = Join-Path `$ToolkitRoot "$RelativeScriptPath"

if (-not (Test-Path `$RepositoryScript)) {
    Write-Host "[ERROR] Repository script not found:" -ForegroundColor Red
    Write-Host "  `$RepositoryScript"
    Write-Host ""
    Read-Host "Press Enter to continue" | Out-Null
    return
}

& `$RepositoryScript
"@ | Set-Content -Path $PSPath -Encoding UTF8

@"
@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1"
set "TOOLKIT_MODULE_EXITCODE=%ERRORLEVEL%"

REM If launched from inside the toolkit, the framework pauses after return.
REM If double-clicked or run directly, pause here so output stays visible.
if /I not "%TOOLKIT_LAUNCHED%"=="1" (
    echo.
    pause
)

endlocal & exit /b %TOOLKIT_MODULE_EXITCODE%
"@ | Set-Content -Path $BatPath -Encoding ASCII

    $Tool = [PSCustomObject]@{
        name=$Details.DisplayName
        category=$Details.Category
        subcategory=$Details.Subcategory
        description=$Details.Description
        keywords=@($Details.Keywords)
        risk=$Details.Risk
        requires_admin=$Details.RequiresAdmin
        supports_logs=$Details.SupportsLogs
        supports_export=$Details.SupportsExport
        entry="run.bat"
        dependencies=@($Details.Dependencies)
        hidden=$false
        source_type="script_repository"
        script_path=$Record.path
    }
    $Tool | ConvertTo-Json -Depth 10 | Set-Content -Path $JsonPath -Encoding UTF8

    Show-LocalHeader "MODULE CREATED"
    Write-Host "Module:"
    Write-Host "  $($Details.DisplayName)"
    Write-Host "Module Path:"
    Write-Host "  $ModulePath"
    Write-Host "Repository Script:"
    Write-Host "  $($Record.path)"
    Write-Host ""
    Write-Host "tool.json created with user-selected metadata."
}

function Show-ScriptRepository {
    Ensure-SoftwareSystem
    while ($true) {
        Show-LocalHeader "SCRIPT REPOSITORY"
        Write-Host "Store, organize, review, and convert PowerShell scripts."
        Write-Host ""
        Write-Host "Repository Path:"
        Write-Host "  Repository\Scripts\"
        Write-Host ""
        Write-Host "[1] Browse Scripts"
        Write-Host "    Live-scan Repository\Scripts for PowerShell scripts."
        Write-Host "[2] Import Script From Incoming"
        Write-Host "    Scan Incoming\ and subfolders for .ps1 files."
        Write-Host "[3] Create Module From Script"
        Write-Host "    Create a toolkit module from a Repository\Scripts entry."
        Write-Host "[4] Script Report"
        Write-Host "[5] Open Scripts Repository"
        Write-Host "[6] Script Help"
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        switch ($Choice) {
            "1" { Show-ScriptList }
            "2" { Invoke-ScriptImportWorkflow }
            "3" { Select-ScriptForModule }
            "4" { Show-ScriptReport }
            "5" { Open-PathSafe $ScriptsRoot }
            "6" { Show-ScriptHelp }
            "B" { return }
        }
    }
}

function Invoke-ScriptImportWorkflow {
    Ensure-SoftwareSystem
    $Items = @(Get-IncomingScriptItems)
    Show-LocalHeader "IMPORT SCRIPT FROM INCOMING"
    if ($Items.Count -eq 0) {
        Write-Host "No PowerShell scripts found in Incoming\."
        Write-Host "Supported now: .ps1"
        Pause-Local
        return
    }
    $Map = @{}
    $Index = 1
    foreach ($Item in $Items) {
        $Detection = Get-ScriptDetection $Item
        Write-Host ("[{0}] {1}" -f $Index, $Item.Name)
        Write-Host ("     Detected Name : {0}" -f $Detection.name) -ForegroundColor DarkGray
        $Map[[string]$Index] = $Detection
        $Index++
    }
    Write-Host ""
    Write-Host "[A] Import All Scripts"
    Write-Host "[B] Back"
    $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
    if ($Choice -eq "B") { return }
    $Selections = @()
    if ($Choice -eq "A") { $Selections = @($Map.Keys | Sort-Object {[int]$_}) }
    elseif ($Map.ContainsKey($Choice)) { $Selections = @($Choice) }
    foreach ($Key in $Selections) {
        $Record = Import-DetectedScript $Map[$Key]
        if ($Record) {
            $Create = (Read-Host "Create module from this script now? (Y/N) [Y]").Trim().ToUpperInvariant()
            if ([string]::IsNullOrWhiteSpace($Create) -or $Create -eq "Y") { Create-ModuleFromScriptRecord $Record }
            Pause-Local
        }
    }
}

function Show-ScriptList {
    Ensure-SoftwareSystem
    while ($true) {
        Show-LocalHeader "SCRIPT LIST"
        $Records = @(Get-ScriptRecords)
        if ($Records.Count -eq 0) {
            Write-Host "No scripts imported yet."
            Write-Host "Place .ps1 files in Incoming\ and import them, or manually sort them into Repository\Scripts."
            Pause-Local
            return
        }
        $Map = @{}
        $Index = 1
        foreach ($R in $Records | Sort-Object name) {
            Write-Host ("[{0}] {1}" -f $Index, $R.name)
            Write-Host ("     Type            : {0}" -f $R.type) -ForegroundColor DarkGray
            Write-Host ("     Repository Path : {0}" -f $R.path) -ForegroundColor DarkGray
            $Map[[string]$Index] = $R
            $Index++
        }
        Write-Host ""
        Write-Host "Select script for details, or [B] Back"
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        if ($Choice -eq "B") { return }
        if ($Map.ContainsKey($Choice)) { Show-ScriptDetails $Map[$Choice] }
    }
}

function Show-ScriptDetails {
    param($Record)
    Show-LocalHeader "SCRIPT DETAILS"
    Write-Host "Name:"
    Write-Host "  $($Record.name)"
    Write-Host "Type:"
    Write-Host "  $($Record.type)"
    Write-Host "Repository Path:"
    Write-Host "  $($Record.path)"
    Write-Host "Imported:"
    Write-Host "  $($Record.imported)"
    Write-Host ""
    Write-Host "[1] Open Folder"
    Write-Host "[2] Open Script"
    Write-Host "[3] Create Module"
    Write-Host "[4] Delete Script Record"
    Write-Host "[B] Back"
    $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
    $Full = Join-Path $ToolkitRoot $Record.path
    switch ($Choice) {
        "1" { Open-PathSafe (Split-Path -Parent $Full) }
        "2" { if (Test-Path $Full) { Invoke-Item $Full } else { Write-Host "Missing script file." -ForegroundColor Yellow; Pause-Local } }
        "3" { Create-ModuleFromScriptRecord $Record; Pause-Local }
        "4" { Remove-ScriptRecord $Record }
        "B" { return }
    }
}

function Remove-ScriptRecord {
    param($Record)
    $Confirm = (Read-Host "Remove script file and record? (Y/N)").Trim().ToUpperInvariant()
    if ($Confirm -ne "Y") { return }
    $Full = Join-Path $ToolkitRoot $Record.path
    if (Test-Path $Full) { Remove-Item -LiteralPath $Full -Force }
    $Records = @(Get-ScriptRecords | Where-Object { $_.path -ne $Record.path })
    Save-ScriptRecords $Records
    Write-Host "Script removed." -ForegroundColor Green
    Pause-Local
}

function Select-ScriptForModule {
    $Records = @(Get-ScriptRecords)
    if ($Records.Count -eq 0) { Show-ScriptList; return }
    Show-ScriptList
}

function Show-ScriptReport {
    Ensure-SoftwareSystem
    Show-LocalHeader "SCRIPT REPORT"
    $Records = @(Get-ScriptRecords)
    $RepoSize = 0L
    if (Test-Path $ScriptsRoot) {
        Get-ChildItem -Path $ScriptsRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne '.keep' -and $_.Name -notlike '*.json' } | ForEach-Object { $RepoSize += $_.Length }
    }
    $SizeText = if ($RepoSize -ge 1MB) { "{0:N2} MB" -f ($RepoSize/1MB) } else { "{0:N0} KB" -f ($RepoSize/1KB) }
    Write-Host ("Total Scripts  : {0}" -f $Records.Count)
    Write-Host "PowerShell     : $($Records.Count)"
    Write-Host ("Repository Size: {0}" -f $SizeText)
    Write-Host ""
    Write-Host "[V] View Script List"
    Write-Host "[B] Back"
    $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
    if ($Choice -eq "V") { Show-ScriptList }
}

function Show-ScriptHelp {
    Show-LocalHeader "SCRIPT REPOSITORY HELP"
    Write-Host "Script Repository stores PowerShell scripts before they become modules."
    Write-Host ""
    Write-Host "Supported now:"
    Write-Host "  .ps1 PowerShell scripts"
    Write-Host ""
    Write-Host "Batch/CMD scripts are not automatically converted."
    Write-Host "Recommended flow: save the original as reference, then manually convert to PowerShell."
    Pause-Local
}


function Test-IsDocumentCandidate {
    param([System.IO.FileSystemInfo]$Item)
    if ($Item.PSIsContainer) { return $false }
    $Ext = Get-RepositoryExtension $Item.FullName
    $Entry = Get-RepositoryFormatEntry $Ext
    return ($Entry -and $Entry.type -eq "Documents")
}

function Get-DocumentTypeFromExtension {
    param([string]$Extension)
    switch ($Extension.ToLowerInvariant()) {
        ".txt"  { "Text Document" }
        ".md"   { "Markdown Document" }
        ".pdf"  { "PDF Document" }
        ".doc"  { "Word Document" }
        ".docx" { "Word Document" }
        ".dot"  { "Word Template" }
        ".dotx" { "Word Template" }
        ".rtf"  { "Rich Text Document" }
        ".xls"  { "Spreadsheet" }
        ".xlsx" { "Spreadsheet" }
        ".xlsm" { "Macro Spreadsheet" }
        ".xltx" { "Spreadsheet Template" }
        ".csv"  { "CSV Spreadsheet" }
        ".tsv"  { "TSV Spreadsheet" }
        ".ods"  { "OpenDocument Spreadsheet" }
        ".ppt"  { "Presentation" }
        ".pptx" { "Presentation" }
        ".pptm" { "Macro Presentation" }
        ".potx" { "Presentation Template" }
        default  { "Document" }
    }
}

function Get-DocumentDetection {
    param([System.IO.FileSystemInfo]$Item)
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($Item.FullName)
    $Ext = Get-RepositoryExtension $Item.FullName
    $Name = ConvertTo-TitleName $BaseName
    $RepositoryName = Get-SafeRepositoryItemName $BaseName
    return [PSCustomObject]@{
        name=$Name
        repository_name=$RepositoryName
        type=(Get-DocumentTypeFromExtension $Ext)
        repository_kind="Document"
        source_path=$Item.FullName
        source_name=$Item.Name
        extension=$Ext
        imported=""
    }
}

function Import-DetectedDocument {
    param($Detection)
    $SafeName = Get-SafeFolderName $Detection.repository_name
    $TargetFolder = Join-Path $DocumentsRoot $SafeName
    $TargetPath = Join-Path $TargetFolder $Detection.source_name
    Show-LocalHeader "IMPORT DOCUMENT"
    Write-Host "Document:"
    Write-Host "  $($Detection.name)"
    Write-Host "Type:"
    Write-Host "  $($Detection.type)"
    Write-Host "Source:"
    Write-Host "  $($Detection.source_path)"
    Write-Host "Destination:"
    Write-Host "  $TargetPath"
    Write-Host ""
    Write-Host "[A] Import Document"
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
    if ($Choice -ne "A") { return $null }
    try {
        if (-not (Test-Path $TargetFolder)) { New-Item -ItemType Directory -Path $TargetFolder -Force | Out-Null }
        Move-Item -LiteralPath $Detection.source_path -Destination $TargetPath -Force
    } catch {
        Write-Host "[ERROR] Document import failed: $($_.Exception.Message)" -ForegroundColor Red
        Pause-Local
        return $null
    }
    $Record = [PSCustomObject]@{
        name=$Detection.name
        type=$Detection.type
        path=$TargetPath.Replace($ToolkitRoot,'').TrimStart('\','/')
        source_name=$Detection.source_name
        extension=$Detection.extension
        imported=(Get-Date).ToString("s")
    }
    $Records = @(Get-DocumentRecords)
    $Records += $Record
    Save-DocumentRecords $Records
    Show-LocalHeader "DOCUMENT IMPORT COMPLETE"
    Write-Host "Document:"
    Write-Host "  $($Detection.name)"
    Write-Host "Source:"
    Write-Host "  $($Detection.source_path)"
    Write-Host "Repository Path:"
    Write-Host "  $($Record.path)"
    Write-Host "Action:"
    Write-Host "  Imported successfully"
    return $Record
}

function Show-DocumentRepository {
    Ensure-SoftwareSystem
    while ($true) {
        Show-LocalHeader "DOCUMENT REPOSITORY"
        Write-Host "Store, organize, and open reference documents from the Repository."
        Write-Host ""
        Write-Host "Repository Path:"
        Write-Host "  Repository\Documents\"
        Write-Host ""
        Write-Host "[1] Browse Documents"
        Write-Host "[2] Import Documents From Incoming"
        Write-Host "[3] Document Report"
        Write-Host "[4] Open Documents Repository"
        Write-Host "[5] Document Help"
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        switch ($Choice) {
            "1" { Show-DocumentList }
            "2" { Invoke-DocumentImportWorkflow }
            "3" { Show-DocumentReport }
            "4" { Open-PathSafe $DocumentsRoot }
            "5" { Show-DocumentHelp }
            "B" { return }
        }
    }
}

function Invoke-DocumentImportWorkflow {
    Ensure-SoftwareSystem
    $Items = @(Get-IncomingItems | Where-Object { Test-IsDocumentCandidate $_ })
    Show-LocalHeader "IMPORT DOCUMENTS FROM INCOMING"
    if ($Items.Count -eq 0) {
        Write-Host "No supported documents found in Incoming\."
        Write-Host "Supported: .txt, .md, .pdf, .doc, .docx, .rtf"
        Pause-Local
        return
    }
    $Map = @{}
    $Index = 1
    foreach ($Item in $Items) {
        $Detection = Get-DocumentDetection $Item
        Write-Host ("[{0}] {1}" -f $Index, $Item.Name)
        Write-Host ("     Type          : {0}" -f $Detection.type) -ForegroundColor DarkGray
        Write-Host ("     Detected Name : {0}" -f $Detection.name) -ForegroundColor DarkGray
        $Map[[string]$Index] = $Detection
        $Index++
    }
    Write-Host ""
    Write-Host "[A] Import All Documents"
    Write-Host "[B] Back"
    $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
    if ($Choice -eq "B") { return }
    $Selections = @()
    if ($Choice -eq "A") { $Selections = @($Map.Keys | Sort-Object {[int]$_}) }
    elseif ($Map.ContainsKey($Choice)) { $Selections = @($Choice) }
    foreach ($Key in $Selections) {
        $Record = Import-DetectedDocument $Map[$Key]
        if ($Record) { Pause-Local }
    }
}

function Show-DocumentList {
    Ensure-SoftwareSystem
    while ($true) {
        Show-LocalHeader "DOCUMENT LIST"
        $Records = @(Get-DocumentRecords)
        if ($Records.Count -eq 0) {
            Write-Host "No documents imported yet."
            Write-Host "Use Document Repository > Import Documents From Incoming."
            Pause-Local
            return
        }
        $Map = @{}
        $Index = 1
        foreach ($R in $Records | Sort-Object type,name) {
            Write-Host ("[{0}] {1}" -f $Index, $R.name)
            Write-Host ("     Type            : {0}" -f $R.type) -ForegroundColor DarkGray
            Write-Host ("     Repository Path : {0}" -f $R.path) -ForegroundColor DarkGray
            $Map[[string]$Index] = $R
            $Index++
        }
        Write-Host ""
        Write-Host "Select document for details, or [B] Back"
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        if ($Choice -eq "B") { return }
        if ($Map.ContainsKey($Choice)) { Show-DocumentDetails $Map[$Choice] }
    }
}

function Show-DocumentDetails {
    param($Record)
    Show-LocalHeader "DOCUMENT DETAILS"
    Write-Host "Name:"
    Write-Host "  $($Record.name)"
    Write-Host "Type:"
    Write-Host "  $($Record.type)"
    Write-Host "Repository Path:"
    Write-Host "  $($Record.path)"
    Write-Host "Imported:"
    Write-Host "  $($Record.imported)"
    Write-Host ""
    Write-Host "[1] Open Folder"
    Write-Host "[2] Open Document"
    Write-Host "[3] Delete Document Record"
    Write-Host "[B] Back"
    $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
    $Full = Join-Path $ToolkitRoot $Record.path
    switch ($Choice) {
        "1" { Open-PathSafe (Split-Path -Parent $Full) }
        "2" { if (Test-Path $Full) { Invoke-Item $Full } else { Write-Host "Missing document file." -ForegroundColor Yellow; Pause-Local } }
        "3" { Remove-DocumentRecord $Record }
        "B" { return }
    }
}

function Remove-DocumentRecord {
    param($Record)
    $Confirm = (Read-Host "Remove document file and record? (Y/N)").Trim().ToUpperInvariant()
    if ($Confirm -ne "Y") { return }
    $Full = Join-Path $ToolkitRoot $Record.path
    if (Test-Path $Full) { Remove-Item -LiteralPath $Full -Force }
    $Records = @(Get-DocumentRecords | Where-Object { $_.path -ne $Record.path })
    Save-DocumentRecords $Records
    Write-Host "Document removed." -ForegroundColor Green
    Pause-Local
}

function Show-DocumentReport {
    Ensure-SoftwareSystem
    Show-LocalHeader "DOCUMENT REPORT"
    $Records = @(Get-DocumentRecords)
    $RepoSize = 0L
    if (Test-Path $DocumentsRoot) {
        Get-ChildItem -Path $DocumentsRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne '.keep' -and $_.Name -notlike '*.json' } | ForEach-Object { $RepoSize += $_.Length }
    }
    $SizeText = if ($RepoSize -ge 1MB) { "{0:N2} MB" -f ($RepoSize/1MB) } else { "{0:N0} KB" -f ($RepoSize/1KB) }
    Write-Host ("Total Documents : {0}" -f $Records.Count)
    Write-Host ("Repository Size : {0}" -f $SizeText)
    Write-Host ""
    Write-Host "[V] View Document List"
    Write-Host "[B] Back"
    $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
    if ($Choice -eq "V") { Show-DocumentList }
}

function Show-DocumentHelp {
    Show-LocalHeader "DOCUMENT REPOSITORY HELP"
    Write-Host "Document Repository stores reference files, guides, notes, and offline documentation."
    Write-Host ""
    Write-Host "Supported:"
    Write-Host "  .txt, .md, .pdf, .doc, .docx, .rtf"
    Write-Host ""
    Write-Host "Incoming is the drop box. Repository is permanent managed storage."
    Pause-Local
}


function Show-FullRepositoryReport {
    Ensure-SoftwareSystem
    Show-LocalHeader "FULL REPOSITORY REPORT"
    $Groups = @(
        [PSCustomObject]@{ Name='Software'; Records=@(Get-SoftwareRecords) },
        [PSCustomObject]@{ Name='Packages'; Records=@(Sync-GenericAssetRecordsFromFolders 'Package') },
        [PSCustomObject]@{ Name='Scripts'; Records=@(Get-ScriptRecords) },
        [PSCustomObject]@{ Name='Documents'; Records=@(Get-DocumentRecords) },
        [PSCustomObject]@{ Name='Archives'; Records=@(Sync-GenericAssetRecordsFromFolders 'Archive') },
        [PSCustomObject]@{ Name='Disk Images'; Records=@(Sync-GenericAssetRecordsFromFolders 'Disk Image') },
        [PSCustomObject]@{ Name='Custom'; Records=@(Sync-GenericAssetRecordsFromFolders 'Custom') }
    )
    foreach ($G in $Groups) {
        Write-Host ""
        Write-Host ("== {0} ({1}) ==" -f $G.Name, @($G.Records).Count) -ForegroundColor Cyan
        if (@($G.Records).Count -eq 0) {
            Write-Host "  None" -ForegroundColor DarkGray
            continue
        }
        foreach ($R in @($G.Records | Sort-Object name,path)) {
            $Fmt = if ($R.format) { " [$($R.format)]" } elseif ($R.extension) { " [$($R.extension)]" } else { "" }
            Write-Host ("  - {0}{1}" -f $R.name, $Fmt)
            if ($R.detection_name) { Write-Host ("    Detection: {0}" -f $R.detection_name) -ForegroundColor DarkGray }
            if ($R.detection_category -or $R.detection_subcategory) { Write-Host ("    Category : {0} / {1}" -f $R.detection_category,$R.detection_subcategory) -ForegroundColor DarkGray }
            if ($R.path) { Write-Host ("    {0}" -f $R.path) -ForegroundColor DarkGray }
        }
    }
    $AllRecords = @()
    foreach ($G in $Groups) { $AllRecords += @($G.Records) }
    $DetectionRecords = @($AllRecords | Where-Object { $_.detection_name })
    if ($DetectionRecords.Count -gt 0) {
        Write-Host ""
        Write-Host "== Detection Summary ==" -ForegroundColor Cyan
        foreach ($DGroup in @($DetectionRecords | Group-Object detection_name | Sort-Object Name)) {
            Write-Host ("  {0}: {1}" -f $DGroup.Name,$DGroup.Count)
        }
    }
    Pause-Local
}

function Show-RepositoryReport {
    Ensure-SoftwareSystem
    while ($true) {
        Show-LocalHeader "REPOSITORY REPORT"
        $SoftwareRecords = @(Get-SoftwareRecords)
        $ScriptRecords = @(Get-ScriptRecords)
        $DocumentRecords = @(Get-DocumentRecords)
        $PackageRecords = @(Sync-GenericAssetRecordsFromFolders 'Package')
        $ArchiveRecords = @(Sync-GenericAssetRecordsFromFolders 'Archive')
        $DiskImageRecords = @(Sync-GenericAssetRecordsFromFolders 'Disk Image')
        $CustomRecords = @(Sync-GenericAssetRecordsFromFolders 'Custom')
        $RepoSize = 0L
        if (Test-Path $RepositoryRoot) {
            Get-ChildItem -Path $RepositoryRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne '.keep' -and $_.Name -notlike '*.json' } | ForEach-Object { $RepoSize += $_.Length }
        }
        $SizeText = if ($RepoSize -ge 1GB) { "{0:N2} GB" -f ($RepoSize/1GB) } elseif ($RepoSize -ge 1MB) { "{0:N2} MB" -f ($RepoSize/1MB) } else { "{0:N0} KB" -f ($RepoSize/1KB) }
        Write-Host ("Software Items : {0}" -f $SoftwareRecords.Count)
        Write-Host ("Packages       : {0}" -f $PackageRecords.Count)
        Write-Host ("Scripts        : {0}" -f $ScriptRecords.Count)
        Write-Host ("Documents      : {0}" -f $DocumentRecords.Count)
        Write-Host ("Archives       : {0}" -f $ArchiveRecords.Count)
        Write-Host ("Disk Images    : {0}" -f $DiskImageRecords.Count)
        Write-Host ("Custom         : {0}" -f $CustomRecords.Count)
        $DetectionSummaryRecords = @($CustomRecords | Where-Object { $_.detection_name })
        Write-Host ("Detections     : {0}" -f $DetectionSummaryRecords.Count)
        Write-Host ("Repository Size: {0}" -f $SizeText)
        if (Test-Path $RepositoryErrorLogPath) { Write-Host "Errors Log     : Logs\errors.log" -ForegroundColor Yellow }
        Write-Host ""
        Write-Host "[1] Software Report"
        Write-Host "[2] Script Report"
        Write-Host "[3] Document Report"
        Write-Host "[4] Package List"
        Write-Host "[5] Archive List"
        Write-Host "[6] Disk Image List"
        Write-Host "[7] Custom List"
        Write-Host "[F] Full Repository Report"
        Write-Host "[B] Back"
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        switch ($Choice) {
            "1" { Show-SoftwareReport }
            "2" { Show-ScriptReport }
            "3" { Show-DocumentReport }
            "4" { Show-GenericAssetList 'Package' }
            "5" { Show-GenericAssetList 'Archive' }
            "6" { Show-GenericAssetList 'Disk Image' }
            "7" { Show-GenericAssetList 'Custom' }
            "F" { Show-FullRepositoryReport }
            "B" { return }
        }
    }
}

function ConvertTo-TitleName {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "Unknown Software" }

    $Clean = $Text -replace '[_\-]+',' '
    # Split normal CamelCase only at lower/digit -> upper boundaries.
    # Avoid character-pair splitting regressions such as:
    #   UpdateCustomset -> U Pd At Ec Us To Ms Et
    $Clean = [System.Text.RegularExpressions.Regex]::Replace($Clean, '(?<=[a-z0-9])(?=[A-Z])', ' ')
    $Clean = $Clean -replace '\s+',' '
    $Clean = $Clean.Trim()

    $Words = @()
    foreach ($Part in ($Clean -split '\s+')) {
        if ([string]::IsNullOrWhiteSpace($Part)) { continue }
        if ($Part.Length -le 3 -and $Part -cmatch '^[A-Z0-9]+$') { $Words += $Part; continue }
        $Words += ($Part.Substring(0,1).ToUpperInvariant() + $(if ($Part.Length -gt 1) { $Part.Substring(1).ToLowerInvariant() } else { "" }))
    }

    $Result = ($Words -join ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($Result)) { return "Unknown Software" }
    return $Result
}

function Get-SafeRepositoryItemName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return "Unknown" }

    # Repository folder names must be predictable and should not use display-name splitting.
    # Keep the original base filename shape while removing invalid path characters.
    $Clean = ($Name -replace '[\\/:*?"<>|]', ' ').Trim()
    $Clean = ($Clean -replace '\s+',' ').Trim()
    if ([string]::IsNullOrWhiteSpace($Clean)) { return "Unknown" }
    return $Clean
}

function Get-VersionFrom7ZipFilename {
    param([string]$BaseName)
    if ($BaseName -match '^7z(?<digits>\d{4})') {
        $D = $Matches.digits
        return ("{0}.{1}" -f [int]$D.Substring(0,2), $D.Substring(2,2))
    }
    return ""
}

function Get-FileVersionInfoSafe {
    param([string]$Path)
    try { return (Get-Item -LiteralPath $Path -ErrorAction Stop).VersionInfo } catch { return $null }
}

function Get-SoftwareTypeFromPath {
    param([string]$Path, [bool]$IsFolder = $false)
    if ($IsFolder) { return "Portable Folder" }
    $Ext = Get-RepositoryExtension $Path
    $FileName = [System.IO.Path]::GetFileName($Path)
    if ($FileName -match '\.paf\.exe$') { return "PortableApps Package" }
    if ($FileName -match 'Portable.*\.exe$') { return "Portable EXE" }
    switch ($Ext) {
        ".msi" { "MSI Package" }
        ".msix" { "Windows Package" }
        ".appx" { "Windows Package" }
        ".msixbundle" { "Windows Package" }
        ".appxbundle" { "Windows Package" }
        ".msp" { "Windows Installer Patch" }
        ".msu" { "Windows Update Package" }
        ".iso" { "Disk Image" }
        ".img" { "Disk Image" }
        ".wim" { "Disk Image" }
        ".esd" { "Disk Image" }
        ".ffu" { "Disk Image" }
        ".vhd" { "Disk Image" }
        ".vhdx" { "Disk Image" }
        ".zip" { "Archive" }
        ".7z" { "Archive" }
        ".rar" { "Archive" }
        ".cab" { "Archive" }
        ".tar" { "Archive" }
        ".gz" { "Archive" }
        ".bz2" { "Archive" }
        ".xz" { "Archive" }
        ".tgz" { "Archive" }
        ".tbz" { "Archive" }
        ".txz" { "Archive" }
        ".tar.gz" { "Archive" }
        ".tar.bz2" { "Archive" }
        ".tar.xz" { "Archive" }
        ".exe" {
            if ($FileName -match 'setup|install|installer|bootstrap') { "Installer" } else { "Portable EXE" }
        }
        default { "Unknown" }
    }
}

function Get-SoftwareDetection {
    param([System.IO.FileSystemInfo]$Item)
    $IsFolder = ($Item.PSIsContainer -eq $true)
    $Path = $Item.FullName
    $Name = $Item.Name
    $BaseName = if ($IsFolder) { $Item.Name } else { [System.IO.Path]::GetFileNameWithoutExtension($Path) }
    $Type = Get-SoftwareTypeFromPath -Path $Path -IsFolder:$IsFolder
    $Product = ""
    $Version = ""
    $Publisher = ""
    $Destination = "Utilities"
    $Entry = ""

    if (-not $IsFolder) {
        $Info = Get-FileVersionInfoSafe $Path
        if ($Info) {
            if (-not [string]::IsNullOrWhiteSpace($Info.ProductName)) { $Product = $Info.ProductName.Trim() }
            elseif (-not [string]::IsNullOrWhiteSpace($Info.FileDescription)) { $Product = $Info.FileDescription.Trim() }
            if (-not [string]::IsNullOrWhiteSpace($Info.ProductVersion)) { $Version = $Info.ProductVersion.Trim() }
            elseif (-not [string]::IsNullOrWhiteSpace($Info.FileVersion)) { $Version = $Info.FileVersion.Trim() }
            if (-not [string]::IsNullOrWhiteSpace($Info.CompanyName)) { $Publisher = $Info.CompanyName.Trim() }
        }
    }

    # Pattern overrides and fallbacks
    if ($Name -match '^7z\d{4}-.*\.exe$') {
        $Product = "7-Zip"
        $Version = Get-VersionFrom7ZipFilename $BaseName
        $Type = "Installer"
        $Destination = "Utilities"
    } elseif ($Name -match '^ChromeSetup.*\.exe$') {
        $Product = "Google Chrome"
        $Type = "Bootstrap Installer"
        $Destination = "Browsers"
        if ([string]::IsNullOrWhiteSpace($Publisher)) { $Publisher = "Google" }
    } elseif ($Name -match '^(?<app>.+)Portable_(?<ver>[0-9][0-9\.]*).*\.paf\.exe$') {
        $Product = (ConvertTo-TitleName $Matches.app) + " Portable"
        $Version = $Matches.ver.TrimEnd('.')
        $Type = "PortableApps Package"
        $Destination = "Portable"
    } elseif ($IsFolder) {
        $Exe = Get-ChildItem -Path $Path -Filter "*.exe" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        $Product = ConvertTo-TitleName $BaseName
        $Destination = "Portable"
        if ($Exe) { $Entry = $Exe.FullName }
    }

    if ([string]::IsNullOrWhiteSpace($Product)) {
        $Product = ConvertTo-TitleName ($BaseName -replace '(?i)setup|installer|install','')
    }
    if ($Type -eq "Windows Package") { $Destination = "Packages" }
    elseif ($Type -match 'ISO|Disk') { $Destination = "Disk Images" }
    elseif ($Type -eq "Archive") { $Destination = "Archives" }
    elseif ($Type -match "MSI|Installer|Bootstrap") {
        if ($Product -match 'Chrome|Firefox|Browser|Edge') { $Destination = "Browsers" } else { $Destination = "Installers" }
    }
    elseif ($Type -match "Portable") { $Destination = "Portable" }

    return [PSCustomObject]@{
        name = $Product
        version = $Version
        publisher = $Publisher
        type = $Type
        destination = $Destination
        source_path = $Path
        source_name = $Name
        is_folder = $IsFolder
        entry = $Entry
    }
}

function Get-IncomingItems {
    Ensure-SoftwareSystem
    $Items = @()
    if (Test-Path $IncomingRoot) {
        $Items += @(Get-ChildItem -Path $IncomingRoot -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne ".keep" -and $_.Name -notlike "*.json" })
        $Items += @(Get-ChildItem -Path $IncomingRoot -Directory -ErrorAction SilentlyContinue)
    }
    return @($Items | Sort-Object Name -Unique)
}

function Test-IsSoftwareCandidate {
    param([System.IO.FileSystemInfo]$Item)
    if ($Item.PSIsContainer) { return $true }
    $Ext = Get-RepositoryExtension $Item.FullName
    $Entry = Get-RepositoryFormatEntry $Ext
    return ($Entry -and $Entry.type -eq "Software")
}

function Get-SafeFolderName {
    param([string]$Name)
    $Clean = ($Name -replace '[\\/:*?"<>|]', ' ').Trim()
    $Clean = ($Clean -replace '\s+',' ').Trim()
    if ([string]::IsNullOrWhiteSpace($Clean)) { return "Unknown Software" }
    return $Clean
}

function Get-AllDestinations {
    $Core = Get-SoftwareCore
    $Lib = Get-SoftwareLibrary
    $CoreDest = @($Core.destinations)
    $UserDest = @($Lib.destinations)
    return [PSCustomObject]@{ core=$CoreDest; user=$UserDest }
}

function Add-UserDestination {
    param([string]$Name)
    $Clean = Get-SafeFolderName $Name
    $Lib = Get-SoftwareLibrary
    $Existing = @($Lib.destinations | Where-Object { $_ -ieq $Clean })
    $Core = Get-SoftwareCore
    $CoreExisting = @($Core.destinations | Where-Object { $_ -ieq $Clean })
    if ($Existing.Count -eq 0 -and $CoreExisting.Count -eq 0) {
        $List = @($Lib.destinations) + $Clean
        $Lib.destinations = @($List | Sort-Object -Unique)
        Save-SoftwareLibrary $Lib
        Write-SoftwareLog "Learned custom destination: $Clean"
    }
    return $Clean
}

function Select-Destination {
    param([string]$Suggested, $Detection)
    while ($true) {
        Show-LocalHeader "CHOOSE DESTINATION"
        Write-Host "Core destinations are protected. User destinations are learned/custom."
        Write-Host ""
        if ($Detection) {
            Write-Host "File:"
            Write-Host "  $($Detection.source_name)"
            Write-Host "Detected Name:"
            Write-Host "  $($Detection.name)"
            Write-Host "Detected Type:"
            Write-Host "  $($Detection.type)"
            if ($Detection.version) { Write-Host "Version:`n  $($Detection.version)" }
            if ($Detection.publisher) { Write-Host "Publisher:`n  $($Detection.publisher)" }
            Write-Host ""
        }
        Write-Host "Suggested Destination: $Suggested"
        Write-Host "Reason:"
        Write-Host "  Based on detected file type/product."
        Write-Host ""
        Write-Host "[A] Accept Recommendation"
        Write-Host "[1] Choose Another Destination"
        Write-Host "[C] Create Custom Destination"
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        switch ($Choice) {
            "A" { return $Suggested }
            "1" {
                $Dest = Choose-ExistingDestination
                if ($Dest) { return $Dest }
            }
            "C" {
                $Name = Read-Host "Custom destination name"
                if (-not [string]::IsNullOrWhiteSpace($Name)) { return (Add-UserDestination $Name) }
            }
            "B" { return $null }
        }
    }
}

function Choose-ExistingDestination {
    while ($true) {
        Show-LocalHeader "EXISTING DESTINATIONS"
        $D = Get-AllDestinations
        $Map = @{}
        $Index = 1
        Write-Host "Core Destinations:"
        foreach ($Dest in @($D.core)) {
            Write-Host ("[{0}] {1}" -f $Index, $Dest)
            $Map[[string]$Index] = $Dest
            $Index++
        }
        Write-Host ""
        Write-Host "User Destinations:"
        if (@($D.user).Count -eq 0) { Write-Host "  none yet" -ForegroundColor DarkGray }
        foreach ($Dest in @($D.user)) {
            Write-Host ("[{0}] {1}" -f $Index, $Dest)
            $Map[[string]$Index] = $Dest
            $Index++
        }
        Write-Host ""
        Write-Host "[C] Custom"
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        if ($Choice -eq "B") { return $null }
        if ($Choice -eq "C") {
            $Name = Read-Host "Custom destination name"
            if (-not [string]::IsNullOrWhiteSpace($Name)) { return (Add-UserDestination $Name) }
        }
        elseif ($Map.ContainsKey($Choice)) { return $Map[$Choice] }
    }
}

function Copy-FileWithProgress {
    param([string]$Source, [string]$Destination)
    $BufferSize = 4MB
    $SourceStream = [System.IO.File]::OpenRead($Source)
    try {
        $DestFolder = Split-Path -Parent $Destination
        if (-not (Test-Path $DestFolder)) { New-Item -ItemType Directory -Path $DestFolder -Force | Out-Null }
        $DestStream = [System.IO.File]::Create($Destination)
        try {
            $Buffer = New-Object byte[] $BufferSize
            $Total = $SourceStream.Length
            $Copied = 0L
            while (($Read = $SourceStream.Read($Buffer,0,$Buffer.Length)) -gt 0) {
                $DestStream.Write($Buffer,0,$Read)
                $Copied += $Read
                $Percent = if ($Total -gt 0) { [int](($Copied / $Total) * 100) } else { 0 }
                Write-Progress -Activity "Moving software" -Status ("{0}%" -f $Percent) -PercentComplete $Percent
            }
        } finally { $DestStream.Close() }
    } finally { $SourceStream.Close(); Write-Progress -Activity "Moving software" -Completed }
}

function Move-SoftwareItem {
    param([string]$Source, [string]$Destination)
    $IsFolder = Test-Path $Source -PathType Container
    if ($IsFolder) {
        Write-Host "Moving folder. Please wait..."
        $Parent = Split-Path -Parent $Destination
        if (-not (Test-Path $Parent)) { New-Item -ItemType Directory -Path $Parent -Force | Out-Null }
        Move-Item -LiteralPath $Source -Destination $Destination -Force
    } else {
        $Size = (Get-Item -LiteralPath $Source).Length
        if ($Size -gt 100MB) {
            Copy-FileWithProgress -Source $Source -Destination $Destination
            Remove-Item -LiteralPath $Source -Force
        } else {
            $Parent = Split-Path -Parent $Destination
            if (-not (Test-Path $Parent)) { New-Item -ItemType Directory -Path $Parent -Force | Out-Null }
            Move-Item -LiteralPath $Source -Destination $Destination -Force
        }
    }
}

function Get-TargetPaths {
    param($Detection, [string]$Destination, [string]$Mode = "Current")
    $Dest = Get-SafeFolderName $Destination
    $App = Get-SafeFolderName $Detection.name
    $Base = Join-Path $SoftwareRoot $App
    $FileName = $Detection.source_name
    if ($Detection.is_folder) { $FileName = $App }
    $Current = Join-Path $Base "Current"
    $Previous = Join-Path $Base "Previous"
    $VersionName = if ([string]::IsNullOrWhiteSpace($Detection.version)) { (Get-Date -Format "yyyyMMdd_HHmmss") } else { Get-SafeFolderName $Detection.version }
    $VersionFolder = Join-Path (Join-Path $Base "Versions") $VersionName
    return [PSCustomObject]@{
        base=$Base
        current_folder=$Current
        previous_folder=$Previous
        version_folder=$VersionFolder
        current_path=(Join-Path $Current $FileName)
        previous_path=(Join-Path $Previous $FileName)
        version_path=(Join-Path $VersionFolder $FileName)
    }
}

function Handle-ExistingSoftware {
    param($Detection, [string]$Destination)
    $Paths = Get-TargetPaths -Detection $Detection -Destination $Destination
    if (-not (Test-Path $Paths.current_folder) -and -not (Test-Path $Paths.base)) {
        return "NewCurrent"
    }
    while ($true) {
        Show-LocalHeader "EXISTING SOFTWARE DETECTED"
        Write-Host "Product:  $($Detection.name)"
        $ExistingVersion = ""
        $ExistingFiles = @()
        if (Test-Path $Paths.current_folder) { $ExistingFiles = @(Get-ChildItem -Path $Paths.current_folder -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1) }
        if ($ExistingFiles.Count -gt 0) {
            $Info = Get-FileVersionInfoSafe $ExistingFiles[0].FullName
            if ($Info) {
                if (-not [string]::IsNullOrWhiteSpace($Info.ProductVersion)) { $ExistingVersion = $Info.ProductVersion.Trim() }
                elseif (-not [string]::IsNullOrWhiteSpace($Info.FileVersion)) { $ExistingVersion = $Info.FileVersion.Trim() }
            }
            if ([string]::IsNullOrWhiteSpace($ExistingVersion) -and $ExistingFiles[0].Name -match '^7z(?<digits>\d{4})') { $ExistingVersion = Get-VersionFrom7ZipFilename ([System.IO.Path]::GetFileNameWithoutExtension($ExistingFiles[0].Name)) }
        }
        if ($ExistingVersion) { Write-Host "Existing Version: $ExistingVersion" }
        if ($Detection.version) { Write-Host "Incoming Version: $($Detection.version)" }
        Write-Host "Location: $Destination\$($Detection.name)"
        Write-Host ""
        Write-Host "[1] Overwrite"
        Write-Host "    Replace the existing current file/version completely."
        Write-Host "[2] Keep Both"
        Write-Host "    Import this copy into a version/timestamp folder."
        Write-Host "[3] Set Incoming as Current, Keep Old as Previous"
        Write-Host "    New version becomes default. Old current is kept as rollback."
        Write-Host "[4] Import as Specific Version Only"
        Write-Host "    Store this version but do not make it default."
        Write-Host "[5] Skip"
        Write-Host ""
        $Choice = (Read-Host "Selection").Trim()
        switch ($Choice) {
            "1" { return "Overwrite" }
            "2" { return "KeepBoth" }
            "3" { return "CurrentPrevious" }
            "4" { return "SpecificVersion" }
            "5" { return "Skip" }
        }
    }
}

function Import-DetectedSoftware {
    param($Detection, [string]$Destination)
    $Mode = Handle-ExistingSoftware -Detection $Detection -Destination $Destination
    if ($Mode -eq "Skip") { return $null }
    $Paths = Get-TargetPaths -Detection $Detection -Destination $Destination
    switch ($Mode) {
        "NewCurrent" { $Target = $Paths.current_path }
        "Overwrite" {
            if (Test-Path $Paths.current_folder) { Remove-Item -LiteralPath $Paths.current_folder -Recurse -Force }
            $Target = $Paths.current_path
        }
        "KeepBoth" { $Target = $Paths.version_path }
        "SpecificVersion" { $Target = $Paths.version_path }
        "CurrentPrevious" {
            if (Test-Path $Paths.previous_folder) { Remove-Item -LiteralPath $Paths.previous_folder -Recurse -Force }
            if (Test-Path $Paths.current_folder) {
                $Parent = Split-Path -Parent $Paths.previous_folder
                if (-not (Test-Path $Parent)) { New-Item -ItemType Directory -Path $Parent -Force | Out-Null }
                Move-Item -LiteralPath $Paths.current_folder -Destination $Paths.previous_folder -Force
            }
            $Target = $Paths.current_path
        }
    }

    Show-LocalHeader "MOVING SOFTWARE"
    Write-Host "Source:"
    Write-Host "  $($Detection.source_path)"
    Write-Host "Destination:"
    Write-Host "  $Target"
    Write-Host ""
    Write-Host "Please wait until the move completes."
    try {
        Move-SoftwareItem -Source $Detection.source_path -Destination $Target
    } catch {
        Write-Host ""
        Write-Host "[ERROR] Move/import failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-SoftwareLog "Import failed source=$($Detection.source_path) target=$Target error=$($_.Exception.Message)"
        Pause-Local
        return $null
    }

    $RecordTarget = $Target
    if ($Detection.is_folder -and -not [string]::IsNullOrWhiteSpace($Detection.entry)) {
        try {
            $RelativeEntry = $Detection.entry.Substring($Detection.source_path.Length).TrimStart('\','/')
            if (-not [string]::IsNullOrWhiteSpace($RelativeEntry)) {
                $RecordTarget = Join-Path $Target $RelativeEntry
            }
        } catch { }
    }

    $Record = [PSCustomObject]@{
        name=$Detection.name
        version=$Detection.version
        publisher=$Detection.publisher
        type=$Detection.type
        destination=$Destination
        path=$RecordTarget.Replace($ToolkitRoot,'').TrimStart('\','/')
        root_path=$Target.Replace($ToolkitRoot,'').TrimStart('\','/')
        mode=$Mode
        imported=(Get-Date).ToString("s")
    }
    $Records = @(Get-SoftwareRecords)
    $Records += $Record
    Save-SoftwareRecords $Records
    Write-SoftwareLog "Imported software name=$($Detection.name) version=$($Detection.version) destination=$Destination mode=$Mode"
    Show-LocalHeader "IMPORT COMPLETE"
    Write-Host "Product:"
    Write-Host "  $($Detection.name)"
    if ($Detection.version) { Write-Host "Version:`n  $($Detection.version)" }
    Write-Host "Source:"
    Write-Host "  $($Detection.source_path)"
    Write-Host "Destination:"
    Write-Host "  $Target"
    Write-Host "Action:"
    Write-Host "  Imported successfully"
    return $Record
}

function New-ModuleNameSafe {
    param([string]$Name)
    $Safe = ($Name -replace '[^A-Za-z0-9_\- ]','').Trim() -replace '\s+','_'
    if ([string]::IsNullOrWhiteSpace($Safe)) { $Safe = "Software_Module" }
    return $Safe
}

function New-RepositoryModuleRunBody {
    param([string]$ModuleName,[string]$RelativePath,[string]$ItemType)
    if ($ItemType -match "MSI") {
        return @"
# ============================================================
# WINDOWS MODULAR TOOLKIT
# $ModuleName
# ============================================================

`$ToolkitRoot = Resolve-Path "`$PSScriptRoot\..\.."
`$RepositoryItemPath = Join-Path `$ToolkitRoot "$RelativePath"
if (-not (Test-Path `$RepositoryItemPath)) { Write-Host "[ERROR] Missing: `$RepositoryItemPath" -ForegroundColor Red; Pause; return }
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"`$RepositoryItemPath`"" -Wait
"@
    }
    if ($ItemType -match "Package|MSIX|AppX|APPX") {
        return @"
# ============================================================
# WINDOWS MODULAR TOOLKIT
# $ModuleName
# ============================================================

`$ToolkitRoot = Resolve-Path "`$PSScriptRoot\..\.."
`$RepositoryItemPath = Join-Path `$ToolkitRoot "$RelativePath"
if (-not (Test-Path `$RepositoryItemPath)) { Write-Host "[ERROR] Missing: `$RepositoryItemPath" -ForegroundColor Red; Pause; return }
Write-Host "Adding Windows package: $ModuleName"
Add-AppxPackage -Path `$RepositoryItemPath
Pause
"@
    }
    if ($ItemType -match "ISO|Disk Image|Disk") {
        return @"
# ============================================================
# WINDOWS MODULAR TOOLKIT
# $ModuleName
# ============================================================

`$ToolkitRoot = Resolve-Path "`$PSScriptRoot\..\.."
`$RepositoryItemPath = Join-Path `$ToolkitRoot "$RelativePath"
if (-not (Test-Path `$RepositoryItemPath)) { Write-Host "[ERROR] Missing: `$RepositoryItemPath" -ForegroundColor Red; Pause; return }
Write-Host "Mounting disk image..."
Mount-DiskImage -ImagePath `$RepositoryItemPath
Write-Host "Image mounted. Open This PC to access the mounted drive."
Pause
"@
    }
    return @"
# ============================================================
# WINDOWS MODULAR TOOLKIT
# $ModuleName
# ============================================================

`$ToolkitRoot = Resolve-Path "`$PSScriptRoot\..\.."
`$RepositoryItemPath = Join-Path `$ToolkitRoot "$RelativePath"

if (-not (Test-Path `$RepositoryItemPath)) {
    Write-Host ""
    Write-Host "[ERROR] Repository item not found:" -ForegroundColor Red
    Write-Host "  `$RepositoryItemPath"
    Write-Host ""
    Write-Host "Run Repository Manager > Repository Report."
    Pause
    return
}

Write-Host "Launching $ModuleName..."
Start-Process -FilePath `$RepositoryItemPath -Wait
"@
}

function New-RepositoryLinkedModule {
    param($Record, [string]$SourceType = "repository_asset", [string]$PathField = "repository_path", [string]$ItemType = "Repository Item")
    if ($null -eq $Record) { return }
    $Context = New-RepoContextFromRecord -Record $Record -FallbackName $Record.name
    $Details = Read-ScriptModuleDetails -SuggestedName $Record.name -Context $Context -Header "REPOSITORY ITEM MODULE DETAILS" -Intro "Create a module from a repository item. Framework suggests values where possible. User decides final values."
    if ($null -eq $Details) { return }
    $ModuleName = $Details.DisplayName
    $FolderName = $Details.FolderName
    $ModulePath = Join-Path $ModulesRoot $FolderName
    if (-not (Test-Path $ModulePath)) { New-Item -ItemType Directory -Path $ModulePath -Force | Out-Null }
    $PSPath = Join-Path $ModulePath "run.ps1"
    $BatPath = Join-Path $ModulePath "run.bat"
    $JsonPath = Join-Path $ModulePath "tool.json"
    $RelativePath = $Record.path
    New-RepositoryModuleRunBody -ModuleName $ModuleName -RelativePath $RelativePath -ItemType $ItemType | Set-Content -Path $PSPath -Encoding UTF8
@"
@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1"
set "TOOLKIT_MODULE_EXITCODE=%ERRORLEVEL%"

REM If launched from inside the toolkit, the framework pauses after return.
REM If double-clicked or run directly, pause here so output stays visible.
if /I not "%TOOLKIT_LAUNCHED%"=="1" (
    echo.
    pause
)

endlocal & exit /b %TOOLKIT_MODULE_EXITCODE%
"@ | Set-Content -Path $BatPath -Encoding ASCII
    $Tool = [ordered]@{
        name=$Details.DisplayName
        category=$Details.Category
        subcategory=$Details.Subcategory
        description=$Details.Description
        keywords=@($Details.Keywords)
        risk=$Details.Risk
        requires_admin=$Details.RequiresAdmin
        supports_logs=$Details.SupportsLogs
        supports_export=$Details.SupportsExport
        entry="run.bat"
        dependencies=@($Details.Dependencies)
        hidden=$false
        source_type=$SourceType
    }
    $Tool[$PathField] = $RelativePath
    if ($Record.PSObject.Properties.Name -contains 'format') { $Tool['format'] = $Record.format }
    if ($Record.PSObject.Properties.Name -contains 'extension') { $Tool['extension'] = $Record.extension }
    $Tool | ConvertTo-Json -Depth 10 | Set-Content -Path $JsonPath -Encoding UTF8
    Show-LocalHeader "MODULE CREATED"
    Write-Host "Module:"
    Write-Host "  $($Details.DisplayName)"
    Write-Host "Module Path:"
    Write-Host "  $ModulePath"
    Write-Host "Repository Item:"
    Write-Host "  $RelativePath"
    Write-Host ""
    Write-Host "tool.json created with user-selected metadata."
}

function Create-SoftwareModule {
    param($Record)
    New-RepositoryLinkedModule -Record $Record -SourceType "software_repository" -PathField "software_path" -ItemType $Record.type
}

function Create-GenericAssetModule {
    param($Record,[string]$Kind)
    New-RepositoryLinkedModule -Record $Record -SourceType ("{0}_repository" -f ($Kind.ToLowerInvariant() -replace ' ','_')) -PathField "asset_path" -ItemType $Kind
}

function Invoke-ImportWorkflow {
    Ensure-SoftwareSystem
    $Items = @(Get-IncomingItems)
    Show-LocalHeader "SCAN INCOMING"
    Write-Host "Scans the universal Incoming folder:"
    Write-Host "  Incoming\"
    Write-Host ""
    if ($Items.Count -eq 0) {
        Write-Host "No incoming items found."
        Write-Host ""
        Write-Host "Place files or folders into Incoming\, then scan again."
        Pause-Local
        return
    }
    $Index = 1
    $Map = @{}
    foreach ($Item in $Items) {
        # Folder intelligence: check Detection Library indicators inside folders before falling back to legacy portable-folder detection.
        # This allows folders containing package.json, .sln, Cargo.toml, go.mod, etc. to classify as source/project assets.
        if ($Item.PSIsContainer) {
            $FolderRuleDetection = Get-DetectionLibraryMatch $Item
            if ($FolderRuleDetection) {
                $DetectedAsset = Get-DetectionLibraryAssetDetection -Item $Item -Rule $FolderRuleDetection
                Write-DetectionLibraryScanResult -Index $Index -Item $Item -Detection $DetectedAsset
                $Map[[string]$Index] = $DetectedAsset
                $Index++
                continue
            }
        }
        if (Test-IsSoftwareCandidate $Item) {
            $ExtForEntry = Get-RepositoryExtension $Item.FullName
            $EntryForSoftware = Get-RepositoryFormatEntry $ExtForEntry
            if ($EntryForSoftware -and $EntryForSoftware.source -eq 'User') {
                $Detection = Get-DetectionFromRepositoryFormatEntry -Item $Item -Entry $EntryForSoftware
            } else {
                $Detection = Get-SoftwareDetection $Item
            }
            Write-Host ("[{0}] {1}" -f $Index, $Item.Name)
            Write-Host ("     Product : {0}" -f $Detection.name) -ForegroundColor DarkGray
            Write-Host ("     Type    : {0}" -f $Detection.type) -ForegroundColor DarkGray
            if ($Detection.PSObject.Properties.Name -contains 'format' -and $Detection.format) { Write-Host ("     Format  : {0}" -f $Detection.format) -ForegroundColor DarkGray }
            if ($Detection.version) { Write-Host ("     Version : {0}" -f $Detection.version) -ForegroundColor DarkGray }
            Write-Host ("     Suggest : {0}" -f $Detection.destination) -ForegroundColor DarkGray
            $Map[[string]$Index] = $Detection
            $Index++
        } elseif (Test-IsScriptCandidate $Item) {
            $Detection = Get-ScriptDetection $Item
            Write-Host ("[{0}] {1}" -f $Index, $Item.Name)
            Write-Host ("     Type    : PowerShell Script") -ForegroundColor DarkGray
            Write-Host ("     Suggest : Script Repository") -ForegroundColor DarkGray
            $Map[[string]$Index] = $Detection
            $Index++
        } elseif (Test-IsDocumentCandidate $Item) {
            $Detection = Get-DocumentDetection $Item
            Write-Host ("[{0}] {1}" -f $Index, $Item.Name)
            Write-Host ("     Type    : {0}" -f $Detection.type) -ForegroundColor DarkGray
            Write-Host ("     Suggest : Document Repository") -ForegroundColor DarkGray
            $Map[[string]$Index] = $Detection
            $Index++
        } elseif (Test-IsPackageCandidate $Item) {
            $Detection = Get-GenericAssetDetection $Item 'Package'
            Write-Host ("[{0}] {1}" -f $Index, $Item.Name)
            Write-Host ("     Type    : Package") -ForegroundColor DarkGray
            Write-Host ("     Format  : {0}" -f $Detection.format) -ForegroundColor DarkGray
            Write-Host "     Suggest : Packages" -ForegroundColor DarkGray
            $Map[[string]$Index] = $Detection
            $Index++
        } elseif (Test-IsArchiveCandidate $Item) {
            $Detection = Get-GenericAssetDetection $Item 'Archive'
            Write-Host ("[{0}] {1}" -f $Index, $Item.Name)
            Write-Host ("     Type    : Archive") -ForegroundColor DarkGray
            Write-Host ("     Format  : {0}" -f $Detection.format) -ForegroundColor DarkGray
            Write-Host "     Suggest : Archives" -ForegroundColor DarkGray
            $Map[[string]$Index] = $Detection
            $Index++
        } elseif (Test-IsDiskImageCandidate $Item) {
            $Detection = Get-GenericAssetDetection $Item 'Disk Image'
            Write-Host ("[{0}] {1}" -f $Index, $Item.Name)
            Write-Host ("     Type    : Disk Image") -ForegroundColor DarkGray
            Write-Host ("     Format  : {0}" -f $Detection.format) -ForegroundColor DarkGray
            Write-Host "     Suggest : Disk Images" -ForegroundColor DarkGray
            $Map[[string]$Index] = $Detection
            $Index++

        } else {
            $ExtForLearned = Get-RepositoryExtension $Item.FullName
            $EntryForLearned = Get-RepositoryFormatEntry $ExtForLearned
            if ($EntryForLearned) {
                $Detection = Get-DetectionFromRepositoryFormatEntry -Item $Item -Entry $EntryForLearned
                Write-Host ("[{0}] {1}" -f $Index, $Item.Name)
                Write-Host ("     Type    : {0}" -f $EntryForLearned.type) -ForegroundColor DarkGray
                Write-Host ("     Format  : {0}" -f $EntryForLearned.format) -ForegroundColor DarkGray
                Write-Host ("     Suggest : {0}" -f $EntryForLearned.folder) -ForegroundColor DarkGray
                $Map[[string]$Index] = $Detection
                $Index++
            } elseif (Test-IsReferenceScriptCandidate $Item) {

            Write-Host ("[-] {0}" -f $Item.Name)
            Write-Host "     Batch/CMD script detected. Use Script Repository help for manual conversion guidance." -ForegroundColor DarkGray
        } else {
            $RuleDetection = Get-DetectionLibraryMatch $Item
            if ($RuleDetection) {
                $DetectedAsset = Get-DetectionLibraryAssetDetection -Item $Item -Rule $RuleDetection
                Write-DetectionLibraryScanResult -Index $Index -Item $Item -Detection $DetectedAsset
                $Map[[string]$Index] = $DetectedAsset
                $Index++
            } else {
                $LearnedDetection = Show-UnknownRepositoryFormatPrompt $Item
                if ($LearnedDetection) {
                    Write-Host ("[{0}] {1}" -f $Index, $Item.Name)
                    Write-Host ("     Type    : {0}" -f $LearnedDetection.repository_kind) -ForegroundColor DarkGray
                    if ($LearnedDetection.format) { Write-Host ("     Format  : {0}" -f $LearnedDetection.format) -ForegroundColor DarkGray }
                    if ($LearnedDetection.folder) { $SuggestText = $LearnedDetection.folder
                        if ($LearnedDetection.repository_kind -eq 'Custom' -and $LearnedDetection.custom_type) { $SuggestText = "Custom\$($LearnedDetection.custom_type)" }
                        Write-Host ("     Suggest : {0}" -f $SuggestText) -ForegroundColor DarkGray }
                    $Map[[string]$Index] = $LearnedDetection
                    $Index++
                } else {
                    Write-Host "     Unsupported item left in Incoming." -ForegroundColor DarkGray
                }
            }
        }
    }
    }
    Write-Host ""
    Write-Host "[A] Process Supported Items"
    Write-Host "    Process all supported items found in Incoming\."
    Write-Host "    Supported now: software, packages, scripts, documents, archives, disk images, learned formats, and Detection Library matches." -ForegroundColor DarkGray
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
    if ($Choice -eq "B") { return }
    $Selections = @()
    if ($Choice -eq "A") { $Selections = @($Map.Keys | Sort-Object {[int]$_}) }
    elseif ($Map.ContainsKey($Choice)) { $Selections = @($Choice) }
    else { return }

    $TranscriptStarted = Start-RepositoryQaTranscript
    foreach ($Key in $Selections) {
        $Detection = $Map[$Key]
        $OldEap = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Stop'
            $ItemNameForLog = if ($Detection.PSObject.Properties.Name -contains 'source_name') { $Detection.source_name } elseif ($Detection.PSObject.Properties.Name -contains 'name') { $Detection.name } else { 'Unknown' }
            $TypeForLog = if ($Detection.PSObject.Properties.Name -contains 'repository_kind') { $Detection.repository_kind } elseif ($Detection.PSObject.Properties.Name -contains 'type') { $Detection.type } else { '' }
            $DestForLog = if ($Detection.PSObject.Properties.Name -contains 'folder') { $Detection.folder } elseif ($Detection.PSObject.Properties.Name -contains 'destination') { $Detection.destination } else { '' }
            Write-RepositoryImportDebug ("IMPORT START item={0} type={1} destination={2}" -f $ItemNameForLog,$TypeForLog,$DestForLog)
        if ($Detection.type -eq "PowerShell Script") {
            $Record = Import-DetectedScript $Detection
            if ($Record) {
                $Create = (Read-Host "Create module from this script now? (Y/N) [Y]").Trim().ToUpperInvariant()
                if ([string]::IsNullOrWhiteSpace($Create) -or $Create -eq "Y") { Create-ModuleFromScriptRecord $Record }
                Pause-Local
            }
            continue
        }
        if ($Detection.PSObject.Properties.Name -contains 'repository_kind' -and $Detection.repository_kind -eq "Document") {
            $Record = Import-DetectedDocument $Detection
            if ($Record) { Pause-Local }
            continue
        }
        if ($Detection.PSObject.Properties.Name -contains 'repository_kind' -and $Detection.repository_kind -in @('Package','Archive','Disk Image','Custom')) {
            $Record = Import-GenericRepositoryAsset $Detection
            if ($Record) {
                if ($Detection.repository_kind -eq 'Package') {
                    $Create = (Read-Host "Create module for this package now? (Y/N) [Y]").Trim().ToUpperInvariant()
                    if ([string]::IsNullOrWhiteSpace($Create) -or $Create -in @('Y','YES')) { Create-GenericAssetModule $Record 'Package' }
                }
                Pause-Local
            }
            continue
        }
        Show-LocalHeader "SOFTWARE DETECTED"
        Write-Host "Product:      $($Detection.name)"
        if ($Detection.version) { Write-Host "Version:      $($Detection.version)" }
        if ($Detection.publisher) { Write-Host "Publisher:    $($Detection.publisher)" }
        Write-Host "Type:         $($Detection.type)"
        if ($Detection.PSObject.Properties.Name -contains 'format' -and $Detection.format) { Write-Host "Format:       $($Detection.format)" }
        Write-Host "Source:       $($Detection.source_name)"
        Write-Host "Suggested:    $($Detection.destination)"
        Write-Host ""
        if ($Detection.PSObject.Properties.Name -contains 'learned_format' -and $Detection.learned_format) {
            $Destination = 'Software'
            Write-Host "Learned format detected. Using Repository\Software without legacy destination prompts." -ForegroundColor DarkGray
        } else {
            $Destination = Select-Destination -Suggested $Detection.destination -Detection $Detection
        }
        if (-not $Destination) { continue }
        $Record = Import-DetectedSoftware -Detection $Detection -Destination $Destination
        if ($Record) {
            Write-Host ""
            Write-Host "Import complete." -ForegroundColor Green
            $Create = (Read-Host "Create module for this software now? (Y/N) [Y]").Trim().ToUpperInvariant()
            if ([string]::IsNullOrWhiteSpace($Create) -or $Create -eq "Y") { Create-SoftwareModule $Record }
            Pause-Local
        }
            Write-RepositoryImportDebug ("IMPORT OK item={0}" -f $ItemNameForLog)
        } catch {
            Write-RepositoryImportException -Detection $Detection -ErrorRecord $_
        } finally {
            $ErrorActionPreference = $OldEap
        }
    }
    Stop-RepositoryQaTranscript -Started $TranscriptStarted
}

function Show-SoftwareRepository {
    Ensure-SoftwareSystem
    while ($true) {
        Show-LocalHeader "SOFTWARE REPOSITORY"
        Write-Host "Repository Path:"
        Write-Host "  Repository\Software\"
        Write-Host ""
        $Records = @(Get-SoftwareRecords)
        if ($Records.Count -eq 0) {
            Write-Host "No software records found yet."
            Write-Host "Use Repository Manager > Scan Incoming to import software."
            Pause-Local
            return
        }
        $Index = 1
        $Map = @{}
        foreach ($R in $Records | Sort-Object destination,name,version) {
            Write-Host ("[{0}] {1}" -f $Index, $R.name)
            Write-Host ("     Type            : {0}" -f $R.type) -ForegroundColor DarkGray
            if ($R.version) { Write-Host ("     Version         : {0}" -f $R.version) -ForegroundColor DarkGray }
            Write-Host ("     Destination     : {0}" -f $R.destination) -ForegroundColor DarkGray
            Write-Host ("     Repository Path : {0}" -f $R.path) -ForegroundColor DarkGray
            $Map[[string]$Index] = $R
            $Index++
        }
        Write-Host ""
        Write-Host "Select software for details, or [B] Back"
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        if ($Choice -eq "B") { return }
        if ($Map.ContainsKey($Choice)) { Show-SoftwareDetails $Map[$Choice] }
    }
}

function Show-SoftwareDetails {
    param($Record)
    Show-LocalHeader "SOFTWARE DETAILS"
    Write-Host "Name:"
    Write-Host "  $($Record.name)"
    if ($Record.version) { Write-Host "Version:`n  $($Record.version)" }
    if ($Record.publisher) { Write-Host "Publisher:`n  $($Record.publisher)" }
    Write-Host "Type:"
    Write-Host "  $($Record.type)"
    Write-Host "Destination:"
    Write-Host "  $($Record.destination)"
    Write-Host "Repository Path:"
    Write-Host "  $($Record.path)"
    Write-Host "Imported:"
    Write-Host "  $($Record.imported)"
    Write-Host ""
    Write-Host "[1] Open Folder"
    Write-Host "[B] Back"
    $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
    if ($Choice -eq "1") {
        $Full = Join-Path $ToolkitRoot $Record.path
        $Folder = if (Test-Path $Full -PathType Container) { $Full } else { Split-Path -Parent $Full }
        Open-PathSafe $Folder
    }
}

function Show-SoftwareReport {
    Ensure-SoftwareSystem
    while ($true) {
        Show-LocalHeader "SOFTWARE REPORT"
        $Records = @(Get-SoftwareRecords)
        $Total = $Records.Count
        $InstallerCount = @($Records | Where-Object { $_.type -match 'Installer|MSI|MSIX|AppX|Update|Bootstrap' }).Count
        $PortableCount = @($Records | Where-Object { $_.type -match 'Portable' }).Count
        $IsoCount = @($Records | Where-Object { $_.type -match 'ISO|Disk' }).Count
        $CustomCount = @($Records | Where-Object { $_.destination -eq 'Custom' }).Count
        $CurrentCount = @($Records | Where-Object { $_.root_path -match '\\Current\\|/Current/' -or $_.path -match '\\Current\\|/Current/' }).Count
        $ArchivedCount = @($Records | Where-Object { $_.root_path -match '\\Previous\\|\\Versions\\|/Previous/|/Versions/' -or $_.path -match '\\Previous\\|\\Versions\\|/Previous/|/Versions/' }).Count
        $RepoSize = 0L
        if (Test-Path $SoftwareRoot) {
            Get-ChildItem -Path $SoftwareRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne '.keep' -and $_.Name -notlike '*.json' } | ForEach-Object { $RepoSize += $_.Length }
        }
        $SizeText = if ($RepoSize -ge 1GB) { "{0:N2} GB" -f ($RepoSize/1GB) } elseif ($RepoSize -ge 1MB) { "{0:N2} MB" -f ($RepoSize/1MB) } else { "{0:N0} KB" -f ($RepoSize/1KB) }
        Write-Host ("Total Software   : {0}" -f $Total)
        Write-Host ("Installers       : {0}" -f $InstallerCount)
        Write-Host ("Portable         : {0}" -f $PortableCount)
        Write-Host ("ISO/Disk Images  : {0}" -f $IsoCount)
        Write-Host ("Custom           : {0}" -f $CustomCount)
        Write-Host ("Current Versions : {0}" -f $CurrentCount)
        Write-Host ("Archived Versions: {0}" -f $ArchivedCount)
        Write-Host ("Repository Size  : {0}" -f $SizeText)
        Write-Host ""
        Write-Host "[V] View Software List"
        Write-Host "[M] Missing Software Report"
        Write-Host "[B] Back"
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        switch ($Choice) {
            "V" { Show-SoftwareRepository }
            "M" { Show-MissingSoftwareReport }
            "B" { return }
        }
    }
}

function Show-MissingSoftwareReport {
    Ensure-SoftwareSystem
    Show-LocalHeader "MISSING SOFTWARE REPORT"
    $Records = @(Get-SoftwareRecords)
    $Missing = @()
    foreach ($R in $Records) {
        $Path = Join-Path $ToolkitRoot $R.path
        if (-not (Test-Path $Path)) { $Missing += $R }
    }
    if ($Missing.Count -eq 0) {
        Write-Host "PASS: No missing software files found." -ForegroundColor Green
    } else {
        foreach ($R in $Missing) {
            Write-Host "[MISSING] $($R.name)" -ForegroundColor Yellow
            Write-Host "          Expected: $($R.path)" -ForegroundColor DarkGray
        }
    }
    Pause-Local
}

function Show-SupportedFormats {
    Ensure-SoftwareSystem
    $Core = Get-SoftwareCore
    Show-LocalHeader "SUPPORTED FORMATS"
    Write-Host "Local files and packages:"
    Write-Host "  EXE, MSI, MSIX, APPX, MSIXBUNDLE, APPXBUNDLE, MSP, MSU"
    Write-Host ""
    Write-Host "Disk and deployment images:"
    Write-Host "  ISO, IMG, WIM, ESD, FFU, VHD, VHDX"
    Write-Host ""
    Write-Host "Archives:"
    Write-Host "  ZIP, 7Z, RAR, TAR, GZ"
    Write-Host ""
    Write-Host "Portable applications:"
    Write-Host "  Portable EXE, extracted portable app folder, PortableApps .paf.exe package"
    Write-Host ""
    Write-Host "Remote sources:"
    Write-Host "  Winget, GitHub, Website link (planned/assisted)"
    Write-Host ""
    Write-Host "Scripts belong in Module Tool Manager, not Software Deployment Manager."
    Pause-Local
}

function Show-DeploymentHelp {
    while ($true) {
        Ensure-SoftwareSystem
        Show-LocalHeader "DEPLOYMENT RESOURCES & HELP"
        Write-Host "Offline resources are available first. Online links are optional."
        Write-Host ""
        Write-Host "[1] Open Offline Software Deployment Guide"
        Write-Host "[2] Open Offline Supported Formats Guide"
        Write-Host "[3] Winget Search Helper"
        Write-Host "[4] Open Winstall.app"
        Write-Host "[5] Open Microsoft Winget Documentation"
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        switch ($Choice) {
            "1" { Invoke-Item (Join-Path $DocsRoot "Software Deployment\Software_Deployment_Guide.txt") }
            "2" { Invoke-Item (Join-Path $DocsRoot "Software Deployment\Supported_Formats.txt") }
            "3" { Invoke-WingetHelper }
            "4" { Start-Process "https://winstall.app/" }
            "5" { Start-Process "https://learn.microsoft.com/en-us/windows/package-manager/winget/list" }
            "B" { return }
        }
    }
}

function Invoke-WingetHelper {
    Show-LocalHeader "WINGET HELPER"
    Write-Host "Winget is a remote software source. It does not store files in Repository\Software."
    Write-Host ""
    Write-Host "[1] Search Winget Repository"
    Write-Host "[2] List Installed Apps"
    Write-Host "[3] Find Installed App By Name"
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
    switch ($Choice) {
        "1" {
            $Q = Read-Host "Search term"
            if ($Q) { cmd.exe /c "winget search `"$Q`"" }
            Pause-Local
        }
        "2" { cmd.exe /c "winget list"; Pause-Local }
        "3" {
            $Q = Read-Host "App name"
            if ($Q) { cmd.exe /c "winget list --name `"$Q`"" }
            Pause-Local
        }
    }
}

function Open-PathSafe {
    param([string]$Path)
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    Invoke-Item $Path
}

function Show-SoftwareDeploymentManager {
    Ensure-SoftwareSystem
    while ($true) {
        Show-LocalHeader "SOFTWARE DEPLOYMENT MANAGER"
        Write-Host "Manage software already stored in the Repository. Incoming scans are handled by Repository Manager."
        Write-Host ""
        Write-Host "Software repository:"
        Write-Host "  Repository\Software\<Destination>\<Application Name>\"
        Write-Host ""
        Write-Host "[1] Create Module From Software"
        Write-Host "    Scan Incoming, import software, then create a launch/deployment module." -ForegroundColor DarkGray
        Write-Host "[2] Browse Software Repository"
        Write-Host "    View imported software records stored under Repository\Software\." -ForegroundColor DarkGray
        Write-Host "[3] Software Report"
        Write-Host "    Show counts, repository size, software list, and missing files." -ForegroundColor DarkGray
        Write-Host "[4] Winget Sources"
        Write-Host "    Search/list Winget packages and IDs." -ForegroundColor DarkGray
        Write-Host "[5] GitHub Sources"
        Write-Host "    Placeholder for saved GitHub source links." -ForegroundColor DarkGray
        Write-Host "[6] Software Help"
        Write-Host "    Offline guides first, optional online references second." -ForegroundColor DarkGray
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        switch ($Choice) {
            "1" { Invoke-ImportWorkflow }
            "2" { Show-SoftwareRepository }
            "3" { Show-SoftwareReport }
            "4" { Invoke-WingetHelper }
            "5" { Show-GitHubSourcesPlaceholder }
            "6" { Show-DeploymentHelp }
            "B" { return }
        }
    }
}


function Test-IsPackageCandidate {
    param([System.IO.FileSystemInfo]$Item)
    if ($Item.PSIsContainer) { return $false }
    $Ext = Get-RepositoryExtension $Item.FullName
    $Entry = Get-RepositoryFormatEntry $Ext
    return ($Entry -and $Entry.type -eq "Packages")
}

function Test-IsArchiveCandidate {
    param([System.IO.FileSystemInfo]$Item)
    if ($Item.PSIsContainer) { return $false }
    $Ext = Get-RepositoryExtension $Item.FullName
    $Entry = Get-RepositoryFormatEntry $Ext
    return ($Entry -and $Entry.type -eq "Archives")
}

function Test-IsDiskImageCandidate {
    param([System.IO.FileSystemInfo]$Item)
    if ($Item.PSIsContainer) { return $false }
    $Ext = Get-RepositoryExtension $Item.FullName
    $Entry = Get-RepositoryFormatEntry $Ext
    return ($Entry -and $Entry.type -eq "Disk Images")
}

function Get-GenericAssetDetection {
    param([System.IO.FileSystemInfo]$Item,[string]$Kind)
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($Item.Name)
    if ($Item.Name.ToLowerInvariant().EndsWith('.tar.gz')) { $BaseName = $Item.Name.Substring(0,$Item.Name.Length-7) }
    elseif ($Item.Name.ToLowerInvariant().EndsWith('.tar.bz2')) { $BaseName = $Item.Name.Substring(0,$Item.Name.Length-8) }
    elseif ($Item.Name.ToLowerInvariant().EndsWith('.tar.xz')) { $BaseName = $Item.Name.Substring(0,$Item.Name.Length-7) }
    $Ext = Get-RepositoryExtension $Item.FullName
    $FormatEntry = Get-RepositoryFormatEntry $Ext
    $Folder = switch ($Kind) { 'Package' { 'Packages' } 'Archive' { 'Archives' } 'Disk Image' { 'Disk Images' } default { 'Custom' } }
    $TypeName = $Kind
    $Format = $Ext.TrimStart('.').ToUpperInvariant()
    if ($FormatEntry) { $Folder = $FormatEntry.folder; $Format = $FormatEntry.format }
    $FriendlyBase = $BaseName -replace '_[a-z0-9]{13}$',''
    $FriendlyBase = $FriendlyBase -replace '\.',' '
    return [PSCustomObject]@{
        name=(ConvertTo-TitleName $FriendlyBase)
        repository_name=(Get-SafeRepositoryItemName $FriendlyBase)
        type=$TypeName
        repository_kind=$Kind
        source_path=$Item.FullName
        source_name=$Item.Name
        extension=$Ext
        format=$Format
        folder=$Folder
        imported=''
    }
}

function Import-GenericRepositoryAsset {
    param($Detection)
    $Root = switch ($Detection.repository_kind) {
        'Package' { $PackagesRoot }
        'Archive' { $ArchivesRoot }
        'Disk Image' { $DiskImagesRoot }
        default { $CustomRoot }
    }
    $SafeName = Get-SafeFolderName $Detection.repository_name
    if ($Detection.repository_kind -eq 'Custom' -and $Detection.PSObject.Properties.Name -contains 'custom_type' -and -not [string]::IsNullOrWhiteSpace($Detection.custom_type)) {
        $TypeFolder = Join-Path $Root (Get-SafeFolderName $Detection.custom_type)
        $TargetFolder = Join-Path $TypeFolder $SafeName
    } else {
        $TargetFolder = Join-Path $Root $SafeName
    }
    $TargetPath = Join-Path $TargetFolder $Detection.source_name
    Show-LocalHeader ("IMPORT {0}" -f ([string]$Detection.repository_kind).ToUpperInvariant())
    Write-Host "Name:"
    Write-Host "  $($Detection.name)"
    if ($Detection.PSObject.Properties.Name -contains 'detection_name' -and -not [string]::IsNullOrWhiteSpace([string]$Detection.detection_name)) {
        Write-Host "Detection:"
        Write-Host "  $($Detection.detection_name)"
        if ($Detection.PSObject.Properties.Name -contains 'detection_category' -and -not [string]::IsNullOrWhiteSpace([string]$Detection.detection_category)) {
            $DetCat = [string]$Detection.detection_category
            if ($Detection.PSObject.Properties.Name -contains 'detection_subcategory' -and -not [string]::IsNullOrWhiteSpace([string]$Detection.detection_subcategory)) { $DetCat = "$DetCat / $($Detection.detection_subcategory)" }
            Write-Host "Category:"
            Write-Host "  $DetCat"
        }
    } else {
        Write-Host "Format:"
        Write-Host "  $($Detection.format) ($($Detection.extension))"
    }
    Write-Host "Source:"
    Write-Host "  $($Detection.source_path)"
    Write-Host "Destination:"
    Write-Host "  $TargetPath"
    Write-Host ""
    Write-Host "[A] Import"
    Write-Host "[B] Back"
    $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
    if ($Choice -ne 'A') { return $null }
    try {
        if (-not (Test-Path $TargetFolder)) { New-Item -ItemType Directory -Path $TargetFolder -Force | Out-Null }
        Move-Item -LiteralPath $Detection.source_path -Destination $TargetPath -Force
    } catch {
        Write-Host "[ERROR] Import failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-RepositoryError -Context ("Import {0}: {1}" -f $Detection.repository_kind, $Detection.source_name) -Message $_.Exception.Message
        Pause-Local
        return $null
    }
    $Record = [PSCustomObject]@{
        name=$Detection.name
        type=$Detection.repository_kind
        format=$Detection.format
        extension=$Detection.extension
        path=($TargetPath.Replace($ToolkitRoot,'') -replace '^[\\/]+','')
        source_name=$Detection.source_name
        detection_name=$(if ($Detection.PSObject.Properties.Name -contains 'detection_name') { $Detection.detection_name } else { '' })
        detection_category=$(if ($Detection.PSObject.Properties.Name -contains 'detection_category') { $Detection.detection_category } else { '' })
        detection_subcategory=$(if ($Detection.PSObject.Properties.Name -contains 'detection_subcategory') { $Detection.detection_subcategory } else { '' })
        custom_type=$(if ($Detection.PSObject.Properties.Name -contains 'custom_type') { $Detection.custom_type } else { '' })
        imported=(Get-Date).ToString('s')
    }
    switch ($Detection.repository_kind) {
        'Package' { $Records=@(Get-PackageRecords); $Records += $Record; Save-PackageRecords $Records }
        'Archive' { $Records=@(Get-ArchiveRecords); $Records += $Record; Save-ArchiveRecords $Records }
        'Disk Image' { $Records=@(Get-DiskImageRecords); $Records += $Record; Save-DiskImageRecords $Records }
        'Custom' { $Records=@(Get-CustomRecords); $Records += $Record; Save-CustomRecords $Records }
    }
    Show-LocalHeader "IMPORT COMPLETE"
    Write-Host "Name:"
    Write-Host "  $($Record.name)"
    Write-Host "Repository Path:"
    Write-Host "  $($Record.path)"
    Write-Host "Action:"
    Write-Host "  Imported successfully"
    return $Record
}

function Get-GenericAssetRootsByKind {
    param([string]$Kind)
    switch ($Kind) {
        'Package' { return @($PackagesRoot) }
        'Archive' { return @($ArchivesRoot) }
        'Disk Image' { return @($DiskImagesRoot) }
        'Custom' { return @($CustomRoot) }
        default { return @() }
    }
}

function Get-GenericAssetRecordsFromFolders {
    param([string]$Kind)
    $Roots = @(Get-GenericAssetRootsByKind $Kind)
    $Out = @()
    foreach ($RootPath in $Roots) {
        if (-not (Test-Path $RootPath)) { continue }
        foreach ($File in @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne '.keep' -and $_.Name -notlike '*.json' })) {
            $Ext = Get-RepositoryExtension $File.FullName
            $Entry = Get-RepositoryFormatEntry $Ext
            if ($Kind -eq 'Package' -and $Entry.type -ne 'Packages') { continue }
            if ($Kind -eq 'Archive' -and $Entry.type -ne 'Archives') { continue }
            if ($Kind -eq 'Disk Image' -and $Entry.type -ne 'Disk Images') { continue }
            if ($Kind -eq 'Custom') {
                $StandardTypes = @(Get-StandardRepositoryTypeNames)
                if (-not $Entry -or ($StandardTypes -contains $Entry.type)) { continue }
            }
            $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
            if ($File.Name.ToLowerInvariant().EndsWith('.tar.gz')) { $BaseName = $File.Name.Substring(0,$File.Name.Length-7) }
            elseif ($File.Name.ToLowerInvariant().EndsWith('.tar.bz2')) { $BaseName = $File.Name.Substring(0,$File.Name.Length-8) }
            elseif ($File.Name.ToLowerInvariant().EndsWith('.tar.xz')) { $BaseName = $File.Name.Substring(0,$File.Name.Length-7) }
            $FriendlyBase = $BaseName -replace '_[a-z0-9]{13}$',''
            $FriendlyBase = $FriendlyBase -replace '\.',' '
            $Out += [PSCustomObject]@{
                name=(ConvertTo-TitleName $FriendlyBase)
                type=$Kind
                format=($(if ($Entry) { $Entry.format } else { $Ext.TrimStart('.').ToUpperInvariant() }))
                extension=$Ext
                path=$File.FullName.Replace($ToolkitRoot,'').TrimStart('\','/')
                source_name=$File.Name
                imported='Filesystem scan'
            }
        }
    }
    return @($Out)
}

function Sync-GenericAssetRecordsFromFolders {
    param([string]$Kind)
    $Existing = switch ($Kind) { 'Package' { @(Get-PackageRecords) } 'Archive' { @(Get-ArchiveRecords) } 'Disk Image' { @(Get-DiskImageRecords) } 'Custom' { @(Get-CustomRecords) } default { @() } }
    $ByPath = @{}
    foreach ($R in $Existing) { if ($R.path) { $ByPath[[string]$R.path] = $R } }
    foreach ($R in @(Get-GenericAssetRecordsFromFolders $Kind)) { if (-not $ByPath.ContainsKey([string]$R.path)) { $ByPath[[string]$R.path] = $R } }
    $Merged = @($ByPath.Values | Sort-Object type,name,path)
    switch ($Kind) { 'Package' { Save-PackageRecords $Merged } 'Archive' { Save-ArchiveRecords $Merged } 'Disk Image' { Save-DiskImageRecords $Merged } 'Custom' { Save-CustomRecords $Merged } }
    return @($Merged)
}

function Show-GenericAssetList {
    param([string]$Kind)
    $Records = @(Sync-GenericAssetRecordsFromFolders $Kind)
    Show-LocalHeader ("{0} REPOSITORY" -f $Kind.ToUpperInvariant())
    if ($Records.Count -eq 0) {
        Write-Host "No $Kind records found." -ForegroundColor Yellow
        Write-Host "Use Repository Manager > Scan Incoming to import supported files."
        Pause-Local
        return
    }
    $Map = @{}
    $i = 1
    foreach ($R in $Records) {
        Write-Host "[$i] $($R.name)"
        Write-Host "     Format          : $($R.format)"
        Write-Host "     Extension       : $($R.extension)"
        Write-Host "     Repository Path : $($R.path)" -ForegroundColor DarkGray
        $Map[[string]$i] = $R
        $i++
    }
    Write-Host ""
    Write-Host "Select item for details, or [B] Back"
    $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
    if ($Choice -eq 'B') { return }
    if ($Map.ContainsKey($Choice)) { Show-GenericAssetDetails $Map[$Choice] $Kind }
}

function Show-GenericAssetDetails {
    param($Record,[string]$Kind)
    while ($true) {
        Show-LocalHeader ("{0} DETAILS" -f $Kind.ToUpperInvariant())
        Write-Host "Name           : $($Record.name)"
        Write-Host "Type           : $Kind"
        Write-Host "Format         : $($Record.format)"
        Write-Host "Extension      : $($Record.extension)"
        Write-Host "Repository Path: $($Record.path)"
        Write-Host "Imported       : $($Record.imported)"
        Write-Host ""
        Write-Host "[1] Open Folder"
        Write-Host "[2] Open File"
        if ($Kind -eq 'Disk Image' -and $Record.extension -in @('.iso','.vhd','.vhdx')) { Write-Host "[3] Mount / Attach" }
        if ($Kind -eq 'Archive') { Write-Host "[3] Extract ZIP/TAR If Supported" }
        Write-Host "[B] Back"
        $Choice=(Read-Host "Selection").Trim().ToUpperInvariant()
        $FullPath = Join-Path $ToolkitRoot $Record.path
        switch ($Choice) {
            '1' { if (Test-Path $FullPath) { Open-PathSafe (Split-Path -Parent $FullPath) } }
            '2' { Open-PathSafe $FullPath }
            '3' {
                if ($Kind -eq 'Disk Image') { Invoke-DiskImageAction $FullPath $Record.extension }
                elseif ($Kind -eq 'Archive') { Invoke-ArchiveExtract $FullPath }
            }
            'B' { return }
        }
    }
}

function Invoke-DiskImageAction {
    param([string]$Path,[string]$Extension)
    Show-LocalHeader "DISK IMAGE ACTION"
    if (-not (Test-Path $Path)) { Write-Host "File not found: $Path" -ForegroundColor Yellow; Pause-Local; return }
    if ($Extension -eq '.iso') {
        Write-Host "PowerShell can mount ISO images with Mount-DiskImage."
        $Do = (Read-Host "Mount this ISO now? Y/N").Trim().ToUpperInvariant()
        if ($Do -in @('Y','YES')) { try { Mount-DiskImage -ImagePath $Path -ErrorAction Stop; Write-Host "ISO mount requested." -ForegroundColor Green } catch { Write-Host $_.Exception.Message -ForegroundColor Red; Write-RepositoryError -Context 'Disk image action' -Message $_.Exception.Message } }
    } elseif ($Extension -in @('.vhd','.vhdx')) {
        Write-Host "PowerShell can attach VHD/VHDX files with Mount-DiskImage."
        $Do = (Read-Host "Attach this virtual disk now? Y/N").Trim().ToUpperInvariant()
        if ($Do -in @('Y','YES')) { try { Mount-DiskImage -ImagePath $Path -ErrorAction Stop; Write-Host "Virtual disk attach requested." -ForegroundColor Green } catch { Write-Host $_.Exception.Message -ForegroundColor Red; Write-RepositoryError -Context 'Disk image action' -Message $_.Exception.Message } }
    } else {
        Write-Host "No mount action available yet for this image type."
        Write-Host "Open Folder or Open File can still be used."
    }
    Pause-Local
}

function Invoke-ArchiveExtract {
    param([string]$Path)
    Show-LocalHeader "ARCHIVE EXTRACT"
    if (-not (Test-Path $Path)) { Write-Host "File not found: $Path" -ForegroundColor Yellow; Pause-Local; return }
    $Ext = Get-RepositoryExtension $Path
    $Dest = Join-Path (Split-Path -Parent $Path) (([System.IO.Path]::GetFileNameWithoutExtension($Path)) + "_Extracted")
    Write-Host "Archive: $Path"
    Write-Host "Destination: $Dest"
    $Do = (Read-Host "Extract if supported by Windows? Y/N").Trim().ToUpperInvariant()
    if ($Do -notin @('Y','YES')) { return }
    try {
        if ($Ext -eq '.zip') { Expand-Archive -LiteralPath $Path -DestinationPath $Dest -Force }
        else { & tar.exe -xf $Path -C (Split-Path -Parent $Path) }
        Write-Host "Extract command completed/requested." -ForegroundColor Green
    } catch { Write-Host "Extract failed: $($_.Exception.Message)" -ForegroundColor Red; Write-RepositoryError -Context ("Archive extract: $Path") -Message $_.Exception.Message }
    Pause-Local
}

function Show-RepositoryFormatsTable {
    Show-LocalHeader "SUPPORTED REPOSITORY ASSETS"
    Write-Host "Type            Formats"
    Write-Host "----            --------------------------"
    Write-Host "Software        EXE, MSI"
    Write-Host "Packages        APPX, APPXBUNDLE, MSIX, MSIXBUNDLE"
    Write-Host "Scripts         PS1"
    Write-Host "Documents       TXT, MD, PDF, RTF, DOC, DOCX, XLSX, PPTX..."
    Write-Host "Archives        ZIP, 7Z, RAR, CAB, TAR, GZ, BZ2, XZ..."
    Write-Host "Disk Images     ISO, IMG, WIM, ESD, FFU, VHD, VHDX"
    Write-Host "Custom          User learned custom asset types"
    Write-Host ""
    Write-Host "Search supports extensions with or without dots, such as pdf/.pdf, xlsx/.xlsx, tar/.tar, gz/.gz, iso/.iso."
    Pause-Local
}

function Show-RepositoryAssetsManager {
    while ($true) {
        Show-LocalHeader "ARCHIVES, PACKAGES & DISK IMAGES"
        Write-Host "Manage repository assets that are not normal modules, scripts, documents, or EXE/MSI installers."
        Write-Host ""
        Write-Host "[1] Packages"
        Write-Host "    APPX, APPXBUNDLE, MSIX, MSIXBUNDLE" -ForegroundColor DarkGray
        Write-Host "[2] Archives"
        Write-Host "    ZIP, 7Z, RAR, CAB, TAR, GZ, BZ2, XZ" -ForegroundColor DarkGray
        Write-Host "[3] Disk Images"
        Write-Host "    ISO, IMG, WIM, ESD, FFU, VHD, VHDX" -ForegroundColor DarkGray
        Write-Host "[4] Custom"
        Write-Host "    Browse learned custom repository asset types." -ForegroundColor DarkGray
        Write-Host "[5] Supported Formats"
        Write-Host "[B] Back"
        $Choice=(Read-Host "Selection").Trim().ToUpperInvariant()
        switch ($Choice) {
            '1' { Show-GenericAssetList 'Package' }
            '2' { Show-GenericAssetList 'Archive' }
            '3' { Show-GenericAssetList 'Disk Image' }
            '4' { Show-GenericAssetList 'Custom' }
            '5' { Show-RepositoryFormatsTable }
            'B' { return }
        }
    }
}

function Show-RepositoryManager {
    Ensure-SoftwareSystem
    while ($true) {
        Show-LocalHeader "REPOSITORY MANAGER"
        Write-Host "Incoming is the universal drop box. Repository is managed storage."
        Write-Host ""
        Write-Host "Incoming:"
        Write-Host "  Incoming\"
        Write-Host "Repository:"
        Write-Host "  Repository\"
        Write-Host ""
        Write-Host "[1] Scan Incoming"
        Write-Host "    Scan files and folders placed in Incoming\." -ForegroundColor DarkGray
        Write-Host "[2] Open Incoming"
        Write-Host "    Open the universal incoming drop folder." -ForegroundColor DarkGray
        Write-Host "[3] Browse Repository"
        Write-Host "    Open the managed Repository folder." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[4] Software Deployment Manager"
        Write-Host "    Manage software, installers, portable apps, Winget, and GitHub sources." -ForegroundColor DarkGray
        Write-Host "[5] Script Repository"
        Write-Host "    Store, organize, review, and create modules from PowerShell scripts." -ForegroundColor DarkGray
        Write-Host "[6] Document Repository"
        Write-Host "    Store, organize, and open PDFs, TXT, DOCX, MD, RTF, guides, and reference files." -ForegroundColor DarkGray
        Write-Host "[7] Packages, Archives & Disk Images"
        Write-Host "    Manage APPX/MSIX packages, archives, ISO/WIM/ESD/FFU/VHD disk images, and extraction/mount actions." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[8] Repository Report"
        Write-Host "    View repository statistics, inventory counts, and storage usage." -ForegroundColor DarkGray
        Write-Host "[9] Repository Help"
        Write-Host "    Open offline repository and deployment help." -ForegroundColor DarkGray
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        switch ($Choice) {
            "1" { Invoke-ImportWorkflow }
            "2" { Open-PathSafe $IncomingRoot }
            "3" { Open-PathSafe $RepositoryRoot }
            "4" { Show-SoftwareDeploymentManager }
            "5" { Show-ScriptRepository }
            "6" { Show-DocumentRepository }
            "7" { Show-RepositoryAssetsManager }
            "8" { Show-RepositoryReport }
            "9" { Show-DeploymentHelp }
            "B" { return }
        }
    }
}


function Show-RepositoryBrowseMenu {
    Ensure-SoftwareSystem
    while ($true) {
        Show-LocalHeader "BROWSE REPOSITORY"
        Write-Host "Browse managed repository items by type."
        Write-Host ""
        Write-Host "[1] Software"
        Write-Host "    Browse imported software, installers, portable apps, and deployment packages." -ForegroundColor DarkGray
        Write-Host "[2] Scripts"
        Write-Host "    Browse PowerShell scripts stored in Repository\Scripts." -ForegroundColor DarkGray
        Write-Host "[3] Documents"
        Write-Host "    Browse PDFs, TXT, DOCX, MD, RTF, guides, and reference files." -ForegroundColor DarkGray
        Write-Host "[4] Packages"
        Write-Host "    Browse APPX, APPXBUNDLE, MSIX, and MSIXBUNDLE packages." -ForegroundColor DarkGray
        Write-Host "[5] Archives"
        Write-Host "    Browse ZIP, 7Z, RAR, CAB, TAR, GZ, BZ2, XZ archives." -ForegroundColor DarkGray
        Write-Host "[6] Disk Images"
        Write-Host "    Browse ISO, IMG, WIM, ESD, FFU, VHD, and VHDX files." -ForegroundColor DarkGray
        Write-Host "[7] Custom"
        Write-Host "    Browse learned custom repository asset types." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        switch ($Choice) {
            "1" { Show-SoftwareRepository }
            "2" { Show-ScriptList }
            "3" { Show-DocumentList }
            "4" { Show-GenericAssetList 'Package' }
            "5" { Show-GenericAssetList 'Archive' }
            "6" { Show-GenericAssetList 'Disk Image' }
            "7" { Show-GenericAssetList 'Custom' }
            "F" { Show-FullRepositoryReport }
            "B" { return }
        }
    }
}

function Show-GitHubSourcesPlaceholder {
    Show-LocalHeader "GITHUB SOURCES"
    Write-Host "GitHub source saving/downloading is planned for a future Repository Manager build."
    Write-Host "For now, download files manually and place them in Incoming\."
    Pause-Local
}

if ($HelpOnly) {
    Ensure-SoftwareSystem
    Show-DeploymentHelp
    return
}

if ($BrowseOnly) {
    Ensure-SoftwareSystem
    Show-RepositoryBrowseMenu
    return
}

Show-RepositoryManager
