# RemNote Auto Updater Script v2.0.0
# Monitors RSS feed for stable releases and auto-updates RemNote
# Automatic task/startup setup, no admin rights required.
# Source: https://github.com/sukarth/remnote-updater
# Author: Sukarth Acharya
# License: MIT

param(
    [switch]$RunOnce, # Deprecated (kept for backwards compatibility)
    [switch]$Loop,    # Run a persistent terminal monitoring loop
    [switch]$Uninstall,
    [switch]$Force,
    [int]$CheckIntervalMinutes = 60,
    [string]$InstallPath = (Join-Path $env:LOCALAPPDATA "RemNote"),
    [string]$TempPath    = (Join-Path $env:LOCALAPPDATA "RemNoteTemp")
)

# Ensure modern TLS protocols are enabled (required for PowerShell 5.1 compatibility on secure sites)
try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
}
catch {
    # Fallback value 3072 represents TLS 1.2 if TLS 1.3 is not defined in older .NET assemblies
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$INSTALLER_DOWNLOAD_URL = "https://backend.remnote.com/desktop/windows"
$RSS_FEED_URL           = "https://feedback.remnote.com/rss/changelog.xml"
$INSTALL_DIR            = $InstallPath
$BACKUP_DIR             = "${InstallPath}_Backup"
$TEMP_DIR               = $TempPath
$VERSION_FILE           = Join-Path $TEMP_DIR "last_version.txt"
$LOG_FILE               = Join-Path $TEMP_DIR "updater.log"
$TASK_NAME              = "RemNoteAutoUpdater"
$SCRIPT_PATH            = $MyInvocation.MyCommand.Path

if (-not (Test-Path $TEMP_DIR)) {
    New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null
}

# ---------------------------------------------------------------------------
# Logging & Log Rotation (Declared early for in-memory setup logs)
# ---------------------------------------------------------------------------
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $msg = "[$ts] [$Level] $Message"
    Write-Host $msg
    Add-Content -Path $LOG_FILE -Value $msg
}

function Trim-Log {
    if (Test-Path $LOG_FILE) {
        try {
            $lines = Get-Content $LOG_FILE -ErrorAction SilentlyContinue
            if ($lines -and $lines.Count -gt 500) {
                $lines | Select-Object -Last 500 | Set-Content $LOG_FILE -Force
            }
        }
        catch {}
    }
}

# Resolve script path safely, even if executed in-memory via 'irm | iex'
if (-not $SCRIPT_PATH -or -not (Test-Path $SCRIPT_PATH -PathType Leaf)) {
    # Force single-run execution for web-loaded instances so the terminal exits cleanly
    $RunOnce = $true
    
    $SCRIPT_PATH = Join-Path $TEMP_DIR "RemNoteUpdater.ps1"
    if (-not (Test-Path $SCRIPT_PATH)) {
        Write-Log "In-memory execution detected. Fetching latest script from GitHub for local registration..."
        try {
            # Automatically pulls the latest raw version to register physically
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile(
                "https://raw.githubusercontent.com/sukarth/remnote-updater/main/RemNoteUpdater.ps1",
                $SCRIPT_PATH
            )
            $webClient.Dispose()
            Write-Log "Script cached successfully at: $SCRIPT_PATH"
        }
        catch {
            Write-Log "Failed to cache script to disk: $($_.Exception.Message)" "ERROR"
        }
    }
}

# ---------------------------------------------------------------------------
# 7zr.exe / 7za.exe - portable engine (no install needed).
# ---------------------------------------------------------------------------
function Get-7zaPath {
    # 1. Look next to the script (bundled in repo)
    $bundled = Join-Path (Split-Path $SCRIPT_PATH) "7za.exe"
    if (Test-Path $bundled) {
        Write-Log "Using bundled 7za.exe"
        return $bundled
    }

    # 2. Look in temp dir (previously auto-downloaded)
    $cached = Join-Path $TEMP_DIR "7zr.exe"
    if (Test-Path $cached) {
        Write-Log "Using cached 7zr.exe"
        return $cached
    }

    # 3. Dynamic multi-mirror fallback download list
    # raw.githubusercontent.com is guaranteed reachable (used to run the script)
    $mirrors = @(
        "https://raw.githubusercontent.com/sukarth/remnote-updater/main/7zr.exe",
        "https://www.7-zip.org/a/7zr.exe"
    )

    foreach ($url in $mirrors) {
        Write-Log "Downloading extraction engine from: $url ..."
        try {
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
            $wc.DownloadFile($url, $cached)
            $wc.Dispose()

            if (Test-Path $cached) {
                $kb = [math]::Round((Get-Item $cached).Length / 1KB, 0)
                if ($kb -gt 100) { # Ensure it's not a 404 HTML page
                    Write-Log "Extraction engine ready (${kb} KB)."
                    return $cached
                } else {
                    Write-Log "Downloaded file from mirror is invalid (too small). Trying next mirror..." "WARN"
                    Remove-Item $cached -Force -ErrorAction SilentlyContinue
                }
            }
        }
        catch {
            # Replaced colon with a hyphen to avoid the variable drive-qualifier parser bug
            Write-Log "Failed to download from $url - error: $($_.Exception.Message)" "WARN"
        }
    }

    Write-Log "All extraction engine download mirrors failed." "ERROR"
    return $null
}

# ---------------------------------------------------------------------------
# Task Scheduler / Startup Folder configuration
# ---------------------------------------------------------------------------
function Register-UpdaterTask {
    try {
        $existing = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Log "Scheduled task '$TASK_NAME' already exists."
            return $true
        }
    }
    catch {}

    # Tier 1: Attempt standard Register-ScheduledTask Cmdlet (WMI-based)
    try {
        $action = New-ScheduledTaskAction `
            -Execute "powershell.exe" `
            -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$SCRIPT_PATH`" -RunOnce"

        $logon  = New-ScheduledTaskTrigger -AtLogOn
        $repeat = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
                      -RepetitionInterval (New-TimeSpan -Minutes $CheckIntervalMinutes)

        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $principal   = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive

        $settings = New-ScheduledTaskSettingsSet `
            -ExecutionTimeLimit (New-TimeSpan -Minutes 15) `
            -StartWhenAvailable `
            -RunOnlyIfNetworkAvailable

        Register-ScheduledTask `
            -TaskName  $TASK_NAME `
            -Action    $action `
            -Trigger   @($logon, $repeat) `
            -Settings  $settings `
            -Principal $principal `
            -Force -ErrorAction Stop | Out-Null

        Write-Log "Scheduled task '$TASK_NAME' registered successfully via cmdlet (every $CheckIntervalMinutes min + logon)."
        return $true
    }
    catch {
        Write-Log "Task Scheduler cmdlet registration failed ($($_.Exception.Message)). Trying schtasks.exe fallback..." "WARN"
    }

    # Tier 2: Attempt native schtasks.exe (bypasses WMI security, runs as standard user)
    try {
        # Native direct execution using the call operator (&) bypasses the Start-Process parser bugs.
        # Escaping quotes precisely using \" is required so schtasks accepts the /tr argument as a single string.
        $output = & schtasks.exe /create /f /tn $TASK_NAME /sc minute /mo $CheckIntervalMinutes /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File \`"$SCRIPT_PATH\`" -RunOnce" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Scheduled task '$TASK_NAME' registered successfully via schtasks.exe (every $CheckIntervalMinutes min)."
            return $true
        }
        else {
            Write-Log "schtasks.exe failed with exit code $LASTEXITCODE. Output: $output" "WARN"
        }
    }
    catch {
        Write-Log "schtasks.exe registration failed: $($_.Exception.Message)" "WARN"
    }

    # Tier 3: Fallback: Startup folder shortcut (no scheduler access required)
    try {
        $startupDir   = [Environment]::GetFolderPath("Startup")
        $shortcutPath = Join-Path $startupDir "RemNoteAutoUpdater.lnk"

        $wsh      = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($shortcutPath)
        $shortcut.TargetPath       = "powershell.exe"
        $shortcut.Arguments        = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$SCRIPT_PATH`" -RunOnce"
        $shortcut.WorkingDirectory = Split-Path $SCRIPT_PATH
        $shortcut.WindowStyle      = 7  # Minimized
        $shortcut.Description      = "RemNote Auto Updater"
        $shortcut.Save()

        Write-Log "Startup folder shortcut created: $shortcutPath"
        Write-Log "Updater will run at logon."
        return $true
    }
    catch {
        Write-Log "Startup folder fallback also failed: $($_.Exception.Message)" "ERROR"
        Write-Log "Auto-start not configured. Run manually with: .\RemNoteUpdater.ps1 -RunOnce" "WARN"
        return $false
    }
}

function Unregister-UpdaterTask {
    # Attempt unregistration via Cmdlet
    try {
        Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false -ErrorAction Stop
        Write-Log "Scheduled task '$TASK_NAME' removed via cmdlet."
    }
    catch {
        # Fallback to schtasks /delete via native direct execution
        try {
            $output = & schtasks.exe /delete /tn $TASK_NAME /f 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Scheduled task '$TASK_NAME' removed via schtasks.exe."
            }
        }
        catch {}
    }

    try {
        $startupDir   = [Environment]::GetFolderPath("Startup")
        $shortcutPath = Join-Path $startupDir "RemNoteAutoUpdater.lnk"
        if (Test-Path $shortcutPath) {
            Remove-Item $shortcutPath -Force
            Write-Log "Startup folder shortcut removed."
        }
    }
    catch {
        Write-Log "Could not remove startup shortcut: $($_.Exception.Message)" "WARN"
    }
}

# ---------------------------------------------------------------------------
# Version Check & Feed Processing
# ---------------------------------------------------------------------------
function Get-LatestStableVersion {
    try {
        Write-Log "Checking RSS feed..."
        $response = Invoke-WebRequest -Uri $RSS_FEED_URL -UseBasicParsing -TimeoutSec 30
        $xml = [xml]$response.Content
        foreach ($item in $xml.rss.channel.item) {
            $title = $null
            if ($item.title -is [System.Xml.XmlElement]) {
                $title = $item.title.'#cdata-section'
                if (-not $title) { $title = $item.title.InnerText }
            } else {
                $title = $item.title
            }

            if ($title -and $title -notmatch '\(Beta\)') {
                Write-Log "Latest stable: $($title.Trim())"
                return $title.Trim()
            }
        }
        Write-Log "No stable release found in RSS." "WARN"
        return $null
    }
    catch {
        Write-Log "RSS fetch error: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Get-LastCheckedVersion {
    if (Test-Path $VERSION_FILE) {
        return (Get-Content $VERSION_FILE -Raw).Trim()
    }
    return $null
}

function Save-CurrentVersion {
    param([string]$Version)
    Set-Content -Path $VERSION_FILE -Value $Version -NoNewline
}

# ---------------------------------------------------------------------------
# File Hash Verification
# ---------------------------------------------------------------------------
function Get-InstallerHash {
    param([string]$FilePath)
    return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
}

# ---------------------------------------------------------------------------
# Download Handler
# ---------------------------------------------------------------------------
function Download-Installer {
    param([string]$Version)

    $safeName = $Version -replace '[^\w\d\.]', '_'
    $path     = Join-Path $TEMP_DIR "RemNote_Setup_${safeName}.exe"
    $hashFile = "$path.sha256"

    # Reuse cached installer only if files exist, local SHA matches, and -Force is not active
    if (-not $Force -and (Test-Path $path) -and (Test-Path $hashFile)) {
        $cachedHash = (Get-Content $hashFile -Raw).Trim()
        $actualHash = Get-InstallerHash -FilePath $path
        if ($cachedHash -eq $actualHash) {
            Write-Log "Installer cached and verified (SHA256: $actualHash)"
            return $path
        }
        else {
            Write-Log "Cached installer hash mismatch - re-downloading." "WARN"
            Remove-Item $path     -Force -ErrorAction SilentlyContinue
            Remove-Item $hashFile -Force -ErrorAction SilentlyContinue
        }
    }

    # Delete older installer assets to conserve space
    Get-ChildItem $TEMP_DIR -Filter "RemNote_Setup_*.exe"    | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem $TEMP_DIR -Filter "RemNote_Setup_*.sha256" | Remove-Item -Force -ErrorAction SilentlyContinue

    try {
        Write-Log "Downloading installer..."
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        $wc.DownloadFile($INSTALLER_DOWNLOAD_URL, $path)
        $wc.Dispose()

        if (-not (Test-Path $path)) {
            Write-Log "Download failed - file missing after transfer." "ERROR"
            return $null
        }

        $mb   = [math]::Round((Get-Item $path).Length / 1MB, 1)
        $hash = Get-InstallerHash -FilePath $path
        Set-Content -Path $hashFile -Value $hash -NoNewline
        Write-Log "Downloaded ${mb} MB - SHA256: $hash"
        return $path
    }
    catch {
        Write-Log "Download error: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# ---------------------------------------------------------------------------
# Deployment Extraction
# ---------------------------------------------------------------------------
function Extract-Installer {
    param([string]$InstallerPath)

    $sevenZip = Get-7zaPath
    if (-not $sevenZip) { return $false }

    if (Test-RemNoteRunning) {
        Write-Log "RemNote is running - cannot replace directory." "WARN"
        return $false
    }

    try {
        $stage1 = Join-Path $TEMP_DIR "nsis_extract"
        if (Test-Path $stage1) { Remove-Item $stage1 -Recurse -Force }
        New-Item -ItemType Directory -Path $stage1 -Force | Out-Null

        Write-Log "Extracting installer..."
        $7zLog = Join-Path $TEMP_DIR "7zr.log"
        $7zErrLog = Join-Path $TEMP_DIR "7zr_err.log"

        # Clear existing logs to prevent corruption
        Remove-Item $7zLog -Force -ErrorAction SilentlyContinue
        Remove-Item $7zErrLog -Force -ErrorAction SilentlyContinue

        $p = Start-Process -FilePath $sevenZip `
            -ArgumentList "x `"$InstallerPath`" -o`"$stage1`" -y" `
            -Wait -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput $7zLog `
            -RedirectStandardError  $7zErrLog

        # Merge standard error log into the primary log file if written
        if (Test-Path $7zErrLog) {
            try {
                $errContent = Get-Content $7zErrLog -ErrorAction SilentlyContinue
                if ($errContent) {
                    Add-Content -Path $7zLog -Value "`n=== Standard Error Output ===" -ErrorAction SilentlyContinue
                    $errContent | Add-Content -Path $7zLog -ErrorAction SilentlyContinue
                }
                Remove-Item $7zErrLog -Force -ErrorAction SilentlyContinue
            }
            catch {}
        }

        if ($p.ExitCode -ne 0) {
            Write-Log "7zr extraction failed (exit $($p.ExitCode)). See: $7zLog" "ERROR"
            Remove-Item $stage1 -Recurse -Force -ErrorAction SilentlyContinue
            return $false
        }

        $extractedExe = Join-Path $stage1 "RemNote.exe"
        if (-not (Test-Path $extractedExe)) {
            Write-Log "RemNote.exe not found in extracted output." "ERROR"
            Remove-Item $stage1 -Recurse -Force -ErrorAction SilentlyContinue
            return $false
        }

        Write-Log "Extraction complete - deploying to $INSTALL_DIR"

        if (Test-Path $BACKUP_DIR) { Remove-Item $BACKUP_DIR -Recurse -Force }
        
        # Handle active directory swap with multiple attempts to mitigate temporary locks
        if (Test-Path $INSTALL_DIR) {
            $renamed = $false
            for ($i = 1; $i -le 5; $i++) {
                try {
                    Rename-Item -Path $INSTALL_DIR -NewName (Split-Path $BACKUP_DIR -Leaf) -ErrorAction Stop
                    $renamed = $true
                    break
                }
                catch {
                    Write-Log "Rename attempt $i failed: $($_.Exception.Message). Retrying in 2 seconds..." "WARN"
                    if ($i -eq 1) {
                        # Actively close background instances locking the folder
                        Close-FolderProcesses -FolderPath $INSTALL_DIR
                    }
                    if ($i -eq 3) {
                        Write-Log "Hint: Please ensure you do not have any File Explorer windows, command prompts, or code editors open targeting: $INSTALL_DIR" "WARN"
                    }
                    Start-Sleep -Seconds 2
                }
            }
            if (-not $renamed) {
                throw "Directory locked by external handle - failed to backup existing installation."
            }
        }

        Move-Item -Path $stage1 -Destination $INSTALL_DIR -Force

        $exe = Join-Path $INSTALL_DIR "RemNote.exe"
        if (-not (Test-Path $exe)) {
            Write-Log "RemNote.exe missing after deploy." "ERROR"
            if (Test-Path $BACKUP_DIR) {
                Remove-Item $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
                Rename-Item -Path $BACKUP_DIR -NewName (Split-Path $INSTALL_DIR -Leaf)
            }
            return $false
        }

        Write-Log "RemNote.exe verified at $exe"
        return $true
    }
    catch {
        Write-Log "Extraction pipeline error: $($_.Message)" "ERROR"
        if (Test-Path $BACKUP_DIR) {
            Remove-Item $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
            Rename-Item -Path $BACKUP_DIR -NewName (Split-Path $INSTALL_DIR -Leaf) -ErrorAction SilentlyContinue
        }
        Remove-Item (Join-Path $TEMP_DIR "nsis_extract") -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }
}

# ---------------------------------------------------------------------------
# Shell / Execution Management
# ---------------------------------------------------------------------------
function Test-RemNoteRunning {
    return ($null -ne (Get-Process -Name "RemNote" -ErrorAction SilentlyContinue))
}

function Close-FolderProcesses {
    param([string]$FolderPath)
    Write-Log "Scanning for background processes running out of installation directory..."
    
    $normalizedFolder = $FolderPath
    if (-not $normalizedFolder.EndsWith("\")) { $normalizedFolder += "\" }

    $procs = Get-Process
    foreach ($p in $procs) {
        # Skip critical system/idle structures immediately to minimize slow permission faults
        if ($p.Name -eq "Idle" -or $p.Name -eq "System" -or $p.Name -eq "Registry") { continue }
        try {
            $procPath = $null
            if ($p.Path) { $procPath = $p.Path }
            elseif ($p.MainModule.FileName) { $procPath = $p.MainModule.FileName }

            if ($procPath -and $procPath.StartsWith($normalizedFolder, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Log "Stopping locking process: $($p.Name) (PID: $($p.Id)) -> $procPath" "WARN"
                Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            # Ignore access restrictions on system-owned tasks
        }
    }
}

function Show-UpdatePrompt {
    Add-Type -AssemblyName System.Windows.Forms

    $form                 = New-Object System.Windows.Forms.Form
    $form.Text            = "RemNote Update Available"
    $form.Size            = New-Object System.Drawing.Size(420, 190)
    $form.StartPosition   = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox     = $false
    $form.TopMost         = $true

    $lbl          = New-Object System.Windows.Forms.Label
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size     = New-Object System.Drawing.Size(380, 70)
    $lbl.Text     = "A new version of RemNote is available.`n`nPlease close RemNote to continue, or click Later to skip this check."
    $form.Controls.Add($lbl)

    $btnNow              = New-Object System.Windows.Forms.Button
    $btnNow.Location     = New-Object System.Drawing.Point(110, 110)
    $btnNow.Size         = New-Object System.Drawing.Size(110, 32)
    $btnNow.Text         = "Update Now"
    $btnNow.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($btnNow)

    $btnLater              = New-Object System.Windows.Forms.Button
    $btnLater.Location     = New-Object System.Drawing.Point(240, 110)
    $btnLater.Size         = New-Object System.Drawing.Size(110, 32)
    $btnLater.Text         = "Later"
    $btnLater.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($btnLater)

    $form.AcceptButton = $btnNow
    $form.CancelButton = $btnLater
    return $form.ShowDialog()
}

function Stop-RemNote {
    $procs = Get-Process -Name "RemNote" -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Log "Closing RemNote..."
        $procs | ForEach-Object {
            try { $_.CloseMainWindow() | Out-Null } catch { }
        }
        Start-Sleep -Seconds 3

        $procs = Get-Process -Name "RemNote" -ErrorAction SilentlyContinue
        $procs | ForEach-Object {
            try { Stop-Process -Id $_.Id -Force } catch { }
        }
        Start-Sleep -Seconds 2
    }

    # Intervene and sweep any auxiliary tools/DB engines running from the directory
    Close-FolderProcesses -FolderPath $INSTALL_DIR

    if (Test-RemNoteRunning) {
        Write-Log "Could not stop all RemNote processes." "ERROR"
        return $false
    }
    return $true
}

function Start-RemNote {
    $exe = Join-Path $INSTALL_DIR "RemNote.exe"
    if (Test-Path $exe) {
        # Detach completely from parent terminal stream using cmd /c
        $argList = "/c start `"`" `"$exe`""
        Start-Process "cmd.exe" -ArgumentList $argList -WindowStyle Hidden
        Write-Log "RemNote launched."
        return $true
    }
    Write-Log "RemNote.exe not found at $exe" "ERROR"
    return $false
}

# ---------------------------------------------------------------------------
# Execution Pipelines
# ---------------------------------------------------------------------------
function Start-UpdateProcess {
    param([string]$Version)

    Write-Log "New version detected: $Version - starting update..."

    $installer = Download-Installer -Version $Version
    if (-not $installer) { return $false }

    if (Test-RemNoteRunning) {
        $result = Show-UpdatePrompt
        if ($result -eq [System.Windows.Forms.DialogResult]::Cancel) {
            Write-Log "User deferred update."
            return $false
        }
        if (-not (Stop-RemNote)) {
            Write-Log "Could not stop RemNote - aborting update." "ERROR"
            return $false
        }
    }

    if (-not (Extract-Installer -InstallerPath $installer)) {
        Write-Log "Update failed during extraction." "ERROR"
        return $false
    }

    Start-RemNote | Out-Null

    # Wait and verify that the updated binary initializes successfully
    Start-Sleep -Seconds 8
    if (-not (Test-RemNoteRunning)) {
        Write-Log "RemNote failed to start after update. Rolling back to previous installation." "ERROR"
        if (Test-Path $BACKUP_DIR) {
            Stop-RemNote | Out-Null
            Remove-Item $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
            Rename-Item -Path $BACKUP_DIR -NewName (Split-Path $INSTALL_DIR -Leaf) -ErrorAction SilentlyContinue
            Start-RemNote | Out-Null
        }
        return $false
    }

    Save-CurrentVersion -Version $Version

    if (Test-Path $BACKUP_DIR) {
        Remove-Item $BACKUP_DIR -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Backup folder cleared."
    }

    Write-Log "RemNote updated to $Version successfully."
    return $true
}

function Start-Monitoring {
    Write-Log "RemNote Auto Updater v2.0.0 started"
    Trim-Log

    # Seed the tracker value unless -Force is specified to avoid redundant installs for existing setups
    if (-not $Force -and (Test-Path (Join-Path $INSTALL_DIR "RemNote.exe")) -and -not (Test-Path $VERSION_FILE)) {
        Write-Log "RemNote is installed but local tracker is missing. Querying feed..."
        $latest = Get-LatestStableVersion
        if ($latest) {
            Save-CurrentVersion -Version $latest
            Write-Log "Tracker initialized to $latest."
        }
    }

    do {
        $latest = Get-LatestStableVersion
        if ($latest) {
            $last = Get-LastCheckedVersion
            # Always run the update pipeline if -Force is checked
            if ($Force -or ($last -ne $latest)) {
                Start-UpdateProcess -Version $latest | Out-Null
            }
            else {
                Write-Log "Already up to date: $latest"
            }
        }

        if ($Loop) {
            Write-Log "Next check in $CheckIntervalMinutes minutes..."
            Start-Sleep -Seconds ($CheckIntervalMinutes * 60)
        }
    } while ($Loop)

    Write-Log "RemNote Auto Updater stopped."
}

# ---------------------------------------------------------------------------
# Orchestration / Entry Point
# ---------------------------------------------------------------------------
try {
    if ($Uninstall) {
        Unregister-UpdaterTask
        exit 0
    }

    if ($Force) {
        Write-Log "Force option enabled. Clearing cached tracking files and installers..."
        if (Test-Path $VERSION_FILE) {
            Remove-Item $VERSION_FILE -Force -ErrorAction SilentlyContinue
        }
        Get-ChildItem $TEMP_DIR -Filter "RemNote_Setup_*.exe"    | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem $TEMP_DIR -Filter "RemNote_Setup_*.sha256" | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    # Verify if first-time configuration has been completed on either fallback mechanism
    $startupDir     = [Environment]::GetFolderPath("Startup")
    $shortcutPath   = Join-Path $startupDir "RemNoteAutoUpdater.lnk"
    $taskExists     = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    $setupCompleted = [bool]($taskExists -or (Test-Path $shortcutPath))

    # Perform automated registration if setup is not completed yet
    if (-not $setupCompleted) {
        Write-Log "=== First-time setup ==="
        $registered = Register-UpdaterTask
        
        # Verify if setup successfully registered a scheduler task (either via cmdlet or schtasks.exe)
        $taskExistsNow = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
        
        # Only force an immediate exit if Task Scheduler registration succeeded (since task manager will take over monitoring).
        # If running the Startup folder fallback, stay active to monitor this session.
        if ($registered -and $taskExistsNow) {
            $RunOnce = $true
        }
    } else {
        # Explicitly log the active registration status when setup is skipped
        if ($taskExists) {
            Write-Log "Background Task Scheduler is active and ready."
        } elseif (Test-Path $shortcutPath) {
            Write-Log "Logon Startup folder fallback is active."
        }
    }

    Start-Monitoring
}
catch {
    Write-Log "Critical error: $($_.Exception.Message)" "ERROR"
}