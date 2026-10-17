param([string]$Destination = (Join-Path (Split-Path $PSScriptRoot -Parent) 'dist'))
$ErrorActionPreference='Stop'
$version=([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'VERSION'))).Trim()
$packageName="HypergryphSteamArt-v$version-win-x64"
$stage=Join-Path $Destination ($packageName+'-'+[guid]::NewGuid().ToString('N'))
$root=Join-Path $stage $packageName
[IO.Directory]::CreateDirectory($root)|Out-Null
$allow=@('App.ps1','Start.cmd','开始使用.cmd','README.md','先读我.txt','VERSION','THIRD-PARTY-NOTICES.md','Logo_明日方舟.png','Logo_明日方舟终末地.png','lib','tools','docs')
foreach($name in $allow){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $root -Recurse -Force}
$files=@(Get-ChildItem -LiteralPath $root -Recurse -File)
foreach($file in @($files|Where-Object Extension -eq '.ps1')){
    $tokens=$null;$errors=$null
    [Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)|Out-Null
    if($errors.Count){throw "PowerShell syntax error: $($file.FullName)"}
}
if(Test-Path -LiteralPath (Join-Path $root 'data')){throw 'Personal runtime data must not be packaged.'}
$lines=foreach($file in ($files|Sort-Object FullName)){
    $relative=$file.FullName.Substring($root.Length+1).Replace('\','/')
    "$((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant())  $relative"
}
[IO.File]::WriteAllLines((Join-Path $root 'SHA256SUMS.txt'),[string[]]$lines,[Text.UTF8Encoding]::new($false))
$zip=Join-Path $Destination "$packageName.zip"
Compress-Archive -LiteralPath $root -DestinationPath $zip -Force
$hash=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$zip.sha256","$hash  $packageName.zip`r`n",[Text.UTF8Encoding]::new($false))
Write-Host "Package: $zip"
Write-Host "SHA256: $hash"
Write-Host "Staging folder retained for inspection: $root"
