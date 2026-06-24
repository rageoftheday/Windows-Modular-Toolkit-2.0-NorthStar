$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "MENU CONSISTENCY NORMALIZER" `
    -RequiresAdmin $false `
    -ScriptBlock {

    $ModulesPath = Join-Path $Root "modules"
    $BackupPath  = Join-Path $Root "backup\menu_consistency"

    if (!(Test-Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath | Out-Null
    }

    $Updated = 0

    Get-ChildItem $ModulesPath -Recurse -Filter "run.ps1" | ForEach-Object {

        $File = $_
        $Content = Get-Content $File.FullName -Raw
        $Original = $Content

        $Content = $Content -replace '\[EXIT\] Exit Toolkit', '[B] Back'
        $Content = $Content -replace '\[BACK\] Categories', '[B] Back'
        $Content = $Content -replace '\[BACK\] Back', '[B] Back'
        $Content = $Content -replace 'Selection', 'Selection'
        $Content = $Content -replace 'Select category', 'Select category'
        $Content = $Content -replace 'Select module', 'Select module'

        $Content = $Content -replace '\$Choice\.ToUpper\(\) -eq "EXIT"', '$Choice.ToUpper() -eq "B"'
        $Content = $Content -replace '\$Selection\.ToUpper\(\) -eq "EXIT"', '$Selection.ToUpper() -eq "B"'
        $Content = $Content -replace '\$ModuleSelection\.ToUpper\(\) -eq "EXIT"', '$ModuleSelection.ToUpper() -eq "B"'

        $Content = $Content -replace '\$ModuleSelection\.ToUpper\(\) -eq "BACK"', '$ModuleSelection.ToUpper() -eq "B"'
        $Content = $Content -replace '\$Selection\.ToUpper\(\) -eq "BACK"', '$Selection.ToUpper() -eq "B"'
        $Content = $Content -replace '\$Choice\.ToUpper\(\) -eq "BACK"', '$Choice.ToUpper() -eq "B"'

        if ($Content -ne $Original) {

            $Relative = $File.FullName.Replace($Root, "").TrimStart("\")
            $SafeName = $Relative -replace '[\\/:*?"<>|]', "_"

            Copy-Item $File.FullName (Join-Path $BackupPath "$SafeName.bak") -Force
            Set-Content $File.FullName $Content -Encoding UTF8

            Write-Host "[UPDATED] $Relative" -ForegroundColor Green
            $Updated++
        }
    }

    Write-Host ""
    Write-Host "Updated files: $Updated"
    Write-Host "Backups:"
    Write-Host $BackupPath
    Write-Host ""

    # 39D_STANDARD_BACK_PAUSE
    Write-Host ""
    Write-Host "[B] Back"
    do { $BackChoice = (Read-Host "Selection").Trim().ToUpper() } until ($BackChoice -eq "B")
}
