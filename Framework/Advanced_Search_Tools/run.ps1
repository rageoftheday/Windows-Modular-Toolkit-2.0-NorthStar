# ============================================================
# ADVANCED SEARCH TOOLS
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"

$RegistryPath = Join-Path $Root "cache\toolkit_registry.json"

Invoke-ToolkitModule `
    -ModuleName "ADVANCED SEARCH TOOLS" `
    -RequiresAdmin $false `
    -ScriptBlock {

    function Convert-ToolkitBooleanLocal {
        param($Value, [bool]$Default = $false)
        if ($null -eq $Value) { return $Default }
        if ($Value -is [bool]) { return [bool]$Value }
        $Text = ([string]$Value).Trim()
        if ([string]::IsNullOrWhiteSpace($Text)) { return $Default }
        switch -Regex ($Text) {
            '^(true|yes|y|1|on)$'  { return $true }
            '^(false|no|n|0|off)$' { return $false }
            default { return $Default }
        }
    }

    function Get-LiveModuleRegistryLocal {
        $ModulesRoot = Join-Path $Root "Modules"
        if (-not (Test-Path $ModulesRoot)) { return @() }
        $Results = @()
        foreach ($FolderItem in @(Get-ChildItem -Path $ModulesRoot -Directory -ErrorAction SilentlyContinue)) {
            $JsonPath = Join-Path $FolderItem.FullName "tool.json"
            if (-not (Test-Path $JsonPath)) { continue }
            try { $Json = Get-Content -Path $JsonPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop } catch { continue }
            $Hidden = $false
            if ($Json.PSObject.Properties.Name -contains 'hidden') { $Hidden = Convert-ToolkitBooleanLocal $Json.hidden $false }
            if ($Hidden) { continue }
            $Name = if ($Json.PSObject.Properties.Name -contains 'name' -and -not [string]::IsNullOrWhiteSpace([string]$Json.name)) { [string]$Json.name } else { $FolderItem.Name }
            $Category = if ($Json.PSObject.Properties.Name -contains 'category' -and -not [string]::IsNullOrWhiteSpace([string]$Json.category)) { [string]$Json.category } else { "Uncategorized" }
            $Subcategory = if ($Json.PSObject.Properties.Name -contains 'subcategory' -and $null -ne $Json.subcategory) { [string]$Json.subcategory } else { "" }
            $Description = if ($Json.PSObject.Properties.Name -contains 'description' -and $null -ne $Json.description) { [string]$Json.description } else { "" }
            $Entry = if ($Json.PSObject.Properties.Name -contains 'entry' -and -not [string]::IsNullOrWhiteSpace([string]$Json.entry)) { [string]$Json.entry } else { "run.bat" }
            $Keywords = if ($Json.PSObject.Properties.Name -contains 'keywords' -and $null -ne $Json.keywords) { @($Json.keywords) } else { @() }
            $RequiresAdmin = $false
            if ($Json.PSObject.Properties.Name -contains 'requires_admin') { $RequiresAdmin = Convert-ToolkitBooleanLocal $Json.requires_admin $false }
            $Results += [PSCustomObject]@{
                name=$Name; folder=$FolderItem.Name; path=$FolderItem.FullName; category=$Category; subcategory=$Subcategory;
                description=$Description; keywords=$Keywords; requires_admin=$RequiresAdmin; entry=$Entry;
                module_scope="User"; framework_protected=$false; hidden=$Hidden
            }
        }
        return @($Results)
    }

    function Get-SearchRegistryLive {
        $Cached = @(Get-ToolkitRegistry $RegistryPath)
        $Framework = @($Cached | Where-Object { $_.module_scope -eq "Framework" -or $_.framework_protected -eq $true })
        $LiveModules = @(Get-LiveModuleRegistryLocal)
        return @($Framework + $LiveModules)
    }

    $LastNoResult = $null

    while ($true) {

        Show-ToolkitHeader "ADVANCED SEARCH TOOLS"

        if ($LastNoResult) {
            Write-Host "No matching modules found for:"
            Write-Host ""
            Write-Host $LastNoResult -ForegroundColor Yellow
            Write-Host ""
            $LastNoResult = $null
        }

        Write-Host "Examples:"
        Write-Host "  network"
        Write-Host "  diagnostics"
        Write-Host "  repair"
        Write-Host "  cleanup"
        Write-Host "  winget"
        Write-Host "  security"
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""

        $Search = Read-Host "Enter search term"

        if ([string]::IsNullOrWhiteSpace($Search)) { continue }
        if ($Search.ToUpper() -eq "B") { return }
        if ($Search.ToUpper() -eq "Q") { return }

        $Registry = @(Get-SearchRegistryLive)
        $Results = @(Find-ToolkitModule -Name $Search -Registry $Registry)
        $Title = "SEARCH RESULTS"

        if (!$Results -or $Results.Count -eq 0) {
            $Suggestions = @()
            if (Get-Command Get-ToolkitSmartSuggestions -ErrorAction SilentlyContinue) {
                $Suggestions = @(Get-ToolkitSmartSuggestions -Query $Search -Registry $Registry -MaxResults 8)
            }

            if (!$Suggestions -or $Suggestions.Count -eq 0) {
                $LastNoResult = $Search
                continue
            }

            $Results = $Suggestions
            $Title = "SEARCH SUGGESTIONS"
        }

        while ($true) {

            Show-ToolkitHeader $Title

            $Index = 1

            foreach ($Result in $Results) {

                Write-Host "[$Index] $($Result.name)"

                if ($Result.description) {
                    Write-Host "     $($Result.description)" -ForegroundColor Gray
                }

                Write-Host "     Category : $($Result.category)"
                Write-Host "     Admin    : $($Result.requires_admin)"
                Write-Host ""

                $Index++
            }

            Write-Host "[S] Search Again"
            Write-Host "[B] Back"
                Write-Host ""

            $Selection = Read-Host "Select result number"

            if ($Selection.ToUpper() -eq "S") { break }
            if ($Selection.ToUpper() -eq "B") { return }
            if ($Selection.ToUpper() -eq "Q") { return }
            if ($Selection -notmatch '^\d+$') { continue }

            $SelectedModule = $Results[[int]$Selection - 1]

            if (!$SelectedModule) { continue }

            Start-ToolkitModule $SelectedModule
        }
    }
}
