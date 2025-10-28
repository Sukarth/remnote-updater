# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

### Documentation
- Comprehensive README with quick start guide
- Troubleshooting section
- Auto-start setup instructions for Task Scheduler and Startup folder
- Contributing guidelines
- MIT License

## [Unreleased]

### Planned
- Silent installation mode (no popups)
- Email/notification support when updates are available
- Update scheduling (e.g., only update at specific times)
- Support for Mac/Linux versions
- GUI configuration tool
- Update history tracking

---

[1.0.0]: https://github.com/sukarth/remnote-updater/releases/tag/v1.0.0
