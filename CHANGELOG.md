# Changelog

All notable changes to this project will be documented in this file.

## [1.1.3] - 2025-12-31

### Improved
- Code quality improvements
  - Fixed all 61 ShellCheck lint warnings across the codebase
  - Separated variable declarations and assignments to prevent exit code masking
  - Added shellcheck directives for variables used across modules
  - Enhanced code maintainability and error handling
- Build process optimization
  - Debug logging code automatically removed from production builds
  - Debug functions remain available in development source files
  - Cleaner production code without development overhead

## [1.1.2] - 2025-12-31

### Fixed
- Multi-selection state preserved correctly after sorting
  - Fixed incorrect index mapping when toggling sort order
  - Selection status now properly maintained across sort mode changes
- Display numbers now show sequential order (1, 2, 3...) after sorting
  - Fixed display index calculation to reflect current sort order
  - Previously showed original indices causing non-sequential numbering

## [1.1.1] - 2025-12-31

### Changed
- Interactive UI selection key changed from Tab to Space
  - More intuitive key binding aligned with common UI patterns
  - Updated help text to reflect new key binding

### Improved
- APK path extraction function (`get_apk_path` → `get_apk_path_for_package`)
  - Renamed for clarity: explicitly indicates package-to-APK-path resolution
  - Switched from `pm list packages -f` to `pm path` for better reliability

### Fixed
- Filter mode rendering bug when moving cursor left/right during search
  - Cursor position now properly maintained during filter input
- Filter box position not fixed during search in filter mode
  - Filter box now remains stable at its designated position
- Signature extraction failure on certain APKs with different signing schemes
  - Implemented automatic fallback mechanism for apksigner verify
  - First attempts without options (compatible with v2/v3 signature APKs)
  - Retries with --min-sdk-version 21 if signature info not extracted (compatible with legacy MD5 signature APKs)
  - Supports both modern and legacy APK signing methods

## [1.1.0] - 2025-12-30

### Added
- Interactive UI for signature command
  - Lists foreground apps from all connected devices with device info
  - Lists APK files in current directory
  - Arrow keys and number keys for quick selection
  - Multi-device support
- Filtering feature (`/` key)
  - Real-time incremental search with highlight
  - Case-insensitive matching
  - Bracketed paste mode for safe clipboard input
- Sorting feature (`S` key)
  - Toggle between original/time-newest/name-ascending order
  - Dynamic status display in help text
- Debug logging system
  - Detailed event logging with timestamps
  - Source file and line number tracking

### Improved
- Interactive UI help text
  - Condensed from 2 lines to 1 line with pipe separators
  - Color-highlighted keys (cyan) for better visibility
  - Semantic labels: "select" (single) vs "confirm" (multi)
- Filtering performance
  - Pre-computed lowercase transformations
  - Optimized highlight computation
  - Separated into dedicated `filter.sh` module
- Scrolling window for long lists
  - Auto-adjusts to terminal height
  - SIGWINCH handler for instant resize response
  - Position indicator (e.g., "Showing 5-15 / 30")

### Changed
- `detect_foreground_package()` now accepts optional device_id parameter
- Added `get_apk_list()` function for APK file management

### Fixed
- UI content preservation when exiting interactive mode
  - Proper cursor positioning before alternate screen exit
- Terminal size validation
  - Minimum 15 lines required with clear error message
  - Graceful degradation for small terminals

## [1.0.3] - 2025-12-22

### Fixed
- Fixed ADB and Android SDK detection when only platform-tools is installed via Homebrew
- Improved error messages for missing Android tools with installation guide

### Changed
- Release workflow now requires CHANGELOG entry (fails if missing)

## [1.0.2] - 2025-12-19

### Changed
- Switched from shc binary to shell script distribution for cross-platform compatibility
- Removed shc dependency from build process
- Supports all Unix-like systems (macOS, Linux, WSL) with single distribution

### Fixed
- Resolved file permission issues during Homebrew installation
- Fixed platform-specific binary execution errors

## [1.0.1] - 2025-12-19

### Fixed
- Homebrew installation failure due to missing build artifacts
- Included prebuilt files in release archive

## [1.0.0] - 2025-12-19

### First Public Release

**Core Features:**
- APK management: install, pull
- App information: info, permissions, signature, activities
- App control: launch, kill, clear, uninstall
- Device management: devices

**Architecture:**
- Modular source structure (src/lib/)
- Build system (single file merge)
- Binary compilation support (shc)
- Zsh completion support

**Installation:**
- Homebrew support
- Source build support
