$ErrorActionPreference = "Continue"
$ToolkitRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$ModulesRoot = Join-Path $ToolkitRoot "Modules"
$TemplatesRoot = Join-Path $ToolkitRoot "Module Templates"
$CoreDefaultsPath = Join-Path $ToolkitRoot "Config\metadata.core.json"
if (-not (Test-Path $CoreDefaultsPath)) { $CoreDefaultsPath = Join-Path $ToolkitRoot "Core\metadata.defaults.json" }
$UserLibraryPath = Join-Path $ToolkitRoot "Config\metadata.library.json"
$MetadataBackupRoot = Join-Path $ToolkitRoot "Config\Backups"
$LogPath = Join-Path $ToolkitRoot "Logs\framework_test.log"

function Write-TestLog {
    param([string]$Level, [string]$Area, [string]$Action, [string]$Message)
    try {
        $dir = Split-Path $LogPath -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        Add-Content -Path $LogPath -Value "$stamp | $Level | $Area | $Action | $Message"
    } catch {}
}

function Show-Header {
    param([string]$Title)
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-BuilderContextHeader {
    param($Context)
    if ($null -eq $Context) { return }
    $script:BuilderContextPrinted = $false
    function Write-BuilderContextLine([string]$Label, [object]$Value) {
        if ($null -eq $Value) { return }
        $Text = [string]$Value
        if ([string]::IsNullOrWhiteSpace($Text)) { return }
        Write-Host ("{0}:" -f $Label) -ForegroundColor DarkGray
        Write-Host ("  {0}" -f $Text)
        $script:BuilderContextPrinted = $true
    }
    $Name = $null; $Type = $null; $Category = $null; $Subcategory = $null; $Source = $null
    if ($Context -is [hashtable]) {
        if ($Context.ContainsKey('Name')) { $Name = $Context['Name'] }
        if ($Context.ContainsKey('Type')) { $Type = $Context['Type'] }
        if ($Context.ContainsKey('Category')) { $Category = $Context['Category'] }
        if ($Context.ContainsKey('Subcategory')) { $Subcategory = $Context['Subcategory'] }
        if ($Context.ContainsKey('Source')) { $Source = $Context['Source'] }
    }
    Write-BuilderContextLine "Current Item" $Name
    Write-BuilderContextLine "Type" $Type
    if (-not [string]::IsNullOrWhiteSpace([string]$Category) -and -not [string]::IsNullOrWhiteSpace([string]$Subcategory)) {
        Write-BuilderContextLine "Category" ("{0} / {1}" -f $Category,$Subcategory)
    } elseif (-not [string]::IsNullOrWhiteSpace([string]$Category)) {
        Write-BuilderContextLine "Category" $Category
    }
    Write-BuilderContextLine "Source" $Source
    if ($script:BuilderContextPrinted) {
        Write-Host ""
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host ""
    }
}

function Pause-Return {
    Read-Host "Press Enter to continue" | Out-Null
}

function Sanitize-Name {
    param([string]$Name)
    $clean = ($Name -replace '[^a-zA-Z0-9_\- ]','').Trim()
    $clean = ($clean -replace '\s+','_')
    return $clean
}

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

function Normalize-MetadataValue {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    $v = ($Value -replace '\s+', ' ').Trim()
    $known = @{
        'dns'='DNS'; 'dhcp'='DHCP'; 'ip'='IP'; 'vpn'='VPN'; 'wifi'='WiFi'; 'wi-fi'='Wi-Fi';
        'sfc'='SFC'; 'dism'='DISM'; 'rsat'='RSAT'; 'winget'='Winget'; 'importexcel'='ImportExcel';
        'azure'='Azure'; 'intune'='Intune'; 'autopilot'='Autopilot'; 'entra'='Entra'; 'm365'='M365';
        'it'='IT'; 'aio'='AIO'; 'edmorse'='Ed Morse'; 'flextg'='FlexTG'
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

function Backup-UserMetadataLibrary {
    try {
        if (-not (Test-Path $UserLibraryPath)) { return }
        if (-not (Test-Path $MetadataBackupRoot)) { New-Item -ItemType Directory -Path $MetadataBackupRoot -Force | Out-Null }
        $bak = Join-Path $MetadataBackupRoot 'metadata.library.bak'
        $prev = Join-Path $MetadataBackupRoot 'metadata.library.previous.bak'
        if (Test-Path $bak) { Copy-Item -Path $bak -Destination $prev -Force }
        Copy-Item -Path $UserLibraryPath -Destination $bak -Force
    } catch {}
}

function Save-UserMetadataLibrary {
    param($Object)
    Backup-UserMetadataLibrary
    Save-JsonFile -Path $UserLibraryPath -Object $Object
}

function ConvertTo-Array {
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [array]) { return @($Value) }
    return @($Value)
}

function Load-JsonFile {
    param([string]$Path, $Fallback)
    try {
        if (Test-Path $Path) {
            return (Get-Content -Path $Path -Raw | ConvertFrom-Json)
        }
    } catch {}
    return $Fallback
}

function Save-JsonFile {
    param([string]$Path, $Object)
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    ($Object | ConvertTo-Json -Depth 12) | Set-Content -Path $Path -Encoding UTF8
}

function Ensure-UserLibrary {
    if (-not (Test-Path $UserLibraryPath)) {
        Save-JsonFile -Path $UserLibraryPath -Object (New-EmptyLibraryObject)
    }
    if (-not (Test-Path $MetadataBackupRoot)) { New-Item -ItemType Directory -Path $MetadataBackupRoot -Force | Out-Null }
    $bak = Join-Path $MetadataBackupRoot 'metadata.library.bak'
    $prev = Join-Path $MetadataBackupRoot 'metadata.library.previous.bak'
    if (-not (Test-Path $bak)) { Copy-Item -Path $UserLibraryPath -Destination $bak -Force }
    if (-not (Test-Path $prev)) { Copy-Item -Path $UserLibraryPath -Destination $prev -Force }
}

function Get-Library {
    Ensure-UserLibrary
    $core = Load-JsonFile -Path $CoreDefaultsPath -Fallback (New-EmptyLibraryObject)
    $user = Load-JsonFile -Path $UserLibraryPath -Fallback (New-EmptyLibraryObject)
    return [ordered]@{ Core = $core; User = $user }
}

function Get-MergedList {
    param([string]$Section)
    $lib = Get-Library
    $vals = @()
    if ($lib.Core.PSObject.Properties.Name -contains $Section) { $vals += ConvertTo-Array $lib.Core.$Section }
    if ($lib.User.PSObject.Properties.Name -contains $Section) { $vals += ConvertTo-Array $lib.User.$Section }
    return @($vals | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { ([string]$_).Trim() } | Sort-Object -Unique)
}

function Get-MergedSubcategories {
    param([string]$Category)
    $lib = Get-Library
    $vals = @()
    foreach ($source in @($lib.Core, $lib.User)) {
        try {
            if ($source.subcategories.PSObject.Properties.Name -contains $Category) {
                $vals += ConvertTo-Array $source.subcategories.$Category
            }
        } catch {}
    }
    return @($vals | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { ([string]$_).Trim() } | Sort-Object -Unique)
}

function Add-ToUserLibrary {
    param([string]$Section, [string]$Value, [string]$Parent = "")
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    $clean = Normalize-MetadataValue $Value
    if ([string]::IsNullOrWhiteSpace($clean)) { return }

    # Do not copy Core defaults into the editable library. The manager should only show learned/custom values.
    $core = Load-JsonFile -Path $CoreDefaultsPath -Fallback (New-EmptyLibraryObject)
    if ($Section -eq "subcategories") {
        try {
            if ($core.subcategories.PSObject.Properties.Name -contains $Parent) {
                $coreExisting = @(ConvertTo-Array $core.subcategories.$Parent)
                if ($coreExisting | Where-Object { $_.ToString().Trim().ToLower() -eq $clean.ToLower() }) { return }
            }
        } catch {}
    } elseif ($core.PSObject.Properties.Name -contains $Section) {
        $coreExisting = @(ConvertTo-Array $core.$Section)
        if ($coreExisting | Where-Object { $_.ToString().Trim().ToLower() -eq $clean.ToLower() }) { return }
    }

    Ensure-UserLibrary
    $user = Load-JsonFile -Path $UserLibraryPath -Fallback (New-EmptyLibraryObject)

    if ($Section -eq "subcategories") {
        if ([string]::IsNullOrWhiteSpace($Parent)) { return }
        if ($null -eq $user.subcategories) { $user | Add-Member -MemberType NoteProperty -Name subcategories -Value ([ordered]@{}) -Force }
        if ($user.subcategories.PSObject.Properties.Name -notcontains $Parent) {
            $user.subcategories | Add-Member -MemberType NoteProperty -Name $Parent -Value @() -Force
        }
        $existing = @(ConvertTo-Array $user.subcategories.$Parent)
        if (-not ($existing | Where-Object { $_.ToString().Trim().ToLower() -eq $clean.ToLower() })) {
            $user.subcategories.$Parent = @($existing + $clean | Sort-Object -Unique)
            Save-UserMetadataLibrary -Object $user
        }
        return
    }

    if ($user.PSObject.Properties.Name -notcontains $Section -or $null -eq $user.$Section) {
        $user | Add-Member -MemberType NoteProperty -Name $Section -Value @() -Force
    }
    $existing = @(ConvertTo-Array $user.$Section)
    if (-not ($existing | Where-Object { $_.ToString().Trim().ToLower() -eq $clean.ToLower() })) {
        $user.$Section = @($existing + $clean | Sort-Object -Unique)
        Save-UserMetadataLibrary -Object $user
    }
}

function Read-Required {
    param([string]$Prompt, [string]$Default = "")
    while ($true) {
        if ($Default) { $v = Read-Host "$Prompt [$Default]" } else { $v = Read-Host $Prompt }
        if ([string]::IsNullOrWhiteSpace($v) -and $Default) { return $Default }
        if (-not [string]::IsNullOrWhiteSpace($v)) { return $v.Trim() }
        Write-Host "Value required." -ForegroundColor Yellow
    }
}

function Read-YN {
    param([string]$Prompt, [bool]$Default = $false)
    $d = if ($Default) { "Y" } else { "N" }
    while ($true) {
        $v = (Read-Host "$Prompt (Y/N) [$d]").Trim().ToUpper()
        if ([string]::IsNullOrWhiteSpace($v)) { return $Default }
        if ($v -in @('Y','YES')) { return $true }
        if ($v -in @('N','NO')) { return $false }
        Write-Host "Enter Y or N." -ForegroundColor Yellow
    }
}

function Select-SingleChoice {
    param(
        [string]$Title,
        [string[]]$Items,
        [string]$Default = "",
        [switch]$AllowCustom,
        [switch]$AllowNone
    )
    while ($true) {
        Write-Host ""
        Write-Host $Title -ForegroundColor Yellow
        for ($i=0; $i -lt $Items.Count; $i++) { Write-Host "[$($i+1)] $($Items[$i])" }
        if ($AllowNone) { Write-Host "[N] None" }
        if ($AllowCustom) { Write-Host "[C] Custom" }
        if ($Default) { Write-Host "[Enter] $Default" -ForegroundColor DarkGray }
        $raw = (Read-Host "Selection").Trim()
        if ([string]::IsNullOrWhiteSpace($raw) -and $Default) { return $Default }
        if ($AllowNone -and $raw.ToUpper() -eq "N") { return "" }
        if ($AllowCustom -and $raw.ToUpper() -eq "C") {
            $custom = Read-Required "Custom value"
            return $custom
        }
        $n = 0
        if ([int]::TryParse($raw, [ref]$n) -and $n -ge 1 -and $n -le $Items.Count) {
            $selected = $Items[$n-1]
            Write-Host "Selected: $selected" -ForegroundColor Green
            Read-Host "Press Enter to accept, or type R to reselect" | ForEach-Object { if ($_.Trim().ToUpper() -eq 'R') { $script:__reselect = $true } else { $script:__reselect = $false } }
            if (-not $script:__reselect) { return $selected }
        } else {
            Write-Host "Invalid selection." -ForegroundColor Yellow
        }
    }
}

function Select-MultipleChoices {
    param(
        [string]$Title,
        [string[]]$Items,
        [string[]]$Default = @(),
        [switch]$AllowCustom,
        [switch]$AllowNone,
        $Context = $null
    )
    while ($true) {
        Show-Header $Title
        Show-BuilderContextHeader $Context
        Write-Host "Example: 1,6,13" -ForegroundColor DarkGray
        for ($i=0; $i -lt $Items.Count; $i++) { Write-Host "[$($i+1)] $($Items[$i])" }
        if ($AllowNone) { Write-Host "[N] None" }
        if ($AllowCustom) { Write-Host "[C] Custom" }
        if ($Default.Count -gt 0) { Write-Host "[Enter] Accept suggested: $($Default -join ', ')" -ForegroundColor DarkGray }
        $raw = (Read-Host "Selection").Trim()
        if ([string]::IsNullOrWhiteSpace($raw) -and $Default.Count -gt 0) { $chosen = @($Default) }
        elseif ($AllowNone -and $raw.ToUpper() -eq "N") { $chosen = @() }
        elseif ($AllowCustom -and $raw.ToUpper() -eq "C") {
            $custom = Read-Host "Custom values comma-separated"
            $chosen = @($custom -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        } else {
            $chosen = @()
            foreach ($part in ($raw -split ',')) {
                $p = $part.Trim()
                $n = 0
                if ([int]::TryParse($p, [ref]$n) -and $n -ge 1 -and $n -le $Items.Count) { $chosen += $Items[$n-1] }
            }
            if ($chosen.Count -eq 0 -and $raw) { Write-Host "No valid selections." -ForegroundColor Yellow; continue }
        }
        $chosen = @($chosen | Where-Object { $_ } | Sort-Object -Unique)
        Write-Host ""
        Write-Host "Selected:" -ForegroundColor Green
        if ($chosen.Count -eq 0) { Write-Host "  None" } else { $chosen | ForEach-Object { Write-Host "  $_" } }
        $confirm = (Read-Host "Press Enter to accept, R to reselect, or C to add custom").Trim().ToUpper()
        if ($confirm -eq "R") { continue }
        if ($confirm -eq "C") {
            $custom = Read-Host "Additional custom values comma-separated"
            $chosen += @($custom -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            $chosen = @($chosen | Sort-Object -Unique)
        }
        return $chosen
    }
}



function Get-CoreMetadataList {
    param([string]$Section)
    $lib = Get-Library
    $vals = @()
    if ($lib.Core.PSObject.Properties.Name -contains $Section) { $vals = @(ConvertTo-Array $lib.Core.$Section) }
    return @($vals | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { Normalize-MetadataValue ([string]$_) } | Sort-Object -Unique)
}

function Get-UserMetadataList {
    param([string]$Section)
    $lib = Get-Library
    $vals = @()
    if ($lib.User.PSObject.Properties.Name -contains $Section) { $vals = @(ConvertTo-Array $lib.User.$Section) }
    return @($vals | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { Normalize-MetadataValue ([string]$_) } | Sort-Object -Unique)
}

function Get-CoreMetadataSubcategories {
    param([string]$Category)
    $lib = Get-Library
    $vals = @()
    try {
        if ($lib.Core.subcategories.PSObject.Properties.Name -contains $Category) { $vals += ConvertTo-Array $lib.Core.subcategories.$Category }
    } catch {}
    return @($vals | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { Normalize-MetadataValue ([string]$_) } | Sort-Object -Unique)
}

function Get-UserMetadataSubcategories {
    param([string]$Category)
    $lib = Get-Library
    $vals = @()
    try {
        if ($lib.User.subcategories.PSObject.Properties.Name -contains $Category) { $vals += ConvertTo-Array $lib.User.subcategories.$Category }
    } catch {}
    return @($vals | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { Normalize-MetadataValue ([string]$_) } | Sort-Object -Unique)
}

function Get-AllMetadataSubcategories {
    $lib = Get-Library
    $vals = @()
    foreach ($source in @($lib.Core, $lib.User)) {
        try {
            foreach ($p in $source.subcategories.PSObject.Properties) {
                $vals += ConvertTo-Array $p.Value
            }
        } catch {}
    }
    return @($vals | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { Normalize-MetadataValue ([string]$_) } | Sort-Object -Unique)
}

function Select-BrowseAllSubcategory {
    param([string]$CurrentCategory)
    while ($true) {
        $items = @(Get-AllMetadataSubcategories)
        Write-Host ""
        Write-Host "Browse All Subcategories" -ForegroundColor Yellow
        Write-Host "Use this when the recommended list for '$CurrentCategory' does not fit." -ForegroundColor DarkGray
        Write-Host ""
        if ($items.Count -eq 0) {
            Write-Host "No subcategories are available yet." -ForegroundColor DarkGray
        }
        else {
            for ($i=0; $i -lt $items.Count; $i++) { Write-Host "[$($i+1)] $($items[$i])" }
        }
        Write-Host ""
        Write-Host "[C] Custom"
        Write-Host "[B] Back"
        $raw = (Read-Host "Selection").Trim()
        if ($raw.ToUpperInvariant() -eq 'B') { return $null }
        if ($raw.ToUpperInvariant() -eq 'C') { return (Normalize-MetadataValue (Read-Required "Custom subcategory")) }
        $n = 0
        if ([int]::TryParse($raw, [ref]$n) -and $n -ge 1 -and $n -le $items.Count) { return $items[$n-1] }
        Write-Host "Invalid selection." -ForegroundColor Yellow
    }
}

function Select-MetadataSingleChoice {
    param(
        [string]$Title,
        [string]$Section,
        [string]$Default = "",
        [switch]$AllowCustom,
        [switch]$AllowNone,
        [string]$ParentCategory = "",
        $Context = $null
    )
    while ($true) {
        $core = @()
        $user = @()
        if ($Section -eq 'subcategories') {
            $core = @(Get-CoreMetadataSubcategories -Category $ParentCategory)
            $user = @(Get-UserMetadataSubcategories -Category $ParentCategory)
        }
        else {
            $core = @(Get-CoreMetadataList -Section $Section)
            $user = @(Get-UserMetadataList -Section $Section)
        }

        $items = @()
        Show-Header $Title
        Show-BuilderContextHeader $Context
        if ($Section -eq 'subcategories' -and $ParentCategory) { Write-Host "Category: $ParentCategory" -ForegroundColor DarkGray }
        Write-Host "Core defaults are protected. User entries are learned/custom." -ForegroundColor DarkGray
        Write-Host ""

        if ($core.Count -gt 0) {
            if ($Section -eq 'subcategories') { Write-Host "Recommended Core choices:" -ForegroundColor Cyan } else { Write-Host "Core choices:" -ForegroundColor Cyan }
            foreach ($v in $core) { $items += $v; Write-Host "[$($items.Count)] $v" }
        }
        else { Write-Host "Core choices: none" -ForegroundColor DarkGray }

        Write-Host ""
        if ($user.Count -gt 0) {
            if ($Section -eq 'subcategories') { Write-Host "Recommended User choices:" -ForegroundColor Cyan } else { Write-Host "User learned choices:" -ForegroundColor Cyan }
            foreach ($v in $user) { $items += $v; Write-Host "[$($items.Count)] $v" }
        }
        else { Write-Host "User learned choices: none yet" -ForegroundColor DarkGray }

        Write-Host ""
        if ($Section -eq 'subcategories' -and $ParentCategory) {
            Write-Host "[M] Browse All Subcategories"
        }
        if ($AllowNone) { Write-Host "[N] None" }
        if ($AllowCustom) { Write-Host "[C] Custom" }
        if ($Default) { Write-Host "[Enter] $Default" -ForegroundColor DarkGray }

        $raw = (Read-Host "Selection").Trim()
        if ([string]::IsNullOrWhiteSpace($raw) -and $Default) { return $Default }
        if ($AllowNone -and $raw.ToUpperInvariant() -eq 'N') { return "" }
        if ($Section -eq 'subcategories' -and $ParentCategory -and $raw.ToUpperInvariant() -eq 'M') {
            $browse = Select-BrowseAllSubcategory -CurrentCategory $ParentCategory
            if ($null -ne $browse) { return $browse }
            continue
        }
        if ($AllowCustom -and $raw.ToUpperInvariant() -eq 'C') {
            $custom = Read-Required "Custom value"
            return (Normalize-MetadataValue $custom)
        }
        $n = 0
        if ([int]::TryParse($raw, [ref]$n) -and $n -ge 1 -and $n -le $items.Count) {
            $selected = $items[$n-1]
            Write-Host "Selected: $selected" -ForegroundColor Green
            $confirm = (Read-Host "Press Enter to accept, or R to reselect").Trim().ToUpperInvariant()
            if ($confirm -ne 'R') { return $selected }
        }
        else { Write-Host "Invalid selection." -ForegroundColor Yellow }
    }
}

function Select-MetadataMultipleChoice {
    param(
        [string]$Title,
        [string]$Section,
        [string[]]$Default = @(),
        [switch]$AllowCustom,
        [switch]$AllowNone,
        $Context = $null
    )
    while ($true) {
        $core = @(Get-CoreMetadataList -Section $Section)
        $user = @(Get-UserMetadataList -Section $Section)
        $items = @()

        Show-Header $Title
        Show-BuilderContextHeader $Context
        Write-Host "Example: 1,6,13" -ForegroundColor DarkGray
        Write-Host "Core defaults are protected. User entries are learned/custom." -ForegroundColor DarkGray
        Write-Host ""

        if ($core.Count -gt 0) {
            if ($Section -eq 'subcategories') { Write-Host "Recommended Core choices:" -ForegroundColor Cyan } else { Write-Host "Core choices:" -ForegroundColor Cyan }
            foreach ($v in $core) { $items += $v; Write-Host "[$($items.Count)] $v" }
        }
        else { Write-Host "Core choices: none" -ForegroundColor DarkGray }

        Write-Host ""
        if ($user.Count -gt 0) {
            if ($Section -eq 'subcategories') { Write-Host "Recommended User choices:" -ForegroundColor Cyan } else { Write-Host "User learned choices:" -ForegroundColor Cyan }
            foreach ($v in $user) { $items += $v; Write-Host "[$($items.Count)] $v" }
        }
        else { Write-Host "User learned choices: none yet" -ForegroundColor DarkGray }

        Write-Host ""
        if ($AllowNone) { Write-Host "[N] None" }
        if ($AllowCustom) { Write-Host "[C] Custom" }
        if ($Default.Count -gt 0) { Write-Host "[Enter] Accept suggested: $($Default -join ', ')" -ForegroundColor DarkGray }

        $raw = (Read-Host "Selection").Trim()
        if ([string]::IsNullOrWhiteSpace($raw) -and $Default.Count -gt 0) { $chosen = @($Default) }
        elseif ($AllowNone -and $raw.ToUpperInvariant() -eq 'N') { $chosen = @() }
        elseif ($AllowCustom -and $raw.ToUpperInvariant() -eq 'C') {
            $custom = Read-Host "Custom values comma-separated"
            $chosen = @($custom -split ',' | ForEach-Object { Normalize-MetadataValue $_ } | Where-Object { $_ })
        }
        else {
            $chosen = @()
            foreach ($part in ($raw -split ',')) {
                $p = $part.Trim()
                $n = 0
                if ([int]::TryParse($p, [ref]$n) -and $n -ge 1 -and $n -le $items.Count) { $chosen += $items[$n-1] }
            }
            if ($chosen.Count -eq 0 -and $raw) { Write-Host "No valid selections." -ForegroundColor Yellow; continue }
        }

        $chosen = @($chosen | ForEach-Object { Normalize-MetadataValue ([string]$_) } | Where-Object { $_ } | Sort-Object -Unique)
        Write-Host ""
        Write-Host "Selected:" -ForegroundColor Green
        if ($chosen.Count -eq 0) { Write-Host "  None" } else { $chosen | ForEach-Object { Write-Host "  $_" } }
        $confirm = (Read-Host "Press Enter to accept, R to reselect, or C to add custom").Trim().ToUpperInvariant()
        if ($confirm -eq 'R') { continue }
        if ($confirm -eq 'C') {
            $custom = Read-Host "Additional custom values comma-separated"
            $chosen += @($custom -split ',' | ForEach-Object { Normalize-MetadataValue $_ } | Where-Object { $_ })
            $chosen = @($chosen | Sort-Object -Unique)
        }
        return $chosen
    }
}

function Get-GeneratedDescription {
    param([string]$Name, [string]$Category, [string]$Subcategory, [string]$Type = "tool")
    if ($Type -eq "Website") { return "Opens the $Name website or web resource." }
    if ($Type -eq "Installer") { return "Launches the $Name installer or setup file." }
    return "Runs the $Name module."
}

function Get-AutoKeywords {
    param([string]$Name, [string]$Description, [string]$Category, [string]$Subcategory)
    $words = @()
    foreach ($part in @($Name, $Description, $Category, $Subcategory)) {
        foreach ($w in ($part -split '[^a-zA-Z0-9]+')) {
            $lw = $w.Trim().ToLower()
            if ($lw.Length -ge 3 -and $lw -notin @('the','and','for','with','this','that','runs','module','tool')) { $words += $lw }
        }
    }
    return @($words | Sort-Object -Unique | Select-Object -First 12)
}

function Read-ModuleDetails {
    param([string]$Type = "Module", [string]$SuggestedName = "")
    $Context = @{ Name=$SuggestedName; Type=$Type; Category=""; Subcategory=""; Source="Add Module Builder" }
    Show-Header "MODULE DETAILS"
    Show-BuilderContextHeader $Context
    Write-Host "Framework suggests values where possible. User decides final values." -ForegroundColor DarkGray
    Write-Host "Custom values are automatically learned into Config\metadata.library.json." -ForegroundColor DarkGray
    Write-Host ""

    if (-not [string]::IsNullOrWhiteSpace($SuggestedName)) {
        Write-Host "Suggested module display name:" -ForegroundColor Yellow
        Write-Host "  $SuggestedName"
        Write-Host "Press Enter to accept, or type your own name." -ForegroundColor DarkGray
        $DisplayName = Read-Required "Module display name" $SuggestedName
    }
    else {
        $DisplayName = Read-Required "Module display name"
    }
    $FolderName = Sanitize-Name $DisplayName
    $Context['Name'] = $DisplayName

    Write-Host ""
    Write-Host "Category examples:" -ForegroundColor DarkGray
    Write-Host "  Diagnostics = checks/reporting" -ForegroundColor DarkGray
    Write-Host "  Windows Repair = fixes/reset tools" -ForegroundColor DarkGray
    Write-Host "  Setup and Install = installers/setup scripts" -ForegroundColor DarkGray
    Write-Host "  Custom Tools = personal/manual tools" -ForegroundColor DarkGray
    $Category = Select-MetadataSingleChoice -Title "Choose Category" -Section "categories" -Default "Custom Tools" -AllowCustom -Context $Context
    Add-ToUserLibrary -Section "categories" -Value $Category
    $Context['Category'] = $Category

    Write-Host ""
    Write-Host "Subcategory examples:" -ForegroundColor DarkGray
    Write-Host "  Audit Tools = reports/checks" -ForegroundColor DarkGray
    Write-Host "  Repair Tools = fixes/resets" -ForegroundColor DarkGray
    Write-Host "  Shortcuts = websites/folders/apps" -ForegroundColor DarkGray
    $Subcategory = Select-MetadataSingleChoice -Title "Choose Subcategory" -Section "subcategories" -ParentCategory $Category -AllowCustom -AllowNone -Context $Context
    if ($Subcategory) { Add-ToUserLibrary -Section "subcategories" -Parent $Category -Value $Subcategory }
    $Context['Subcategory'] = $Subcategory

    $suggestedDescription = Get-GeneratedDescription -Name $DisplayName -Category $Category -Subcategory $Subcategory -Type $Type
    Write-Host ""
    Write-Host "Description examples:" -ForegroundColor DarkGray
    Write-Host "  Runs a custom diagnostic script." -ForegroundColor DarkGray
    Write-Host "  Repairs common Windows issues." -ForegroundColor DarkGray
    Write-Host "  Opens a support website." -ForegroundColor DarkGray
    Write-Host "Suggested description:" -ForegroundColor Yellow
    Write-Host "  $suggestedDescription"
    $descChoice = (Read-Host "Press Enter to accept, or C for custom").Trim().ToUpper()
    if ($descChoice -eq "C") { $Description = Read-Required "Custom description" } else { $Description = $suggestedDescription }
    Add-ToUserLibrary -Section "description_templates" -Value $Description

    Write-Host ""
    Write-Host "Risk examples:" -ForegroundColor DarkGray
    Write-Host "  Safe = read-only or informational" -ForegroundColor DarkGray
    Write-Host "  Moderate = changes files/settings or may need admin" -ForegroundColor DarkGray
    Write-Host "  Dangerous = registry edits, deletes, resets, repairs, destructive actions" -ForegroundColor DarkGray
    while ($true) {
        $riskRaw = (Read-Host "Risk [S] Safe  [M] Moderate  [D] Dangerous").Trim().ToUpper()
        if ([string]::IsNullOrWhiteSpace($riskRaw)) { $riskRaw = "S" }
        if ($riskRaw -eq "S") { $Risk = "Safe"; break }
        if ($riskRaw -eq "M") { $Risk = "Moderate"; break }
        if ($riskRaw -eq "D") { $Risk = "Dangerous"; break }
        Write-Host "Choose S, M, or D." -ForegroundColor Yellow
    }
    Write-Host "Selected: $Risk" -ForegroundColor Green
    $Admin = Read-YN "Requires admin" ($Risk -ne "Safe")

    $autoKeywords = Get-AutoKeywords -Name $DisplayName -Description $Description -Category $Category -Subcategory $Subcategory
    $keywordDefault = @($autoKeywords | Select-Object -First 8)
    $Keywords = Select-MetadataMultipleChoice -Title "Choose Common Keywords" -Section "keywords" -Default $keywordDefault -AllowCustom -Context $Context
    foreach ($kw in $Keywords) { Add-ToUserLibrary -Section "keywords" -Value $kw }

    $Dependencies = Select-MetadataMultipleChoice -Title "Choose Dependencies" -Section "dependencies" -AllowCustom -AllowNone -Context $Context
    foreach ($dep in $Dependencies) { Add-ToUserLibrary -Section "dependencies" -Value $dep }

    return [ordered]@{
        DisplayName = $DisplayName
        FolderName = $FolderName
        Description = $Description
        Category = $Category
        Subcategory = $Subcategory
        Risk = $Risk
        RequiresAdmin = $Admin
        Keywords = @($Keywords)
        Dependencies = @($Dependencies)
    }
}

function Get-DefaultRunBat {
@'
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
'@
}

function Get-ModuleHeader {
    param([string]$ModuleName)
    if ([string]::IsNullOrWhiteSpace($ModuleName)) { $ModuleName = "Module Template" }
@"
# ============================================================
# WINDOWS MODULAR TOOLKIT
# $ModuleName
# ============================================================
"@
}

function Test-HasStandardHeader {
    param([string]$Content)
    return ($Content -match '(?m)^#\s*=+' -and $Content -match 'WINDOWS MODULAR TOOLKIT')
}

function Add-Ps1HeaderIfMissing {
    param([string]$Content, [string]$ModuleName)
    if ([string]::IsNullOrWhiteSpace($Content)) { $Content = "" }
    if (Test-HasStandardHeader -Content $Content) { return $Content }
    return ((Get-ModuleHeader -ModuleName $ModuleName) + [Environment]::NewLine + [Environment]::NewLine + $Content.TrimStart())
}


function Invoke-ScriptAnalysisStep {
    param([string]$Content, [string]$ModuleName)

    Show-Header "SCRIPT ANALYSIS"
    Write-Host "Module: $ModuleName" -ForegroundColor DarkGray
    Write-Host ""

    if ([string]::IsNullOrWhiteSpace($Content)) {
        Write-Host "WARN: Script content is empty." -ForegroundColor Yellow
        Write-Host "The module will be created, but run.ps1 will not do anything yet." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "[Enter] Continue anyway"
        Write-Host "[E] Return to paste editor"
        Write-Host "[C] Cancel"
        $choice = (Read-Host "Selection").Trim().ToUpper()
        if ($choice -eq 'E') { return 'Edit' }
        if ($choice -eq 'C') { return 'Cancel' }
        return 'Continue'
    }

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) {
        Write-Host "FAIL: PowerShell syntax check found $($errors.Count) issue(s)." -ForegroundColor Red
        Write-Host ""
        foreach ($err in $errors) {
            Write-Host "Line $($err.Extent.StartLineNumber), Column $($err.Extent.StartColumnNumber)" -ForegroundColor Yellow
            Write-Host "  $($err.Message)" -ForegroundColor Red
            Write-Host ""
        }
        Write-Host "Recommended action: return to the paste editor and fix the script before creating the module." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[E] Return to paste editor"
        Write-Host "[C] Cancel module creation"
        Write-Host "[A] Create anyway"
        while ($true) {
            $choice = (Read-Host "Selection").Trim().ToUpper()
            if ($choice -eq 'E') { return 'Edit' }
            if ($choice -eq 'C') { return 'Cancel' }
            if ($choice -eq 'A') { return 'Continue' }
            Write-Host "Choose E, C, or A." -ForegroundColor Yellow
        }
    }

    Write-Host "PASS: PowerShell syntax valid." -ForegroundColor Green

    $commandAsts = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true))
    $commands = @()
    foreach ($cmdAst in $commandAsts) {
        try {
            $name = $cmdAst.GetCommandName()
            if (-not [string]::IsNullOrWhiteSpace($name)) { $commands += $name }
        } catch {}
    }
    $commands = @($commands | Sort-Object -Unique)

    $lines = @($Content -split "`r?`n")
    $nonCommentLines = @($lines | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') })

    Write-Host ""
    Write-Host "Script Statistics:" -ForegroundColor Yellow
    Write-Host "  Lines              : $($lines.Count)"
    Write-Host "  Non-comment lines  : $($nonCommentLines.Count)"
    Write-Host "  Commands detected  : $($commands.Count)"

    if ($commands.Count -gt 0) {
        Write-Host ""
        Write-Host "Detected Commands:" -ForegroundColor Yellow
        $commands | Select-Object -First 20 | ForEach-Object { Write-Host "  - $_" }
        if ($commands.Count -gt 20) { Write-Host "  ...and $($commands.Count - 20) more" -ForegroundColor DarkGray }
    }

    $warnings = @()
    $dangerous = @('Remove-Item','Clear-Content','Set-ItemProperty','Remove-ItemProperty','New-ItemProperty','Format-Volume','Clear-Disk','Remove-Partition','bcdedit','diskpart','reg','Restart-Computer','Stop-Computer','Disable-LocalUser','Remove-LocalUser')
    $adminLikely = @('sfc','dism','ipconfig','netsh','Restart-Service','Stop-Service','Start-Service','Set-Service','Get-Printer','Add-Printer','Remove-Printer','winget','choco','msiexec')
    $outputOnly = @('Write-Host','Read-Host','Pause','Clear-Host')

    $lowerCommands = @($commands | ForEach-Object { $_.ToLowerInvariant() })
    $dangerHits = @($commands | Where-Object { $dangerous | ForEach-Object { if ($_.ToLowerInvariant() -eq ([string]$_).ToLowerInvariant()) {} } })
    $dangerHits = @()
    foreach ($c in $commands) { foreach ($d in $dangerous) { if ($c.ToLowerInvariant() -eq $d.ToLowerInvariant()) { $dangerHits += $c } } }
    $adminHits = @()
    foreach ($c in $commands) { foreach ($a in $adminLikely) { if ($c.ToLowerInvariant() -eq $a.ToLowerInvariant()) { $adminHits += $c } } }

    $meaningfulCommands = @()
    foreach ($c in $commands) {
        $isOutput = $false
        foreach ($o in $outputOnly) { if ($c.ToLowerInvariant() -eq $o.ToLowerInvariant()) { $isOutput = $true } }
        if (-not $isOutput) { $meaningfulCommands += $c }
    }

    if ($commands.Count -eq 0) { $warnings += "No PowerShell commands detected. The script may not do anything." }
    elseif ($meaningfulCommands.Count -eq 0) { $warnings += "Only output/pause commands detected. This may be a test or placeholder script." }

    $pauseHits = @()
    foreach ($c in $commands) {
        if ($c.ToLowerInvariant() -in @('pause','read-host')) { $pauseHits += $c }
    }
    if ($pauseHits.Count -gt 0) {
        $warnings += "Pause/input command detected ($(@($pauseHits | Select-Object -Unique) -join ', ')). The toolkit already pauses after module execution; keep this only if the script needs user input mid-run."
    }

    $qualityWarnings = @()
    $commandPattern = '(?i)\b(Write-Host|Start-Process|Invoke-Item|Remove-Item|Set-Item|New-Item|Get-ChildItem|Get-Item|Copy-Item|Move-Item|Restart-Computer|Stop-Computer)\b'
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $matches = [regex]::Matches($lines[$i], $commandPattern)
        if ($matches.Count -gt 1) { $qualityWarnings += "Suspicious line $($i+1): multiple command names appear on one line. Possible pasted commands ran together." }
    }
    $warnings += $qualityWarnings

    $suggestedRisk = 'Safe'
    if ($dangerHits.Count -gt 0) { $suggestedRisk = 'Dangerous' }
    elseif ($adminHits.Count -gt 0) { $suggestedRisk = 'Moderate' }

    $suggestedAdmin = if ($adminHits.Count -gt 0 -or $dangerHits.Count -gt 0) { 'Yes / Maybe' } else { 'No' }

    Write-Host ""
    Write-Host "Suggestions:" -ForegroundColor Yellow
    Write-Host "  Suggested Risk       : $suggestedRisk"
    Write-Host "  Suggested Admin Need : $suggestedAdmin"

    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "Warnings:" -ForegroundColor Yellow
        foreach ($w in $warnings) { Write-Host "  - $w" -ForegroundColor Yellow }
    }

    Write-Host ""
    Write-Host "Continue to module preview?" -ForegroundColor Cyan
    Write-Host "[Enter] Continue"
    Write-Host "[E] Return to paste editor"
    Write-Host "[C] Cancel"
    $choice = (Read-Host "Selection").Trim().ToUpper()
    if ($choice -eq 'E') { return 'Edit' }
    if ($choice -eq 'C') { return 'Cancel' }
    return 'Continue'
}


function Invoke-TemplateAnalysisStep {
    param([string]$Content, [string]$ModuleName)

    Show-Header "TEMPLATE ANALYSIS"
    Write-Host "Module: $ModuleName" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Template Type:" -ForegroundColor Yellow
    Write-Host "  Blank Module Template"
    Write-Host ""
    Write-Host "This module will be created with a generic run.ps1 placeholder." -ForegroundColor Yellow
    Write-Host "It will not perform real work until run.ps1 is edited." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Created files will include:" -ForegroundColor Yellow
    Write-Host "  run.bat"
    Write-Host "  run.ps1"
    Write-Host "  tool.json"
    Write-Host ""
    Write-Host "Continue to module preview?" -ForegroundColor Cyan
    Write-Host "[Enter] Continue"
    Write-Host "[E] Return to module source selection"
    Write-Host "[C] Cancel"
    $choice = (Read-Host "Selection").Trim().ToUpper()
    if ($choice -eq 'E') { return 'Edit' }
    if ($choice -eq 'C') { return 'Cancel' }
    return 'Continue'
}

function Invoke-NoScriptContentStep {
    Show-Header "NO SCRIPT CONTENT DETECTED"
    Write-Host "No PowerShell content was pasted or imported." -ForegroundColor Yellow
    Write-Host "The builder will not analyze the blank/template file as if it was user script." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "[P] Return to paste editor"
    Write-Host "[T] Use Blank Template instead"
    Write-Host "[C] Cancel module creation"
    while ($true) {
        $choice = (Read-Host "Selection").Trim().ToUpper()
        if ($choice -eq 'P') { return 'Edit' }
        if ($choice -eq 'T') { return 'Template' }
        if ($choice -eq 'C') { return 'Cancel' }
        Write-Host "Choose P, T, or C." -ForegroundColor Yellow
    }
}

function Get-ModuleDisplayNameFromFolder {
    param([string]$FolderPath)
    $jsonPath = Join-Path $FolderPath "tool.json"
    if (Test-Path $jsonPath) {
        try {
            $j = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
            if ($j.name) { return [string]$j.name }
        } catch { }
    }
    return (Split-Path $FolderPath -Leaf)
}

function Get-BlankRunPs1 {
    param([string]$ModuleName = "Module Template")
    $body = @'

Clear-Host
Write-Host "============================================================"
Write-Host " WINDOWS MODULAR TOOLKIT MODULE"
Write-Host "============================================================"
Write-Host ""
Write-Host "This is a blank module template."
Write-Host "Edit run.ps1 to add your module logic."
Write-Host ""
Write-Host "Output note: the toolkit launcher pauses after this script returns."
Write-Host "If run.bat is double-clicked directly, run.bat pauses before closing."
'@
    return (Get-ModuleHeader -ModuleName $ModuleName) + $body
}

function New-ToolJsonObject {
    param($Details, [string]$SourceLabel = "Add Module Builder")
    [ordered]@{
        name = $Details.DisplayName
        category = $Details.Category
        subcategory = $Details.Subcategory
        description = $Details.Description
        keywords = @($Details.Keywords)
        risk = $Details.Risk
        requires_admin = [bool]$Details.RequiresAdmin
        supports_logs = $false
        supports_export = $false
        entry = "run.bat"
        dependencies = @($Details.Dependencies | Where-Object { $_ -and ([string]$_).Trim().ToLowerInvariant() -notin @("none","n/a","na","no dependencies") })
        hidden = $false
        source = $SourceLabel
    }
}

function Preview-And-CreateModule {
    param($Details, [string]$RunPs1Content, [string]$SourceLabel = "Add Module Builder", [switch]$BlankTemplate)
    $Target = Join-Path $ModulesRoot $Details.FolderName
    if (Test-Path $Target) {
        Write-Host "Module folder already exists: $($Details.FolderName)" -ForegroundColor Red
        Pause-Return
        return
    }

    while ($true) {
        if ($BlankTemplate) {
            $analysisResult = Invoke-TemplateAnalysisStep -Content $RunPs1Content -ModuleName $Details.DisplayName
        }
        else {
            # Analyze only the user's pasted/imported content. Do not add the standard header first,
            # because that makes an empty paste look like a valid script.
            if ([string]::IsNullOrWhiteSpace($RunPs1Content)) {
                $emptyChoice = Invoke-NoScriptContentStep
                if ($emptyChoice -eq 'Cancel') { return }
                if ($emptyChoice -eq 'Template') {
                    $RunPs1Content = Get-BlankRunPs1 -ModuleName $Details.DisplayName
                    $BlankTemplate = $true
                    continue
                }
                if ($emptyChoice -eq 'Edit') {
                    $RunPs1Content = Read-PastedContent "POWERSHELL SCRIPT"
                    continue
                }
            }
            $analysisResult = Invoke-ScriptAnalysisStep -Content $RunPs1Content -ModuleName $Details.DisplayName
        }
        if ($analysisResult -eq 'Continue') { break }
        if ($analysisResult -eq 'Cancel') { return }
        if ($analysisResult -eq 'Edit') {
            if ($BlankTemplate) {
                return (Create-EmptyTemplate)
            }
            else {
                $RunPs1Content = Read-PastedContent "POWERSHELL SCRIPT"
            }
        }
    }

    $tool = New-ToolJsonObject -Details $Details -SourceLabel $SourceLabel
    Show-Header "PREVIEW MODULE"
    Write-Host "Folder:" -ForegroundColor Yellow
    Write-Host "  $Target"
    Write-Host ""
    Write-Host "Files to create:" -ForegroundColor Yellow
    Write-Host "  run.bat"
    Write-Host "  run.ps1"
    Write-Host "  tool.json"
    Write-Host ""
    Write-Host "Metadata:" -ForegroundColor Yellow
    Write-Host "  Name        : $($tool.name)"
    Write-Host "  Category    : $($tool.category)"
    Write-Host "  Subcategory : $($tool.subcategory)"
    Write-Host "  Risk        : $($tool.risk)"
    Write-Host "  Admin       : $($tool.requires_admin)"
    Write-Host "  Entry       : $($tool.entry)"
    Write-Host "  Keywords    : $(@($tool.keywords) -join ', ')"
    Write-Host "  Dependencies: $(@($tool.dependencies) -join ', ')"
    Write-Host ""
    $ok = Read-YN "Create this module" $true
    if (-not $ok) { return }

    New-Item -ItemType Directory -Path $Target -Force | Out-Null
    Set-Content -Path (Join-Path $Target "run.bat") -Value (Get-DefaultRunBat) -Encoding ASCII
    $finalPs1 = Add-Ps1HeaderIfMissing -Content $RunPs1Content -ModuleName $Details.DisplayName
    Set-Content -Path (Join-Path $Target "run.ps1") -Value $finalPs1 -Encoding UTF8
    Save-JsonFile -Path (Join-Path $Target "tool.json") -Object $tool

    Show-Header "MODULE CREATED"
    Write-Host "Created: $Target" -ForegroundColor Green
    Write-Host ""
    Write-Host "Created files:" -ForegroundColor Yellow
    Write-Host "  run.bat"
    Write-Host "  run.ps1"
    Write-Host "  tool.json"
    Write-Host ""
    Write-Host "What would you like to do?"
    Write-Host "[1] Open Module Folder"
    Write-Host "[2] Modify PowerShell Script"
    Write-Host "[3] Modify Batch Script"
    Write-Host "[B] Back"
    $choice = (Read-Host "Selection").Trim().ToUpper()
    switch ($choice) {
        "1" { Start-Process explorer.exe $Target }
        "2" { Edit-TextFile -Path (Join-Path $Target "run.ps1") -Title "MODIFY POWERSHELL SCRIPT" }
        "3" { Edit-TextFile -Path (Join-Path $Target "run.bat") -Title "MODIFY BATCH SCRIPT" }
    }
    Write-TestLog "PASS" "Add Module Builder" "Create Module" "$($Details.DisplayName) -> $($Details.FolderName)"
}

function Select-ModuleFolder {
    Show-Header "SELECT MODULE FOLDER"
    if (-not (Test-Path $ModulesRoot)) { New-Item -ItemType Directory -Path $ModulesRoot -Force | Out-Null }
    $modules = @(Get-ChildItem -Path $ModulesRoot -Directory | Sort-Object Name)
    if ($modules.Count -eq 0) {
        Write-Host "No module folders found." -ForegroundColor Yellow
        Pause-Return
        return $null
    }
    for ($i=0; $i -lt $modules.Count; $i++) { Write-Host "[$($i+1)] $($modules[$i].Name)" }
    Write-Host "[C] Choose folder manually"
    Write-Host "[B] Back"
    while ($true) {
        $raw = (Read-Host "Selection").Trim().ToUpper()
        if ($raw -eq "B") { return $null }
        if ($raw -eq "C") {
            $p = Read-Required "Folder path"
            $p = $p.Trim('"')
            if (Test-Path $p) { return $p }
            Write-Host "Folder not found." -ForegroundColor Red
            continue
        }
        $n = 0
        if ([int]::TryParse($raw, [ref]$n) -and $n -ge 1 -and $n -le $modules.Count) { return $modules[$n-1].FullName }
        Write-Host "Invalid selection." -ForegroundColor Yellow
    }
}

function Show-FilePreview {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host "File not found: $Path" -ForegroundColor Yellow
        return
    }
    Write-Host "Current file:" -ForegroundColor Yellow
    Write-Host "----------------------------------------"
    try {
        $lines = @(Get-Content -Path $Path -ErrorAction Stop)
        $max = [Math]::Min($lines.Count, 80)
        for ($i=0; $i -lt $max; $i++) { Write-Host $lines[$i] }
        if ($lines.Count -gt 80) { Write-Host "... preview truncated. Open in Notepad to view full file." -ForegroundColor DarkGray }
    } catch { Write-Host "Could not read file." -ForegroundColor Red }
    Write-Host "----------------------------------------"
}

function Read-PastedContent {
    param([string]$Label)
    Show-Header "PASTE $Label"
    Write-Host "Paste content below." -ForegroundColor Yellow
    Write-Host "Type END on its own line when finished." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Output / pause standard:" -ForegroundColor Cyan
    Write-Host "  - Do NOT add PAUSE just to keep output visible." -ForegroundColor DarkGray
    Write-Host "  - The toolkit pauses after the module returns." -ForegroundColor DarkGray
    Write-Host "  - Direct double-click runs are protected by run.bat." -ForegroundColor DarkGray
    Write-Host "  - Only add Read-Host/Pause when the script itself truly needs user input." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Large multi-line pastes may trigger a console paste warning. Choose Yes/Allow if expected." -ForegroundColor DarkGray
    Write-Host ""
    $lines = New-Object System.Collections.Generic.List[string]
    while ($true) {
        $line = [Console]::ReadLine()
        if ($null -eq $line) { break }
        if ($line.Trim() -eq "END") { break }
        $lines.Add($line)
    }
    return ($lines -join [Environment]::NewLine)
}


function Test-PowerShellScriptQuality {
    param([string]$Path)
    $warnings = @()
    if (-not (Test-Path $Path)) { return $warnings }
    $lines = @(Get-Content -Path $Path -ErrorAction SilentlyContinue)
    $commandPattern = '(?i)\b(Write-Host|Start-Process|Invoke-Item|Remove-Item|Set-Item|New-Item|Get-ChildItem|Get-Item|Copy-Item|Move-Item|Restart-Computer|Stop-Computer)\b'
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $matches = [regex]::Matches($line, $commandPattern)
        if ($matches.Count -gt 1) {
            $warnings += "Suspicious line $($i+1): multiple PowerShell commands appear on one line. Possible pasted commands ran together."
        }
    }
    return $warnings
}


function Test-PowerShellScriptFile {
    param([string]$Path)
    Show-Header "VALIDATE POWERSHELL SCRIPT"
    Write-Host "File: $Path" -ForegroundColor DarkGray
    Write-Host ""
    if (-not (Test-Path $Path)) {
        Write-Host "FAIL: File not found." -ForegroundColor Red
        Pause-Return
        return
    }
    try {
        $content = Get-Content -Path $Path -Raw -ErrorAction Stop
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors) | Out-Null
        if ($errors -and $errors.Count -gt 0) {
            Write-Host "FAIL: PowerShell syntax check found $($errors.Count) issue(s)." -ForegroundColor Red
            Write-Host ""
            foreach ($err in $errors) {
                $line = $err.Extent.StartLineNumber
                $col = $err.Extent.StartColumnNumber
                Write-Host "Line $line, Column $col" -ForegroundColor Yellow
                Write-Host "  $($err.Message)" -ForegroundColor Red
                if ($line -gt 0) {
                    $fileLines = @(Get-Content -Path $Path -ErrorAction SilentlyContinue)
                    if ($line -le $fileLines.Count) { Write-Host "  > $($fileLines[$line-1])" -ForegroundColor DarkGray }
                }
                Write-Host ""
            }
            Write-Host "Suggestion: choose [3] Open in Notepad, fix the listed line(s), then test again." -ForegroundColor Cyan
            Write-TestLog "FAIL" "Add Module Builder" "Validate PowerShell Script" "$Path"
        }
        else {
            Write-Host "PASS: PowerShell syntax check passed." -ForegroundColor Green
            Write-Host "No parse errors found." -ForegroundColor Green
            $qualityWarnings = @(Test-PowerShellScriptQuality -Path $Path)
            if ($qualityWarnings.Count -gt 0) {
                Write-Host ""
                Write-Host "Warnings:" -ForegroundColor Yellow
                foreach ($warn in $qualityWarnings) { Write-Host " - $warn" -ForegroundColor Yellow }
                Write-Host "Suggestion: open the script and verify pasted lines did not run together." -ForegroundColor Cyan
                Write-TestLog "WARN" "Add Module Builder" "Validate PowerShell Script" "$Path"
            } else {
                Write-TestLog "PASS" "Add Module Builder" "Validate PowerShell Script" "$Path"
            }
        }
    } catch {
        Write-Host "FAIL: Could not test script." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-TestLog "FAIL" "Add Module Builder" "Validate PowerShell Script" "$($_.Exception.Message)"
    }
    Pause-Return
}

function Edit-TextFile {
    param([string]$Path, [string]$Title)
    while ($true) {
        Show-Header $Title
        Write-Host "File: $Path" -ForegroundColor DarkGray
        Write-Host ""
        Show-FilePreview -Path $Path
        Write-Host ""
        Write-Host "[1] Replace file by pasting content"
        Write-Host "[2] Append pasted content"
        Write-Host "[3] Open in Notepad"
        Write-Host "[4] Open module folder"
        if ([IO.Path]::GetExtension($Path).ToLower() -eq ".ps1") {
            Write-Host "[5] Validate Script"
            Write-Host "[6] Add/Repair standard header"
        }
        Write-Host "[B] Back"
        $choice = (Read-Host "Selection").Trim().ToUpper()
        switch ($choice) {
            "1" {
                $new = Read-PastedContent $Title
                if ($new.Trim()) {
                    if ([IO.Path]::GetExtension($Path).ToLower() -eq ".ps1") {
                        $moduleName = Get-ModuleDisplayNameFromFolder -FolderPath (Split-Path $Path -Parent)
                        $new = Add-Ps1HeaderIfMissing -Content $new -ModuleName $moduleName
                    }
                    Set-Content -Path $Path -Value $new -Encoding UTF8
                    Write-Host "File replaced." -ForegroundColor Green
                    Pause-Return
                }
                else { Write-Host "No content entered." -ForegroundColor Yellow; Pause-Return }
            }
            "2" {
                $new = Read-PastedContent $Title
                if ($new.Trim()) { Add-Content -Path $Path -Value $new -Encoding UTF8; Write-Host "Content appended." -ForegroundColor Green; Pause-Return }
                else { Write-Host "No content entered." -ForegroundColor Yellow; Pause-Return }
            }
            "3" { Start-Process notepad.exe $Path }
            "4" { Start-Process explorer.exe (Split-Path $Path -Parent) }
            "5" {
                if ([IO.Path]::GetExtension($Path).ToLower() -eq ".ps1") { Test-PowerShellScriptFile -Path $Path }
                else { Write-Host "Test Script is only available for PowerShell files." -ForegroundColor Yellow; Pause-Return }
            }
            "6" {
                if ([IO.Path]::GetExtension($Path).ToLower() -eq ".ps1") {
                    $moduleName = Get-ModuleDisplayNameFromFolder -FolderPath (Split-Path $Path -Parent)
                    $current = ""
                    if (Test-Path $Path) { $current = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue }
                    $fixed = Add-Ps1HeaderIfMissing -Content $current -ModuleName $moduleName
                    Set-Content -Path $Path -Value $fixed -Encoding UTF8
                    Write-Host "Standard header added/repaired." -ForegroundColor Green
                    Pause-Return
                }
                else { Write-Host "Header repair is only available for PowerShell files." -ForegroundColor Yellow; Pause-Return }
            }
            "B" { return }
        }
    }
}

function Select-ModuleSourceContent {
    param($Details)
    while ($true) {
        Show-Header "MODULE SOURCE"
        Write-Host "Choose how run.ps1 should be created." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[1] Paste PowerShell Script"
        Write-Host "    Paste script content, then type END on its own line."
        Write-Host "    Output is kept visible by the launcher; PAUSE is not required."
        Write-Host "[2] Import Existing Script"
        Write-Host "    Copy content from an existing .ps1 file."
        Write-Host "[3] Use Blank Template"
        Write-Host "    Create a safe placeholder run.ps1 to edit later."
        Write-Host ""
        Write-Host "[B] Back"
        $choice = (Read-Host "Selection").Trim().ToUpper()
        switch ($choice) {
            "1" {
                $content = Read-PastedContent "POWERSHELL SCRIPT"
                return [ordered]@{ Content = $content; BlankTemplate = $false; SourceLabel = "Pasted PowerShell script" }
            }
            "2" {
                $path = Read-Required "Existing .ps1 path"
                $path = $path.Trim('"')
                if (-not (Test-Path $path)) { Write-Host "File not found." -ForegroundColor Red; Pause-Return; continue }
                try {
                    $content = Get-Content -Path $path -Raw -ErrorAction Stop
                    return [ordered]@{ Content = $content; BlankTemplate = $false; SourceLabel = "Imported script: $path" }
                } catch {
                    Write-Host "Could not read file: $($_.Exception.Message)" -ForegroundColor Red
                    Pause-Return
                }
            }
            "3" {
                return [ordered]@{ Content = (Get-BlankRunPs1 -ModuleName $Details.DisplayName); BlankTemplate = $true; SourceLabel = "Blank template" }
            }
            "B" { return $null }
        }
    }
}

function Create-EmptyTemplate {
    $details = Read-ModuleDetails -Type "Module"
    $source = Select-ModuleSourceContent -Details $details
    if ($null -eq $source) { return }
    Preview-And-CreateModule -Details $details -RunPs1Content $source.Content -SourceLabel $source.SourceLabel -BlankTemplate:([bool]$source.BlankTemplate)
}

function Modify-PowerShellScript {
    $folder = Select-ModuleFolder
    if (-not $folder) { return }
    Edit-TextFile -Path (Join-Path $folder "run.ps1") -Title "MODIFY POWERSHELL SCRIPT"
}

function Modify-BatchScript {
    $folder = Select-ModuleFolder
    if (-not $folder) { return }
    $bat = Join-Path $folder "run.bat"
    if (-not (Test-Path $bat)) {
        Write-Host "run.bat not found. Create default launcher?" -ForegroundColor Yellow
        if (Read-YN "Create run.bat" $true) { Set-Content -Path $bat -Value (Get-DefaultRunBat) -Encoding ASCII }
        else { return }
    }
    Edit-TextFile -Path $bat -Title "MODIFY BATCH SCRIPT"
}

function Normalize-WebsiteUrl {
    param([string]$Url)
    $u = ($Url | ForEach-Object { [string]$_ }).Trim().Trim('"')
    if ([string]::IsNullOrWhiteSpace($u) -or $u -eq "https://" -or $u -eq "http://") { return "" }
    if ($u -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') { $u = "https://$u" }
    return $u
}

function Select-InstallerPath {
    Show-Header "SELECT INSTALLER"
    Write-Host "Choose an installer by scanning Incoming and Repository software folders, or enter a path manually." -ForegroundColor DarkGray
    Write-Host ""

    $scanRoots = @(
        (Join-Path $ToolkitRoot "Incoming"),
        (Join-Path $ToolkitRoot "Repository\Software"),
        (Join-Path $ToolkitRoot "Downloads")
    ) | Where-Object { Test-Path $_ }

    $installers = @()
    foreach ($root in $scanRoots) {
        $installers += @(Get-ChildItem -Path $root -Recurse -File -Include *.exe,*.msi,*.msix,*.msixbundle -ErrorAction SilentlyContinue)
    }
    $installers = @($installers | Sort-Object FullName -Unique)

    if ($installers.Count -gt 0) {
        Write-Host "Found installers:" -ForegroundColor Yellow
        for ($i=0; $i -lt $installers.Count; $i++) {
            $rel = $installers[$i].FullName.Replace($ToolkitRoot.Path, '').TrimStart('\')
            Write-Host "[$($i+1)] $rel"
        }
        Write-Host ""
        Write-Host "[M] Manual path"
        Write-Host "[R] Rescan"
        Write-Host "[B] Back"
        while ($true) {
            $raw = (Read-Host "Selection").Trim().ToUpper()
            if ($raw -eq 'B') { return $null }
            if ($raw -eq 'R') { return (Select-InstallerPath) }
            if ($raw -eq 'M') {
                $manual = Read-Required "Installer path"
                return $manual.Trim('"')
            }
            $n = 0
            if ([int]::TryParse($raw, [ref]$n) -and $n -ge 1 -and $n -le $installers.Count) { return $installers[$n-1].FullName }
            Write-Host "Invalid selection." -ForegroundColor Yellow
        }
    }

    Write-Host "[WARN] No installer files found in common toolkit folders." -ForegroundColor Yellow
    Write-Host "Scanned:" -ForegroundColor DarkGray
    $displayRoots = @((Join-Path $ToolkitRoot "Incoming"), (Join-Path $ToolkitRoot "Repository\Software"), (Join-Path $ToolkitRoot "Downloads"))
    foreach ($r in $displayRoots) { Write-Host "  $r" -ForegroundColor DarkGray }
    Write-Host ""
    Write-Host "[1] Enter installer path manually"
    Write-Host "[2] Open Incoming folder"
    Write-Host "[B] Back"
    while ($true) {
        $raw = (Read-Host "Selection").Trim().ToUpper()
        if ($raw -eq 'B') { return $null }
        if ($raw -eq '1') {
            $manual = Read-Required "Installer path"
            return $manual.Trim('"')
        }
        if ($raw -eq '2') {
            $incomingRoot = Join-Path $ToolkitRoot "Incoming"
            if (-not (Test-Path $incomingRoot)) { New-Item -ItemType Directory -Path $incomingRoot -Force | Out-Null }
            Start-Process explorer.exe $incomingRoot
        }
        else { Write-Host "Invalid selection." -ForegroundColor Yellow }
    }
}


function Convert-ToTitleName {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $parts = @($Text -split '[^a-zA-Z0-9]+' | Where-Object { $_ })
    $fixed = foreach ($part in $parts) {
        if ($part.Length -le 1) { $part.ToUpper() }
        else { $part.Substring(0,1).ToUpper() + $part.Substring(1).ToLower() }
    }
    return ($fixed -join ' ')
}

function Get-WebsiteNameGuess {
    param([string]$Url)
    try {
        $working = $Url.Trim()
        if ($working -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') { $working = 'https://' + $working.TrimStart('/') }
        $host = ''
        try { $host = ([System.Uri]$working).Host } catch { $host = '' }
        if ([string]::IsNullOrWhiteSpace($host)) {
            $host = ($working -replace '^[a-zA-Z][a-zA-Z0-9+.-]*://','') -replace '^www\.',''
            $host = ($host -split '[/:?#]')[0]
        }
        $host = $host.ToLowerInvariant()
        if ($host.StartsWith('www.')) { $host = $host.Substring(4) }
        $base = ($host -split '\.')[0]
        $known = @{
            'google'='Google'; 'microsoft'='Microsoft'; 'github'='GitHub'; 'youtube'='YouTube';
            'reddit'='Reddit'; 'chatgpt'='ChatGPT'; 'openai'='OpenAI'; 'edmorse'='Ed Morse'
        }
        if ($known.ContainsKey($base)) { return $known[$base] }
        $guess = Convert-ToTitleName $base
        if ([string]::IsNullOrWhiteSpace($guess)) { return 'Website Shortcut' }
        return $guess
    } catch { return "Website Shortcut" }
}

function Get-InstallerNameGuess {
    param([string]$Path)
    $name = [IO.Path]::GetFileNameWithoutExtension($Path)
    if ([string]::IsNullOrWhiteSpace($name)) { return "Installer" }
    $lower = $name.ToLowerInvariant()
    if ($lower -match '^7z') { return '7Zip' }
    if ($lower -match 'notepad\+\+|npp') { return 'Notepad++' }
    if ($lower -match 'chrome') { return 'Google Chrome' }
    if ($lower -match 'firefox') { return 'Mozilla Firefox' }
    if ($lower -match 'edge') { return 'Microsoft Edge' }
    if ($lower -match 'vlc') { return 'VLC' }
    if ($lower -match 'teams') { return 'Microsoft Teams' }
    $clean = $name
    $clean = $clean -replace '(?i)(setup|installer|install|win64|win32|x64|x86|amd64|arm64|offline|online)', ' '
    $clean = $clean -replace '\b\d+(\.\d+)*\b', ' '
    $clean = $clean -replace '[-_]+', ' '
    $clean = ($clean -replace '\s+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($clean)) { $clean = $name -replace '[-_]+', ' ' }
    return (Convert-ToTitleName $clean)
}

function Select-InstallerArguments {
    param([string]$InstallerPath)
    $ext = [IO.Path]::GetExtension($InstallerPath).ToLowerInvariant()
    Write-Host ""
    Write-Host "Common installer arguments:" -ForegroundColor Yellow
    Write-Host "These are presets. Installer switches vary by vendor." -ForegroundColor DarkGray
    Write-Host ""
    $options = @()
    $options += [pscustomobject]@{Args=''; Desc='None - launch normally / show installer UI'}
    $options += [pscustomobject]@{Args='/quiet /norestart'; Desc='Common Microsoft EXE silent install, no reboot'}
    $options += [pscustomobject]@{Args='/silent /norestart'; Desc='Common quiet install, no reboot'}
    $options += [pscustomobject]@{Args='/verysilent /norestart'; Desc='Inno Setup very quiet install, no reboot'}
    $options += [pscustomobject]@{Args='/S'; Desc='NSIS-style silent install; capital S matters'}
    $options += [pscustomobject]@{Args='/passive /norestart'; Desc='Shows progress only, no reboot'}
    $options += [pscustomobject]@{Args='/qn /norestart'; Desc='MSI silent install, no reboot'}
    $options += [pscustomobject]@{Args='/qb! /norestart'; Desc='MSI basic UI, no cancel button, no reboot'}
    $options += [pscustomobject]@{Args='/qn /norestart /l*v "%TEMP%\install.log"'; Desc='MSI silent install with verbose log'}
    $options += [pscustomobject]@{Args='/quiet /norestart /log "%TEMP%\install.log"'; Desc='Common EXE quiet install with log path'}

    for ($i=0; $i -lt $options.Count; $i++) {
        $label = if ([string]::IsNullOrWhiteSpace($options[$i].Args)) { '[none]' } else { $options[$i].Args }
        Write-Host "[$($i+1)] $label"
        Write-Host "    $($options[$i].Desc)" -ForegroundColor DarkGray
    }
    Write-Host "[C] Custom arguments"
    Write-Host "[?] Help"
    while ($true) {
        $raw = (Read-Host "Selection").Trim().ToUpper()
        if ($raw -eq '?') {
            Write-Host ""
            Write-Host "Notes:" -ForegroundColor Yellow
            Write-Host " - /qn and /qb are MSI options."
            Write-Host " - /S is common for NSIS installers."
            Write-Host " - /verysilent is common for Inno Setup installers."
            Write-Host " - /quiet, /silent, /passive, /norestart are common but not universal."
            Write-Host " - Verbose logging is useful when an install fails."
            Write-Host ""
            continue
        }
        if ($raw -eq 'C') { return (Read-Host "Custom arguments") }
        $n = 0
        if ([int]::TryParse($raw, [ref]$n) -and $n -ge 1 -and $n -le $options.Count) { return $options[$n-1].Args }
        if ([string]::IsNullOrWhiteSpace($raw)) { return '' }
        Write-Host "Invalid selection." -ForegroundColor Yellow
    }
}

function Create-WebsiteModule {
    Show-Header "CREATE FROM WEBSITE"
    Write-Host "Creates a module that opens a website." -ForegroundColor DarkGray
    Write-Host "Examples:" -ForegroundColor DarkGray
    Write-Host "  google.com" -ForegroundColor DarkGray
    Write-Host "  https://support.microsoft.com" -ForegroundColor DarkGray
    Write-Host ""
    $url = ""
    while ([string]::IsNullOrWhiteSpace($url)) {
        $rawUrl = Read-Required "Website URL" "https://"
        $url = Normalize-WebsiteUrl -Url $rawUrl
        if ([string]::IsNullOrWhiteSpace($url)) { Write-Host "Enter a valid website URL or domain." -ForegroundColor Yellow }
    }
    Write-Host "Using URL: $url" -ForegroundColor Green
    $guessName = Get-WebsiteNameGuess -Url $url
    $details = Read-ModuleDetails -Type "Website" -SuggestedName $guessName
    $safeUrl = $url.Replace('"','')
    $content = @"
Start-Process -FilePath `"$safeUrl`"
"@
    Preview-And-CreateModule -Details $details -RunPs1Content $content.Trim() -SourceLabel "Website: $url"
}

function Create-InstallerModule {
    Show-Header "CREATE FROM INSTALLER"
    Write-Host "Creates a module that launches an installer path." -ForegroundColor DarkGray
    Write-Host "Examples:" -ForegroundColor DarkGray
    Write-Host "  EXE: setup.exe /quiet /norestart" -ForegroundColor DarkGray
    Write-Host "  MSI: msiexec.exe /i app.msi /qn /norestart" -ForegroundColor DarkGray
    Write-Host ""
    $path = Select-InstallerPath
    if (-not $path) { return }
    $path = $path.Trim('"')
    $args = Select-InstallerArguments -InstallerPath $path
    $guessName = Get-InstallerNameGuess -Path $path
    $details = Read-ModuleDetails -Type "Installer" -SuggestedName $guessName
    $safePath = $path.Replace('"','')
    $relativePath = $null
    try {
        $rootFull = ([IO.Path]::GetFullPath($ToolkitRoot.Path)).TrimEnd('\')
        $pathFull = [IO.Path]::GetFullPath($safePath)
        if ($pathFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            $relativePath = $pathFull.Substring($rootFull.Length).TrimStart('\')
        }
    } catch {}

    if ($relativePath) {
        $content = "`$ToolkitRoot = Resolve-Path `"`$PSScriptRoot\..\..`"" + [Environment]::NewLine
        $content += "`$InstallerPath = Join-Path `$ToolkitRoot `"$relativePath`"" + [Environment]::NewLine
        $content += "Start-Process -FilePath `$InstallerPath"
    }
    else {
        $content = "Start-Process -FilePath `"$safePath`""
    }
    if (-not [string]::IsNullOrWhiteSpace($args)) { $content += " -ArgumentList `"$($args.Replace('"',''))`"" }
    $content += " -Wait"
    Preview-And-CreateModule -Details $details -RunPs1Content $content -SourceLabel "Installer launcher: $path"
}

function Open-ModulesFolder {
    if (-not (Test-Path $ModulesRoot)) { New-Item -ItemType Directory -Path $ModulesRoot -Force | Out-Null }
    Start-Process explorer.exe $ModulesRoot
}

function Open-ModuleBlanksFolder {
    if (-not (Test-Path $TemplatesRoot)) { New-Item -ItemType Directory -Path $TemplatesRoot -Force | Out-Null }
    Start-Process explorer.exe $TemplatesRoot
}

while ($true) {
    Show-Header "ADD MODULE BUILDER"
    Write-Host "Create and modify real toolkit modules. New modules use the standard layout:" -ForegroundColor DarkGray
    Write-Host "  run.bat  -> launches run.ps1" -ForegroundColor DarkGray
    Write-Host "  run.ps1  -> module logic" -ForegroundColor DarkGray
    Write-Host "  tool.json -> metadata" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "[1] Create Empty Module Template"
    Write-Host "    Create a new blank module with run.bat, run.ps1, and tool.json."
    Write-Host "[2] Modify PowerShell Script"
    Write-Host "    Select a module folder and modify its run.ps1 script."
    Write-Host "[3] Modify Batch Script"
    Write-Host "    Select a module folder and modify its run.bat launcher."
    Write-Host "[4] Create From Installer"
    Write-Host "    Create a module that launches an installer path."
    Write-Host "[5] Create From Website"
    Write-Host "    Create a module that opens a website."
    Write-Host "[6] Open Modules Folder"
    Write-Host "[7] Open Module Blanks Folder"
    Write-Host ""
    Write-Host "[B] Back"
    Write-Host ""
    $choice = (Read-Host "Selection").Trim().ToUpper()
    switch ($choice) {
        "1" { Create-EmptyTemplate }
        "2" { Modify-PowerShellScript }
        "3" { Modify-BatchScript }
        "4" { Create-InstallerModule }
        "5" { Create-WebsiteModule }
        "6" { Open-ModulesFolder }
        "7" { Open-ModuleBlanksFolder }
        "B" { return }
        "Q" { return }
    }
}
