# HostBlockSites for Windows 11

Install the [`hosts`](https://github.com/gurutto-manila/hostblocksites/blob/main/hosts) blocklist in the Windows hosts file.

> [!WARNING]
> This is a broad blocklist, not an adult-only list. Its current contents also block major sites and services such as YouTube, Netflix, Facebook, Instagram, TikTok, Discord, Steam, Amazon, Shopee, and others. Review the list before installing it.

## What the installer does

- Downloads the list from GitHub's raw-file URL.
- Keeps only valid `0.0.0.0 domain` entries.
- removes duplicate entries.
- creates a timestamped backup of the current Windows hosts file.
- replaces an earlier HostBlockSites section when run again, instead of adding duplicates.
- clears the Windows DNS cache.

The raw URL used by the installer is:

```text
https://raw.githubusercontent.com/gurutto-manila/hostblocksites/main/hosts
```

Do not use the GitHub `/blob/` page URL with `Invoke-WebRequest`; that URL returns an HTML page rather than the plain hosts file.

## Install with PowerShell

1. Download [`install-hostblocksites.ps1`](install-hostblocksites.ps1) from this repository.
2. Right-click **Start**, choose **Terminal (Admin)**, and approve the administrator prompt.
3. Go to the folder containing the downloaded script. For example:

   ```powershell
   cd "$HOME\Downloads"
   ```

4. Run:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-hostblocksites.ps1
   ```

Administrator access is required because Windows protects the system hosts file.

For a direct copy-and-paste install, open `install-hostblocksites.ps1`, select its entire contents, copy them, and paste them into an administrator PowerShell window.

## Install from Command Prompt

1. Download [`install-hostblocksites.ps1`](install-hostblocksites.ps1).
2. Open **Command Prompt as administrator**.
3. Run the script, changing the path if it is not in your Downloads folder:

   ```cmd
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\Downloads\install-hostblocksites.ps1"
   ```

The installer prints the number of installed entries and the exact backup location.

## Update the blocklist

Run the installer again. It downloads the current GitHub list and replaces only the section it previously managed.

## Uninstall the blocklist

Download [`uninstall-hostblocksites.ps1`](uninstall-hostblocksites.ps1), open PowerShell or Command Prompt as administrator, and run one of the following.

PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\uninstall-hostblocksites.ps1
```

Command Prompt:

```cmd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\Downloads\uninstall-hostblocksites.ps1"
```

This removes only the section between the HostBlockSites markers. Other hosts-file entries are preserved.

## Restore a backup manually

The installer saves backups beside the Windows hosts file with names such as:

```text
C:\Windows\System32\drivers\etc\hosts.backup-20260810-143000
```

To restore one, open PowerShell as administrator and run:

```powershell
Copy-Item "C:\Windows\System32\drivers\etc\hosts.backup-YYYYMMDD-HHMMSS" "$env:SystemRoot\System32\drivers\etc\hosts" -Force
Clear-DnsClientCache
```

Replace `YYYYMMDD-HHMMSS` with the timestamp of the backup you want to restore.

## Notes

- A hosts file blocks exact hostnames only. It does not support wildcard domains.
- Browsers using Secure DNS may behave differently from ordinary Windows DNS resolution.
- A very large hosts file can make name resolution or some applications slower.
- If a wanted site stops working, uninstall this blocklist or remove the relevant entry from the source list and reinstall.
- Review third-party lists before trusting them; changes to this GitHub file affect the next update.
