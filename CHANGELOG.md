# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
```