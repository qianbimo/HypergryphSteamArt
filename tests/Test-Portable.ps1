$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('HypergryphSteamArt-portable-'+[guid]::NewGuid().ToString('N'))
$env:HYPERGRYPH_STEAM_ART_HOME=Join-Path $fixture 'user data'
. (Join-Path $root 'lib\Common.ps1')
if($script:ArtRoot -ne $root){throw 'Program root was redirected'}
if($script:ArtData -ne (Join-Path $env:HYPERGRYPH_STEAM_ART_HOME 'data')){throw 'State is not app-local'}
Save-ArtConfig @{schemaVersion=1;steamPath='fixture';userId='1';games=@();debugMarkerOwned=$false}
$configHash=(Get-FileHash $script:ArtConfigPath).Hash
$script:ArtStartup=Join-Path $fixture 'startup.lnk'
Enable-ArtStartup
$shell=New-Object -ComObject WScript.Shell
$link=$shell.CreateShortcut($script:ArtStartup)
if(!$link.Arguments.Contains((Join-Path $root 'lib\Watch.ps1'))){throw 'Startup does not point to extracted program'}
if($link.WorkingDirectory -ne $root){throw 'Startup working directory is wrong'}
$moved=Join-Path $fixture 'moved portable folder'
[IO.Directory]::CreateDirectory($moved)|Out-Null
$script:ArtRoot=$moved
Enable-ArtStartup
$link=$shell.CreateShortcut($script:ArtStartup)
if(!$link.Arguments.Contains((Join-Path $moved 'lib\Watch.ps1'))){throw 'Re-enable did not retarget moved program'}
if((Get-FileHash $script:ArtConfigPath).Hash -ne $configHash){throw 'Moving program changed saved configuration'}
$script:ArtRoot=$root

# A legacy installed App.ps1 must never receive menu actions from the portable copy.
$legacy=Join-Path $script:ArtHome 'App.ps1'
[IO.File]::WriteAllText($legacy,'throw "Unexpected redirect to legacy installed copy"')
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'App.ps1'),[ref]$tokens,[ref]$errors)
foreach($f in $ast.FindAll({param($a)$a -is [Management.Automation.Language.FunctionDefinitionAst]},$false)){. ([scriptblock]::Create($f.Extent.Text))}
function Enable-Art { $script:PortableActionReached=$true }
Invoke-ArtAction Enable
if(!$script:PortableActionReached){throw 'Portable menu did not run local action'}
Remove-Item -LiteralPath $legacy
if(Test-Path -LiteralPath (Join-Path $script:ArtHome 'lib')){throw 'Code was copied to data directory'}
Write-Host 'PASS: extracted program startup, retarget after move, shared state preservation, no legacy redirect/code copy.'
