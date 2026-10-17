param([string]$WorkPath=(Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'HypergryphSteamArt-build\tests'), [string]$PackageRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$sourceRoot=Split-Path $PSScriptRoot -Parent
$root=$PackageRoot

Add-Type -AssemblyName System.Drawing
$run=Join-Path $WorkPath ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($run)|Out-Null
$env:HYPERGRYPH_STEAM_ART_HOME=Join-Path $run 'user data'
. (Join-Path $root 'lib\Common.ps1')
$steam=Join-Path $run '中文 Steam with spaces'
$user=[string](Get-Random -Minimum 990000000 -Maximum 999999999)
$grid=Join-Path $steam "userdata\$user\config\grid"
[IO.Directory]::CreateDirectory($grid)|Out-Null
$game1=Join-Path $run '游戏目录\Arknights'
$game2=Join-Path $run '游戏目录\Arknights Endfield'
foreach($dir in @($game1,$game2)){[IO.Directory]::CreateDirectory($dir)|Out-Null}
[IO.File]::WriteAllBytes((Join-Path $steam 'steam.exe'),[byte[]]@())
[IO.File]::WriteAllBytes((Join-Path $game1 'Arknights.exe'),[byte[]]@())
[IO.File]::WriteAllBytes((Join-Path $game2 'EndfieldDirect.exe'),[byte[]]@())
$vdf=Join-Path $steam "userdata\$user\config\shortcuts.vdf"
$w=[IO.BinaryWriter]::new([IO.File]::Create($vdf))
function Z([string]$s){$w.Write([Text.Encoding]::UTF8.GetBytes($s));$w.Write([byte]0)}
function S([string]$key,[string]$value){$w.Write([byte]1);Z $key;Z $value}
try{
    $w.Write([byte]0);Z 'shortcuts'
    $entries=@(@{id=[uint32]3999999901;name='已改名的明日方舟';exe=(Join-Path $game1 'Arknights.exe')},@{id=[uint32]3999999902;name='明日方舟：终末地';exe=(Join-Path $game2 'EndfieldDirect.exe')})
    for($i=0;$i -lt $entries.Count;$i++){
        $w.Write([byte]0);Z ([string]$i)
        $w.Write([byte]2);Z 'appid';$w.Write([uint32]$entries[$i].id)
        S 'AppName' $entries[$i].name;S 'Exe' ('"'+$entries[$i].exe+'"');S 'StartDir' ([IO.Path]::GetDirectoryName($entries[$i].exe))
        $w.Write([byte]0);Z 'tags';$w.Write([byte]8);$w.Write([byte]8)
    }
    $w.Write([byte]8);$w.Write([byte]8)
}finally{$w.Dispose()}
$shortcuts=@(Get-ArtShortcuts $steam)
if($shortcuts.Count -ne 2 -or (Get-ArtGameKind $shortcuts[0]) -notin @('arknights','endfield')){throw 'Shortcut discovery failed'}
foreach($entry in $shortcuts){if(!(Get-ArtGameDirectory $entry (Get-ArtGameKind $entry))){throw 'Game directory discovery failed'}}
Write-Host 'PASS: binary VDF, renamed shortcut, spaces/Chinese paths, game directory detection.'

# Offline network stubs: only synthetic Steam paths are modified.
$fixturePng=Join-Path $run 'official.png'
$bmp=[Drawing.Bitmap]::new(1200,720);$g=[Drawing.Graphics]::FromImage($bmp)
try{$g.Clear([Drawing.Color]::DarkSlateGray);$bmp.Save($fixturePng,[Drawing.Imaging.ImageFormat]::Png)}finally{$g.Dispose();$bmp.Dispose()}
$global:ArtTestFixture=$fixturePng
function Invoke-RestMethod {param($Uri,$Method,$ContentType,$Body,$TimeoutSec)
    return @{proxy_rsps=@(@{kind='get_main_bg_image';get_main_bg_image_rsp=@{main_bg_image=@{url='https://hg-utils-public.hycdn.cn/fixture.png';md5=(Get-FileHash $global:ArtTestFixture -Algorithm MD5).Hash}}})}
}
function Invoke-WebRequest {param($Uri,$OutFile,[switch]$UseBasicParsing,$TimeoutSec) Copy-Item -LiteralPath $global:ArtTestFixture -Destination $OutFile}
$original=Join-Path $grid '3999999901p.png'
Copy-Item -LiteralPath (Join-Path $root 'Logo_明日方舟.png') -Destination $original
$originalHash=(Get-FileHash $original).Hash
$params=@{SteamPath=$steam;UserId=$user;ShortcutId='3999999901';GameName='已改名的明日方舟';BackgroundPath=(Join-Path $game1 'backgroud');DataPath=(Join-Path $run 'cache1');LogoPath=(Join-Path $run 'missing.png');FallbackLogoPath=(Join-Path $root 'Logo_明日方舟.png')}
& (Join-Path $root 'lib\Update-Game.ps1') @params
if(!(Test-Path -LiteralPath (Join-Path $grid '3999999901p.jpg'))){throw 'Composed cover missing'}
$manifest=Join-Path $script:ArtHome "data\originals\$user\3999999901\manifest.json"
if(!(Test-Path -LiteralPath $manifest)){throw 'Original backup missing'}
$saved=Join-Path (Split-Path $manifest -Parent) '3999999901p.png'
if((Get-FileHash $saved).Hash -ne $originalHash){throw 'Original artwork was not preserved'}
$backupTime=(Get-Item $manifest).LastWriteTimeUtc
& (Join-Path $root 'lib\Update-Game.ps1') @params
if((Get-Item $manifest).LastWriteTimeUtc -ne $backupTime){throw 'Original backup was overwritten'}
Write-Host 'PASS: offline update, fallback logo, image outputs, first-run backup retention.'
$global:ArtTestFixture=Join-Path $sourceRoot 'tests\fixtures\sample.webp'
$params.ShortcutId='3999999902';$params.GameName='明日方舟：终末地';$params.AppCode='6LL0KJuqHBVz33WK';$params.BackgroundPath=Join-Path $game2 'backgroud';$params.DataPath=Join-Path $run 'cache2';$params.FallbackLogoPath=Join-Path $root 'Logo_明日方舟终末地.png';$params.LogoSizePercent=35
& (Join-Path $root 'lib\Update-Game.ps1') @params
if(!(Test-Path -LiteralPath (Join-Path $grid '3999999902.json'))){throw 'Endfield logo position missing'}
if(!(Test-Path -LiteralPath (Join-Path $game2 'backgroud\latest-cover.jpg'))){throw 'Endfield cover missing'}
Write-Host 'PASS: bundled native WebP decoding and Endfield metadata.'

# Preview must not create or alter any Steam files.
$hashBefore=@(Get-ChildItem $grid -File|Get-FileHash|ForEach-Object Hash)-join ','
& (Join-Path $root 'lib\Update-Game.ps1') @params -Preview
$hashAfter=@(Get-ChildItem $grid -File|Get-FileHash|ForEach-Object Hash)-join ','
if($hashBefore -ne $hashAfter){throw 'Preview modified Steam files'}
Write-Host 'PASS: preview has no Steam writes.'

# Load only App's function definitions, never its interactive entry point.
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'App.ps1'),[ref]$tokens,[ref]$errors)
foreach($function in $ast.FindAll({param($a)$a -is [Management.Automation.Language.FunctionDefinitionAst]},$false)){
    . ([scriptblock]::Create($function.Extent.Text))
}
if(Test-Path -LiteralPath (Join-Path $script:ArtHome 'App.ps1')){throw 'Program code was copied to data directory'}
# Do not stop any real Steam/watcher processes in the restore test.
function Disable-Art {}
function Get-Process {}
Restore-Art
if(!(Test-Path -LiteralPath $original) -or (Get-FileHash $original).Hash -ne $originalHash){throw 'Restoration failed'}
if(Test-Path -LiteralPath (Join-Path $grid '3999999902p.jpg')){throw 'No-original artwork was not removed on restore'}
Write-Host 'PASS: portable code/data separation and original artwork restoration.'
Write-Host "ALL DISTRIBUTION TESTS PASSED. Fixtures: $run"
