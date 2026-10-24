param(
    [switch]$Debug,
    [switch]$Zip
)
<#
Exports RIFTWARD as a standalone Windows x86_64 build.

Requirements:
  * Godot 4.7.2 (tools/find_godot.ps1 locates it, or set $env:GODOT_BIN)
  * Godot 4.7.2 export templates installed for the same engine version
    (Editor -> Manage Export Templates, or place them in
     %APPDATA%\Godot\export_templates\<version>\)

Usage:
  powershell -ExecutionPolicy Bypass -File tools/build_export.ps1
  powershell -ExecutionPolicy Bypass -File tools/build_export.ps1 -Zip
  powershell -ExecutionPolicy Bypass -File tools/build_export.ps1 -Debug
#>
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "find_godot.ps1")

$godot = Find-RiftwardGodot
$exe = if ($godot.Console) { $godot.Console } else { $godot.Gui }
$projectRoot = Split-Path -Parent $PSScriptRoot

# --- Resolve the installed template version, e.g. "4.7.2.stable" ---
$rawVersion = (& $exe --version 2>$null | Out-String).Trim()
if (-not $rawVersion) { throw "Could not query the Godot version from $exe" }
$version = ($rawVersion -split '\.official')[0]
Write-Host "Godot: $exe ($version)" -ForegroundColor Cyan

$templateDir = Join-Path $env:APPDATA "Godot\export_templates\$version"
$templateName = if ($Debug) { "windows_debug_x86_64.exe" } else { "windows_release_x86_64.exe" }
if (-not (Test-Path -LiteralPath (Join-Path $templateDir $templateName))) {
    throw @"
Export templates for Godot $version are not installed.

Expected: $(Join-Path $templateDir $templateName)

Install them one of two ways:
  1. Open the project in the Godot editor -> Editor -> Manage Export Templates -> Download and Install.
  2. Download Godot_v$version`_export_templates.tpz from the Godot release page and unzip its
     `templates` folder into: $templateDir
"@
}

# --- Export ---
$buildDir = Join-Path $projectRoot "build"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

$preset = "Windows Desktop"
$outExe = Join-Path $buildDir "RIFTWARD.exe"
$mode = if ($Debug) { "--export-debug" } else { "--export-release" }

Push-Location $projectRoot
try {
    Write-Host "Exporting preset '$preset' -> build\RIFTWARD.exe" -ForegroundColor Cyan
    & $exe --headless --path . $mode $preset "build/RIFTWARD.exe"
    if ($LASTEXITCODE -ne 0) { throw "Godot export failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}

$pck = Join-Path $buildDir "RIFTWARD.pck"
foreach ($f in @($outExe, $pck)) {
    if (-not (Test-Path -LiteralPath $f)) { throw "Export did not produce $f" }
    $mb = [math]::Round((Get-Item -LiteralPath $f).Length / 1MB, 2)
    Write-Host ("  {0} ({1} MB)" -f (Split-Path -Leaf $f), $mb) -ForegroundColor Green
}
Write-Host "Build complete: $buildDir" -ForegroundColor Green

# --- Optional distributable package (exe + pck + README, zipped) ---
if ($Zip) {
    & (Join-Path $PSScriptRoot "package_release.ps1")
    if ($LASTEXITCODE -ne 0) { throw "Packaging failed with exit code $LASTEXITCODE" }
}
