$script:ArtRoot = Split-Path $PSScriptRoot -Parent
$script:ArtHome = if ($env:HYPERGRYPH_STEAM_ART_HOME) { [IO.Path]::GetFullPath($env:HYPERGRYPH_STEAM_ART_HOME) } else { Join-Path $env:LOCALAPPDATA 'HypergryphSteamArt' }
$script:ArtData = Join-Path $script:ArtHome 'data'
$script:ArtConfigPath = Join-Path $script:ArtData 'settings.json'
$script:ArtStartup = Join-Path ([Environment]::GetFolderPath('Startup')) 'HypergryphSteamArt.lnk'
function Read-ZeroString([IO.BinaryReader]$Reader) {
    $bytes = New-Object 'System.Collections.Generic.List[byte]'
    while (($b=$Reader.ReadByte()) -ne 0) { $bytes.Add($b) }
    return [Text.Encoding]::UTF8.GetString($bytes.ToArray())
}
function Read-ArtVdf([IO.BinaryReader]$Reader) {
    $r=@{}
    while ($true) {
        $type=$Reader.ReadByte()
        if ($type -eq 8) { return $r }
        $key=Read-ZeroString $Reader
        switch($type) {
            0 { $r[$key]=Read-ArtVdf $Reader }
            1 { $r[$key]=Read-ZeroString $Reader }
            2 { $r[$key]=$Reader.ReadUInt32() }
            7 { $r[$key]=$Reader.ReadUInt64() }
            default { throw "Unsupported shortcuts.vdf type: $type" }
        }
    }
}
function Get-ArtShortcuts([string]$SteamPath) {
    foreach ($user in @(Get-ChildItem (Join-Path $SteamPath 'userdata') -Directory -ErrorAction SilentlyContinue)) {
        if ($user.Name -notmatch '^\d+$') { continue }
        $path=Join-Path $user.FullName 'config\shortcuts.vdf'
        if (!(Test-Path -LiteralPath $path)) { continue }
        $reader=[IO.BinaryReader]::new([IO.MemoryStream]::new([IO.File]::ReadAllBytes($path)))
        try { $vdf=Read-ArtVdf $reader } finally { $reader.Dispose() }
        foreach($entry in $vdf.shortcuts.Values) {
            if (!$entry.ContainsKey('appid')) { continue }
            [pscustomobject]@{UserId=$user.Name;AppId=[string]$entry.appid;Name=$entry.AppName;Exe=$entry.Exe;StartDir=$entry.StartDir}
        }
    }
}
function Find-ArtSteam {
    foreach($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
        $reg=Get-ItemProperty $key -ErrorAction SilentlyContinue
        foreach($value in @($reg.SteamPath,$reg.InstallPath)) {
            if ($value -and (Test-Path -LiteralPath (Join-Path $value 'steam.exe'))) { return [IO.Path]::GetFullPath($value) }
        }
    }
    return ''
}
function Get-ArtGameKind($Entry) {
    $exe=[IO.Path]::GetFileName(([string]$Entry.Exe).Trim('"'))
    if ($exe -in @('Endfield.exe','EndfieldDirect.exe') -or $Entry.Name -in @('明日方舟：终末地','明日方舟:终末地','Arknights: Endfield')) { return 'endfield' }
    if ($exe -eq 'Arknights.exe' -or $Entry.Name -in @('明日方舟','Arknights')) { return 'arknights' }
    return ''
}
function Get-ArtGameDirectory($Entry,[string]$Kind) {
    foreach($dir in @([IO.Path]::GetDirectoryName(([string]$Entry.Exe).Trim('"')),([string]$Entry.StartDir).Trim('"'))) {
        if (!$dir) { continue }
        $names=if($Kind -eq 'arknights'){@('Arknights.exe')}else{@('Endfield.exe','EndfieldDirect.exe')}
        foreach($name in $names){if(Test-Path -LiteralPath (Join-Path $dir $name)){return $dir}}
        $sub=if($Kind -eq 'arknights'){'games\Arknights'}else{'games\Arknights Endfield'}
        if(Test-Path -LiteralPath (Join-Path $dir $sub)){return (Join-Path $dir $sub)}
    }
    return ''
}
function Save-ArtConfig($Config) {
    [IO.Directory]::CreateDirectory($script:ArtData)|Out-Null
    $json=$Config|ConvertTo-Json -Depth 12
    [IO.File]::WriteAllText($script:ArtConfigPath,$json,[Text.UTF8Encoding]::new($false))
}
function Get-ArtConfig {
    if (!(Test-Path -LiteralPath $script:ArtConfigPath)) { throw '尚未配置，请先选择“启用自动更新”。' }
    $c=Get-Content -LiteralPath $script:ArtConfigPath -Raw -Encoding UTF8|ConvertFrom-Json
    if($c.schemaVersion -ne 1){throw '不支持的配置版本，请重新配置。'}
    return $c
}
function Select-ArtFolder([string]$Title) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog=[Windows.Forms.FolderBrowserDialog]::new()
    try{$dialog.Description=$Title;if($dialog.ShowDialog() -eq 'OK'){return $dialog.SelectedPath}}finally{$dialog.Dispose()}
    return ''
}
function Stop-ArtWatcher {
    $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    try{$event=[Threading.EventWaitHandle]::OpenExisting("Local\HypergryphSteamArtStop-$sid");try{$event.Set()|Out-Null}finally{$event.Dispose()}}catch{}
    # Do not start a replacement until the previous watcher releases its mutex.
    $deadline=[DateTime]::UtcNow.AddSeconds(12)
    do {
        $m=[Threading.Mutex]::new($false,'Local\HypergryphSteamArtWatcher')
        try{$free=$m.WaitOne(0);if($free){$m.ReleaseMutex();return}}finally{$m.Dispose()}
        Start-Sleep -Milliseconds 250
    }while([DateTime]::UtcNow -lt $deadline)
    throw '后台正在更新，请稍候再操作；未强制结束进程。'
}
function Start-ArtWatcher([switch]$SkipCurrent) {
    $ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $watch=Join-Path $script:ArtRoot 'lib\Watch.ps1'
    $extra=if($SkipCurrent){' -SkipCurrent'}else{''}
    Start-Process -FilePath $ps -ArgumentList "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$watch`"$extra" -WindowStyle Hidden
}
function Enable-ArtStartup {
    $shell=New-Object -ComObject WScript.Shell
    $link=$shell.CreateShortcut($script:ArtStartup)
    $link.TargetPath=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $link.Arguments="-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$(Join-Path $script:ArtRoot 'lib\Watch.ps1')`""
    $link.WorkingDirectory=$script:ArtRoot
    $link.WindowStyle=7
    $link.Save()
}
function Initialize-ArtBackup($Target) {
    $folder=Join-Path $script:ArtData "originals\$($Target.User)\$($Target.Id)"
    $manifest=Join-Path $folder 'manifest.json'
    if(Test-Path -LiteralPath $manifest){return}
    [IO.Directory]::CreateDirectory($folder)|Out-Null
    $names=@("$($Target.Id)p","$($Target.Id)_hero","$($Target.Id)","$($Target.Id)_logo")
    $files=@(Get-ChildItem -LiteralPath $Target.Grid -File -ErrorAction SilentlyContinue|Where-Object{
        $_.BaseName -in $names -and $_.Extension.ToLowerInvariant() -in @('.jpg','.jpeg','.png','.webp','.json')
    })
    foreach($file in $files){Copy-Item -LiteralPath $file.FullName -Destination $folder}
    @{grid=$Target.Grid;appId=$Target.Id;names=@($files|ForEach-Object Name);createdAt=[DateTime]::Now.ToString('o')}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $manifest -Encoding UTF8
}
