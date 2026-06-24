$ScriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Resolve-Path "$ScriptFolder\.."
$Modules = Join-Path $Root "modules"

if (!(Test-Path $Modules)) {
    Write-Host "[FAIL] Modules folder not found:"
    Write-Host $Modules
    Read-Host "Press Enter to continue"
    exit
}

Get-ChildItem $Modules -Directory | ForEach-Object {

    $JsonPath = Join-Path $_.FullName "tool.json"

    if (Test-Path $JsonPath) {

        try {
            $Json = Get-Content $JsonPath -Raw | ConvertFrom-Json

            if ($null -eq $Json.dependencies) {
                $Json | Add-Member dependencies @() -MemberType NoteProperty -Force

                $Json |
                    ConvertTo-Json -Depth 10 |
                    Set-Content $JsonPath -Encoding UTF8

                Write-Host "[FIXED] Added dependencies: $($_.Name)"
            }
            else {
                Write-Host "[SKIP] Already has dependencies: $($_.Name)"
            }
        }
        catch {
            Write-Host "[FAIL] Invalid JSON: $($_.Name)"
        }
    }
}

Write-Host ""
Write-Host "Done."
Read-Host "Press Enter to continue"