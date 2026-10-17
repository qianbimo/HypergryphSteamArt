param([ValidateSet('Menu','Enable','Update','Configure','Status','Disable','Restore','Uninstall')][string]$Action='Menu')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'lib\Common.ps1')

function Install-ArtPackage {
    if([IO.Path]::GetFullPath($script:ArtRoot).TrimEnd('\') -eq [IO.Path]::GetFullPath($script:ArtInstall).TrimEnd('\')){return}
    if(Test-Path -LiteralPath (Join-Path $script:ArtInstall 'App.ps1')){Stop-ArtWatcher}
    [IO.Directory]::CreateDirectory($script:ArtInstall)|Out-Null
    foreach($name in @('App.ps1','Start.cmd','开始使用.cmd','README.md','先读我.txt','VERSION','THIRD-PARTY-NOTICES.md','Logo_明日方舟.png','Logo_明日方舟终末地.png','lib','tools','docs')){
        Copy-Item -LiteralPath (Join-Path $script:ArtRoot $name) -Destination $script:ArtInstall -Recurse -Force
    }
    Write-Host "程序已安装到：$script:ArtInstall"
}
function Configure-Art {
    $steam=Find-ArtSteam
    if(!$steam){$steam=Select-ArtFolder '请选择包含 steam.exe 的 Steam 安装文件夹'}
    if(!$steam -or !(Test-Path -LiteralPath (Join-Path $steam 'steam.exe'))){throw '未找到 Steam。请先安装并登录 Steam。'}
    $entries=@(Get-ArtShortcuts $steam|Where-Object {Get-ArtGameKind $_})
    if(!$entries.Count){throw '没有找到支持的非 Steam 游戏。请先把明日方舟或终末地加入 Steam，并退出一次 Steam 以保存快捷方式。'}
    $users=@($entries.UserId|Select-Object -Unique)
    $active=[string](Get-ItemProperty 'HKCU:\Software\Valve\Steam\ActiveProcess' -ErrorAction SilentlyContinue).ActiveUser
    $user=if($active -in $users){$active}elseif($users.Count -eq 1){$users[0]}else{''}
    if(!$user){
        Write-Host '检测到多个 Steam 账户，请选择要更新的账户：'
        for($i=0;$i -lt $users.Count;$i++){Write-Host "$($i+1). $($users[$i])"}
        $choice=Read-Host '输入编号'
        if($choice -notmatch '^\d+$' -or [int]$choice -lt 1 -or [int]$choice -gt $users.Count){throw '账户编号无效。'}
        $user=$users[[int]$choice-1]
    }
    $games=@()
    foreach($kind in @('arknights','endfield')){
        $matches=@($entries|Where-Object {$_.UserId -eq $user -and (Get-ArtGameKind $_) -eq $kind})
        if(!$matches.Count){continue}
        $entry=$matches[0]
        if($matches.Count -gt 1){
            Write-Host "检测到多个 $kind 条目，请选择："
            for($i=0;$i -lt $matches.Count;$i++){Write-Host "$($i+1). $($matches[$i].Name) / $($matches[$i].Exe)"}
            $choice=Read-Host '输入编号'
            if($choice -notmatch '^\d+$' -or [int]$choice -lt 1 -or [int]$choice -gt $matches.Count){throw '条目编号无效。'}
            $entry=$matches[[int]$choice-1]
        }
        $dir=Get-ArtGameDirectory $entry $kind
        if(!$dir){
            Write-Host "未能确定 $($entry.Name) 的游戏目录。可以选择文件夹，取消则把图片存到程序数据目录。"
            $dir=Select-ArtFolder "选择 $($entry.Name) 游戏目录；取消使用程序数据目录"
        }
        $games+=[pscustomobject]@{kind=$kind;name=$entry.Name;appId=$entry.AppId;enabled=$true;gameDirectory=$dir;logoPath='';logoSizePercent=$(if($kind -eq 'endfield'){35}else{0})}
    }
    $marker=Join-Path $steam '.cef-enable-remote-debugging'
    $owned=$false
    if(Test-Path -LiteralPath $script:ArtConfigPath){$old=Get-ArtConfig;if($old.steamPath -eq $steam){$owned=[bool]$old.debugMarkerOwned}}
    $config=[pscustomobject]@{schemaVersion=1;steamPath=$steam;userId=$user;debugMarkerOwned=$owned;games=$games}
    Save-ArtConfig $config
    Write-Host "已配置 $($games.Count) 个游戏，Steam 账户：$user。"
}
function Enable-Art {
    if(!(Test-Path -LiteralPath $script:ArtConfigPath)){Configure-Art}
    $config=Get-ArtConfig
    $marker=Join-Path $config.steamPath '.cef-enable-remote-debugging'
    if(!(Test-Path -LiteralPath $marker)){
        try{
            [IO.File]::WriteAllBytes($marker,[byte[]]@())
            $config.debugMarkerOwned=$true
            Save-ArtConfig $config
            Write-Host '已启用 Steam 本机界面接口。首次启用后，请在游戏退出后正常重启 Steam 一次。'
        }catch{Write-Warning 'Steam 目录不可写：仍可保存图片，但无法启用即时刷新。处理方法见使用说明“权限问题”。'}
    }
    Stop-ArtWatcher
    Enable-ArtStartup
    Start-ArtWatcher
    Write-Host '已启用：每次 Steam 启动只检查一次；后台每 3 秒仅检查本机进程，不重复下载。' -ForegroundColor Green
    Write-Host '本机调试接口允许本机程序操作 Steam 界面；不要转发 8080 端口。程序不会自动重启 Steam。'
}
function Disable-Art {
    if(Test-Path -LiteralPath $script:ArtStartup){Remove-Item -LiteralPath $script:ArtStartup}
    Stop-ArtWatcher
    Write-Host '已停用自动更新；当前图片、配置与备份均保留。'
}
function Restore-Art {
    Disable-Art
    if(Get-Process steam -ErrorAction SilentlyContinue){throw '为避免 Steam 缓存覆盖恢复结果，请先正常退出 Steam，再执行恢复。'}
    $manifests=@(Get-ChildItem (Join-Path $script:ArtData 'originals') -Filter manifest.json -Recurse -File -ErrorAction SilentlyContinue)
    if(!$manifests.Count){Write-Host '没有原始图片备份，无需恢复。';return}
    foreach($file in $manifests){
        $m=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8|ConvertFrom-Json
        if($m.appId -notmatch '^\d+$'){throw '备份中的 appId 无效。'}
        $allowed=@("$($m.appId)p","$($m.appId)_hero","$($m.appId)","$($m.appId)_logo")
        foreach($name in @($m.names|Where-Object {$_})){
            if([IO.Path]::GetFileName($name) -ne $name -or [IO.Path]::GetFileNameWithoutExtension($name) -notin $allowed){throw '备份文件名无效。'}
            if(!(Test-Path -LiteralPath (Join-Path $file.DirectoryName $name))){throw "备份文件缺失：$name"}
        }
        # Only remove artwork belonging to this exact shortcut, then restore originals.
        Get-ChildItem -LiteralPath $m.grid -File -ErrorAction SilentlyContinue|Where-Object{
            $_.BaseName -in $allowed -and $_.Extension -in @('.jpg','.jpeg','.png','.webp','.json')
        }|ForEach-Object{Remove-Item -LiteralPath $_.FullName}
        foreach($name in @($m.names|Where-Object {$_})){Copy-Item -LiteralPath (Join-Path $file.DirectoryName $name) -Destination $m.grid -Force}
    }
    Write-Host '已恢复首次更新前的自定义图片；原先没有自定义图片的条目恢复为默认。'
}
function Show-ArtStatus {
    Write-Host "程序目录：$script:ArtRoot"
    Write-Host "登录自动启动：$(Test-Path -LiteralPath $script:ArtStartup)"
    try{$m=[Threading.Mutex]::OpenExisting('Local\HypergryphSteamArtWatcher');$m.Dispose();Write-Host '启动监视器：运行中'}catch{Write-Host '启动监视器：未运行'}
    if(Test-Path -LiteralPath $script:ArtConfigPath){$c=Get-ArtConfig;Write-Host "Steam：$($c.steamPath)";foreach($g in $c.games){Write-Host "  $($g.name) / $($g.appId) / 启用=$($g.enabled)"}}
    try{$pages=Invoke-RestMethod 'http://127.0.0.1:8080/json/list' -TimeoutSec 2;Write-Host "即时刷新接口：$(@($pages|Where-Object title -eq SharedJSContext).Count -gt 0)"}catch{Write-Host '即时刷新接口：未就绪（Steam 关闭时正常）'}
    $run=Join-Path $script:ArtData 'last-run.json'
    if(Test-Path -LiteralPath $run){Get-Content -LiteralPath $run -Encoding UTF8}
}
function Uninstall-Art {
    Disable-Art
    if(Test-Path -LiteralPath $script:ArtConfigPath){
        $c=Get-ArtConfig
        if($c.debugMarkerOwned){
            $marker=Join-Path $c.steamPath '.cef-enable-remote-debugging'
            if(Test-Path -LiteralPath $marker){Remove-Item -LiteralPath $marker}
            $c.debugMarkerOwned=$false;Save-ArtConfig $c
        }
    }
    Write-Host '已卸载后台启动并移除本程序创建的调试标记。重启 Steam 后关闭本机接口。'
    Write-Host "图片和备份仍保留。确认无需恢复后，可手动删除：$script:ArtRoot"
}
function Invoke-ArtAction([string]$Name){
    if($script:ArtRoot -ne $script:ArtInstall -and $Name -eq 'Enable'){
        Install-ArtPackage
        & (Join-Path $script:ArtInstall 'App.ps1') -Action Enable
        return
    }
    if($script:ArtRoot -ne $script:ArtInstall -and (Test-Path -LiteralPath (Join-Path $script:ArtInstall 'App.ps1'))){
        & (Join-Path $script:ArtInstall 'App.ps1') -Action $Name
        return
    }
    switch($Name){
        Enable{Enable-Art}
        Update{Stop-ArtWatcher;try{& (Join-Path $script:ArtRoot 'lib\Update.ps1')}finally{if(Test-Path -LiteralPath $script:ArtStartup){Start-ArtWatcher -SkipCurrent}}}
        Configure{Stop-ArtWatcher;Configure-Art;if(Test-Path -LiteralPath $script:ArtStartup){Start-ArtWatcher}}
        Status{Show-ArtStatus}
        Disable{Disable-Art}
        Restore{Restore-Art}
        Uninstall{Uninstall-Art}
    }
}
if($Action -ne 'Menu'){Invoke-ArtAction $Action;return}
while($true){
    Write-Host "`n鹰角游戏 Steam 图片同步 1.0.0" -ForegroundColor Cyan
    Write-Host '1. 启用 / 更新程序（首次使用选这个）'
    Write-Host '2. 立即更新图片'
    Write-Host '3. 查看状态'
    Write-Host '4. 重新识别游戏 / 更换账户'
    Write-Host '5. 停用自动更新'
    Write-Host '6. 恢复原始 Steam 图片（需退出 Steam）'
    Write-Host '7. 卸载后台功能（保留图片和备份）'
    Write-Host '8. 打开完整使用说明'
    Write-Host '0. 退出'
    $choice=Read-Host '输入编号'
    try{
        switch($choice){
            '1'{Invoke-ArtAction Enable}
            '2'{Invoke-ArtAction Update}
            '3'{Invoke-ArtAction Status}
            '4'{Invoke-ArtAction Configure}
            '5'{Invoke-ArtAction Disable}
            '6'{if((Read-Host '恢复会覆盖本工具管理的图片，输入 YES 确认') -ceq 'YES'){Invoke-ArtAction Restore}}
            '7'{Invoke-ArtAction Uninstall}
            '8'{Start-Process (Join-Path $script:ArtRoot 'docs\使用说明.html')}
            '0'{return}
            default{Write-Host '请输入 0 到 8。'}
        }
    }catch{Write-Host "操作未完成：$($_.Exception.Message)" -ForegroundColor Red;Write-Host '请查看使用说明，或选择 3 检查状态。'}
}
