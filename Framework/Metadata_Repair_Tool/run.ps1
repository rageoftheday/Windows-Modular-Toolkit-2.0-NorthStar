$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"
$Root = Resolve-Path "$PSScriptRoot\..\.."


. "$Root\core\bootstrap.ps1"
Clear-Host

$Root = Resolve-Path "$PSScriptRoot\..\.."


. "$Root\core\bootstrap.ps1"
Set-Location $Root

$Modules = Join-Path $Root "modules"

Write-Host "============================================================"
Write-Host "               METADATA REPAIR TOOL"
Write-Host "============================================================"
Write-Host ""

$CountFixed = 0
$CountExisting = 0

Get-ChildItem $Modules -Directory | ForEach-Object {

    $ModuleName = $_.Name
    $JsonFile = Join-Path $_.FullName "tool.json"

    Write-Host "Module: $ModuleName"

    if (Test-Path $JsonFile) {

        Write-Host "Status: Metadata Present"
        Write-Host ""

        $CountExisting++

    }
    else {

        $DefaultJson = @{
            name = $ModuleName.Replace("_"," ")
            category = "Custom Tools"
            subcategory = "Recovered"
            description = "Auto-generated metadata"
            keywords = @("toolkit","auto-generated")
            author = "Toolkit System"
            version = "1.0"
            risk = "Unknown"
            estimated_time = "Unknown"
            requires_admin = $false
            supports_logs = $false
            supports_export = $false
            entry = "run.bat"
        }

        $DefaultJson | ConvertTo-Json -Depth 5 | Set-Content $JsonFile

        Write-Host "Status: Metadata Rebuilt" -ForegroundColor Yellow
        Write-Host ""

        $CountFixed++
    }

}

Write-Host "============================================================"
Write-Host "Repair Complete"
Write-Host "============================================================"
Write-Host ""
Write-Host "Metadata Present : $CountExisting"
Write-Host "Metadata Rebuilt : $CountFixed"
Write-Host ""

Write-Host "[B] Back"
do { $BackChoice = (Read-Host "Selection").Trim().ToUpper() } until ($BackChoice -eq "B" -or $BackChoice -eq "")




