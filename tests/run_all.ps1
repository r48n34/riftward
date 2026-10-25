param(
    [switch]$Quick
)
$ErrorActionPreference = "Stop"
. (Join-Path (Split-Path -Parent $PSScriptRoot) "tools\find_godot.ps1")
$projectRoot = Split-Path -Parent $PSScriptRoot

# Some sandboxed dev environments deny writes under %APPDATA%. Godot's user://
# (profile saves, engine logs) lives there, so probe it and redirect Godot's
# data root into the workspace when it is not writable. A fresh user dir keeps
# suites deterministic across runs.
$appDataProbe = Join-Path $env:APPDATA "Godot\app_userdata\riftward_write_probe"
$appDataWritable = $true
try {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $appDataProbe) | Out-Null
    Set-Content -LiteralPath $appDataProbe -Value "probe" -ErrorAction Stop
    Remove-Item -LiteralPath $appDataProbe -Force -ErrorAction SilentlyContinue
} catch {
    $appDataWritable = $false
}
if (-not $appDataWritable) {
    $env:APPDATA = Join-Path $projectRoot "tests\.appdata"
    $godotUserDir = Join-Path $env:APPDATA "Godot\app_userdata\RIFTWARD"
    if (Test-Path -LiteralPath $godotUserDir) {
        Remove-Item -LiteralPath $godotUserDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $godotUserDir) | Out-Null
    Write-Host "APPDATA is not writable; Godot user:// redirected to $($env:APPDATA)" -ForegroundColor DarkYellow
}

$godot = Find-RiftwardGodot
$console = $godot.Console
$logDir = Join-Path $PSScriptRoot "artifacts\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# Suite list lives in tests/suites.json so the local gate and the GitHub Actions
# workflow (.github/workflows/tests.yml, the README "headless-tests" badge) cannot
# drift apart. Add a new suite there, not here.
$manifestPath = Join-Path $PSScriptRoot "suites.json"
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Suite manifest not found: $manifestPath"
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$tests = @($manifest.suites | ForEach-Object {
    [pscustomobject]@{
        Name = [string]$_.name
        Args = @($_.args | ForEach-Object { [string]$_ })
        Marker = if ($null -ne $_.marker) { [string]$_.marker } else { $null }
        TimeoutMs = [int]$_.timeoutSeconds * 1000
    }
})
if ($tests.Count -eq 0) {
    throw "Suite manifest $manifestPath contains no suites."
}

if ($Quick) {
    $tests = $tests | Where-Object { $_.Name -in @("boot", "shooting", "inventory", "integration", "death", "ui", "ui_icons") }
}

Write-Host "Running $($tests.Count) suite(s) from tests/suites.json (Godot $($manifest.godotVersion))" -ForegroundColor DarkGray

$results = @()
foreach ($test in $tests) {
    $name = $test.Name
    Write-Host "=== Running $name ===" -ForegroundColor Cyan
    $outPath = Join-Path $logDir "$name.out.txt"
    $errPath = Join-Path $logDir "$name.err.txt"
    Remove-Item -LiteralPath $outPath, $errPath -ErrorAction SilentlyContinue
    $arguments = @("--headless", "--path", $projectRoot) + @($test.Args | ForEach-Object { [string]$_ })
    $proc = Start-Process -FilePath $console -ArgumentList $arguments -WorkingDirectory $projectRoot -RedirectStandardOutput $outPath -RedirectStandardError $errPath -PassThru -WindowStyle Hidden
    $finished = $proc.WaitForExit([int]$test.TimeoutMs)
    if (-not $finished) {
        try { $proc.Kill() } catch { }
        $results += [pscustomobject]@{ Name = $name; Passed = $false; Detail = "timeout" }
        Write-Host "TIMEOUT: $name" -ForegroundColor Red
        continue
    }
    $output = ""
    if (Test-Path -LiteralPath $outPath) { $output += Get-Content -LiteralPath $outPath -Raw }
    if (Test-Path -LiteralPath $errPath) { $output += "`n" + (Get-Content -LiteralPath $errPath -Raw) }
    $exitCode = $proc.ExitCode
    $hasScriptError = $output -match "SCRIPT ERROR"
    # The engine probes the Windows certificate store at startup. Some sandboxed
    # environments deny that read; it is engine noise, not a game error.
    $errorOutput = $output -replace [regex]::Escape("ERROR: Failed to read the root certificate store."), ""
    $hasRuntimeError = $errorOutput -match "(?m)(^|\s)ERROR:"
    $hasMarker = $true
    if ($test.Marker) { $hasMarker = $output -match [regex]::Escape($test.Marker) }
    # PowerShell's Start-Process can leave ExitCode null in this environment;
    # explicit PASS markers plus absence of script/runtime errors are the gates.
    $passed = (-not $hasScriptError) -and (-not $hasRuntimeError) -and $hasMarker
    $detail = "finished"
    if ($hasScriptError) { $detail += " script-errors" }
    if ($hasRuntimeError) { $detail += " runtime-errors" }
    if (-not $hasMarker) { $detail += " missing-marker" }
    $results += [pscustomobject]@{ Name = $name; Passed = $passed; Detail = $detail }
    if ($passed) {
        Write-Host "PASS: $name ($detail)" -ForegroundColor Green
    } else {
        Write-Host "FAIL: $name ($detail)" -ForegroundColor Red
        if (Test-Path -LiteralPath $outPath) {
            Get-Content -LiteralPath $outPath -Tail 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
        }
        if (Test-Path -LiteralPath $errPath) {
            Get-Content -LiteralPath $errPath -Tail 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
        }
    }
}

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize
$failed = @($results | Where-Object { -not $_.Passed })
if ($failed.Count -gt 0) {
    Write-Host "$($failed.Count) test suite(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host "All $($results.Count) test suites passed." -ForegroundColor Green
exit 0
