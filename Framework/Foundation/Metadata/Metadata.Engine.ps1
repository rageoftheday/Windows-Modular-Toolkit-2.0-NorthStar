# Windows Modular Toolkit - Foundation Metadata Engine
# Framework 2.0 Phase 35B
# Metadata is infrastructure: generated/stored with real objects, not created as orphan records.

if (-not $script:MetadataEngineLoaded) { $script:MetadataEngineLoaded = $true }

function ConvertTo-WmtSafeId {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return 'item' }
    $Safe = $Text.ToLowerInvariant() -replace '[^a-z0-9]+','-'
    $Safe = $Safe.Trim('-')
    if ([string]::IsNullOrWhiteSpace($Safe)) { $Safe = 'item' }
    return $Safe
}

function Get-WmtUniqueWords {
    param([string]$Text)
    $StopWords = @('the','and','for','from','with','that','this','into','onto','are','was','were','you','your','a','an','of','to','in','on','by','is','it','as','or','at','be','used','use','tool','tools','module','item','app')
    $Words = New-Object System.Collections.ArrayList
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    $Parts = ($Text.ToLowerInvariant() -replace '[^a-z0-9\.]+',' ') -split '\s+'
    foreach ($Part in $Parts) {
        $Word = $Part.Trim('.')
        if ($Word.Length -lt 2) { continue }
        if ($StopWords -contains $Word) { continue }
        if (-not ($Words -contains $Word)) { [void]$Words.Add($Word) }
    }
    return @($Words)
}

function Add-WmtKeyword {
    param($List,[string]$Word)
    if ([string]::IsNullOrWhiteSpace($Word)) { return }
    $Clean = $Word.ToLowerInvariant().Trim()
    if ($Clean.Length -lt 2) { return }
    if (-not ($List -contains $Clean)) { [void]$List.Add($Clean) }
}

function Get-WmtSuggestedType {
    param([string]$Name,[string]$Description,[string]$Path)
    $Text = (($Name + ' ' + $Description + ' ' + $Path).ToLowerInvariant())
    if ($Text -match 'https?://|www\.|\.com|\.net|\.org|portal|website|site|url') { return 'Website' }
    if ($Text -match 'installer|install|setup|msi|exe|chrome|firefox|7zip|7-zip|crowdstrike|falcon|winget') { return 'Installer' }
    if ($Text -match 'script|powershell|ps1|batch|bat|cmd') { return 'Script' }
    if ($Text -match 'document|documentation|guide|manual|readme|docs') { return 'Documentation' }
    if ($Text -match 'folder|share|directory|path') { return 'Folder' }
    if ($Text -match 'dns|flush|repair|status|check|reset|validator|module|toolkit') { return 'Module' }
    return 'Item'
}

function Get-WmtSuggestedCategory {
    param([string]$Name,[string]$Description,[string]$Type)
    $Text = (($Name + ' ' + $Description + ' ' + $Type).ToLowerInvariant())
    if ($Text -match 'chrome|firefox|edge|browser|web browser') { return 'Browsers' }
    if ($Text -match 'dns|network|ipconfig|ping|winsock|tcp|wifi|ethernet') { return 'Networking' }
    if ($Text -match 'printer|print|toner|flextg|suppl') { return 'Printers' }
    if ($Text -match 'crowdstrike|falcon|security|antivirus|endpoint|defender') { return 'Security' }
    if ($Text -match 'github|git|developer|powershell|script|code') { return 'Development' }
    if ($Text -match 'install|installer|setup|msi|exe|winget') { return 'Installers' }
    if ($Text -match 'document|documentation|guide|manual|readme') { return 'Documentation' }
    if ($Type -eq 'Website') { return 'Websites' }
    if ($Type -eq 'Folder') { return 'Folders' }
    if ($Type -eq 'Script') { return 'Scripts' }
    if ($Type -eq 'Module') { return 'Modules' }
    return 'Other'
}

function Get-WmtSuggestedKeywords {
    param([string]$Name,[string]$Description,[string]$Type,[string]$Category,[string]$Path)
    $Keywords = New-Object System.Collections.ArrayList
    foreach ($Word in (Get-WmtUniqueWords ($Name + ' ' + $Description + ' ' + $Type + ' ' + $Category + ' ' + $Path))) { Add-WmtKeyword $Keywords $Word }
    $Text = (($Name + ' ' + $Description + ' ' + $Category + ' ' + $Path).ToLowerInvariant())
    if ($Text -match 'chrome') { foreach ($w in @('chrome','google','browser','internet','web')) { Add-WmtKeyword $Keywords $w } }
    if ($Text -match 'dns') { foreach ($w in @('dns','network','cache','flush','resolver','windows')) { Add-WmtKeyword $Keywords $w } }
    if ($Text -match 'flextg') { foreach ($w in @('flextg','printer','orders','supplies','portal')) { Add-WmtKeyword $Keywords $w } }
    if ($Text -match 'printer|toner|suppl') { foreach ($w in @('printer','print','toner','supplies')) { Add-WmtKeyword $Keywords $w } }
    if ($Text -match 'crowdstrike|falcon') { foreach ($w in @('crowdstrike','falcon','security','endpoint','sensor','installer')) { Add-WmtKeyword $Keywords $w } }
    if ($Text -match 'github|git') { foreach ($w in @('github','git','repository','code')) { Add-WmtKeyword $Keywords $w } }
    if ($Text -match 'website|portal|\.com|https?') { foreach ($w in @('website','portal','link')) { Add-WmtKeyword $Keywords $w } }
    return @($Keywords)
}

function New-WmtMetadata {
    param(
        [string]$Name,
        [string]$Description,
        [string]$Type,
        [string]$Category,
        [string[]]$Keywords,
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Type)) { $Type = Get-WmtSuggestedType -Name $Name -Description $Description -Path $Path }
    if ([string]::IsNullOrWhiteSpace($Category)) { $Category = Get-WmtSuggestedCategory -Name $Name -Description $Description -Type $Type }
    if ($null -eq $Keywords -or $Keywords.Count -eq 0) { $Keywords = @(Get-WmtSuggestedKeywords -Name $Name -Description $Description -Type $Type -Category $Category -Path $Path) }
    return [PSCustomObject]@{
        name = $Name
        description = $Description
        type = $Type
        category = $Category
        keywords = @($Keywords)
        important = $false
        metadata_version = '1.0'
        metadata_source = 'MetadataEngine'
        metadata_updated = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
    }
}

function Test-WmtMetadata {
    param($Object)
    $Issues = New-Object System.Collections.ArrayList
    if ($null -eq $Object) { [void]$Issues.Add('Metadata object is null'); return @($Issues) }
    if ([string]::IsNullOrWhiteSpace([string]$Object.name)) { [void]$Issues.Add('Missing name') }
    if ([string]::IsNullOrWhiteSpace([string]$Object.description)) { [void]$Issues.Add('Missing description') }
    if ([string]::IsNullOrWhiteSpace([string]$Object.type)) { [void]$Issues.Add('Missing type') }
    if ([string]::IsNullOrWhiteSpace([string]$Object.category)) { [void]$Issues.Add('Missing category') }
    if ($null -eq $Object.keywords -or $Object.keywords.Count -eq 0) { [void]$Issues.Add('Missing keywords') }
    return @($Issues)
}

function Repair-WmtMetadataObject {
    param($Object,[string]$DefaultType,[string]$Path)
    if ($null -eq $Object) { return $null }
    $Name = [string]$Object.name
    if ([string]::IsNullOrWhiteSpace($Name)) { $Name = [System.IO.Path]::GetFileNameWithoutExtension($Path) }
    $Description = [string]$Object.description
    if ([string]::IsNullOrWhiteSpace($Description)) { $Description = $Name }
    $Type = [string]$Object.type
    if ([string]::IsNullOrWhiteSpace($Type)) { $Type = $DefaultType }
    if ([string]::IsNullOrWhiteSpace($Type)) { $Type = Get-WmtSuggestedType -Name $Name -Description $Description -Path $Path }
    $Category = [string]$Object.category
    if ([string]::IsNullOrWhiteSpace($Category)) { $Category = Get-WmtSuggestedCategory -Name $Name -Description $Description -Type $Type }
    $Keywords = @()
    if ($Object.keywords) { foreach ($K in $Object.keywords) { if (-not [string]::IsNullOrWhiteSpace([string]$K)) { $Keywords += ([string]$K).Trim().ToLowerInvariant() } } }
    if ($Keywords.Count -eq 0) { $Keywords = @(Get-WmtSuggestedKeywords -Name $Name -Description $Description -Type $Type -Category $Category -Path $Path) }
    if (-not ($Object.PSObject.Properties.Name -contains 'name')) { Add-Member -InputObject $Object -MemberType NoteProperty -Name name -Value $Name -Force } else { $Object.name = $Name }
    if (-not ($Object.PSObject.Properties.Name -contains 'description')) { Add-Member -InputObject $Object -MemberType NoteProperty -Name description -Value $Description -Force } else { $Object.description = $Description }
    if (-not ($Object.PSObject.Properties.Name -contains 'type')) { Add-Member -InputObject $Object -MemberType NoteProperty -Name type -Value $Type -Force } else { $Object.type = $Type }
    if (-not ($Object.PSObject.Properties.Name -contains 'category')) { Add-Member -InputObject $Object -MemberType NoteProperty -Name category -Value $Category -Force } else { $Object.category = $Category }
    if (-not ($Object.PSObject.Properties.Name -contains 'keywords')) { Add-Member -InputObject $Object -MemberType NoteProperty -Name keywords -Value @($Keywords) -Force } else { $Object.keywords = @($Keywords) }
    if (-not ($Object.PSObject.Properties.Name -contains 'important')) { Add-Member -InputObject $Object -MemberType NoteProperty -Name important -Value $false -Force }
    Add-Member -InputObject $Object -MemberType NoteProperty -Name metadata_version -Value '1.0' -Force
    Add-Member -InputObject $Object -MemberType NoteProperty -Name metadata_source -Value 'MetadataEngine' -Force
    Add-Member -InputObject $Object -MemberType NoteProperty -Name metadata_updated -Value (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') -Force
    return $Object
}

function Read-WmtJsonFile {
    param([string]$Path)
    try {
        if (!(Test-Path $Path)) { return $null }
        $Raw = Get-Content -Path $Path -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
        return ($Raw | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        return $null
    }
}

function Write-WmtJsonFile {
    param([string]$Path,$Object)
    try {
        $Json = ConvertTo-Json -InputObject $Object -Depth 20
        Set-Content -Path $Path -Value $Json -Encoding UTF8
        return $true
    } catch {
        return $false
    }
}
