param([switch]$SkipCurrent)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$mutex=[Threading.Mutex]::new($false,'Local\HypergryphSteamArtWatcher')
if(!$mutex.WaitOne(0)){$mutex.Dispose();exit}
$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$stop=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,"Local\HypergryphSteamArtStop-$sid")
$session=(Get-Process -Id $PID).SessionId
$seen=''
if($SkipCurrent){
    $initial=Get-Process steam -ErrorAction SilentlyContinue|Where-Object SessionId -eq $session|Sort-Object StartTime|Select-Object -First 1
    if($initial){$seen="$($initial.Id):$($initial.StartTime.Ticks)"}
}
[IO.Directory]::CreateDirectory($script:ArtData)|Out-Null
try{
    while(!$stop.WaitOne(0)){
        try{
            $steam=Get-Process steam -ErrorAction SilentlyContinue|Where-Object SessionId -eq $session|Sort-Object StartTime|Select-Object -First 1
            $key=if($steam){"$($steam.Id):$($steam.StartTime.Ticks)"}else{''}
            if($key -and $key -ne $seen){
                $seen=$key
                $deadline=[DateTime]::UtcNow.AddMinutes(3)
                while([DateTime]::UtcNow -lt $deadline -and !$stop.WaitOne(0)){
                    if(!(Get-Process -Id $steam.Id -ErrorAction SilentlyContinue)){break}
                    try{
                        $pages=Invoke-RestMethod 'http://127.0.0.1:8080/json/list' -TimeoutSec 2
                        $ready=@($pages|Where-Object title -eq 'SharedJSContext').Count -gt 0
                        $active=(Get-ItemProperty 'HKCU:\Software\Valve\Steam\ActiveProcess' -ErrorAction SilentlyContinue).ActiveUser
                        if($ready -and $active){break}
                    }catch{}
                    if($stop.WaitOne(3000)){break}
                }
                if($stop.WaitOne(0)){break}
                if(Get-Process -Id $steam.Id -ErrorAction SilentlyContinue){
                    $record=@{steamProcess=$key;time=[DateTime]::Now.ToString('o');result='completed'}
                    try{& (Join-Path $PSScriptRoot 'Update.ps1') *>&1|Out-File (Join-Path $script:ArtData 'last-update.log') -Encoding UTF8}
                    catch{$record.result='failed';$record.error=$_.Exception.Message}
                    $record|ConvertTo-Json|Set-Content (Join-Path $script:ArtData 'last-run.json') -Encoding UTF8
                }
            }
        }catch{Add-Content (Join-Path $script:ArtData 'watcher.log') "$(Get-Date -Format o) $($_.Exception.Message)" -Encoding UTF8}
        if($stop.WaitOne(3000)){break}
    }
}finally{$stop.Dispose();$mutex.ReleaseMutex();$mutex.Dispose()}
