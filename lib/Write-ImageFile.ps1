function Publish-GameImage([string]$Source,[string]$Destination) {
    if ([IO.Path]::GetFullPath($Source) -eq [IO.Path]::GetFullPath($Destination)) { return }
    $pending = $Destination + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::Copy($Source,$pending,$true)
        if (!(Test-Path -LiteralPath $Destination)) { [IO.File]::Move($pending,$Destination); return }
        $encrypted = ([IO.File]::GetAttributes($pending) -band [IO.FileAttributes]::Encrypted) -or
            ([IO.File]::GetAttributes($Destination) -band [IO.FileAttributes]::Encrypted)
        if ($encrypted) {
            # ReplaceFile cannot merge EFS metadata on some Windows profiles.
            # Copying preserves the destination's encryption and permissions.
            [IO.File]::Copy($pending,$Destination,$true)
        } else { [IO.File]::Replace($pending,$Destination,[NullString]::Value) }
    } finally { if (Test-Path -LiteralPath $pending) { Remove-Item -LiteralPath $pending } }
}
