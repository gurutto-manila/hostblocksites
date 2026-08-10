$ErrorActionPreference = "Stop"

$IsAdministrator = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $IsAdministrator) {
    throw "Run PowerShell or Command Prompt as administrator, then run this script again."
}

$HostsFile  = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
$BackupFile = "$HostsFile.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$ListFile   = Join-Path $env:TEMP "hostblocksites-$([guid]::NewGuid().ToString('N')).txt"
$ListUrl    = "https://raw.githubusercontent.com/gurutto-manila/hostblocksites/main/hosts"
$BeginMarker = "# BEGIN HOSTBLOCKSITES MANAGED BLOCKLIST"
$EndMarker   = "# END HOSTBLOCKSITES MANAGED BLOCKLIST"
$Utf8NoBom   = New-Object System.Text.UTF8Encoding($false)

try {
    Write-Host "Downloading HostBlockSites..."
    Invoke-WebRequest -Uri $ListUrl -OutFile $ListFile -UseBasicParsing

    $Entries = @(
        Get-Content -LiteralPath $ListFile |
            ForEach-Object {
                if ($_ -match '^\s*0\.0\.0\.0\s+([^\s#]+)') {
                    "0.0.0.0 $($Matches[1].ToLowerInvariant())"
                }
            } |
            Sort-Object -Unique
    )

    if ($Entries.Count -eq 0) {
        throw "The downloaded file did not contain any usable 0.0.0.0 hosts entries. The Windows hosts file was not changed."
    }

    Copy-Item -LiteralPath $HostsFile -Destination $BackupFile -Force

    $ExistingContent = [IO.File]::ReadAllText($HostsFile)
    $ManagedPattern = '(?ms)^' + [regex]::Escape($BeginMarker) + '.*?^' + [regex]::Escape($EndMarker) + '\s*(?:\r?\n)?'
    $CleanContent = [regex]::Replace($ExistingContent, $ManagedPattern, '').TrimEnd("`r", "`n")

    $ManagedBlock = @(
        $BeginMarker
        "# Source: $ListUrl"
        "# Installed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')"
        $Entries
        $EndMarker
    ) -join "`r`n"

    $NewContent = if ([string]::IsNullOrWhiteSpace($CleanContent)) {
        "$ManagedBlock`r`n"
    }
    else {
        "$CleanContent`r`n`r`n$ManagedBlock`r`n"
    }

    [IO.File]::WriteAllText($HostsFile, $NewContent, $Utf8NoBom)
    Clear-DnsClientCache

    Write-Host "HostBlockSites installed successfully."
    Write-Host "Entries installed: $($Entries.Count)"
    Write-Host "Backup created at: $BackupFile"
}
catch {
    Write-Error $_
    exit 1
}
finally {
    if (Test-Path -LiteralPath $ListFile) {
        Remove-Item -LiteralPath $ListFile -Force
    }
}

