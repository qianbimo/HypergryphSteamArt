$ErrorActionPreference='Stop'
$source=Split-Path $PSScriptRoot -Parent
$root=Join-Path ([IO.Path]::GetTempPath()) ('HypergryphSteamArt-storage-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory((Join-Path $root 'lib'))|Out-Null
[IO.Directory]::CreateDirectory((Join-Path $root 'data'))|Out-Null
Copy-Item -LiteralPath (Join-Path $source 'lib\Common.ps1'),(Join-Path $source 'lib\Update.ps1') -Destination (Join-Path $root 'lib')
$stub=@'
param($SteamPath,$UserId,$ShortcutId,$GameName,$AppCode,$BackgroundPath,$LogoPath,$FallbackLogoPath,$DataPath,$LogoSizePercent,[switch]$Preview)
@{output=$BackgroundPath;cache=$DataPath;name=$GameName}|ConvertTo-Json -Compress|Add-Content (Join-Path (Split-Path $PSScriptRoot -Parent) 'routes.jsonl')
'@
[IO.File]::WriteAllText((Join-Path $root 'lib\Update-Game.ps1'),$stub,[Text.UTF8Encoding]::new($true))
$games=@(
    @{kind='arknights';name='明日方舟';appId='1';enabled=$true;gameDirectory=(Join-Path $root 'game-must-not-be-written');logoPath='';logoSizePercent=0},
    @{kind='endfield';name='明日方舟：终末地';appId='2';enabled=$true;gameDirectory=(Join-Path $root 'game-must-not-be-written');logoPath='';logoSizePercent=35}
)
@{schemaVersion=1;steamPath='Z:\Steam';userId='1';games=$games}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $root 'data\settings.json') -Encoding UTF8
& (Join-Path $root 'lib\Update.ps1')
$routes=@(Get-Content (Join-Path $root 'routes.jsonl')|ForEach-Object{$_|ConvertFrom-Json})
if($routes.Count -ne 2){throw 'Expected two routes'}
for($i=0;$i -lt 2;$i++){
    $folder=@('Arknights','ArknightsEndfield')[$i]
    $expected=Join-Path $root $folder
    if($routes[$i].output -ne $expected -or $routes[$i].cache -ne $expected){throw "Incorrect image/cache location for $folder"}
}
Write-Host 'PASS: images and temporary decoding files use separate app-local folders; no game-directory output.'
