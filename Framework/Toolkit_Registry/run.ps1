# ============================================================
# TOOLKIT REGISTRY BUILDER
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"

Clear-Host
Set-Location $Root

$ModulesDir = Join-Path $Root "modules"
$FrameworkDir = Join-Path $Root "Framework"
$CacheDir   = Join-Path $Root "cache"
$Registry   = Join-Path $CacheDir "toolkit_registry.json"

if (!(Test-Path $CacheDir)) {
    New-Item -ItemType Directory -Path $CacheDir | Out-Null
}

function Pause-Toolkit {
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Build-Registry {

    Clear-Host

    Write-Host "============================================================"
    Write-Host "                 BUILDING REGISTRY"
    Write-Host "============================================================"
    Write-Host ""

    if (Test-Path $Registry) {
        Remove-Item $Registry -Force
    }

    $Results = @()
    $Count = 0
    $FrameworkCount = 0
    $UserCount = 0
    $Failed = 0

    $ScanRoots = @(
        [PSCustomObject]@{ Path = $FrameworkDir; Scope = "Framework"; RelativeRoot = "Framework" },
        [PSCustomObject]@{ Path = $ModulesDir; Scope = "User"; RelativeRoot = "modules" }
    )

    foreach ($ScanRoot in $ScanRoots) {

        if (!(Test-Path $ScanRoot.Path)) {
            continue
        }

        Get-ChildItem $ScanRoot.Path -Directory | ForEach-Object {

            if ($_.Name -ne "quarantine") {

                $ToolJson = Join-Path $_.FullName "tool.json"

                if (Test-Path $ToolJson) {

                    Write-Host "Processing [$($ScanRoot.Scope)]: $($_.Name)"

                    try {
                        $Json = Get-Content $ToolJson -Raw | ConvertFrom-Json

                        if ($null -eq $Json.dependencies) {
                            $Json | Add-Member dependencies @() -MemberType NoteProperty -Force
                        }

                        if ($null -eq $Json.entry) {
                            $Json | Add-Member entry "run.bat" -MemberType NoteProperty -Force
                        }

                        if ($ScanRoot.Scope -eq "Framework") {
                            $Json | Add-Member module_scope "Framework" -MemberType NoteProperty -Force
                            $Json | Add-Member framework_protected $true -MemberType NoteProperty -Force
                            $Json | Add-Member allow_delete $false -MemberType NoteProperty -Force
                            $Json | Add-Member allow_rename $false -MemberType NoteProperty -Force
                            $Json | Add-Member allow_move $false -MemberType NoteProperty -Force
                            $FrameworkCount++
                        }
                        else {
                            if ($Json.module_scope -eq "Framework" -or $Json.framework_protected -eq $true) {
                                $Json | Add-Member module_scope "User" -MemberType NoteProperty -Force
                                $Json | Add-Member framework_protected $false -MemberType NoteProperty -Force
                            }
                            $UserCount++
                        }

                        $Json | Add-Member folder $_.Name -MemberType NoteProperty -Force

                        $RelativePath = Join-Path $ScanRoot.RelativeRoot $_.Name

                        $Json | Add-Member path $RelativePath -MemberType NoteProperty -Force

                        $Results += $Json
                        $Count++
                    }
                    catch {
                        Write-Host "[FAIL] Invalid JSON: $($_.Name)" -ForegroundColor Red
                        $Failed++
                    }
                }
            }
        }
    }

    $Results |
        ConvertTo-Json -Depth 10 |
        Set-Content $Registry -Encoding UTF8

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Registry Build Complete"
    Write-Host "Total Indexed        : $Count"
    Write-Host "Framework Components : $FrameworkCount"
    Write-Host "User Modules         : $UserCount"
    Write-Host "Failed Modules       : $Failed"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "Registry Location:"
    Write-Host $Registry

    Pause-Toolkit
}

function View-Registry {

    Clear-Host

    if (Test-Path $Registry) {
        notepad $Registry
    }
    else {
        Write-Host ""
        Write-Host "Registry not found." -ForegroundColor Red
        Pause-Toolkit
    }
}

function Registry-Stats {

    Clear-Host

    Write-Host "============================================================"
    Write-Host "                 REGISTRY STATISTICS"
    Write-Host "============================================================"
    Write-Host ""

    if (!(Test-Path $Registry)) {
        Write-Host "Registry not found." -ForegroundColor Red
        Pause-Toolkit
        return
    }

    $Data = Get-Content $Registry -Raw | ConvertFrom-Json

    Write-Host ("Total Indexed Modules : " + $Data.Count)
    Write-Host ("Requires Admin        : " + (($Data | Where-Object { $_.requires_admin -eq $true }).Count))
    Write-Host ("Supports Logs         : " + (($Data | Where-Object { $_.supports_logs -eq $true }).Count))
    Write-Host ("Supports Export       : " + (($Data | Where-Object { $_.supports_export -eq $true }).Count))

    Write-Host ""

    $File = Get-Item $Registry

    Write-Host ("Registry Size      : " + $File.Length + " bytes")
    Write-Host ("Last Modified      : " + $File.LastWriteTime)

    Pause-Toolkit
}

function Validate-Registry {

    Clear-Host

    Write-Host "============================================================"
    Write-Host "                 VALIDATING REGISTRY"
    Write-Host "============================================================"
    Write-Host ""

    try {
        Get-Content $Registry -Raw | ConvertFrom-Json | Out-Null
        Write-Host "[PASS] Registry JSON valid" -ForegroundColor Green
    }
    catch {
        Write-Host "[FAIL] Registry JSON invalid" -ForegroundColor Red
    }

    Pause-Toolkit
}

function Delete-Registry {

    Clear-Host

    Write-Host "============================================================"
    Write-Host "                 DELETE REGISTRY CACHE"
    Write-Host "============================================================"
    Write-Host ""

    if (!(Test-Path $Registry)) {
        Write-Host "Registry cache not found." -ForegroundColor Yellow
        Pause-Toolkit
        return
    }

    Write-Host "This will permanently delete:"
    Write-Host ""
    Write-Host $Registry -ForegroundColor Cyan
    Write-Host ""

    $Confirm = Read-Host "Type DELETE to confirm"

    if ($Confirm -eq "DELETE") {
        Remove-Item $Registry -Force

        Write-Host ""
        Write-Host "[PASS] Registry cache deleted." -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "Cancelled." -ForegroundColor Yellow
    }

    Pause-Toolkit
}

while ($true) {

    Clear-Host

    Write-Host "============================================================"
    Write-Host "              TOOLKIT REGISTRY BUILDER"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "[1] Build Registry"
    Write-Host "[2] View Registry"
    Write-Host "[3] Registry Statistics"
    Write-Host "[4] Validate Registry"
    Write-Host "[5] Delete Registry Cache"
    Write-Host ""
    Write-Host "[B] Back"
    Write-Host ""
    Write-Host "============================================================"
    Write-Host ""

    $Choice = Read-Host "Selection"

    switch ($Choice.ToUpper()) {

        "1" {
            Build-Registry
        }

        "2" {
            View-Registry
        }

        "3" {
            Registry-Stats
        }

        "4" {
            Validate-Registry
        }

        "5" {
            Delete-Registry
        }

        "B" {
            $Global:ToolkitSuppressCompletion = $true
            return
        }
        "Q" {
            $Global:ToolkitSuppressCompletion = $true
            return
        }
    }
}