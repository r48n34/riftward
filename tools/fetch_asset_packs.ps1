<#
.SYNOPSIS
    Downloads, curates and verifies the CC0 asset packs RIFTWARD ships in assets/.

.DESCRIPTION
    RIFTWARD's art is procedural, but a small curated set of CC0 particle textures,
    prototype textures, UI/impact/weapon sounds and music jingles is committed so the
    game has authored feedback without any paid or attribution-required assets.

    This script is idempotent: by default it skips a pack whose MANIFEST.json is
    present and whose files still match their recorded sha256 hashes. Re-running it
    never re-downloads, rewrites or "repairs" already-verified packs.

    Network access in this project's build sandbox only works through Python's
    OpenSSL stack (PowerShell Invoke-WebRequest / WebClient / curl.exe fail with
    schannel SEC_E_NO_CREDENTIALS). Downloads therefore shell out to a Python
    interpreter with a browser User-Agent. Everything else (unzip, copy, hashing,
    manifest writing, verification) is native PowerShell and works offline.

    Repo layout this script owns:
      assets/cc0/<pack>/LICENSE.txt          canonical CC0 license per pack
      assets/cc0/<pack>/MANIFEST.json        provenance + per-file sha256 + sizes
      assets/textures/particles/*.png        curated Kenney Particle Pack subset
      assets/textures/prototype/{dark,light}/*.png
      assets/audio/cc0/kenney_interface/*.wav
      assets/audio/cc0/kenney_ui/*.wav
      assets/audio/cc0/kenney_scifi/*.ogg
      assets/audio/cc0/kenney_impact/*.ogg
      assets/music/kenney/*.ogg

    Sources (all CC0, all verified reachable at time of writing):
      784 Kenney Particle Pack        Calinou/kenney-particle-pack      @7e801dc
      781 Kenney Prototype Textures   Calinou/kenney-prototype-textures @db6622f
      794 Kenney Interface Sounds     Calinou/kenney-interface-sounds   @ad144fc
      796 Kenney UI Audio             Calinou/kenney-ui-audio           @b80d045
      kenney.nl sci-fi sounds / impact sounds / music jingles: the Godot Asset
      Library copies of those three point at deleted GitHub repositories, so they
      are fetched straight from kenney.nl (still CC0) and the URL + archive sha256
      are recorded in their manifests instead of a commit hash.

.PARAMETER Offline
    No network. Verify every committed pack against its MANIFEST.json: files exist,
    byte sizes match and sha256 hashes match. Exits 1 if anything drifted/missing.

.PARAMETER Force
    Re-download and re-curate every pack even when the current copy verifies.
    Default behaviour is skip-if-verified.

.PARAMETER PythonBin
    Explicit Python interpreter path. Default resolution order:
    $env:PYTHON_BIN, the DSH bundled runtime, "python", "py -3".

.PARAMETER SizeCapMB
    Hard cap for the total curated payload recorded in the manifests (default 18).

.EXAMPLE
    pwsh -File tools/fetch_asset_packs.ps1                 # skip-if-verified, download missing
    pwsh -File tools/fetch_asset_packs.ps1 -Offline        # CI/local integrity gate
    pwsh -File tools/fetch_asset_packs.ps1 -Force          # refresh everything from upstream
#>
[CmdletBinding()]
param(
    [switch]$Offline,
    [switch]$Force,
    [string]$PythonBin = "",
    [int]$SizeCapMB = 18
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$PackRoot = Join-Path $RepoRoot "assets\cc0"
$WorkRoot = Join-Path $env:TEMP "riftward_cc0"
$DownloadDir = Join-Path $WorkRoot "dl"
$ExtractRoot = Join-Path $WorkRoot "extract"
$HelperPath = Join-Path $WorkRoot "riftward_http.py"

$script:Failures = New-Object System.Collections.ArrayList
$script:Warnings = New-Object System.Collections.ArrayList

# ---------------------------------------------------------------------------
# Pack table. "Url" is exactly what is fetched; for the four GitHub-hosted packs
# the URL is the immutable commit archive advertised by the Godot Asset Library
# API (asset-library/api/asset/<id> -> download_url), so "Commit" is the real
# content id. kenney.nl URLs are content-hashed paths on kenney.nl and are
# recorded together with the archive sha256 instead.
# ---------------------------------------------------------------------------
$script:Packs = @(
    @{
        Id = "kenney_particle_pack"
        AssetLibraryDownloadUrl = "https://codeload.github.com/Calinou/kenney-particle-pack/zip/7e801dc538996622a91327bb1dd5879cf977aa09"
        AssetLibraryDownloadStatus = "ok"
        Title = "Kenney Particle Pack"
        Author = "Kenney (kenney.nl)"
        Uploader = "Calinou"
        AssetLibraryId = 784
        AssetLibraryVersion = "1.0.2"
        SourceKind = "github-archive"
        Url = "https://codeload.github.com/Calinou/kenney-particle-pack/zip/7e801dc538996622a91327bb1dd5879cf977aa09"
        Commit = "7e801dc538996622a91327bb1dd5879cf977aa09"
        LicenseSource = "addons/kenney_particle_pack/LICENSE.txt"
        SourcePrefix = "addons/kenney_particle_pack/"
        Destination = "assets/textures/particles"
        Flatten = $true
        Glob = ""
        Files = @(
            "circle_01.png", "circle_02.png", "circle_03.png", "circle_04.png",
            "dirt_01.png", "dirt_02.png", "dirt_03.png",
            "fire_01.png", "fire_02.png",
            "flame_01.png", "flame_02.png", "flame_03.png", "flame_04.png",
            "flare_01.png",
            "magic_01.png", "magic_02.png",
            "muzzle_01.png", "muzzle_02.png", "muzzle_03.png", "muzzle_04.png", "muzzle_05.png",
            "scorch_01.png", "scorch_02.png", "scorch_03.png",
            "smoke_01.png", "smoke_02.png", "smoke_03.png", "smoke_04.png", "smoke_05.png", "smoke_06.png",
            "spark_01.png", "spark_02.png", "spark_03.png", "spark_04.png", "spark_05.png",
            "star_01.png", "star_02.png",
            "trace_01.png", "trace_02.png", "trace_03.png", "trace_04.png",
            "twirl_01.png", "twirl_02.png"
        )
        # Logical effect id -> curated file. Keep in sync with the effect table in
        # features/fx/particle_library.gd; tests/assets_test.gd checks that every
        # logical id resolves to a texture on disk.
        LogicalNames = [ordered]@{
            muzzle = "muzzle_01.png"
            impact_metal = "spark_02.png"
            impact_dirt = "dirt_01.png"
            explosion = "fire_01.png"
            dust = "smoke_01.png"
            exhaust = "smoke_03.png"
            sparks = "spark_05.png"
            splash = "circle_02.png"
            smoke = "smoke_05.png"
            rain = "trace_01.png"
            portal = "twirl_01.png"
            scorch = "scorch_01.png"
            flare = "flare_01.png"
            trail = "trace_03.png"
        }
    }
    @{
        Id = "kenney_prototype_textures"
        AssetLibraryDownloadUrl = "https://codeload.github.com/Calinou/kenney-prototype-textures/zip/db6622fbe90621eed70a0b417ae8d97281f45e6c"
        AssetLibraryDownloadStatus = "ok"
        Title = "Kenney Prototype Textures"
        Author = "Kenney (kenney.nl)"
        Uploader = "Calinou"
        AssetLibraryId = 781
        AssetLibraryVersion = "1.0.2"
        SourceKind = "github-archive"
        Url = "https://codeload.github.com/Calinou/kenney-prototype-textures/zip/db6622fbe90621eed70a0b417ae8d97281f45e6c"
        Commit = "db6622fbe90621eed70a0b417ae8d97281f45e6c"
        LicenseSource = "addons/kenney_prototype_textures/LICENSE.txt"
        SourcePrefix = "addons/kenney_prototype_textures/"
        Destination = "assets/textures/prototype"
        Flatten = $false
        Glob = ""
        # dark/ = full modular panel set (grid, hatch, checker, hazard, door frame);
        # light/ = the neutral/light variants useful for lit interior floors.
        Files = @(
            "dark/texture_01.png", "dark/texture_02.png", "dark/texture_03.png", "dark/texture_04.png",
            "dark/texture_05.png", "dark/texture_06.png", "dark/texture_07.png", "dark/texture_08.png",
            "dark/texture_09.png", "dark/texture_10.png", "dark/texture_11.png", "dark/texture_12.png",
            "dark/texture_13.png",
            "light/texture_01.png", "light/texture_02.png", "light/texture_03.png", "light/texture_04.png",
            "light/texture_07.png", "light/texture_09.png", "light/texture_12.png"
        )
    }
    @{
        Id = "kenney_interface_sounds"
        AssetLibraryDownloadUrl = "https://codeload.github.com/Calinou/kenney-interface-sounds/zip/ad144fc2dd079cdd728bc8c7fcf9c4e64a7a7f83"
        AssetLibraryDownloadStatus = "ok"
        Title = "Kenney Interface Sounds"
        Author = "Kenney (kenney.nl)"
        Uploader = "Calinou"
        AssetLibraryId = 794
        AssetLibraryVersion = "1.0.0"
        SourceKind = "github-archive"
        Url = "https://codeload.github.com/Calinou/kenney-interface-sounds/zip/ad144fc2dd079cdd728bc8c7fcf9c4e64a7a7f83"
        Commit = "ad144fc2dd079cdd728bc8c7fcf9c4e64a7a7f83"
        LicenseSource = "addons/kenney_interface_sounds/LICENSE.txt"
        SourcePrefix = "addons/kenney_interface_sounds/"
        Destination = "assets/audio/cc0/kenney_interface"
        Flatten = $true
        Glob = ""
        # Original Kenney stems are preserved: autoload/audio_director.gd indexes
        # res://assets/audio/cc0/** by filename stem.
        Files = @(
            "back_001.wav", "click_001.wav", "click_002.wav", "click_003.wav",
            "close_001.wav", "confirmation_001.wav", "confirmation_002.wav",
            "drop_001.wav", "error_001.wav", "glass_001.wav", "open_001.wav",
            "pluck_001.wav", "scratch_001.wav", "select_001.wav", "select_002.wav",
            "switch_001.wav", "tick_001.wav", "toggle_001.wav"
        )
    }
    @{
        Id = "kenney_ui_audio"
        AssetLibraryDownloadUrl = "https://codeload.github.com/Calinou/kenney-ui-audio/zip/b80d045f07d782cd9068f7071fb1e7873a0de04d"
        AssetLibraryDownloadStatus = "ok"
        Title = "Kenney UI Audio"
        Author = "Kenney (kenney.nl)"
        Uploader = "Calinou"
        AssetLibraryId = 796
        AssetLibraryVersion = "1.0.0"
        SourceKind = "github-archive"
        Url = "https://codeload.github.com/Calinou/kenney-ui-audio/zip/b80d045f07d782cd9068f7071fb1e7873a0de04d"
        Commit = "b80d045f07d782cd9068f7071fb1e7873a0de04d"
        LicenseSource = "addons/kenney_ui_audio/LICENSE.txt"
        SourcePrefix = "addons/kenney_ui_audio/"
        Destination = "assets/audio/cc0/kenney_ui"
        Flatten = $true
        Glob = ""
        Files = @(
            "click1.wav", "click2.wav", "click3.wav", "click4.wav", "click5.wav",
            "mouseclick1.wav", "mouserelease1.wav",
            "rollover1.wav", "rollover2.wav", "rollover3.wav", "rollover4.wav", "rollover5.wav", "rollover6.wav",
            "switch1.wav", "switch2.wav", "switch3.wav", "switch4.wav", "switch5.wav"
        )
    }
    @{
        Id = "kenney_scifi_sounds"
        Title = "Kenney Sci-Fi Sounds"
        Author = "Kenney (kenney.nl)"
        Uploader = "Lopano"
        AssetLibraryId = 1834
        AssetLibraryVersion = "1.0.2"
        # The Asset Library entry's download_url points at a deleted GitHub repo
        # (verified HTTP 404); the pack is fetched from kenney.nl instead.
        AssetLibraryDownloadUrl = "https://github.com/Loppansson/kenney-sci-fi-sounds-for-godot/archive/c094967fe930c57ddb376f67c75f8aa0296690b7.zip"
        AssetLibraryDownloadStatus = "dead"
        SourceKind = "kenney.nl"
        Url = "https://kenney.nl/media/pages/assets/sci-fi-sounds/6b296f9ecf-1677589334/kenney_sci-fi-sounds.zip"
        Commit = ""
        LicenseSource = "License.txt"
        SourcePrefix = "Audio/"
        Destination = "assets/audio/cc0/kenney_scifi"
        Flatten = $true
        Glob = ""
        Files = @(
            "laserLarge_000.ogg", "laserLarge_001.ogg", "laserLarge_002.ogg",
            "laserSmall_000.ogg", "laserSmall_001.ogg", "laserSmall_002.ogg",
            "laserRetro_000.ogg",
            "explosionCrunch_000.ogg", "explosionCrunch_001.ogg", "explosionCrunch_002.ogg",
            "impactMetal_000.ogg", "impactMetal_001.ogg", "impactMetal_002.ogg",
            "lowFrequency_explosion_000.ogg", "lowFrequency_explosion_001.ogg",
            "doorOpen_000.ogg", "doorClose_000.ogg", "forceField_000.ogg",
            "thrusterFire_000.ogg", "thrusterFire_001.ogg",
            "engineCircular_000.ogg", "engineCircular_001.ogg"
        )
    }
    @{
        Id = "kenney_impact_sounds"
        Title = "Kenney Impact Sounds"
        Author = "Kenney (kenney.nl)"
        Uploader = "Lopano"
        AssetLibraryId = 1841
        AssetLibraryVersion = "1.0.2"
        # Asset Library download_url is a deleted repo (verified HTTP 404).
        AssetLibraryDownloadUrl = "https://github.com/Loppansson/kenney-impact-sounds-for-godot/archive/999dd1684873f8b020a3aa5b26e713da21688924.zip"
        AssetLibraryDownloadStatus = "dead"
        SourceKind = "kenney.nl"
        Url = "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip"
        Commit = ""
        LicenseSource = "License.txt"
        SourcePrefix = ""
        Destination = "assets/audio/cc0/kenney_impact"
        Flatten = $true
        Glob = "Audio/*.ogg"
        Files = @()
    }
    @{
        Id = "kenney_music_jingles"
        Title = "Kenney Music Jingles"
        Author = "Kenney (kenney.nl)"
        Uploader = "Lopano"
        AssetLibraryId = 1839
        AssetLibraryVersion = "1.0.2"
        # Asset Library download_url is a deleted repo (verified HTTP 404).
        AssetLibraryDownloadUrl = "https://github.com/Loppansson/kenney-music-jingles-for-godot/archive/1312c1a8ab2b5830136a5f53ea8c570389bd0808.zip"
        AssetLibraryDownloadStatus = "dead"
        SourceKind = "kenney.nl"
        Url = "https://kenney.nl/media/pages/assets/music-jingles/f37e530b9e-1677590399/kenney_music-jingles.zip"
        Commit = ""
        LicenseSource = "License.txt"
        SourcePrefix = "Audio/"
        Destination = "assets/music/kenney"
        Flatten = $true
        Glob = ""
        # Short stings only (each < 45 KB); no multi-minute loops are committed.
        # Stems are kept verbatim so the music director can map mood -> file.
        Files = @(
            "8-Bit jingles/jingles_NES00.ogg", "8-Bit jingles/jingles_NES03.ogg",
            "8-Bit jingles/jingles_NES05.ogg", "8-Bit jingles/jingles_NES07.ogg",
            "Hit jingles/jingles_HIT00.ogg", "Hit jingles/jingles_HIT07.ogg", "Hit jingles/jingles_HIT15.ogg",
            "Pizzicato jingles/jingles_PIZZI00.ogg", "Pizzicato jingles/jingles_PIZZI04.ogg",
            "Pizzicato jingles/jingles_PIZZI12.ogg",
            "Sax jingles/jingles_SAX00.ogg", "Sax jingles/jingles_SAX04.ogg", "Sax jingles/jingles_SAX07.ogg",
            "Steel jingles/jingles_STEEL00.ogg", "Steel jingles/jingles_STEEL03.ogg",
            "Steel jingles/jingles_STEEL14.ogg"
        )
    }
)

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------
function Write-Info([string]$Message) { Write-Host "[assets] $Message" -ForegroundColor DarkGray }
function Write-Ok([string]$Message) { Write-Host "[assets] OK   $Message" -ForegroundColor Green }
function Write-Skip([string]$Message) { Write-Host "[assets] SKIP $Message" -ForegroundColor DarkYellow }
function Add-Failure([string]$Message) {
    [void]$script:Failures.Add($Message)
    Write-Host "[assets] FAIL $Message" -ForegroundColor Red
}

function Get-ManifestPath([hashtable]$Pack) {
    return (Join-Path (Join-Path $PackRoot $Pack.Id) "MANIFEST.json")
}

function Get-LicensePath([hashtable]$Pack) {
    return (Join-Path (Join-Path $PackRoot $Pack.Id) "LICENSE.txt")
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-TextFile([string]$Path, [string]$Text) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

# ---------------------------------------------------------------------------
# Python discovery: $PythonBin -> $env:PYTHON_BIN -> DSH bundled runtime ->
# python -> py -3. Returns a string array: exe plus optional leading args.
# ---------------------------------------------------------------------------
function Resolve-Python {
    $bundled = "C:\Users\devre\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe"
    $candidates = @()
    if ($PythonBin -ne "") { $candidates += , @($PythonBin) }
    if ($env:PYTHON_BIN -and $env:PYTHON_BIN -ne "") { $candidates += , @($env:PYTHON_BIN) }
    $candidates += , @($bundled)
    $candidates += , @("python")
    $candidates += , @("py", "-3")

    foreach ($candidate in $candidates) {
        $exe = [string]$candidate[0]
        $pre = @()
        if ($candidate.Count -gt 1) { $pre = @($candidate[1..($candidate.Count - 1)]) }
        try {
            $output = & $exe @pre -c "import sys; print('%d.%d' % sys.version_info[:2])" 2>$null
            $code = $LASTEXITCODE
        } catch {
            continue
        }
        if ($code -eq 0 -and $output -and ([string]$output).Trim() -match '^3\.') {
            Write-Info "Python: $exe $($pre -join ' ') ($(([string]$output).Trim()))"
            return @($exe) + $pre
        }
    }
    return $null
}

function Invoke-Python {
    param(
        [Parameter(Mandatory = $true)][string[]]$PythonCmd,
        [Parameter(Mandatory = $true)][string[]]$PythonArgs
    )
    $exe = $PythonCmd[0]
    $pre = @()
    if ($PythonCmd.Count -gt 1) { $pre = @($PythonCmd[1..($PythonCmd.Count - 1)]) }
    $all = @($pre) + @($PythonArgs)
    $output = & $exe @all 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        throw "Python command failed (exit $code): $exe $($all -join ' ')`n$($output -join "`n")"
    }
    return $output
}

$script:HttpHelperSource = @'
"""Tiny HTTP downloader used by tools/fetch_asset_packs.ps1.

PowerShell's TLS stack is unusable in the build sandbox, Python's OpenSSL is not.
A browser-like User-Agent is mandatory (godotengine.org and some CDNs return 403
for urllib's default agent). Supports one retry with backoff.
"""
import os
import sys
import time
import urllib.error
import urllib.request

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
)


def download(url, dest, attempts=3):
    os.makedirs(os.path.dirname(os.path.abspath(dest)), exist_ok=True)
    last_error = None
    for attempt in range(1, attempts + 1):
        tmp = dest + ".part"
        try:
            request = urllib.request.Request(
                url,
                headers={
                    "User-Agent": USER_AGENT,
                    "Accept": "*/*",
                    "Accept-Encoding": "identity",
                },
            )
            with urllib.request.urlopen(request, timeout=120) as response, open(tmp, "wb") as handle:
                while True:
                    chunk = response.read(262144)
                    if not chunk:
                        break
                    handle.write(chunk)
            size = os.path.getsize(tmp)
            if size <= 0:
                raise IOError("downloaded 0 bytes")
            os.replace(tmp, dest)
            print("downloaded %d bytes -> %s" % (size, dest))
            return 0
        except Exception as exc:  # noqa: BLE001 - report and retry
            last_error = exc
            try:
                if os.path.exists(tmp):
                    os.remove(tmp)
            except OSError:
                pass
            if attempt < attempts:
                time.sleep(1.5 * attempt)
    print("download failed: %s (%r)" % (url, last_error), file=sys.stderr)
    return 1


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("usage: riftward_http.py <url> <destination>", file=sys.stderr)
        sys.exit(2)
    sys.exit(download(sys.argv[1], sys.argv[2]))
'@

function Ensure-HttpHelper {
    if (-not (Test-Path -LiteralPath $WorkRoot)) {
        New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null
    }
    if (-not (Test-Path -LiteralPath $DownloadDir)) {
        New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null
    }
    # Always refresh the helper so edits land deterministically.
    Write-TextFile $HelperPath $script:HttpHelperSource
}

# ---------------------------------------------------------------------------
# Verification: compare committed tree against MANIFEST.json.
# Returns a hashtable: Ok, Problems (array), Bytes, FileCount, Manifest.
# ---------------------------------------------------------------------------
function Test-Pack {
    param([hashtable]$Pack)

    $result = @{ Ok = $false; Problems = (New-Object System.Collections.ArrayList); Bytes = 0; FileCount = 0; Manifest = $null }
    $manifestPath = Get-ManifestPath $Pack
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        [void]$result.Problems.Add("missing manifest: $(Get-Relative $manifestPath)")
        return $result
    }
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        [void]$result.Problems.Add("unparseable manifest: $(Get-Relative $manifestPath): $($_.Exception.Message)")
        return $result
    }
    $result.Manifest = $manifest

    if ($manifest.pack_id -ne $Pack.Id) {
        [void]$result.Problems.Add("manifest pack_id '$($manifest.pack_id)' != '$($Pack.Id)'")
    }
    if ([string]$manifest.license -notmatch 'CC0') {
        [void]$result.Problems.Add("manifest license is not CC0: '$($manifest.license)'")
    }

    $licensePath = Get-LicensePath $Pack
    if (-not (Test-Path -LiteralPath $licensePath)) {
        [void]$result.Problems.Add("missing license: $(Get-Relative $licensePath)")
    } elseif ((Get-Item -LiteralPath $licensePath).Length -lt 64) {
        [void]$result.Problems.Add("license looks empty: $(Get-Relative $licensePath)")
    }

    $files = @($manifest.files)
    if ($files.Count -eq 0) {
        [void]$result.Problems.Add("manifest lists no files: $(Get-Relative $manifestPath)")
    }
    foreach ($entry in $files) {
        $rel = [string]$entry.path
        $diskPath = ConvertFrom-ResPath $rel
        if (-not (Test-Path -LiteralPath $diskPath)) {
            [void]$result.Problems.Add("missing file: $rel")
            continue
        }
        $item = Get-Item -LiteralPath $diskPath
        if ([long]$item.Length -ne [long]$entry.bytes) {
            [void]$result.Problems.Add("size mismatch: $rel (manifest $($entry.bytes), disk $($item.Length))")
            continue
        }
        $hash = Get-Sha256 $diskPath
        if ($hash -ne [string]$entry.sha256) {
            [void]$result.Problems.Add("sha256 mismatch: $rel")
            continue
        }
        $result.Bytes += [long]$item.Length
        $result.FileCount += 1
    }

    foreach ($copy in @($manifest.license_copies)) {
        if ($null -eq $copy) { continue }
        $copyPath = ConvertFrom-ResPath ([string]$copy)
        if (-not (Test-Path -LiteralPath $copyPath)) {
            [void]$result.Problems.Add("missing license copy: $copy")
        }
    }

    $result.Ok = ($result.Problems.Count -eq 0)
    return $result
}

function Get-Relative([string]$Path) {
    if ($Path.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $Path.Substring($RepoRoot.Length).TrimStart('\', '/')
    }
    return $Path
}

function ConvertFrom-ResPath([string]$ResPath) {
    if ($ResPath.StartsWith("res://")) {
        return (Join-Path $RepoRoot ($ResPath.Substring(6) -replace '/', '\'))
    }
    return $ResPath
}

# ---------------------------------------------------------------------------
# Fetch + curate one pack.
# ---------------------------------------------------------------------------
function Fetch-Pack {
    param([hashtable]$Pack, [string[]]$PythonCmd)

    $zipPath = Join-Path $DownloadDir ($Pack.Id + ".zip")
    $packExtract = Join-Path $ExtractRoot $Pack.Id
    $manifestPath = Get-ManifestPath $Pack
    $packMetaDir = Join-Path $PackRoot $Pack.Id
    $destDir = Join-Path $RepoRoot ($Pack.Destination -replace '/', '\')

    Write-Info "fetching $($Pack.Title) ($($Pack.Id))"
    Ensure-HttpHelper

    # A cached archive is only reusable for the exact URL that produced it; the
    # sidecar stops a changed source URL from silently reusing a stale zip (and
    # recording the wrong commit in the manifest).
    $sourceMarker = $zipPath + ".source"
    $cachedUrl = ""
    if (Test-Path -LiteralPath $sourceMarker) {
        $markerLines = @(Get-Content -LiteralPath $sourceMarker)
        if ($markerLines.Count -gt 0) { $cachedUrl = [string]$markerLines[0] }
    }
    if ($cachedUrl -ne $Pack.Url) {
        if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
        if (Test-Path -LiteralPath $sourceMarker) { Remove-Item -LiteralPath $sourceMarker -Force }
    }
    if ($Force -and (Test-Path -LiteralPath $zipPath)) {
        Remove-Item -LiteralPath $zipPath -Force
        if (Test-Path -LiteralPath $sourceMarker) { Remove-Item -LiteralPath $sourceMarker -Force }
    }
    if (-not (Test-Path -LiteralPath $zipPath)) {
        $null = Invoke-Python -PythonCmd $PythonCmd -PythonArgs @($HelperPath, $Pack.Url, $zipPath)
    }
    if (-not (Test-Path -LiteralPath $zipPath)) {
        throw "download produced no archive: $($Pack.Url)"
    }
    $archiveBytes = (Get-Item -LiteralPath $zipPath).Length
    $archiveSha = Get-Sha256 $zipPath
    Write-TextFile $sourceMarker ($Pack.Url + "`n" + $archiveSha + "`n")

    if (-not (Test-Path -LiteralPath $ExtractRoot)) {
        New-Item -ItemType Directory -Force -Path $ExtractRoot | Out-Null
    }
    if (Test-Path -LiteralPath $packExtract) {
        Remove-Item -LiteralPath $packExtract -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $packExtract | Out-Null
    Expand-Archive -LiteralPath $zipPath -DestinationPath $packExtract -Force

    # Two archive layouts are supported:
    #  * GitHub "codeload" zips wrap everything in <repo>-<sha>/ (asset library packs)
    #  * kenney.nl zips keep Audio/ and License.txt at the archive root
    # Pick the wrapper only when it actually contains this pack's license/prefix.
    $archiveRoot = $packExtract
    $childDirs = @(Get-ChildItem -LiteralPath $packExtract -Directory)
    if ($childDirs.Count -eq 1) {
        $candidateRoot = $childDirs[0].FullName
        $licenseProbe = Join-Path $candidateRoot ($Pack.LicenseSource -replace '/', '\')
        $hasLicenseInside = Test-Path -LiteralPath $licenseProbe
        $hasPrefixInside = $false
        if ($Pack.SourcePrefix -ne "") {
            $hasPrefixInside = Test-Path -LiteralPath (Join-Path $candidateRoot ($Pack.SourcePrefix -replace '/', '\'))
        }
        if ($hasLicenseInside -or $hasPrefixInside) {
            $archiveRoot = $candidateRoot
        }
    }

    # Resolve curated file list (explicit names, or a single glob).
    $sourceRelPaths = New-Object System.Collections.ArrayList
    if ($Pack.Glob -ne "") {
        $globRel = $Pack.Glob
        if ($Pack.SourcePrefix -ne "") { $globRel = $Pack.SourcePrefix + $Pack.Glob }
        $pattern = Join-Path $archiveRoot ($globRel -replace '/', '\')
        foreach ($item in @(Get-ChildItem -Path $pattern -File | Sort-Object Name)) {
            [void]$sourceRelPaths.Add($item.FullName.Substring($archiveRoot.Length + 1))
        }
    } else {
        foreach ($file in @($Pack.Files)) {
            [void]$sourceRelPaths.Add(($Pack.SourcePrefix + $file))
        }
    }
    if ($sourceRelPaths.Count -eq 0) {
        throw "no files matched the curation table for $($Pack.Id)"
    }

    # License: canonical copy under assets/cc0/<pack>/ plus one beside the assets.
    $licenseSource = Join-Path $archiveRoot ($Pack.LicenseSource -replace '/', '\')
    if (-not (Test-Path -LiteralPath $licenseSource)) {
        throw "license not found in archive: $($Pack.LicenseSource)"
    }
    $licenseText = Get-Content -LiteralPath $licenseSource -Raw -Encoding UTF8
    $canonicalLicense = Get-LicensePath $Pack
    Write-TextFile $canonicalLicense $licenseText
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }
    $destLicense = Join-Path $destDir "LICENSE.txt"
    Write-TextFile $destLicense $licenseText

    # Copy curated files, then hash the repo copy so the manifest describes the
    # bytes that actually ship (not the zip's bytes).
    $entries = New-Object System.Collections.ArrayList
    $logicalDest = @{}
    foreach ($srcRel in $sourceRelPaths) {
        $srcAbs = Join-Path $archiveRoot ($srcRel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $srcAbs)) {
            throw "curated file not found in archive: $srcRel"
        }
        if ($Pack.Flatten) {
            $destRel = Split-Path -Leaf $srcRel
        } else {
            $destRel = $srcRel
            if ($Pack.SourcePrefix -ne "" -and $destRel.StartsWith($Pack.SourcePrefix)) {
                $destRel = $destRel.Substring($Pack.SourcePrefix.Length)
            }
        }
        $destAbs = Join-Path $destDir ($destRel -replace '/', '\')
        $destParent = Split-Path -Parent $destAbs
        if (-not (Test-Path -LiteralPath $destParent)) {
            New-Item -ItemType Directory -Force -Path $destParent | Out-Null
        }
        Copy-Item -LiteralPath $srcAbs -Destination $destAbs -Force
        $destRes = "res://" + (($Pack.Destination + "/" + $destRel) -replace '\\', '/')
        [void]$entries.Add([ordered]@{
            path = $destRes
            bytes = [long](Get-Item -LiteralPath $destAbs).Length
            sha256 = Get-Sha256 $destAbs
            source = $srcRel
        })
        $logicalDest[$destRel] = $destRes
    }

    $entriesSorted = @($entries | Sort-Object { $_.path })
    $totalBytes = 0
    foreach ($entry in $entriesSorted) { $totalBytes += [long]$entry.bytes }

    # Asset Library metadata: only when the pack is actually listed there. The
    # Library's own download_url is recorded separately from the URL we actually
    # fetched: for three packs the Library URL is dead (HTTP 404) and the payload
    # came straight from kenney.nl, and the manifest says so explicitly.
    $assetLibrary = $null
    if ([int]$Pack.AssetLibraryId -gt 0) {
        $listedDownloadUrl = [string]$Pack.AssetLibraryDownloadUrl
        if ($listedDownloadUrl -eq "") { $listedDownloadUrl = [string]$Pack.Url }
        $listedStatus = [string]$Pack.AssetLibraryDownloadStatus
        if ($listedStatus -eq "") { $listedStatus = "ok" }
        $assetLibrary = [ordered]@{
            id = [int]$Pack.AssetLibraryId
            version = [string]$Pack.AssetLibraryVersion
            api_url = "https://godotengine.org/asset-library/api/asset/$($Pack.AssetLibraryId)"
            page_url = "https://godotengine.org/asset-library/asset/$($Pack.AssetLibraryId)"
            listed_license = "CC0"
            listed_download_status = $listedStatus
            listed_download_url = $listedDownloadUrl
            fetched_download_url = [string]$Pack.Url
        }
    }

    $commitValue = $null
    if ($Pack.Commit -ne "") { $commitValue = [string]$Pack.Commit }

    $manifest = [ordered]@{
        schema = 1
        pack_id = [string]$Pack.Id
        title = [string]$Pack.Title
        author = [string]$Pack.Author
        uploader = [string]$Pack.Uploader
        asset_library = $assetLibrary
        source_kind = [string]$Pack.SourceKind
        source_url = [string]$Pack.Url
        commit = $commitValue
        archive_sha256 = $archiveSha
        archive_bytes = [long]$archiveBytes
        license = "CC0-1.0"
        license_file = "res://assets/cc0/$($Pack.Id)/LICENSE.txt"
        license_copies = @("res://" + $Pack.Destination + "/LICENSE.txt")
        curated_root = "res://" + $Pack.Destination
        file_count = $entriesSorted.Count
        total_bytes = [long]$totalBytes
        generated_by = "tools/fetch_asset_packs.ps1"
        files = $entriesSorted
    }
    if ($Pack.ContainsKey("LogicalNames")) {
        $logical = [ordered]@{}
        foreach ($key in $Pack.LogicalNames.Keys) {
            $file = [string]$Pack.LogicalNames[$key]
            $destRes = $logicalDest[$file]
            if ($null -eq $destRes) {
                throw "logical id '$key' points at '$file' which is not in the curated file list"
            }
            $logical[$key] = $destRes
        }
        $manifest["logical_names"] = $logical
    }

    $json = $manifest | ConvertTo-Json -Depth 8
    Write-TextFile $manifestPath ($json + "`n")

    $mb = [math]::Round($totalBytes / 1MB, 2)
    Write-Ok "$($Pack.Title): $($entriesSorted.Count) files, $mb MB -> $($Pack.Destination)"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
Write-Host "RIFTWARD CC0 asset packs (cap: $SizeCapMB MB)" -ForegroundColor Cyan
Write-Info "repo: $RepoRoot"

if ($Offline -and $Force) {
    Write-Host "[assets] -Offline ignores -Force (nothing is downloaded)." -ForegroundColor DarkYellow
    $Force = $false
}

$pythonCmd = $null
if (-not $Offline) {
    $pythonCmd = Resolve-Python
    if ($null -eq $pythonCmd) {
        Write-Host "[assets] FATAL: no Python 3 interpreter found." -ForegroundColor Red
        Write-Host "        Tried: -PythonBin, `$env:PYTHON_BIN, the DSH bundled runtime," -ForegroundColor Red
        Write-Host "        'python' and 'py -3'. Set PYTHON_BIN to a Python 3 executable." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Info "offline mode: verifying committed files only (no network, no writes)"
}

if (-not (Test-Path -LiteralPath $PackRoot)) {
    New-Item -ItemType Directory -Force -Path $PackRoot | Out-Null
}

$totalBytes = 0
$totalFiles = 0
$verifiedPacks = 0

foreach ($pack in $script:Packs) {
    $manifestPath = Get-ManifestPath $pack
    $needsFetch = $true

    if (-not $Force -and (Test-Path -LiteralPath $manifestPath)) {
        $existing = Test-Pack -Pack $pack
        if ($existing.Ok) {
            Write-Skip "$($pack.Title): verified ($($existing.FileCount) files, $([math]::Round($existing.Bytes / 1MB, 2)) MB)"
            $needsFetch = $false
            $verifiedPacks += 1
            $totalBytes += $existing.Bytes
            $totalFiles += $existing.FileCount
        } else {
            Write-Info "$($pack.Title): stale/incomplete, refreshing"
            foreach ($problem in $existing.Problems) { Write-Info "  - $problem" }
        }
    } elseif ($Force) {
        Write-Info "$($pack.Title): -Force, refreshing"
    }

    if ($needsFetch) {
        if ($Offline) {
            $offlineCheck = Test-Pack -Pack $pack
            foreach ($problem in $offlineCheck.Problems) { Add-Failure "$($pack.Id): $problem" }
            $totalBytes += $offlineCheck.Bytes
            $totalFiles += $offlineCheck.FileCount
            continue
        }
        try {
            Fetch-Pack -Pack $pack -PythonCmd $pythonCmd
        } catch {
            Add-Failure "$($pack.Title): $($_.Exception.Message)"
            continue
        }
        $fresh = Test-Pack -Pack $pack
        if (-not $fresh.Ok) {
            foreach ($problem in $fresh.Problems) { Add-Failure "$($pack.Id): $problem" }
            continue
        }
        Write-Ok "$($pack.Title): post-write verification passed"
        $totalBytes += $fresh.Bytes
        $totalFiles += $fresh.FileCount
    }
}

$totalMB = [math]::Round($totalBytes / 1MB, 2)
Write-Host ""
Write-Host ("[assets] curated total: {0} files, {1} MB (cap {2} MB)" -f $totalFiles, $totalMB, $SizeCapMB) -ForegroundColor Cyan
if ($totalBytes -gt ([long]$SizeCapMB * 1MB)) {
    Add-Failure ("curated total {0} MB exceeds the {1} MB cap; trim the curation tables" -f $totalMB, $SizeCapMB)
}

# Every pack must have its manifest + license even in -Offline mode.
foreach ($pack in $script:Packs) {
    if (-not (Test-Path -LiteralPath (Get-ManifestPath $pack))) {
        Add-Failure "$($pack.Id): no MANIFEST.json (run without -Offline to fetch)"
    }
    if (-not (Test-Path -LiteralPath (Get-LicensePath $pack))) {
        Add-Failure "$($pack.Id): no LICENSE.txt"
    }
}

if ($script:Failures.Count -eq 0) {
    Write-Host "[assets] RESULT: PASS ($verifiedPacks pack(s) skipped as already verified)" -ForegroundColor Green
    exit 0
}

Write-Host "" -ForegroundColor Red
Write-Host "[assets] RESULT: FAIL - $($script:Failures.Count) problem(s):" -ForegroundColor Red
foreach ($failure in $script:Failures) { Write-Host "  - $failure" -ForegroundColor Red }
exit 1
