$ErrorActionPreference = "Stop"

$IsAdministrator = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $IsAdministrator) {
    throw "Run PowerShell or Command Prompt as administrator, then run this script again."
}

$HostsFile   = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
$BackupFile  = "$HostsFile.backup-before-uninstall-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
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
[IO.File]::WriteAllText($HostsFile, $NewContent, $Utf8NoBom)
Clear-DnsClientCache

Write-Host "HostBlockSites removed successfully."
Write-Host "Backup created at: $BackupFile"

