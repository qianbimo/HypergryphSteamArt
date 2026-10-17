# Only connects to Steam's local CEF debugger; never opens a network listener.
function Invoke-SteamCdp {
    param([string]$WebSocketUrl, [string]$Expression)
    $uri = [uri]$WebSocketUrl
    if ($uri.Scheme -ne 'ws' -or $uri.Host -notin @('127.0.0.1','localhost','[::1]')) {
        throw 'Refusing a non-local Steam debugging endpoint.'
    }
    $socket = [Net.WebSockets.ClientWebSocket]::new()
    $socket.Options.Proxy = $null
    $timeout = [Threading.CancellationTokenSource]::new(15000)
    try {
        $socket.ConnectAsync($uri,$timeout.Token).GetAwaiter().GetResult() | Out-Null
        $request = @{id=1;method='Runtime.evaluate';params=@{
            expression=$Expression;awaitPromise=$true;returnByValue=$true
        }} | ConvertTo-Json -Depth 8 -Compress
        $bytes = [Text.Encoding]::UTF8.GetBytes($request)
        $socket.SendAsync([ArraySegment[byte]]::new($bytes),[Net.WebSockets.WebSocketMessageType]::Text,$true,$timeout.Token).GetAwaiter().GetResult() | Out-Null
        $buffer = New-Object byte[] 65536
        while ($true) {
            $message = [IO.MemoryStream]::new()
            try {
                do {
                    $part = $socket.ReceiveAsync([ArraySegment[byte]]::new($buffer),$timeout.Token).GetAwaiter().GetResult()
                    if ($part.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) { throw 'Steam closed the debugging connection.' }
                    $message.Write($buffer,0,$part.Count)
                    if ($message.Length -gt 1048576) { throw 'Unexpectedly large Steam debugging response.' }
                } while (!$part.EndOfMessage)
                $reply = [Text.Encoding]::UTF8.GetString($message.ToArray()) | ConvertFrom-Json
            } finally { $message.Dispose() }
            if ($reply.id -ne 1) { continue }
            if ($reply.error) { throw "Steam CDP error: $($reply.error.message)" }
            if ($reply.result.exceptionDetails) { throw 'Steam artwork API raised an exception.' }
            return $reply.result.result.value
        }
    } finally { $socket.Dispose(); $timeout.Dispose() }
}

function Invoke-SteamArtworkRefresh {
    param([uint32]$AppId,[string]$ImagePath,[ValidateSet(0,1,2,3)][int]$AssetType = 1,
        [ValidateSet('jpg','png')][string]$ImageType = 'jpg')
    try {
        $pages = Invoke-RestMethod 'http://127.0.0.1:8080/json/list' -TimeoutSec 2
    } catch { return 'unavailable' }
    $pages = @($pages | Where-Object {
        $_.webSocketDebuggerUrl -and $_.url -match '^https?://steamloopback\.host(?::\d+)?/'
    } | Sort-Object @{Expression={ if ($_.title -eq 'SharedJSContext') { 0 } else { 1 } }})
    $base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($ImagePath))
    foreach ($page in $pages) {
        $probe = Invoke-SteamCdp $page.webSocketDebuggerUrl 'typeof SteamClient !== "undefined" && typeof SteamClient.Apps?.SetCustomArtworkForApp === "function"'
        if (!$probe) { continue }
        # 0 = portrait capsule, 1 = hero, 2 = transparent logo, 3 = wide header.
        $expression = '(async()=>{await SteamClient.Apps.SetCustomArtworkForApp(' + $AppId + ',"' + $base64 + '","' + $ImageType + '",' + $AssetType + ');return "applied"})()'
        $result = Invoke-SteamCdp $page.webSocketDebuggerUrl $expression
        if ($result -ne 'applied') { throw 'Steam did not acknowledge the artwork update.' }
        return 'applied'
    }
    return 'unavailable'
}

function Set-SteamLiveLogoPosition([uint32]$AppId,[string]$PositionJson) {
    $pages = Invoke-RestMethod 'http://127.0.0.1:8080/json/list' -TimeoutSec 2
    foreach ($page in $pages) {
        if ($page.title -ne 'SharedJSContext' -or $page.url -notmatch '^https?://steamloopback\.host(?::\d+)?/') { continue }
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($PositionJson))
        $expression = '(async()=>{await SteamClient.Apps.SetCustomLogoPositionForApp(' + $AppId + ',atob("' + $encoded + '"));return "applied"})()'
        return Invoke-SteamCdp $page.webSocketDebuggerUrl $expression
    }
    throw 'Steam logo positioning interface unavailable.'
}
