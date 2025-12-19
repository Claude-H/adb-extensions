[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/luminousvault/adb-extensions)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)
![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=flat&logo=gnu-bash&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?logo=android&logoColor=white)
![Homebrew](https://img.shields.io/badge/Homebrew-supported-orange.svg?logo=homebrew)

# ADB Extensions Kit (ak)

**Essential ADB utilities for Android development**

A unified CLI tool that simplifies Android Debug Bridge (ADB) operations including APK management, device control, and app inspection.

**Languages:** [🇺🇸 English](README.md) | [🇰🇷 한국어](README.ko.md)

## Features

- **Unified CLI** - Single command for all ADB operations
- **Multi-device Support** - Install APKs to multiple devices simultaneously
- **Interactive UI** - Intuitive selection interface with keyboard navigation
- **Auto Recovery** - Automatic error handling and recovery attempts
- **Tab Completion** - Zsh completion for commands and options
- **Rich Output** - Color-coded, structured information display

## Installation

### Homebrew (Recommended)

```bash
brew tap luminousvault/ak
brew install ak
```

### From Source

```bash
# Clone repository
git clone https://github.com/luminousvault/adb-extensions.git
cd adb-extensions

# Build and install
./build.sh
sudo ./build.sh --install
```

## Quick Start

```bash
# Install APK
ak install app.apk

# Get app information
ak info com.example.app

# Launch app
ak launch com.example.app

# View connected devices
ak devices
```

## Usage

### Basic Syntax

```bash
ak <command> [options] [arguments...]
```

### Available Commands

#### APK Management

**install** - Install APK files

```bash
ak install [options] [apk_files...]

# Examples
ak install app.apk              # Install single APK
ak install -l                   # Install latest APK
ak install -a                   # Install all APKs
ak install -p debug             # Filter by pattern
ak install -m app.apk           # Install to all devices
```

Options:
- `-l` - Install latest APK file
- `-a` - Install all APK files
- `-p <pattern>` - Filter APKs by pattern
- `-m` - Install to all connected devices
- `-r` - Replace existing app (default)
- `-t` - Allow test APKs
- `-d` - Allow version downgrade

**pull** - Extract APK from device

```bash
ak pull [package|filename] [filename|package]

# Examples (order is flexible)
ak pull                         # Extract foreground app
ak pull myapp.apk               # Extract foreground app as myapp.apk
ak pull com.example.app         # Extract specific package
ak pull com.example.app my.apk  # Specify package and filename
ak pull my.apk com.example.app  # Same as above (order flexible)
```

#### App Information

**info** - Display app information

```bash
ak info [package]

# Shows: version, SDK info, debuggable status, installer
```

**permissions** - List app permissions

```bash
ak permissions [package]

# Shows granted permissions
```

**signature** - Display app signature

```bash
ak signature [package|apk_file]

# Examples
ak signature com.example.app    # Check installed app
ak signature app.apk            # Check local APK file
```

**activities** - Display activity stack

```bash
ak activities [--all]

# Examples
ak activities                   # Foreground task activities
ak activities --all             # All task activities
```

#### App Control

**launch** - Launch app

```bash
ak launch <package>

# Launches main activity
```

**kill** - Force stop app

```bash
ak kill [packages...]

# Examples
ak kill                         # Kill foreground app
ak kill com.app1 com.app2      # Kill multiple apps
```

**clear** - Clear app data

```bash
ak clear [packages...]

# Examples
ak clear                        # Clear foreground app data
ak clear com.app1 com.app2     # Clear multiple apps data
```

**uninstall** - Uninstall app

```bash
ak uninstall [package]

# Interactive selection if no package specified
```

#### Device Management

**devices** - List connected devices

```bash
ak devices

# Shows: brand, model, ID, Android version, CPU architecture
```

### Global Options

```bash
ak --version, -v                # Show version information
ak --help, -h                   # Show help message
ak <command> --help             # Show command-specific help
```

## Interactive UI Features

### APK Selection

- **Arrow keys** (Up/Down) - Navigate through APKs
- **Space** - Toggle selection
- **A** - Select/deselect all
- **Number keys** (1-9) - Quick select (single item, 9 or fewer APKs)
- **Enter** - Confirm selection
- **Ctrl+C** - Cancel

### Device Selection

- **Arrow keys** (Up/Down) - Navigate through devices
- **Number keys** (1-9) - Quick select (9 or fewer devices)
- **Enter** - Confirm selection
- **Ctrl+C** - Cancel

## Examples

### Install Latest Debug APK

```bash
ak install -l -p debug
```

### Install to All Devices

```bash
ak install -m app.apk
```

### Extract and Check Signature

```bash
ak pull com.example.app
ak signature com.example.app.apk
```

### Kill Multiple Apps

```bash
ak kill com.app1 com.app2 com.app3
```

### View Activity Stack

```bash
ak activities --all
```

## Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

## License

MIT License - See [LICENSE.md](LICENSE.md) for details.

## Author

Claude Hwang

## Contributing

Contributions are welcome! We appreciate bug fixes, new features, documentation improvements, and more.

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on:

- Development setup
- Project structure
- Build system
- Adding new commands
- Code style guidelines
- Pull request process

Quick start for contributors:

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/adb-extensions.git
cd adb-extensions

# Test changes directly
./src/ak <command>

# Build and test
./build.sh
./build/ak <command>
```

## Acknowledgments

- Built with Bash for maximum compatibility
- Inspired by the need for efficient Android development workflows
- Special thanks to the Android development community

## Support

- **Issues**: [GitHub Issues](https://github.com/luminousvault/adb-extensions/issues)
- **Discussions**: [GitHub Discussions](https://github.com/luminousvault/adb-extensions/discussions)
