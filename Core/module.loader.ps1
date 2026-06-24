# ============================================================
# TOOLKIT MODULE LOADER
# ============================================================

function Get-ToolkitRegistry {

    param(
        [string]$RegistryPath
    )

    if (!(Test-Path $RegistryPath)) {

        Write-Host ""
        Write-Host "[FAIL] Toolkit registry not found." `
            -ForegroundColor Red

        Write-Host ""
        return @()
    }

    try {

        $Data = Get-Content `
            $RegistryPath `
            -Raw | ConvertFrom-Json

        if ($null -eq $Data) {
            return @()
        }

        # PowerShell can sometimes treat a top-level JSON array as one object
        # when passed through functions/pipelines. Emit each registry item
        # individually so callers always receive a true list of tools.
        if ($Data -is [System.Array]) {
            foreach ($Item in $Data) {
                Write-Output $Item
            }
            return
        }

        if ($Data.PSObject.Properties.Name -contains "items") {
            foreach ($Item in @($Data.items)) {
                Write-Output $Item
            }
            return
        }

        Write-Output $Data
    }
    catch {

        Write-Host ""
        Write-Host "[FAIL] Registry JSON invalid." `
            -ForegroundColor Red

        Write-Host ""
        return @()
    }
}

function Get-ToolkitModulePropertyValue {
    param([object]$Item, [string]$Name, [object]$Default = $null)
    if ($null -eq $Item) { return $Default }
    if ($Item.PSObject.Properties.Name -contains $Name) {
        $Value = $Item.$Name
        if ($null -ne $Value) { return $Value }
    }
    return $Default
}

# ============================================================
# FIND MODULES
# ============================================================

function Find-ToolkitModule {

    param(
        [string]$Name,
        [array]$Registry
    )

    if (!$Registry) {
        return @()
    }

    $Search = $Name.ToLower()

    return @(
        $Registry | Where-Object {

            ([string](Get-ToolkitModulePropertyValue $_ 'name' '')).ToLower().Contains($Search) -or
            ([string](Get-ToolkitModulePropertyValue $_ 'category' '')).ToLower().Contains($Search) -or
            ([string](Get-ToolkitModulePropertyValue $_ 'subcategory' '')).ToLower().Contains($Search) -or
            ([string](Get-ToolkitModulePropertyValue $_ 'description' '')).ToLower().Contains($Search) -or
            ((@(Get-ToolkitModulePropertyValue $_ 'keywords' @()) -join " ").ToLower().Contains($Search))
        }
    )
}


# ============================================================
# SMART SEARCH SUGGESTIONS
# ============================================================

function Normalize-ToolkitSearchText {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return (($Text.ToLower() -replace '[^a-z0-9]+',' ') -replace '\s+',' ').Trim()
}

function Get-ToolkitLevenshteinDistance {
    param(
        [string]$A,
        [string]$B
    )

    $A = [string]$A
    $B = [string]$B
    $N = $A.Length
    $M = $B.Length

    if ($N -eq 0) { return $M }
    if ($M -eq 0) { return $N }

    $D = New-Object 'int[,]' ($N + 1), ($M + 1)
    for ($i = 0; $i -le $N; $i++) { $D[$i,0] = $i }
    for ($j = 0; $j -le $M; $j++) { $D[0,$j] = $j }

    for ($i = 1; $i -le $N; $i++) {
        for ($j = 1; $j -le $M; $j++) {
            $Cost = if ($A[$i - 1] -eq $B[$j - 1]) { 0 } else { 1 }
            $Delete = $D[($i - 1), $j] + 1
            $Insert = $D[$i, ($j - 1)] + 1
            $Substitute = $D[($i - 1), ($j - 1)] + $Cost
            $D[$i, $j] = [Math]::Min([Math]::Min($Delete, $Insert), $Substitute)
        }
    }

    return $D[$N, $M]
}

function Get-ToolkitModuleSearchText {
    param([object]$Module)
    $KeywordText = ""
    $Keywords = Get-ToolkitModulePropertyValue $Module 'keywords' @()
    if ($Keywords) { $KeywordText = (@($Keywords) -join " ") }
    return Normalize-ToolkitSearchText ((@(
        (Get-ToolkitModulePropertyValue $Module 'name' ''),
        (Get-ToolkitModulePropertyValue $Module 'folder' ''),
        (Get-ToolkitModulePropertyValue $Module 'category' ''),
        (Get-ToolkitModulePropertyValue $Module 'subcategory' ''),
        (Get-ToolkitModulePropertyValue $Module 'description' ''),
        $KeywordText
    ) -join " "))
}

function Test-ToolkitSuggestionCandidate {
    param(
        [string]$InputText,
        [string]$CandidateText
    )

    $InputText = Normalize-ToolkitSearchText $InputText
    $CandidateText = Normalize-ToolkitSearchText $CandidateText

    if ([string]::IsNullOrWhiteSpace($InputText) -or [string]::IsNullOrWhiteSpace($CandidateText)) { return $false }
    if ($InputText.Length -lt 3 -or $CandidateText.Length -lt 3) { return $false }

    # Avoid random suggestions like xander -> Advanced or Account.
    # Suggestions should feel intentional, so the first character must match.
    if ($InputText[0] -ne $CandidateText[0]) { return $false }

    $Distance = Get-ToolkitLevenshteinDistance $InputText $CandidateText
    $MaxLength = [Math]::Max($InputText.Length, $CandidateText.Length)

    # Conservative fuzzy matching:
    # - short words allow only 1 typo
    # - longer words allow 2 typos
    # - distance must still be reasonably close by ratio
    $AllowedDistance = if ($MaxLength -le 5) { 1 } else { 2 }
    $Ratio = [double]$Distance / [double]$MaxLength

    return ($Distance -le $AllowedDistance -and $Ratio -le 0.30)
}

function Get-ToolkitSmartSuggestions {
    param(
        [string]$Query,
        [array]$Registry,
        [int]$MaxResults = 5
    )

    if (!$Registry -or [string]::IsNullOrWhiteSpace($Query)) { return @() }

    $Q = Normalize-ToolkitSearchText $Query
    if ([string]::IsNullOrWhiteSpace($Q)) { return @() }
    $Terms = @($Q -split '\s+' | Where-Object { $_ })

    $Scored = foreach ($Module in $Registry) {
        $Name = Normalize-ToolkitSearchText (Get-ToolkitModulePropertyValue $Module 'name' '')
        $Folder = Normalize-ToolkitSearchText (Get-ToolkitModulePropertyValue $Module 'folder' '')
        $Category = Normalize-ToolkitSearchText (Get-ToolkitModulePropertyValue $Module 'category' '')
        $Subcategory = Normalize-ToolkitSearchText (Get-ToolkitModulePropertyValue $Module 'subcategory' '')
        $SearchText = Get-ToolkitModuleSearchText $Module

        $Score = 999
        $Matched = $false

        if ($SearchText -like "*$Q*") {
            $Score = 0
            $Matched = $true
        }
        else {
            # Whole-query suggestions against primary labels only.
            $Fields = @($Name, $Folder, $Category, $Subcategory) | Where-Object { $_ }
            foreach ($Field in $Fields) {
                if (Test-ToolkitSuggestionCandidate -InputText $Q -CandidateText $Field) {
                    $Distance = Get-ToolkitLevenshteinDistance $Q $Field
                    if ($Distance -lt $Score) { $Score = $Distance }
                    $Matched = $true
                }
            }

            # Per-word suggestions for typo cases like "dns flsuh" -> DNS Flush.
            foreach ($Term in $Terms) {
                foreach ($Word in @($SearchText -split '\s+' | Where-Object { $_ })) {
                    if (Test-ToolkitSuggestionCandidate -InputText $Term -CandidateText $Word) {
                        $Distance = Get-ToolkitLevenshteinDistance $Term $Word
                        if ($Distance -lt $Score) { $Score = $Distance }
                        $Matched = $true
                    }
                }
            }
        }

        if ($Matched) {
            [pscustomobject]@{ Module = $Module; Score = $Score; Name = (Get-ToolkitModulePropertyValue $Module 'name' '') }
        }
    }

    return @(
        $Scored |
        Sort-Object Score, Name |
        Select-Object -First $MaxResults |
        ForEach-Object { $_.Module }
    )
}


function Wait-ToolkitModuleReturn {
    Write-Host ""
    Write-Host "Module finished or returned to toolkit." -ForegroundColor DarkGray
    Read-Host "Press Enter to return to toolkit" | Out-Null
}


function Invoke-ToolkitLaunchedCommand {
    param(
        [scriptblock]$ScriptBlock
    )

    $PreviousToolkitLaunched = $env:TOOLKIT_LAUNCHED
    $env:TOOLKIT_LAUNCHED = '1'
    try {
        & $ScriptBlock
    }
    finally {
        if ($null -eq $PreviousToolkitLaunched) {
            Remove-Item Env:\TOOLKIT_LAUNCHED -ErrorAction SilentlyContinue
        }
        else {
            $env:TOOLKIT_LAUNCHED = $PreviousToolkitLaunched
        }
    }
}

# ============================================================
# START MODULE
# ============================================================

function Start-ToolkitModule {

    param(
        [object]$Module
    )

    $Root = Resolve-Path "$PSScriptRoot\.."

    # --------------------------------------------------------
    # LOAD DEPENDENCY ENGINE
    # --------------------------------------------------------

    $DependencyEngine = Join-Path `
        $Root `
        "core\dependency.engine.ps1"

    if (Test-Path $DependencyEngine) {

        . $DependencyEngine
    }

    Write-Host ""
    Write-Host "Launching: $($Module.name)"
    Write-Host ""

    # --------------------------------------------------------
    # DEPENDENCY CHECKS
    # --------------------------------------------------------

    if (Get-Command `
        Test-ToolkitDependencies `
        -ErrorAction SilentlyContinue) {

        if (!(Test-ToolkitDependencies $Module)) {

            Pause-Toolkit
            return
        }
    }

    # --------------------------------------------------------
    # RESOLVE MODULE PATH
    # --------------------------------------------------------

    $ModulePath = $Module.path

    # --------------------------------------------------------
    # HANDLE RELATIVE PORTABLE PATHS
    # --------------------------------------------------------

    if ($ModulePath -and `
        !(Split-Path $ModulePath -IsAbsolute)) {

        $ModulePath = Join-Path `
            $Root `
            $ModulePath
    }

    # --------------------------------------------------------
    # FALLBACK USING FOLDER NAME
    # --------------------------------------------------------

    if (!(Test-Path $ModulePath)) {

        if ($Module.folder) {

            $FallbackRoots = @("modules")

            if ($Module.module_scope -eq "Framework" -or $Module.framework_protected -eq $true) {
                $FallbackRoots = @("Framework", "modules")
            }

            foreach ($FallbackRoot in $FallbackRoots) {

                $FallbackPath = Join-Path `
                    $Root `
                    "$FallbackRoot\$($Module.folder)"

                if (Test-Path $FallbackPath) {

                    $ModulePath = $FallbackPath
                    break
                }
            }
        }
    }

    # --------------------------------------------------------
    # BUILD LAUNCHER PATHS
    # --------------------------------------------------------

    $Entry = $Module.entry

    if ([string]::IsNullOrWhiteSpace($Entry)) {
        $Entry = "run.ps1"
    }

    $EntryPath = Join-Path $ModulePath $Entry

    $PS1 = Join-Path `
        $ModulePath `
        "run.ps1"

    $BAT = Join-Path `
        $ModulePath `
        "run.bat"

    # --------------------------------------------------------
    # ADMIN LAUNCH POLICY
    # --------------------------------------------------------

    $RequiresAdmin = $false
    if ($Module.PSObject.Properties.Name -contains 'requires_admin') {
        try { $RequiresAdmin = [System.Convert]::ToBoolean($Module.requires_admin) } catch { $RequiresAdmin = $false }
    }

    if ($RequiresAdmin -and -not (Test-ToolkitAdmin)) {

        Show-ToolkitHeader "ADMIN REQUIRED"
        Write-Host "This module requires administrator privileges." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To keep this module running in the current toolkit window," -ForegroundColor Yellow
        Write-Host "restart the toolkit as Administrator first." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "[1] Launch elevated in a separate admin window"
        Write-Host "[2] Return and restart toolkit as admin"
        Write-Host ""

        $AdminChoice = (Read-Host "Selection").Trim().ToUpperInvariant()

        if ($AdminChoice -ne "1") {
            return
        }

        if (-not (Test-Path $EntryPath)) {
            if (Test-Path $BAT) { $EntryPath = $BAT }
            elseif (Test-Path $PS1) { $EntryPath = $PS1 }
        }

        if (-not (Test-Path $EntryPath)) {
            Write-Host ""
            Write-Host "[FAIL] Entry file not found for elevated launch." -ForegroundColor Red
            Pause-Toolkit
            return
        }

        $Extension = [System.IO.Path]::GetExtension($EntryPath).ToLower()
        $SafeModulePath = $ModulePath.Replace("'", "''")
        $SafeEntryPath  = $EntryPath.Replace("'", "''")

        if ($Extension -eq ".bat") {
            $ElevatedCommand = @"
Set-Location -LiteralPath '$SafeModulePath'
$env:TOOLKIT_LAUNCHED = '1'
& cmd.exe /d /c "`"$SafeEntryPath`""
Write-Host ''
Read-Host 'Press Enter to close elevated module window'
"@
        }
        elseif ($Extension -eq ".ps1") {
            $ElevatedCommand = @"
Set-Location -LiteralPath '$SafeModulePath'
$env:TOOLKIT_LAUNCHED = '1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File '$SafeEntryPath'
Write-Host ''
Read-Host 'Press Enter to close elevated module window'
"@
        }
        else {
            $ElevatedCommand = @"
Set-Location -LiteralPath '$SafeModulePath'
$env:TOOLKIT_LAUNCHED = '1'
& '$SafeEntryPath'
Write-Host ''
Read-Host 'Press Enter to close elevated module window'
"@
        }

        $EncodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ElevatedCommand))

        Start-Process `
            -FilePath "powershell.exe" `
            -Verb RunAs `
            -WorkingDirectory $ModulePath `
            -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$EncodedCommand)

        return
    }

    # --------------------------------------------------------
    # LAUNCH CONFIGURED ENTRY FIRST
    # --------------------------------------------------------

    if (Test-Path $EntryPath) {
        $Extension = [System.IO.Path]::GetExtension($EntryPath).ToLower()

        Push-Location $ModulePath
        try {
            switch ($Extension) {
                ".ps1" {
                    Invoke-ToolkitLaunchedCommand { powershell -NoProfile -ExecutionPolicy Bypass -File $EntryPath }
                    Wait-ToolkitModuleReturn
                    return
                }
                ".bat" {
                    Invoke-ToolkitLaunchedCommand { cmd.exe /d /c "`"$EntryPath`"" }
                    Wait-ToolkitModuleReturn
                    return
                }
                ".cmd" {
                    Invoke-ToolkitLaunchedCommand { cmd.exe /d /c "`"$EntryPath`"" }
                    Wait-ToolkitModuleReturn
                    return
                }
                ".exe" {
                    Invoke-ToolkitLaunchedCommand { & $EntryPath }
                    Wait-ToolkitModuleReturn
                    return
                }
                ".msi" {
                    Invoke-ToolkitLaunchedCommand { Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$EntryPath`"" -Wait }
                    Wait-ToolkitModuleReturn
                    return
                }
                default {
                    Invoke-ToolkitLaunchedCommand { & $EntryPath }
                    Wait-ToolkitModuleReturn
                    return
                }
            }
        }
        finally {
            Pop-Location
        }
    }

    # --------------------------------------------------------
    # LAUNCH POWERSHELL MODULE FALLBACK
    # --------------------------------------------------------

    if (Test-Path $PS1) {
        Push-Location $ModulePath
        try {
            Invoke-ToolkitLaunchedCommand {
                powershell `
                    -NoProfile `
                    -ExecutionPolicy Bypass `
                    -File $PS1
            }
            Wait-ToolkitModuleReturn
        }
        finally {
            Pop-Location
        }

        return
    }

    # --------------------------------------------------------
    # LAUNCH BAT MODULE FALLBACK
    # --------------------------------------------------------

    if (Test-Path $BAT) {
        Push-Location $ModulePath
        try {
            Invoke-ToolkitLaunchedCommand { cmd /c "`"$BAT`"" }
            Wait-ToolkitModuleReturn
        }
        finally {
            Pop-Location
        }

        return
    }

    # --------------------------------------------------------
    # FAIL
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "[FAIL] Launcher not found." `
        -ForegroundColor Red

    Write-Host ""
    Write-Host "Module:"
    Write-Host $Module.name

    Write-Host ""
    Write-Host "Path:"
    Write-Host $ModulePath

    Write-Host ""

    Pause-Toolkit
}