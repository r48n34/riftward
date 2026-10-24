function Find-RiftwardGodot {
    <#
    Locates a Godot 4.7.2 Windows executable for RIFTWARD.
    Set $env:GODOT_BIN to override. Returns an object with Gui and Console paths.
    #>
    $guiNames = @(
        "Godot_v4.7.2-stable_win64.exe",
        "Godot_v4.7.2-stable_win64_console.exe"
    )
    $gui = $null
    $console = $null

    if ($env:GODOT_BIN -and (Test-Path -LiteralPath $env:GODOT_BIN)) {
        $resolved = (Resolve-Path -LiteralPath $env:GODOT_BIN).Path
        if ((Get-Item -LiteralPath $resolved) -is [System.IO.DirectoryInfo]) {
            $innerGui = Get-ChildItem -LiteralPath $resolved -Filter "Godot*win64*.exe" -File |
                Where-Object { $_.Name -notlike "*_console.exe" } |
                Select-Object -First 1
            $innerConsole = Get-ChildItem -LiteralPath $resolved -Filter "Godot*win64*console*.exe" -File |
                Select-Object -First 1
            if ($innerGui) { $gui = $innerGui.FullName }
            if ($innerConsole) { $console = $innerConsole.FullName }
        } elseif ($resolved -like "*_console.exe") {
            $console = $resolved
        } else {
            $gui = $resolved
            $consoleCandidate = $resolved -replace "\.exe$", "_console.exe"
            if (Test-Path -LiteralPath $consoleCandidate) { $console = $consoleCandidate }
        }
    }

    if (-not $gui -and -not $console) {
        $command = Get-Command godot -ErrorAction SilentlyContinue
        if ($command) {
            if ($command.Source -like "*_console.exe") { $console = $command.Source } else { $gui = $command.Source }
        }
    }

    if (-not $gui -and -not $console) {
        $roots = @(
            (Join-Path $env:USERPROFILE "Downloads"),
            (Join-Path $env:USERPROFILE "Desktop"),
            "C:\Program Files",
            "C:\Program Files (x86)",
            "D:\"
        )
        foreach ($root in $roots) {
            if (-not (Test-Path -LiteralPath $root)) { continue }
            $found = Get-ChildItem -LiteralPath $root -Filter "Godot_v4.7.2*win64*.exe" -File -Recurse -Depth 2 -ErrorAction SilentlyContinue |
                Sort-Object FullName |
                Select-Object -First 4
            if ($found) {
                $foundGui = $found | Where-Object { $_.Name -notlike "*_console.exe" } | Select-Object -First 1
                $foundConsole = $found | Where-Object { $_.Name -like "*_console.exe" } | Select-Object -First 1
                if ($foundGui) { $gui = $foundGui.FullName }
                if ($foundConsole) { $console = $foundConsole.FullName }
                if ($gui -or $console) { break }
            }
        }
    }

    if (-not $gui -and -not $console) {
        throw "Godot 4.7.2 was not found. Install Godot 4.7.2 or set GODOT_BIN to the executable path."
    }
    if (-not $console) { $console = $gui }
    if (-not $gui) { $gui = $console }
    return [pscustomobject]@{
        Gui = $gui
        Console = $console
    }
}
