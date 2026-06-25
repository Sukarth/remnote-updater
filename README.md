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
| Internet connection | For downloading RemNote and (one-time) SharpCompress |

## Usage/Installation

1. [Download this repository as a ZIP](https://github.com/sukarth/remnote-updater/archive/refs/heads/main.zip) and extract it anywhere (e.g. your Desktop).
2. Double-click **`Install.bat`**.
3. That's it. ✅

On first run the script will:
- Download RemNote (if not already installed)
- Register a **Windows Task Scheduler** entry so updates are checked automatically every hour — even after reboots
- All files are stored in `%LOCALAPPDATA%\RemNote` and `%LOCALAPPDATA%\RemNoteTemp` — no admin rights ever needed

## Uninstallation

Run the below command in powershell (terminal):
```powershell
.\RemNoteUpdater.ps1 -Uninstall
```

This removes the scheduled task. To fully clean up, delete the `%LOCALAPPDATA%\RemNote` and `%LOCALAPPDATA%\RemNoteTemp` folders.

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
| `-RunOnce` | Switch | False | Check once and exit |
| `-CheckIntervalMinutes` | Integer | 60 | Minutes between checks |
| `-InstallPath` | String | `%LOCALAPPDATA%\RemNote` | Custom install location |
| `-TempPath` | String | `%LOCALAPPDATA%\RemNoteTemp` | Custom temp location |
| `-Uninstall` | - | - | Remove the scheduled task |
| `-Setup` | - | - | Run setup that registers the scheduled task |

### Customizing RSS Feed or Download URL

Edit these variables in `RemNoteUpdater.ps1` if needed:

```powershell
$RSS_FEED_URL = "https://feedback.remnote.com/rss/changelog.xml"
$INSTALLER_DOWNLOAD_URL = "https://backend.remnote.com/desktop/windows"
```

## 🔄 How It Works

1. Reads the [RemNote changelog RSS feed](https://feedback.remnote.com/rss/changelog.xml) — skips beta versions
2. If a new stable version is found, downloads the installer from official RemNote servers
3. Extracts the app silently using **SharpCompress** (a ~500 KB .NET library, downloaded automatically on first run — no user action needed)
4. Backs up your current install, deploys the new version, then launches RemNote
5. If RemNote is open when an update is found, a prompt asks whether to update now or later
6. Confirms `RemNote.exe` exists in installation and auto starts it
7. Removes temporary files after successful update


## Manual / advanced usage

```powershell
# Check for updates right now (one-shot, no scheduling)
.\RemNoteUpdater.ps1 -RunOnce

# Run the setup again (re-registers the scheduled task)
.\RemNoteUpdater.ps1 -Setup

# Remove the scheduled task
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
- ✅ SHA256 hash verification prevents corrupted downloads
- ✅ Automatic backup before any modifications
- ✅ Rollback mechanism on failure
- ✅ No elevation/admin rights required or requested


## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This is an unofficial tool and is not affiliated with, endorsed by, or connected to RemNote or RemNote Inc. in any way.

- This tool downloads RemNote installers from official RemNote servers
- Always review scripts before running them on your system
- Keep backups of your RemNote data

## 🙏 Acknowledgments

- [RemNote](https://www.remnote.com/) - Amazing note-taking and spaced repetition software
- [SharpCompress](https://github.com/adamhathcock/sharpcompress) - File archiver used for extraction

## 💬 Support

- **Issues:** [GitHub Issues](https://github.com/sukarth/remnote-updater/issues)
- **RemNote Community:** [RemNote Discord](https://remnote.com/discord)

---

**Made with ❤️ by Sukarth for the RemNote community**
