# Quick Installation Guide

## For Users Without Git

### Step 1: Download
1. Click the green **Code** button at the top of this page
2. Select **Download ZIP**
3. Extract the ZIP file to a location of your choice (e.g., `C:\Tools\remnote-updater`)

### Step 2: Install 7-Zip (if not already installed)
1. Download from: https://www.7-zip.org/
2. Install using default settings

### Step 3: Enable PowerShell Scripts
1. Open PowerShell as yourself (not as admin)
2. Run this command:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
3. Type `Y` and press Enter

### Step 4: First Run
1. Navigate to where you extracted the files
2. Right-click `RemNoteUpdater.ps1`
3. Select **Run with PowerShell**
4. Wait for RemNote to download and install
5. RemNote will launch automatically

### Step 5: (Optional) Set Up Auto-Updates
See the main [README.md](README.md#auto-start-setup) for instructions on setting up automatic updates.

## For Users With Git

```powershell
git clone https://github.com/sukarth/remnote-updater.git
cd remnote-updater
.\RemNoteUpdater.ps1 -RunOnce
```

## Default Installation Location

RemNote will be installed to:
```
%LOCALAPPDATA%\RemNote
```

This typically resolves to:
```
C:\Users\YourUsername\AppData\Local\RemNote
```

## Creating a Desktop Shortcut

After installation, you can create a desktop shortcut to RemNote:

1. Navigate to: `%LOCALAPPDATA%\RemNote`
2. Find `RemNote.exe`
3. Right-click and select **Create shortcut**
4. Move the shortcut to your Desktop

Or use PowerShell:
```powershell
# Create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\RemNote.lnk")
$Shortcut.TargetPath = "$env:LOCALAPPDATA\RemNote\RemNote.exe"
$Shortcut.Save()
```

## Uninstallation

To completely remove RemNote and the updater:

```powershell
# Stop RemNote if running
Get-Process RemNote -ErrorAction SilentlyContinue | Stop-Process -Force

# Remove RemNote installation
Remove-Item "$env:LOCALAPPDATA\RemNote" -Recurse -Force

# Remove temp files and installers
Remove-Item "$env:LOCALAPPDATA\RemNoteTemp" -Recurse -Force

# Remove backup (if exists)
Remove-Item "$env:LOCALAPPDATA\RemNote_Backup" -Recurse -Force -ErrorAction SilentlyContinue

# Remove updater script (optional)
# Delete the folder where you extracted remnote-updater
```

## Troubleshooting

If you encounter any issues, see the [Troubleshooting section](README.md#-troubleshooting) in the main README.
