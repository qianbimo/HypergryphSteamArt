param(
    [string]$SteamPath = '',
    [string]$GameName = '明日方舟',
    [string]$AppCode = 'GzD1CpaWgmSq1wew',
    [string]$UserId = '',
    [string]$BackgroundPath = '',
    [string]$ShortcutId = '',
    [string]$LogoPath = '',
    [string]$FallbackLogoPath = '',
    [string]$DataPath = '',
    [ValidateRange(0,100)][int]$LogoSizePercent = 0,
    [ValidateRange(60,86400)][int]$IntervalSeconds = 300,
    [switch]$Watch,
    [switch]$Preview
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'Steam-LiveRefresh.ps1')
. (Join-Path $PSScriptRoot 'Cover-Composer.ps1')
. (Join-Path $PSScriptRoot 'Logo-Resolver.ps1')
. (Join-Path $PSScriptRoot 'Write-ImageFile.ps1')
. (Join-Path $PSScriptRoot 'Common.ps1')
$dataDir = if ($DataPath) { $DataPath } else { Join-Path $PSScriptRoot 'data' }
[IO.Directory]::CreateDirectory($dataDir) | Out-Null

function Get-Targets {
    $entries=@(Get-ArtShortcuts $SteamPath | Where-Object { $_.UserId -eq $UserId -and $_.AppId -eq $ShortcutId })
    foreach($entry in $entries){
        [pscustomobject]@{User=$entry.UserId;Id=$entry.AppId;Grid=(Join-Path $SteamPath "userdata\$($entry.UserId)\config\grid")}
    }
}
function Update-LiveBackground($Target, [string]$ImagePath, [int]$AssetType) {
    # Never apply another local Steam account's artwork to the active account.
    $activeUser = (Get-ItemProperty 'HKCU:\Software\Valve\Steam\ActiveProcess' -ErrorAction SilentlyContinue).ActiveUser
    if ([string]$activeUser -ne $Target.User) { return }
    try {
        $imageType = if ([IO.Path]::GetExtension($ImagePath) -ieq '.png') { 'png' } else { 'jpg' }
        $live = Invoke-SteamArtworkRefresh -AppId ([uint32]$Target.Id) -ImagePath $ImagePath -AssetType $AssetType -ImageType $imageType
        if ($live -eq 'applied') { Write-Host "Steam live artwork refreshed: $($Target.Id), type $AssetType" }
        else { Write-Host 'Steam live refresh unavailable; background saved on disk.' }
    } catch { Write-Warning "Steam live refresh failed; background saved on disk. $($_.Exception.Message)" }
}
function Invoke-Update {
    $targets = @(Get-Targets)
    if (!$targets.Count) { throw "No Steam shortcut exactly named '$GameName' found." }
    $requestParams = @{appcode=$AppCode;language='zh-cn';channel='1';sub_channel='1';platform='Windows';source='launcher'}
    $body = @{proxy_reqs = @(
        @{kind='get_main_bg_image';get_main_bg_image_req=$requestParams}

    )} | ConvertTo-Json -Depth 8 -Compress
    $response = Invoke-RestMethod 'https://launcher.hypergryph.com/api/proxy/web/batch_proxy' -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 30
    if ($response.code -and $response.code -ne 0) { throw "Official API returned code $($response.code)" }
    $image = @($response.proxy_rsps | Where-Object kind -eq 'get_main_bg_image')[0].get_main_bg_image_rsp.main_bg_image
    if (!$image.url) { throw 'Official API did not return a main background image.' }
    $uri = [uri]$image.url
    if ($uri.Scheme -ne 'https' -or !($uri.DnsSafeHost.EndsWith('.hycdn.cn') -or $uri.DnsSafeHost.EndsWith('.hypergryph.com'))) { throw 'Unexpected image host.' }
    $raw = Join-Path $dataDir 'download.tmp'
    $jpg = Join-Path $dataDir 'latest.jpg'
    try {
        Invoke-WebRequest $image.url -OutFile $raw -UseBasicParsing -TimeoutSec 60
        if ($image.md5 -and (Get-FileHash $raw -Algorithm MD5).Hash -ine $image.md5) { throw 'Image checksum mismatch.' }
        $decodedPath = Join-Path $dataDir 'decoded-background.png'
        $header = [IO.File]::ReadAllBytes($raw)
        $isWebp = $header.Length -ge 12 -and [Text.Encoding]::ASCII.GetString($header,0,4) -eq 'RIFF' -and [Text.Encoding]::ASCII.GetString($header,8,4) -eq 'WEBP'
        $decodeSource = $raw
        if ($isWebp) {
            $decoder = Join-Path $script:ArtRoot 'tools\dwebp.exe'
            if (!(Test-Path -LiteralPath $decoder)) { throw 'Bundled WebP decoder is missing. Re-extract the complete package.' }
            # dwebp writes diagnostics to stderr even when decoding succeeds.
            $decodeProcess = Start-Process -FilePath $decoder -ArgumentList ('"{0}" -o "{1}" -quiet' -f $raw,$decodedPath) -WindowStyle Hidden -PassThru
            if (!$decodeProcess.WaitForExit(30000)) { $decodeProcess.Kill(); throw 'WebP decoder timed out.' }
            if ($decodeProcess.ExitCode -ne 0) { throw 'Official WebP decoding failed.' }
            $decodeSource = $decodedPath
        }
        $bitmap = [Drawing.Image]::FromFile($decodeSource)
        try {
            if ($bitmap.Width -lt 800 -or $bitmap.Height -lt 300) { throw 'Image is too small for a Steam background.' }
            $size = "$($bitmap.Width)x$($bitmap.Height)"
            $bitmap.Save($jpg, [Drawing.Imaging.ImageFormat]::Jpeg)
        } finally { $bitmap.Dispose() }
        if (!$Preview) {
            [IO.Directory]::CreateDirectory($BackgroundPath) | Out-Null
            $extension = [IO.Path]::GetExtension($uri.AbsolutePath).ToLowerInvariant()
            if ($extension -notin @('.png','.jpg','.jpeg','.webp','.bmp','.gif')) { $extension = '.image' }
            # Keep the validated official original as well as the Steam-compatible JPEG.
            foreach ($item in @(
                @{Source=$raw; Name="latest-original$extension"},
                @{Source=$jpg; Name='latest.jpg'}
            )) {
                $saved = Join-Path $BackgroundPath $item.Name
                Publish-GameImage $item.Source $saved
            }
            $jpg = Join-Path $BackgroundPath 'latest.jpg'
            Write-Host "Background saved: $jpg"
        }
    } finally {
        if (Test-Path $raw) { Remove-Item -LiteralPath $raw }
        if ($decodedPath -and (Test-Path $decodedPath)) { Remove-Item -LiteralPath $decodedPath }
    }
    $assets = @(
        @{Suffix='p';Type=0;Path=$jpg;Extension='jpg';Size=$size},
        @{Suffix='_hero';Type=1;Path=$jpg;Extension='jpg';Size=$size},
        @{Suffix='';Type=3;Path=$jpg;Extension='jpg';Size=$size}
    )
    # Use the user's original Arknights wordmark, never the activity title.
    $primaryLogo = if ($LogoPath) { $LogoPath } else { Join-Path $script:ArtRoot 'Logo_明日方舟.png' }
    $fallbackName = if ($AppCode -eq '6LL0KJuqHBVz33WK') { 'Logo_明日方舟终末地.png' } else { 'Logo_明日方舟.png' }
    $logoFallbacks = @(
        $FallbackLogoPath,
        (Join-Path $script:ArtRoot $fallbackName),
        (Join-Path ([IO.Path]::GetDirectoryName($BackgroundPath.TrimEnd('\'))) $fallbackName),
        (Join-Path $BackgroundPath 'latest-logo.png')
    )
    $logoPng = Resolve-GameLogo $primaryLogo $logoFallbacks
    if ($logoPng) {
    if (!$Preview) {
        $savedLogo = Join-Path $BackgroundPath 'latest-logo.png'
        Publish-GameImage $logoPng $savedLogo
    }
    $assets += @{Suffix='_logo';Type=2;Path=$logoPng;Extension='png';Size="$GameName logo"}
    $coverPath = Join-Path $dataDir 'latest-cover.jpg'
    [ArknightsCoverComposer]::Create($jpg,$logoPng,$coverPath)
    if (!$Preview) {
        $savedCover = Join-Path $BackgroundPath 'latest-cover.jpg'
        Publish-GameImage $coverPath $savedCover
        $coverPath = $savedCover
    }
    $assets[0].Path = $coverPath
    $assets[0].Size = '600x900, game logo at bottom'
    } else {
        # Do not overwrite the existing composed cover with a logo-less image.
        $assets = @($assets | Where-Object { $_.Type -ne 0 })
    }
    foreach ($target in $targets) {
      if (!$Preview) { Initialize-ArtBackup $target }
      foreach ($asset in $assets) {
        $baseName = "$($target.Id)$($asset.Suffix)"
        $destination = Join-Path $target.Grid "$baseName.$($asset.Extension)"
        if ($Preview) { Write-Host "Preview: $($asset.Size) -> $destination"; continue }
        [IO.Directory]::CreateDirectory($target.Grid) | Out-Null
        $existing = @(Get-ChildItem -LiteralPath $target.Grid -File | Where-Object { $_.BaseName -eq $baseName -and $_.Extension -in @('.jpg','.jpeg','.png','.webp') })
        if ($existing.Count -eq 1 -and $existing[0].FullName -eq $destination -and (Get-FileHash $destination).Hash -eq (Get-FileHash $asset.Path).Hash) {
            Update-LiveBackground $target $asset.Path $asset.Type
            Write-Host "Unchanged: $($target.User)/$baseName"; continue
        }
        # Stage on the same volume before replacing the destination.
        Publish-GameImage $asset.Path $destination
        foreach ($old in $existing) { if ($old.FullName -ne $destination) { Remove-Item -LiteralPath $old.FullName } }
        Update-LiveBackground $target $asset.Path $asset.Type
        Write-Host "Updated: $($target.User)/$baseName, $($asset.Size)."
      }
      if ($LogoSizePercent -gt 0 -and !$Preview) {
        $positionPath = Join-Path $target.Grid "$($target.Id).json"
        $position = @{nVersion=1;logoPosition=@{pinnedPosition='BottomLeft';nWidthPct=$LogoSizePercent;nHeightPct=$LogoSizePercent}}
        if (Test-Path -LiteralPath $positionPath) {
            $currentPosition = Get-Content -LiteralPath $positionPath -Raw | ConvertFrom-Json
            if ($currentPosition.logoPosition.pinnedPosition) { $position.logoPosition.pinnedPosition = $currentPosition.logoPosition.pinnedPosition }
            $backupPath = Join-Path $dataDir "backups\$($target.User)\$($target.Id)\logo-position-original.json"
            if (!(Test-Path -LiteralPath $backupPath)) {
                [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($backupPath)) | Out-Null
                Copy-Item -LiteralPath $positionPath -Destination $backupPath
            }
        }
        $positionJson = $position | ConvertTo-Json -Depth 4 -Compress
        [IO.File]::WriteAllText($positionPath,$positionJson,[Text.UTF8Encoding]::new($false))
        $activeUser = (Get-ItemProperty 'HKCU:\Software\Valve\Steam\ActiveProcess' -ErrorAction SilentlyContinue).ActiveUser
        if ([string]$activeUser -eq $target.User) {
            try {
                $positionResult = Set-SteamLiveLogoPosition ([uint32]$target.Id) $positionJson
                if ($positionResult -eq 'applied') { Write-Host "Steam detail logo size set: $LogoSizePercent percent" }
            } catch { Write-Warning "Logo size saved on disk; live adjustment unavailable. $($_.Exception.Message)" }
        }
      }
    }
    @{game=$GameName;url=$image.url;md5=$image.md5;logoSource=$logoPng;checkedAt=[DateTime]::Now.ToString('o')} | ConvertTo-Json | Set-Content (Join-Path $dataDir 'last-check.json') -Encoding UTF8
}
$mutex = [Threading.Mutex]::new($false,"Local\HypergryphSteamArtUpdate-$AppCode")
if (!$mutex.WaitOne(0)) { $mutex.Dispose(); throw 'Another updater is already running.' }
try {
    do {
        try { Invoke-Update }
        catch {
            $message = "$(Get-Date -Format o) $($_.Exception.Message)"
            Add-Content (Join-Path $dataDir 'errors.log') $message -Encoding UTF8
            if (!$Watch) { throw }
            Write-Warning $message
        }
        if ($Watch) { Start-Sleep -Seconds $IntervalSeconds }
    } while ($Watch)
} finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
