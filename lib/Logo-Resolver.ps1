function Test-UsableGameLogo([string]$Path) {
    if (!$Path -or !(Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $image = $null
    $sample = $null
    try {
        $image = [Drawing.Image]::FromFile($Path)
        if ($image.Width -lt 32 -or $image.Height -lt 16 -or $image.RawFormat.Guid -ne [Drawing.Imaging.ImageFormat]::Png.Guid) { return $false }
        # Reject empty/fully transparent PNGs before attempting cover composition.
        $sample = [Drawing.Bitmap]::new($image,32,32)
        for ($y=0; $y -lt 32; $y++) {
            for ($x=0; $x -lt 32; $x++) {
                if ($sample.GetPixel($x,$y).A -gt 8) { return $true }
            }
        }
        return $false
    } catch { return $false }
    finally {
        if ($sample) { $sample.Dispose() }
        if ($image) { $image.Dispose() }
    }
}

function Resolve-GameLogo([string]$PrimaryPath,[string[]]$FallbackPaths) {
    if (Test-UsableGameLogo $PrimaryPath) { return $PrimaryPath }
    foreach ($candidate in @($FallbackPaths | Select-Object -Unique)) {
        if (Test-UsableGameLogo $candidate) {
            Write-Warning "Primary logo unavailable; using fallback: $candidate"
            return $candidate
        }
    }
    Write-Warning 'No usable logo found; preserving existing Steam logo and portrait cover, updating backgrounds only.'
    return $null
}
