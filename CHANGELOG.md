# Changelog

모든 주요 변경 사항이 이 파일에 기록됩니다.

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

## [1.0.0]

### 첫 공개 릴리스

**핵심 기능:**
- APK 관리: install, pull
- 앱 정보: info, permissions, signature, activities
- 앱 제어: launch, kill, clear, uninstall
- 디바이스 관리: devices

**아키텍처:**
- 모듈형 소스 구조 (src/lib/)
- 빌드 시스템 (단일 파일 병합)
- 바이너리 컴파일 지원 (shc)
- Zsh 자동완성

**설치 방법:**
- Homebrew 지원
- 소스 빌드 지원
