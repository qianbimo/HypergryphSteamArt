param([switch]$Preview)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$config=Get-ArtConfig
$failed=@()
foreach($game in @($config.games|Where-Object enabled)){
    try{
        $kind=$game.kind
        $spec=if($kind -eq 'endfield'){@{code='6LL0KJuqHBVz33WK';logo='Logo_明日方舟终末地.png';folder='ArknightsEndfield'}}else{@{code='GzD1CpaWgmSq1wew';logo='Logo_明日方舟.png';folder='Arknights'}}
        $output=Join-Path $script:ArtRoot $spec.folder
        $logo=if($game.logoPath){$game.logoPath}elseif($game.gameDirectory){Join-Path $game.gameDirectory $spec.logo}else{Join-Path $script:ArtRoot $spec.logo}
        Write-Host "正在更新：$($game.name)"
        & (Join-Path $PSScriptRoot 'Update-Game.ps1') -SteamPath $config.steamPath -UserId $config.userId -ShortcutId $game.appId -GameName $game.name -AppCode $spec.code -BackgroundPath $output -LogoPath $logo -FallbackLogoPath (Join-Path $script:ArtRoot $spec.logo) -DataPath $output -LogoSizePercent $game.logoSizePercent -Preview:$Preview
    }catch{$failed+="$($game.name)：$($_.Exception.Message)";Write-Warning $failed[-1]}
}
if($failed.Count){throw ($failed -join [Environment]::NewLine)}
