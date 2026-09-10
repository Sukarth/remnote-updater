# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-09-10

### Fixed
- **Missed Releases (Pinned Announcement Posts)**: Version detection read only the *first* entry of the changelog feed and treated its title as a version string. The feed mixes release entries (`1.28.18`) with announcement posts (`🎉 RemNote 1.28: Faster, Smoother, Smarter 🎉`), and those posts get pinned to the top. While one was pinned, the updater compared the announcement title against itself, reported "Already up to date" on every check, and silently skipped every real release published behind it (`1.28.4` through `1.28.7` were missed for roughly two weeks). Every entry in the feed is now scanned, only titles that are *nothing but* a version number are accepted as releases, and the highest one wins.
- **Installed Version Is Now Read From the Binary**: Update decisions compared the feed title against a text tracker file, which never described what was actually installed. `backend.remnote.com` always serves the current build, which regularly runs ahead of the changelog (a feed entry of `1.28.18` ships a `1.28.19` binary), so the tracker drifted permanently out of sync. The installed version is now taken from `RemNote.exe`'s `FileVersion`, compared numerically (not as strings), and the tracker file records what actually landed on disk. The old tracker is still read as a fallback for installs that predate this release.
- **Overlapping Updater Instances**: The logon trigger and the hourly repetition trigger overlap in practice, and because the scheduled task launches PowerShell detached through `wscript.exe`, Task Scheduler's own `IgnoreNew` policy never saw the real worker. Two instances raced through the same update: both prompted, and the one the user did *not* click "Later" on carried on and updated anyway. Worse, two concurrent extractions would shuffle `%LOCALAPPDATA%\RemNote` and its backup directory at the same time. A session-scoped mutex now allows exactly one instance to run.
- **"Later" Is Remembered**: Deferring an update only skipped that single check - the next trigger (as little as minutes later, or the next logon) re-prompted immediately, and re-downloaded the 300+ MB installer to do it. A deferral is now recorded and suppresses re-prompting for that version for 6 hours. It is checked before downloading, and it only applies while RemNote is open; once RemNote is closed the update proceeds silently as before.
- **Blank Extraction Errors**: The extraction failure handler logged `$_.Message`, which is always empty on an `ErrorRecord`, so the reason a deployment failed was never recorded. It now logs `$_.Exception.Message`.
- **Task Skipped on Battery**: Newly registered scheduled tasks inherited Windows' default "do not start on batteries" setting, which silently suppressed update checks on any unplugged laptop. Tasks are now registered with `-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries`.
- **Log File Encoding**: `Add-Content` wrote the log as ANSI on PowerShell 5.1, turning emoji in feed titles into `?`. The log is now written as UTF-8 throughout, including during rotation.

### Changed
- **Update Prompt**: The dialog now names the version being offered and describes what each button does - "Update Now" closes and reopens RemNote itself, so the old "Please close RemNote to continue" instruction was misleading.
- **Clearer Status Logging**: Up-to-date checks now log both sides of the comparison (`Already up to date: installed 1.28.19, latest published 1.28.18`), and a successful update reports the version actually installed alongside the changelog entry that triggered it.

---

## [2.0.1] - 2026-07-26

### Changed
- **State-Preserving Launch**: RemNote is no longer left running after a background update if it was closed beforehand. The updated binary is still launched once for the post-extraction integrity check, then shut down again, so silent updates no longer pop the app open unexpectedly. If RemNote *was* open when the update ran, it is relaunched and left running as before (including on rollback).

### Fixed
- **Repeating Update Loop (UTF-8 Version Tracking)**: Release titles containing emoji were corrupted twice over - the RSS body was decoded as ISO-8859-1 (no charset header on the feed), and `Set-Content` then wrote it as ANSI, replacing the emoji with `?`. The stored version could therefore never match the live feed, so every scheduled check re-extracted, redeployed and relaunched RemNote. The feed is now decoded as UTF-8 explicitly and the tracker file is read/written as UTF-8 without BOM.

---

## [2.0.0] - 2026-06-26

### Added
- **One-Click Web Installer**: Fully supported execution directly in memory via `irm | iex`. Added self-caching fallback logic that automatically saves the remote script payload locally to `%LOCALAPPDATA%\RemNoteTemp\RemNoteUpdater.ps1` for local setup.
- **Multi-Tier Auto-Start Configuration**: Implemented hands-free setup on first launch. If setup is not completed, it automatically registers a recurring task across a 3-tier fallback matrix:
  1. Standard PowerShell Task Scheduler cmdlets utilizing an explicit interactive user principal (allowing standard users to register local tasks).
  2. Native Win32 `schtasks.exe` command execution to bypass WMI/CIM infrastructure restrictions on managed endpoints.
  3. Standard Windows Startup folder shortcut fallback (`RemNoteAutoUpdater.lnk`) if scheduler interfaces are locked down.
- **Active Lock Mitigation (`Close-FolderProcesses`)**: Resolves directory access denials on file replacement by scanning running processes and shutting down any sub-processes or database helper instances executing directly from within your `%LOCALAPPDATA%\RemNote` installation folder.
- **Pre-Bundled & Standalone Extraction**: `7za.exe` is now pre-bundled directly within the repository ZIP package. Additionally, the script automatically downloads a fallback single-binary `7zr.exe` engine (~500 KB) from raw GitHub CDN or official mirrors if running in-memory without the ZIP.
- **Log Management (`Trim-Log`)**: Implemented automated log rotation that truncates the log file at a maximum of 500 lines to prevent unmanaged storage growth.
- **Active Rollback Guard**: The script now verifies that the updated RemNote process initializes successfully post-extraction; if it fails to launch within 8 seconds, it kills hanging threads, rolls back deployment files from the backup directory, and restores the previous working version.
- **Force Flag (`-Force`)**: Parameter to ignore cached binaries, clear local tracking files, and execute a fresh download and installation of the latest stable build.
- **Dedicated Loop Switch (`-Loop`)**: Added to isolate the infinite background execution logic (making single-run and exit the safe default behavior when running plainly).
- **Clean Uninstallation (`-Uninstall`)**: Parameter to quickly remove Task Scheduler objects, schtasks actions, and Startup folder shortcuts.

### Changed
- **Bandwidth Optimization**: Instead of downloading a full 300+ MB installer file just to hash it and compare it to previous versions (as done in `v1`), `v2.0.0` now relies on a local `.sha256` sidecar file to immediately verify and reuse cached installer binaries without performing unnecessary downloads.
- **Streamlined Extraction**: Rewrote extraction routines to support single-stage NSIS setup structures directly rather than performing slow, nested two-stage extraction runs.
- **Security Protocols Enforced**: Added explicit security protocol configuration to enforce modern **TLS 1.2** and **TLS 1.3** across older Windows environments, resolving connection blocks.
- **Header Masking**: Configured standard browser User-Agent headers on web downloads to bypass server-side agent filters.

### Removed
- **Redundant Switches**: Removed the obsolete `-Setup` parameter since the engine performs automated registration on first launch by default.
- **Obsolete Launchers**: Cleaned up the helper background batch runners (.bat files).

---

## [1.0.0] - 2025-10-28

### Added
- Initial release of RemNote Auto Updater
- Automatic RSS feed monitoring for stable releases
- No admin rights required - installs to `%LOCALAPPDATA%`
- Customizable installation paths via command-line parameters
- SHA256 hash verification to prevent duplicate downloads
- User-friendly update dialog with "Update Now" or "Update Later" options
- Graceful process handling (try close windows first, then force kill if needed)
- Automatic backup before updates with rollback on failure
- Two-stage extraction: NSIS installer → app-64.7z → RemNote files
- Comprehensive logging system
- Support for both 64-bit and 32-bit RemNote installations
- Auto-launch RemNote after successful update
- Configurable check intervals
- Background/silent operation mode
- Batch file launcher for easy execution

### Features
- Monitors `https://feedback.remnote.com/rss/changelog.xml`
- Filters out beta releases, only downloads stable versions
- Keeps maximum 2 installers in temp directory
- Automatic cleanup of temporary files and old backups
- Detailed error handling and recovery
- Version tracking to avoid redundant updates

---

[1.0.0]: https://github.com/sukarth/remnote-updater/releases/tag/v1.0.0
[2.0.0]: https://github.com/sukarth/remnote-updater/releases/tag/v2.0.0
[2.0.1]: https://github.com/sukarth/remnote-updater/releases/tag/v2.0.1
```