# ============================================================
# DRY RUN MODULE VALIDATOR
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "DRY RUN MODULE VALIDATOR" `
    -RequiresAdmin $false `
    -ScriptBlock {

    Show-ToolkitHeader "DRY RUN MODULE VALIDATOR"

    $Modules = Get-ChildItem "$Root\modules" -Recurse -Filter "tool.json"
    $Errors = @()
    $Warnings = @()
    $Checked = 0

    foreach ($ToolJson in $Modules) {

        $Checked++

        try {
            $Json = Get-Content $ToolJson.FullName -Raw | ConvertFrom-Json
        }
        catch {
            $Errors += "[BAD JSON] $($ToolJson.FullName)"
            continue
        }

        $ModuleDir = $ToolJson.Directory.FullName
        $Entry = $Json.entry

        if ([string]::IsNullOrWhiteSpace($Entry)) {
            $Errors += "[MISSING ENTRY] $($Json.name)"
            continue
        }

        $EntryPath = Join-Path $ModuleDir $Entry

        if (!(Test-Path $EntryPath)) {
            $Errors += "[MISSING FILE] $($Json.name) -> $Entry"
            continue
        }

        if ($Entry -like "*.ps1") {

            $Code = Get-Content $EntryPath -Raw

            $Tokens = $null
            $ParseErrors = $null

            [System.Management.Automation.Language.Parser]::ParseInput(
                $Code,
                [ref]$Tokens,
                [ref]$ParseErrors
            ) | Out-Null

            if ($ParseErrors.Count -gt 0) {
                foreach ($Err in $ParseErrors) {
                    $Errors += "[PS SYNTAX] $($Json.name) -> $($Err.Message)"
                }
            }

            if ($Json.name -ne "Dry Run Module Validator" -and $Code -match '>>\s*"%f%"|%PSDIR%|cmd\.exe /c "\("') {
                $Warnings += "[LEGACY ARTIFACT] $($Json.name)"
            }

            if ($Code -notmatch "bootstrap.ps1") {
                $Warnings += "[NO BOOTSTRAP] $($Json.name)"
            }
        }

        if ($Entry -like "*.bat") {

            $Bat = Get-Content $EntryPath -Raw -ErrorAction SilentlyContinue

            if ([string]::IsNullOrWhiteSpace($Bat)) {
                $Errors += "[EMPTY BAT] $($Json.name)"
            }

            if ($Bat -notmatch "powershell|cmd|echo|call|start") {
                $Warnings += "[SUSPICIOUS BAT] $($Json.name)"
            }
        }
    }

    Write-Host "Modules checked : $Checked"
    Write-Host "Errors found    : $($Errors.Count)"
    Write-Host "Warnings found  : $($Warnings.Count)"
    Write-Host ""

    if ($Errors.Count -eq 0) {
        Write-Host "[PASS] No blocking dry-run errors found." -ForegroundColor Green
    }
    else {
        Write-Host "[ERRORS]" -ForegroundColor Red
        $Errors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    }

    if ($Warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "[WARNINGS]" -ForegroundColor Yellow
        $Warnings | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    }

    $Out = Join-Path $Root "logs\dry_run_validator_report.txt"

    @(
        "DRY RUN MODULE VALIDATOR REPORT"
        "Generated: $(Get-Date)"
        ""
        "Modules checked : $Checked"
        "Errors found    : $($Errors.Count)"
        "Warnings found  : $($Warnings.Count)"
        ""
        "[ERRORS]"
        $Errors
        ""
        "[WARNINGS]"
        $Warnings
    ) | Set-Content $Out -Encoding UTF8

    Write-Host ""
    Write-Host "Saved report:"
    Write-Host $Out

    # 39D_STANDARD_BACK_PAUSE
    Write-Host ""
    Write-Host "[B] Back"
    do { $BackChoice = (Read-Host "Selection").Trim().ToUpper() } until ($BackChoice -eq "B")
}
