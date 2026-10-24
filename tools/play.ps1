param(
    [switch]$Console
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "find_godot.ps1")
$godot = Find-RiftwardGodot
$projectRoot = Split-Path -Parent $PSScriptRoot
$exe = if ($Console) { $godot.Console } else { $godot.Gui }
Write-Host "Launching RIFTWARD with $exe" -ForegroundColor Cyan
& $exe --path $projectRoot @args
exit $LASTEXITCODE
