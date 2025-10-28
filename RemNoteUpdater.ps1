# RemNote Auto Updater Script
# Monitors RSS feed for stable releases and auto-updates RemNote
# https://github.com/sukarth/remnote-updater

param(
    [switch]$RunOnce,
    [int]$CheckIntervalMinutes = 60,
    [string]$InstallPath = (Join-Path $env:LOCALAPPDATA "RemNote"),
    [string]$TempPath = (Join-Path $env:LOCALAPPDATA "RemNoteTemp")
)

# Configuration
$RSS_FEED_URL = "https://feedback.remnote.com/rss/changelog.xml"
$INSTALLER_DOWNLOAD_URL = "https://backend.remnote.com/desktop/windows"
$TEMP_DIR = $TempPath
$INSTALL_DIR = $InstallPath
$BACKUP_DIR = "$($InstallPath)_Backup"
$VERSION_FILE = Join-Path $TEMP_DIR "last_version.txt"
$MAX_INSTALLERS = 2

# Ensure temp directory exists
if (-not (Test-Path $TEMP_DIR)) {
    New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null
}

# Function to write log messages
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path (Join-Path $TEMP_DIR "updater.log") -Value $logMessage
}

# Function to get latest stable version from RSS
function Get-LatestStableVersion {
    try {
        Write-Log "Checking RSS feed for updates..."
        $response = Invoke-WebRequest -Uri $RSS_FEED_URL -UseBasicParsing -TimeoutSec 30
        $xml = [xml]$response.Content
        
        # Find first non-beta release
        foreach ($item in $xml.rss.channel.item) {
            $title = $item.title.'#cdata-section'
            if ($title -notmatch '\(Beta\)') {
                Write-Log "Found stable release: $title"
                return $title.Trim()
            }
        }
        
        Write-Log "No stable release found in RSS feed" "WARN"
        return $null
    }
    catch {
        Write-Log "Error fetching RSS feed: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# Function to get last checked version
function Get-LastCheckedVersion {
    if (Test-Path $VERSION_FILE) {
        return Get-Content $VERSION_FILE -Raw
    }
    return $null
}

# Function to save current version
function Save-CurrentVersion {
    param([string]$Version)
    Set-Content -Path $VERSION_FILE -Value $Version -NoNewline
}

# Function to compare file hashes
function Compare-InstallerFiles {
    param([string]$File1, [string]$File2)
    
    if (-not (Test-Path $File1) -or -not (Test-Path $File2)) {
        return $false
    }
    
    $hash1 = (Get-FileHash -Path $File1 -Algorithm SHA256).Hash
    $hash2 = (Get-FileHash -Path $File2 -Algorithm SHA256).Hash
    
    return $hash1 -eq $hash2
}

# Function to download installer
function Download-Installer {
    param([string]$Version)
    
    try {
        $installerPath = Join-Path $TEMP_DIR "RemNote_Setup_$($Version -replace '[^\w\d\.]', '_').exe"
        
        Write-Log "Downloading installer to: $installerPath"
        
        # Use .NET WebClient for better download performance
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($INSTALLER_DOWNLOAD_URL, $installerPath)
        $webClient.Dispose()
        
        if (Test-Path $installerPath) {
            $fileSize = (Get-Item $installerPath).Length / 1MB
            Write-Log "Download complete. Size: $([math]::Round($fileSize, 2)) MB"
            return $installerPath
        }
        else {
            Write-Log "Download failed - file not found" "ERROR"
            return $null
        }
    }
    catch {
        Write-Log "Error downloading installer: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# Function to manage installer files (keep max 2)
function Manage-InstallerFiles {
    param([string]$NewInstallerPath)
    
    $installers = Get-ChildItem -Path $TEMP_DIR -Filter "RemNote_Setup_*.exe" | 
                  Sort-Object LastWriteTime -Descending
    
    # Check if we have an old installer to compare with
    if ($installers.Count -ge 2) {
        $oldInstaller = $installers[1].FullName
        
        # Compare files
        if (Compare-InstallerFiles -File1 $NewInstallerPath -File2 $oldInstaller) {
            Write-Log "New installer is identical to existing installer. Skipping update." "WARN"
            Remove-Item $NewInstallerPath -Force
            return $false
        }
    }
    
    # Keep only the newest installer (delete older ones)
    foreach ($installer in $installers) {
        if ($installer.FullName -ne $NewInstallerPath) {
            Write-Log "Removing old installer: $($installer.Name)"
            Remove-Item $installer.FullName -Force
        }
    }
    
    return $true
}

# Function to check if RemNote is running
function Test-RemNoteRunning {
    return (Get-Process -Name "RemNote" -ErrorAction SilentlyContinue) -ne $null
}

# Function to show update prompt
function Show-UpdatePrompt {
    Add-Type -AssemblyName System.Windows.Forms
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "RemNote Update Available"
    $form.Size = New-Object System.Drawing.Size(400, 180)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $true
    $form.TopMost = $true
    
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(20, 20)
    $label.Size = New-Object System.Drawing.Size(360, 60)
    $label.Text = "A new version of RemNote is available.`n`nPlease close RemNote to continue with the update."
    $form.Controls.Add($label)
    
    $btnUpdate = New-Object System.Windows.Forms.Button
    $btnUpdate.Location = New-Object System.Drawing.Point(100, 100)
    $btnUpdate.Size = New-Object System.Drawing.Size(100, 30)
    $btnUpdate.Text = "Update Now"
    $btnUpdate.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($btnUpdate)
    
    $btnLater = New-Object System.Windows.Forms.Button
    $btnLater.Location = New-Object System.Drawing.Point(220, 100)
    $btnLater.Size = New-Object System.Drawing.Size(100, 30)
    $btnLater.Text = "Update Later"
    $btnLater.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($btnLater)
    
    $form.AcceptButton = $btnUpdate
    $form.CancelButton = $btnLater
    
    return $form.ShowDialog()
}

# Function to kill RemNote processes
function Stop-RemNote {
    $processes = Get-Process -Name "RemNote" -ErrorAction SilentlyContinue
    
    if ($processes) {
        Write-Log "Stopping RemNote processes..."
        
        # First try graceful close
        foreach ($proc in $processes) {
            try {
                if (-not $proc.HasExited) {
                    $proc.CloseMainWindow() | Out-Null
                }
            }
            catch {
                Write-Log "Could not close window for process $($proc.Id): $($_.Exception.Message)" "WARN"
            }
        }
        
        # Wait for graceful exit
        Start-Sleep -Seconds 3
        
        # Force kill any remaining processes
        $processes = Get-Process -Name "RemNote" -ErrorAction SilentlyContinue
        foreach ($proc in $processes) {
            try {
                if (-not $proc.HasExited) {
                    Write-Log "Force stopping process $($proc.Id)..."
                    Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                }
            }
            catch {
                Write-Log "Error stopping process $($proc.Id): $($_.Exception.Message)" "WARN"
            }
        }
        
        Start-Sleep -Seconds 2
        
        # Verify all processes are stopped
        if (Test-RemNoteRunning) {
            Write-Log "Some RemNote processes could not be stopped" "ERROR"
            return $false
        }
    }
    
    return $true
}

# Function to extract installer using 7-Zip
function Extract-Installer {
    param([string]$InstallerPath)
    
    try {
        # Find 7-Zip
        $7zipPaths = @(
            "C:\Program Files\7-Zip\7z.exe",
            "C:\Program Files (x86)\7-Zip\7z.exe",
            "$env:ProgramFiles\7-Zip\7z.exe",
            "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
        )
        
        $7zipExe = $null
        foreach ($path in $7zipPaths) {
            if (Test-Path $path) {
                $7zipExe = $path
                break
            }
        }
        
        if (-not $7zipExe) {
            Write-Log "7-Zip not found. Please install 7-Zip." "ERROR"
            return $false
        }
        
        Write-Log "Using 7-Zip: $7zipExe"
        
        # Create temporary extraction directory
        $tempExtractDir = Join-Path $TEMP_DIR "temp_extract"
        if (Test-Path $tempExtractDir) {
            Remove-Item $tempExtractDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $tempExtractDir -Force | Out-Null
        
        # Extract NSIS installer to temp directory
        Write-Log "Extracting NSIS installer to temp directory..."
        $extractArgs = "x `"$InstallerPath`" -o`"$tempExtractDir`" -y"
        $process = Start-Process -FilePath $7zipExe -ArgumentList $extractArgs -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -ne 0) {
            Write-Log "7-Zip extraction of NSIS installer failed with exit code: $($process.ExitCode)" "ERROR"
            Remove-Item $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
            return $false
        }
        
        # Find the app-64.7z file (prefer 64-bit)
        $app64Path = Join-Path $tempExtractDir "`$PLUGINSDIR\app-64.7z"
        $app32Path = Join-Path $tempExtractDir "`$PLUGINSDIR\app-32.7z"
        
        $appArchivePath = $null
        if (Test-Path $app64Path) {
            $appArchivePath = $app64Path
            Write-Log "Found 64-bit application archive"
        }
        elseif (Test-Path $app32Path) {
            $appArchivePath = $app32Path
            Write-Log "Found 32-bit application archive"
        }
        else {
            Write-Log "Could not find app-64.7z or app-32.7z in extracted NSIS installer" "ERROR"
            Remove-Item $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
            return $false
        }
        
        # Delete backup directory if it exists
        if (Test-Path $BACKUP_DIR) {
            Write-Log "Removing old backup directory..."
            Remove-Item $BACKUP_DIR -Recurse -Force
        }
        
        # Rename current installation to backup
        if (Test-Path $INSTALL_DIR) {
            Write-Log "Creating backup of current installation..."
            Rename-Item -Path $INSTALL_DIR -NewName (Split-Path $BACKUP_DIR -Leaf)
        }
        
        # Create new installation directory
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
        
        # Extract the actual app archive to installation directory
        Write-Log "Extracting RemNote application to: $INSTALL_DIR"
        $extractArgs = "x `"$appArchivePath`" -o`"$INSTALL_DIR`" -y"
        $process = Start-Process -FilePath $7zipExe -ArgumentList $extractArgs -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -ne 0) {
            Write-Log "7-Zip extraction of app archive failed with exit code: $($process.ExitCode)" "ERROR"
            
            # Restore backup
            if (Test-Path $BACKUP_DIR) {
                Write-Log "Restoring backup..."
                if (Test-Path $INSTALL_DIR) {
                    Remove-Item $INSTALL_DIR -Recurse -Force
                }
                Rename-Item -Path $BACKUP_DIR -NewName (Split-Path $INSTALL_DIR -Leaf)
            }
            
            # Cleanup temp directory
            Remove-Item $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
            return $false
        }
        
        # Cleanup temp extraction directory
        Write-Log "Cleaning up temporary files..."
        Remove-Item $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
        
        # Verify RemNote.exe exists
        $remNoteExe = Join-Path $INSTALL_DIR "RemNote.exe"
        if (-not (Test-Path $remNoteExe)) {
            Write-Log "RemNote.exe not found after extraction" "ERROR"
            
            # Restore backup
            if (Test-Path $BACKUP_DIR) {
                Write-Log "Restoring backup..."
                Remove-Item $INSTALL_DIR -Recurse -Force
                Rename-Item -Path $BACKUP_DIR -NewName (Split-Path $INSTALL_DIR -Leaf)
            }
            
            return $false
        }
        
        Write-Log "Extraction successful - RemNote.exe verified"
        return $true
    }
    catch {
        Write-Log "Error during extraction: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to launch RemNote
function Start-RemNote {
    $remNoteExe = Join-Path $INSTALL_DIR "RemNote.exe"
    
    if (Test-Path $remNoteExe) {
        Write-Log "Launching RemNote..."
        Start-Process -FilePath $remNoteExe
        return $true
    }
    else {
        Write-Log "RemNote.exe not found at: $remNoteExe" "ERROR"
        return $false
    }
}

# Main update process
function Start-UpdateProcess {
    param([string]$Version)
    
    Write-Log "Starting update process for version: $Version"
    
    # Download installer
    $installerPath = Download-Installer -Version $Version
    if (-not $installerPath) {
        Write-Log "Update aborted - download failed" "ERROR"
        return $false
    }
    
    # Manage installer files
    if (-not (Manage-InstallerFiles -NewInstallerPath $installerPath)) {
        Write-Log "Update aborted - identical installer detected" "WARN"
        return $false
    }
    
    # Check if RemNote is running and prompt user
    if (Test-RemNoteRunning) {
        Write-Log "RemNote is currently running"
        $result = Show-UpdatePrompt
        
        if ($result -eq [System.Windows.Forms.DialogResult]::Cancel) {
            Write-Log "User chose to update later" "INFO"
            return $false
        }
        
        # User chose to update, stop RemNote
        if (-not (Stop-RemNote)) {
            Write-Log "Failed to stop RemNote processes" "ERROR"
            return $false
        }
    }
    
    # Extract installer
    if (-not (Extract-Installer -InstallerPath $installerPath)) {
        Write-Log "Update failed during extraction" "ERROR"
        return $false
    }
    
    # Launch RemNote
    if (Start-RemNote) {
        Write-Log "Update completed successfully!"
        Save-CurrentVersion -Version $Version
        
        # Clean up old backup after successful update
        if (Test-Path $BACKUP_DIR) {
            Start-Sleep -Seconds 5
            try {
                Remove-Item $BACKUP_DIR -Recurse -Force
                Write-Log "Cleaned up backup directory"
            }
            catch {
                Write-Log "Could not remove backup directory: $($_.Exception.Message)" "WARN"
            }
        }
        
        return $true
    }
    else {
        Write-Log "Update failed - could not launch RemNote" "ERROR"
        return $false
    }
}

# Main monitoring loop
function Start-Monitoring {
    Write-Log "RemNote Auto Updater started"
    Write-Log "Check interval: $CheckIntervalMinutes minutes"
    
    do {
        $latestVersion = Get-LatestStableVersion
        
        if ($latestVersion) {
            $lastVersion = Get-LastCheckedVersion
            
            if ($lastVersion -ne $latestVersion) {
                Write-Log "New version detected: $latestVersion (Previous: $lastVersion)"
                
                if (Start-UpdateProcess -Version $latestVersion) {
                    Write-Log "Update cycle completed successfully"
                }
                else {
                    Write-Log "Update cycle failed or postponed" "WARN"
                }
            }
            else {
                Write-Log "No new version available (Current: $latestVersion)"
            }
        }
        
        if (-not $RunOnce) {
            Write-Log "Waiting $CheckIntervalMinutes minutes until next check..."
            Start-Sleep -Seconds ($CheckIntervalMinutes * 60)
        }
        
    } while (-not $RunOnce)
    
    Write-Log "RemNote Auto Updater stopped"
}

# Start the monitoring process
try {
    Start-Monitoring
}
catch {
    Write-Log "Critical error: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.Exception.StackTrace)" "ERROR"
}
