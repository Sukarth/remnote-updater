# RemNote Auto Updater

<center>

**Portable RemNote installation and automatic updates for Windows - No admin rights required!**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)

Automatically monitors the RemNote RSS feed for new stable releases and updates your RemNote installation. Perfect for users who want a portable RemNote setup or don't have administrator access on their Windows machine.

</center>

## 🌟 Features

- ✅ **No Admin Rights Required** - Installs to user directory (`%LOCALAPPDATA%`)
- ✅ **Automatic Updates** - Monitors RSS feed for new stable releases
- ✅ **Smart Version Detection** - Ignores beta versions, only stable releases
- ✅ **Portable Installation** - Fully self-contained in user directory
- ✅ **Safe Updates** - Creates backup before updating with automatic rollback on failure
- ✅ **Comprehensive Logging** - Detailed logs for troubleshooting
- ✅ **Lightweight** - Minimal resource usage, efficient scheduling

## 📋 Prerequisites

| Requirement | Notes |
|---|---|
| Windows 10 / 11 | PowerShell 5.1 is built in — no extra install |
| Internet connection | For downloading RemNote and (one-time) 7zr.exe (7zip engine) |

## Usage/Installation

Open PowerShell and paste the following command, then press **Enter**:

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/sukarth/remnote-updater/main/RemNoteUpdater.ps1 | iex"
```

No files or downloads are required. The script executes in memory, downloads its registration components automatically, configures your background updater, and runs an initial update sweep.

---

### What happens on first run:
- Downloads RemNote (if not already installed in `%LOCALAPPDATA%\RemNote`)
- Registers a **Windows Task Scheduler** entry (or **Startup folder shortcut** as fallback) so updates are checked automatically every hour — even after reboots
- All files are stored in `%LOCALAPPDATA%\RemNote` and `%LOCALAPPDATA%\RemNoteTemp` — no admin rights ever needed

## Uninstallation

Run the below command in powershell (terminal):
```powershell
.\RemNoteUpdater.ps1 -Uninstall
```

This cleanly removes both the Windows Scheduled Task and any Startup folder shortcuts. To fully clean up, delete the `%LOCALAPPDATA%\RemNote` and `%LOCALAPPDATA%\RemNoteTemp` folders.

## 🔧 Configuration

### Default Paths

| Path | Default Location | Description |
|------|------------------|-------------|
| Installation | `%LOCALAPPDATA%\RemNote` | Where RemNote.exe is installed |
| Temp/Cache | `%LOCALAPPDATA%\RemNoteTemp` | Downloads and logs |
| Backup | `%LOCALAPPDATA%\RemNote_Backup` | Backup during updates |

**Note:** `%LOCALAPPDATA%` typically resolves to `C:\Users\YourUsername\AppData\Local`

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-RunOnce` | Switch | False | Check once and exit (Deprecated and kept for backwards compatibility) |
| `-CheckIntervalMinutes` | Integer | 60 | Minutes between checks |
| `-InstallPath` | String | `%LOCALAPPDATA%\RemNote` | Custom install location |
| `-TempPath` | String | `%LOCALAPPDATA%\RemNoteTemp` | Custom temp location |
| `-Force` | Switch | False | Force a fresh download and reinstallation |
| `-Uninstall` | - | - | Remove the scheduled task or startup shortcuts |
| `-Loop` | Switch | False | Run a persistent terminal monitoring loop |

### Customizing RSS Feed or Download URL

Edit these variables in `RemNoteUpdater.ps1` if needed:

```powershell
$RSS_FEED_URL = "https://feedback.remnote.com/rss/changelog.xml"
$INSTALLER_DOWNLOAD_URL = "https://backend.remnote.com/desktop/windows"
```

## 🔄 How It Works

1. Reads the [RemNote changelog RSS feed](https://feedback.remnote.com/rss/changelog.xml) — skips beta versions.
2. If a new stable version is found, downloads the installer from official RemNote servers.
3. Verifies file integrity using a local SHA256 sidecar file.
4. Extracts the app silently using 7-Zip
    - The standalone `7za.exe` engine is present in the repository and its zip if downloaded
    - If running in-memory via the web one-liner (without downloading the repo), the script automatically downloads the **7zr engine**.
5. Sweeps any active processes running out of the `%LOCALAPPDATA%\RemNote` directory to resolve file locks.
6. Backs up your current install, deploys the new version, then launches RemNote.
7. If RemNote is open when an update is found, a prompt asks whether to update now or later.
8. Confirms `RemNote.exe` successfully executes post-extraction; if it fails, the script rolls back deployment from the backup directory.
9. Cleans up temporary installation files and old backup folders.

## Manual / advanced usage

```powershell
# Check for updates right now (one-shot, no scheduling)
.\RemNoteUpdater.ps1 -RunOnce

# Force a fresh re-download of the latest version immediately
.\RemNoteUpdater.ps1 -RunOnce -Force

# Run a persistent monitoring loop in the active terminal window
.\RemNoteUpdater.ps1 -Loop

# Remove the scheduled task or startup shortcuts
.\RemNoteUpdater.ps1 -Uninstall

# Custom install path and check interval
.\RemNoteUpdater.ps1 -InstallPath "D:\Apps\RemNote" -CheckIntervalMinutes 30
```

## 📊 Logs

Logs are saved to:
```
%LOCALAPPDATA%\RemNoteTemp\updater.log
```

View recent logs:
```powershell
Get-Content "$env:LOCALAPPDATA\RemNoteTemp\updater.log" -Tail 50
```

## 🛠️ Troubleshooting

### Script Won't Run

**Error:** "Running scripts is disabled on this system"

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Update Failed - Restoring Backup

If an update fails, the script automatically restores your previous RemNote installation from the backup.

**Manual Rollback** (if needed):
```powershell
# Remove failed installation
Remove-Item "$env:LOCALAPPDATA\RemNote" -Recurse -Force

# Restore backup
Rename-Item "$env:LOCALAPPDATA\RemNote_Backup" "RemNote"
```

### Check Current Version

View the last installed version:
```powershell
Get-Content "$env:LOCALAPPDATA\RemNoteTemp\last_version.txt"
```

### Force Re-Download

Delete the version file to force a fresh download:
```powershell
Remove-Item "$env:LOCALAPPDATA\RemNoteTemp\last_version.txt"
.\RemNoteUpdater.ps1 -RunOnce
```

## 🔐 Security

- ✅ Downloads only from official RemNote servers (`backend.remnote.com`)
- ✅ RSS feed from official RemNote changelog (`feedback.remnote.com`)
- ✅ Local SHA256 checksum tracking prevents duplicate or corrupted downloads
- ✅ Automatic backup before any modifications
- ✅ Automated rollback on startup failure
- ✅ No elevation/admin rights required or requested

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📜 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for more details.

## ⚠️ Disclaimer

This is an unofficial tool and is not affiliated with, endorsed by, or connected to RemNote or RemNote Inc. in any way.

- This tool downloads RemNote installers from official RemNote servers.
- Always review scripts before running them on your system.
- Keep backups of your RemNote data.

## 🙏 Acknowledgments

- [RemNote](https://www.remnote.com/) - Note-taking and spaced repetition software
- [7-Zip by Igor Pavlov](https://www.7-zip.org/) - Standalone 7zr executable engine used for extraction

## 💬 Support

- **Issues:** [GitHub Issues](https://github.com/sukarth/remnote-updater/issues)
- **RemNote Community:** [RemNote Discord](https://remnote.com/discord)

---

**Made with ❤️ by Sukarth for the RemNote community**