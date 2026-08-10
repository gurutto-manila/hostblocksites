$ErrorActionPreference = "Stop"

$IsAdministrator = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $IsAdministrator) {
    throw "Run PowerShell or Command Prompt as administrator, then run this script again."
}

$HostsFile   = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
$BackupFile  = "$HostsFile.backup-before-uninstall-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$StagedFile  = Join-Path $env:TEMP "hostblocksites-uninstall-$([guid]::NewGuid().ToString('N')).txt"
$BeginMarker = "# BEGIN HOSTBLOCKSITES MANAGED BLOCKLIST"
$EndMarker   = "# END HOSTBLOCKSITES MANAGED BLOCKLIST"
$Utf8NoBom   = New-Object System.Text.UTF8Encoding($false)

$ExistingContent = [IO.File]::ReadAllText($HostsFile)
$ManagedPattern = '(?ms)^' + [regex]::Escape($BeginMarker) + '.*?^' + [regex]::Escape($EndMarker) + '\s*(?:\r?\n)?'

if (-not [regex]::IsMatch($ExistingContent, $ManagedPattern)) {
    Write-Host "No HostBlockSites managed section was found. Nothing was changed."
    exit 0
}

Copy-Item -LiteralPath $HostsFile -Destination $BackupFile -Force
$NewContent = [regex]::Replace($ExistingContent, $ManagedPattern, '').TrimEnd("`r", "`n") + "`r`n"
[IO.File]::WriteAllText($StagedFile, $NewContent, $Utf8NoBom)

$OriginalAttributes = [IO.File]::GetAttributes($HostsFile)
$WasReadOnly = ($OriginalAttributes -band [IO.FileAttributes]::ReadOnly) -ne 0
$AttributesChanged = $false

try {
    if ($WasReadOnly) {
        $WritableAttributes = $OriginalAttributes -band (-bnot [IO.FileAttributes]::ReadOnly)
        [IO.File]::SetAttributes($HostsFile, $WritableAttributes)
        $AttributesChanged = $true
    }

    $Removed = $false
    for ($Attempt = 1; $Attempt -le 5; $Attempt++) {
        try {
            Copy-Item -LiteralPath $StagedFile -Destination $HostsFile -Force -ErrorAction Stop
            $Removed = $true
            break
        }
        catch [System.IO.IOException] {
            if ($Attempt -lt 5) {
                Write-Warning "The hosts file is temporarily in use. Retrying in 3 seconds ($Attempt/5)..."
                Start-Sleep -Seconds 3
            }
            else {
                throw "The hosts file remained locked after 5 attempts. Close programs that may have it open, then retry."
            }
        }
    }

    if (-not $Removed) {
        throw "The HostBlockSites section could not be removed."
    }
}
catch [System.UnauthorizedAccessException] {
    throw "Windows denied access to '$HostsFile'. Confirm that Terminal says 'Administrator'. If it does, security software or an organization policy may be protecting the hosts file. Backup: $BackupFile"
}
finally {
    if ($AttributesChanged -and (Test-Path -LiteralPath $HostsFile)) {
        try {
            [IO.File]::SetAttributes($HostsFile, $OriginalAttributes)
        }
        catch {
            Write-Warning "The hosts file was updated, but its original file attributes could not be restored: $($_.Exception.Message)"
        }
    }
    if (Test-Path -LiteralPath $StagedFile) {
        Remove-Item -LiteralPath $StagedFile -Force
    }
}

Clear-DnsClientCache

Write-Host "HostBlockSites removed successfully."
Write-Host "Backup created at: $BackupFile"
