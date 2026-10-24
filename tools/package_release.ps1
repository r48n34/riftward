param(
    [switch]$SkipZip
)
<#
Assembles a player-facing release folder from the exported build.

Produces:
  release/windows/          RIFTWARD.exe + RIFTWARD.pck + README.txt
  release/RIFTWARD-win64.zip
  release/SHA256SUMS.txt

Run tools/build_export.ps1 first so build/ is current.

Usage:
  powershell -ExecutionPolicy Bypass -File tools/package_release.ps1
#>
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$build = Join-Path $root "build"
$release = Join-Path $root "release"
$stage = Join-Path $release "windows"

$exe = Join-Path $build "RIFTWARD.exe"
$pck = Join-Path $build "RIFTWARD.pck"
foreach ($f in @($exe, $pck)) {
    if (-not (Test-Path -LiteralPath $f)) { throw "Missing $f - run tools/build_export.ps1 first." }
}

if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

Copy-Item -LiteralPath $exe -Destination $stage
Copy-Item -LiteralPath $pck -Destination $stage
Copy-Item -LiteralPath (Join-Path $root "docs\PLAYER_README.txt") -Destination (Join-Path $stage "README.txt")

$files = Get-ChildItem -LiteralPath $stage -File | Sort-Object Name
foreach ($f in $files) {
    Write-Host ("  {0} ({1} MB)" -f $f.Name, [math]::Round($f.Length / 1MB, 2)) -ForegroundColor Green
}

$zip = Join-Path $release "RIFTWARD-win64.zip"
if (-not $SkipZip) {
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal
    Write-Host ("Packaged {0} ({1} MB)" -f $zip, [math]::Round((Get-Item -LiteralPath $zip).Length / 1MB, 2)) -ForegroundColor Cyan
}

$sums = Join-Path $release "SHA256SUMS.txt"
$lines = foreach ($f in $files) {
    $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower()
    "$h  $($f.Name)"
}
$lines | Set-Content -LiteralPath $sums -Encoding utf8
Write-Host "Wrote $sums" -ForegroundColor Cyan
