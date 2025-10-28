# RemNote Auto Updater

<center>

**Portable RemNote installation and automatic update system for Windows - No admin rights required!**

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
- ✅ **Duplicate Prevention** - SHA256 hash comparison to avoid redundant downloads
- ✅ **User-Friendly** - Clean popup dialogs for update confirmation
- ✅ **Graceful Process Handling** - Safely closes RemNote before updating
- ✅ **Comprehensive Logging** - Detailed logs for troubleshooting
- ✅ **Lightweight** - Minimal resource usage, efficient scheduling

## 📋 Prerequisites

- **Windows 10/11** (PowerShell 5.1 or higher - included by default)
- **7-Zip** must be installed ([Download here](https://www.7-zip.org/))
- **Internet connection** for downloading updates

## 🚀 Quick Start

### 1. Download & Setup

```powershell
# Clone or download this repository
git clone https://github.com/sukarth/remnote-updater.git
cd remnote-updater

# Or download and extract the ZIP file from GitHub
```

### 2. First-Time Installation

```powershell
# Run once to download and install RemNote
.\RemNoteUpdater.ps1 -RunOnce
```

This will:
- Download the latest stable RemNote version
- Extract it to `%LOCALAPPDATA%\RemNote`
- Launch RemNote automatically

### 3. Set Up Auto-Updates (Optional)

See [Auto-Start Setup](#auto-start-setup) below to run the updater automatically on Windows startup.

## 📖 Usage

### Check for Updates Now (Run Once)
```powershell
.\RemNoteUpdater.ps1 -RunOnce
```

### Monitor Continuously (Default: Check Every Hour)
```powershell
.\RemNoteUpdater.ps1
```

### Custom Check Interval (e.g., Every 30 Minutes)
```powershell
.\RemNoteUpdater.ps1 -CheckIntervalMinutes 30
```

### Custom Installation Path
```powershell
.\RemNoteUpdater.ps1 -InstallPath "D:\MyApps\RemNote" -TempPath "D:\MyApps\RemNoteTemp"
```

### Run Silently in Background
```powershell
Start-Process powershell -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PWD\RemNoteUpdater.ps1`"" -WindowStyle Hidden
```

Or simply double-click **`RunUpdater.bat`** for easy launching.

## 🔧 Configuration

### Default Paths

| Path | Default Location | Description |
|------|------------------|-------------|
| Installation | `%LOCALAPPDATA%\RemNote` | Where RemNote is installed |
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

### Customizing RSS Feed or Download URL

Edit these variables in `RemNoteUpdater.ps1` if needed:

```powershell
$RSS_FEED_URL = "https://feedback.remnote.com/rss/changelog.xml"
$INSTALLER_DOWNLOAD_URL = "https://backend.remnote.com/desktop/windows"
```

## 🔄 How It Works

1. **RSS Monitoring**: Checks RemNote's changelog RSS feed for the latest stable release
2. **Version Comparison**: Compares with previously installed version
3. **Download**: Downloads NSIS installer to temp directory if new version available
4. **Hash Verification**: SHA256 comparison prevents re-downloading identical files
5. **User Prompt**: Shows dialog if RemNote is running, requesting to close it
6. **NSIS Extraction**: Extracts NSIS installer wrapper to temp directory
7. **App Extraction**: Extracts `app-64.7z` (or `app-32.7z`) containing RemNote
8. **Backup**: Renames current installation to backup before updating
9. **Install**: Extracts RemNote application to installation directory
10. **Verify**: Confirms `RemNote.exe` exists in installation
11. **Launch**: Automatically starts RemNote
12. **Cleanup**: Removes backup and temporary files after successful update

## Auto-Start Setup

### Option 1: Task Scheduler (Recommended)

1. Open **Task Scheduler** (`taskschd.msc`)
2. Click **Create Task** (not Basic Task)
3. **General** tab:
   - Name: `RemNote Auto Updater`
   - Description: `Monitors for RemNote updates`
   - Select: "Run whether user is logged on or not"
   - **DO NOT** check "Run with highest privileges" (not needed!)
4. **Triggers** tab:
   - New → At startup (or At log on)
   - Delay: 1 minute (optional)
5. **Actions** tab:
   - New → Start a program
   - Program: `powershell.exe`
   - Arguments: `-WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Path\To\RemNoteUpdater.ps1"`
   - **Replace** `C:\Path\To\` with your actual path
6. **Conditions** tab:
   - Check "Start only if the following network connection is available"
7. Click **OK**

### Option 2: Startup Folder

1. Press `Win + R`, type `shell:startup`, press Enter
2. Create a shortcut to `RunUpdater.bat`
3. Or create a shortcut with target:
   ```
   powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Path\To\RemNoteUpdater.ps1"
   ```
   *(Replace `C:\Path\To\` with your actual path)*

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

### 7-Zip Not Found

**Error:** "7-Zip not found. Please install 7-Zip."

**Solution:** Install 7-Zip from [https://www.7-zip.org/](https://www.7-zip.org/)

The script checks these locations:
- `C:\Program Files\7-Zip\7z.exe`
- `C:\Program Files (x86)\7-Zip\7z.exe`

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

## 📝 File Structure

```
remnote-updater/
├── RemNoteUpdater.ps1    # Main updater script
├── RunUpdater.bat        # Quick launcher (Windows)
├── README.md             # This file
└── LICENSE               # MIT License
```

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

This is an unofficial tool and is not affiliated with, endorsed by, or connected to RemNote or RemNote Inc. in any way. Use at your own risk.

- This tool downloads RemNote installers from official RemNote servers
- Always review scripts before running them on your system
- Keep backups of your RemNote data

## 🙏 Acknowledgments

- [RemNote](https://www.remnote.com/) - Amazing note-taking and spaced repetition software
- [7-Zip](https://www.7-zip.org/) - File archiver used for extraction

## 💬 Support

- **Issues:** [GitHub Issues](https://github.com/sukarth/remnote-updater/issues)
- **RemNote Community:** [RemNote Discord](https://remnote.com/discord)

---

**Made with ❤️ by Sukarth for the RemNote community**
