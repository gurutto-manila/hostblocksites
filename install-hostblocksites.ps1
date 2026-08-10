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
$StagedFile = Join-Path $env:TEMP "hostblocksites-staged-$([guid]::NewGuid().ToString('N')).txt"
$ListUrl    = "https://raw.githubusercontent.com/gurutto-manila/hostblocksites/main/hosts"
$BeginMarker = "# BEGIN HOSTBLOCKSITES MANAGED BLOCKLIST"
$EndMarker   = "# END HOSTBLOCKSITES MANAGED BLOCKLIST"
$Utf8NoBom   = New-Object System.Text.UTF8Encoding($false)

try {
    Write-Host "[1/6] Downloading HostBlockSites..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $ListUrl -OutFile $ListFile -UseBasicParsing

    Write-Host "[2/6] Processing and removing duplicate entries..." -ForegroundColor Cyan
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

    Write-Host "      Found $($Entries.Count) unique entries."
    Write-Host "[3/6] Creating a backup of the current hosts file..." -ForegroundColor Cyan
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

    Write-Host "[4/6] Preparing the updated hosts file..." -ForegroundColor Cyan

    # Build the replacement outside the protected Windows directory first.
    # This follows Microsoft's recommended pattern of preparing a hosts file
    # elsewhere and then copying it into the Etc directory as administrator.
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

        Write-Host "[5/6] Installing the updated hosts file..." -ForegroundColor Cyan
        Copy-Item -LiteralPath $StagedFile -Destination $HostsFile -Force
    }
    catch [System.UnauthorizedAccessException] {
        throw "Windows denied access to '$HostsFile'. Confirm that Terminal says 'Administrator'. If it does, Windows Security, third-party antivirus, or an organization policy may be protecting the hosts file. The original hosts file has not been intentionally removed; backup: $BackupFile"
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
    }

    Write-Host "[6/6] Clearing the Windows DNS cache..." -ForegroundColor Cyan
    Clear-DnsClientCache

    Write-Host "HostBlockSites installed successfully." -ForegroundColor Green
    Write-Host "Entries installed: $($Entries.Count)"
    Write-Host "Backup created at: $BackupFile"
}
catch {
    Write-Host "HostBlockSites installation failed." -ForegroundColor Red
    Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "If a backup was created, its expected path is: $BackupFile"
    throw
}
finally {
    if (Test-Path -LiteralPath $ListFile) {
        Remove-Item -LiteralPath $ListFile -Force
    }
    if (Test-Path -LiteralPath $StagedFile) {
        Remove-Item -LiteralPath $StagedFile -Force
    }
}
