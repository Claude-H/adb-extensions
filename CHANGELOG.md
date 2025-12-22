# Changelog

All notable changes to this project will be documented in this file.

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
