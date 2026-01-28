[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](https://github.com/luminousvault/adb-extensions)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-lightgrey.svg)
![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=flat&logo=gnu-bash&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?logo=android&logoColor=white)
![Homebrew](https://img.shields.io/badge/Homebrew-supported-orange.svg?logo=homebrew)

# ADB Extensions Kit (ak)

**안드로이드 개발을 위한 필수 ADB 유틸리티**

APK 관리, 디바이스 제어, 앱 검사 등 Android Debug Bridge(ADB) 작업을 단순화하는 통합 CLI 도구입니다.

**Languages:** [🇺🇸 English](README.md) | [🇰🇷 한국어](README.ko.md)

## 주요 기능

- **통합 CLI** - 모든 ADB 작업을 하나의 명령어로 실행
- **멀티 디바이스 지원** - 여러 디바이스에 동시 APK 설치
- **인터랙티브 UI** - 키보드 탐색이 가능한 직관적인 선택 인터페이스
- **자동 복구** - 자동 에러 처리 및 복구 시도
- **탭 자동완성** - 명령어 및 옵션 Zsh 자동완성
- **풍부한 출력** - 색상 구분, 구조화된 정보 표시

## 설치

### Homebrew (권장)

```bash
brew tap luminousvault/adb-extensions
brew install ak
```

### 소스에서 설치

```bash
# 저장소 클론
git clone https://github.com/luminousvault/adb-extensions.git
cd adb-extensions

# 빌드 및 설치
./build.sh
sudo ./build.sh --install
```

## 빠른 시작

```bash
# APK 설치 (인터랙티브 선택)
ak install

# 특정 APK 설치
ak install app.apk

# 앱 정보 조회
ak info com.example.app

# 앱 실행
ak launch com.example.app

# 연결된 디바이스 목록
ak devices
```

## 사용법

### 기본 문법

```bash
ak <command> [options] [arguments...]
```

**참고:** 많은 명령어가 패키지를 지정하지 않으면 포그라운드 앱을 자동으로 감지합니다. 자세한 사용 시나리오는 [사용 예시](#사용-예시)를 참조하세요.

### 사용 가능한 명령어

#### APK 관리

| 명령어 | 설명 | 주요 옵션 |
|--------|------|-----------|
| `install [apk_files\|directories...]` | APK 파일 설치 (인터랙티브 선택 지원) | `-l` (최신), `-a` (전체), `-f <filter>` (필터), `-m` (모든 디바이스), `-r` (교체), `-t` (테스트 APK), `-d` (다운그레이드) |
| `pull [package\|filename] [filename\|package]` | 디바이스에서 APK 추출 | 순서 무관 |

#### 앱 정보

| 명령어 | 설명 | 주요 옵션 |
|--------|------|-----------|
| `info [package]` | 앱 정보 표시 (버전, SDK, 디버그 가능 여부, 설치자) | 패키지 생략 시 포그라운드 앱 자동 감지 |
| `permissions [package]` | 허용된 앱 권한 목록 | 패키지 생략 시 포그라운드 앱 자동 감지 |
| `signature [package\|apk_file]` | 앱 서명 표시 (인터랙티브 선택 지원) | - |
| `activities [--all]` | 액티비티 스택 표시 | `--all` (모든 태스크) |

#### 앱 제어

| 명령어 | 설명 | 주요 옵션 |
|--------|------|-----------|
| `launch <package>` | 앱 실행 (메인 액티비티) | - |
| `kill [packages...]` | 앱 강제 종료 | 패키지 생략 시 포그라운드 앱 자동 감지 |
| `clear [packages...]` | 앱 데이터 삭제 | 패키지 생략 시 포그라운드 앱 자동 감지 |
| `uninstall [package]` | 앱 제거 | 패키지 생략 시 포그라운드 앱 자동 감지 |

#### 디바이스 관리

| 명령어 | 설명 | 주요 옵션 |
|--------|------|-----------|
| `devices` | 연결된 디바이스 목록 (브랜드, 모델, ID, Android 버전, CPU) | - |

### 인터랙티브 UI 기능

#### APK 선택

- **방향키** (위/아래) - APK 탐색
- **Space** - 선택 토글
- **A** - 전체 선택/해제
- **숫자키** (1-9) - 빠른 선택 (단일 항목, 9개 이하 APK)
- **Enter** - 선택 확정
- **Ctrl+C** - 취소

#### 디바이스 선택

- **방향키** (위/아래) - 디바이스 탐색
- **숫자키** (1-9) - 빠른 선택 (9개 이하 디바이스)
- **Enter** - 선택 확정
- **Ctrl+C** - 취소

### 글로벌 옵션

```bash
ak --version, -v                # 버전 정보 표시
ak --help, -h                   # 도움말 표시
ak <command> --help             # 명령어별 도움말
```

## 사용 예시

### APK 설치

**현재 디렉토리에서 인터랙티브 선택:**
```bash
ak install
```

**특정 APK 설치:**
```bash
ak install app.apk
```

**최신 APK 설치:**
```bash
ak install -l
```

**최신 디버그 APK 설치:**
```bash
ak install -l -f debug
```

**모든 APK 설치:**
```bash
ak install -a
```

**필터링:**
```bash
ak install -f debug              # 현재 디렉토리
ak install -f debug /path/to/dir  # 특정 디렉토리
```

**모든 연결된 디바이스에 설치:**
```bash
ak install -m app.apk
```

**디렉토리에서 인터랙티브 선택:**
```bash
ak install /path/to/dir
```

### APK 추출

**포그라운드 앱 추출:**
```bash
ak pull
```

**포그라운드 앱을 사용자 지정 파일명으로 추출:**
```bash
ak pull myapp.apk
```

**특정 패키지 추출:**
```bash
ak pull com.example.app
```

**패키지와 파일명 지정 (순서 무관):**
```bash
ak pull com.example.app my.apk
ak pull my.apk com.example.app  # 위와 동일
```

### 앱 정보

**앱 정보 표시 (포그라운드 앱 자동 감지):**
```bash
ak info
ak info com.example.app
```

**앱 권한 목록:**
```bash
ak permissions
ak permissions com.example.app
```

**앱 서명 확인 (인터랙티브 선택):**
```bash
ak signature                   # 인터랙티브: 포그라운드 앱 + APK 파일
ak signature com.example.app   # 설치된 앱
ak signature app.apk           # 로컬 APK 파일
```

**액티비티 스택 조회:**
```bash
ak activities                   # 포그라운드 태스크
ak activities --all             # 모든 태스크
```

### 앱 제어

**앱 실행:**
```bash
ak launch com.example.app
```

**앱 종료:**
```bash
ak kill                         # 포그라운드 앱
ak kill com.app1 com.app2      # 여러 앱
```

**앱 데이터 삭제:**
```bash
ak clear                        # 포그라운드 앱
ak clear com.app1 com.app2     # 여러 앱
```

**앱 제거:**
```bash
ak uninstall                    # 포그라운드 앱 (자동 감지)
ak uninstall com.example.app
```

### 디바이스 관리

**연결된 디바이스 목록:**
```bash
ak devices
```

### 워크플로우 예시

**APK 추출 및 서명 확인:**
```bash
ak pull com.example.app
ak signature com.example.app.apk
```

**설치, 실행, 정보 조회:**
```bash
ak install app.apk
ak launch com.example.app
ak info com.example.app
```

## 버전 히스토리

자세한 버전 히스토리는 [CHANGELOG.md](CHANGELOG.md)를 참조하세요.

## 라이선스

MIT License - 자세한 내용은 [LICENSE.md](LICENSE.md)를 참조하세요.

## 작성자

Claude Hwang

## 기여하기

기여를 환영합니다! 버그 수정, 새로운 기능, 문서 개선 등 모든 기여를 감사히 받습니다.

자세한 가이드라인은 [CONTRIBUTING.md](CONTRIBUTING.md)를 참조하세요:

- 개발 환경 구축
- 프로젝트 구조
- 빌드 시스템
- 새 명령어 추가 방법
- 코드 스타일 가이드
- Pull Request 프로세스

기여자를 위한 빠른 시작:

```bash
# Fork 및 클론
git clone https://github.com/YOUR_USERNAME/adb-extensions.git
cd adb-extensions

# 변경사항 직접 테스트
./src/ak <command>

# 빌드 및 테스트
./build.sh
./build/ak <command>
```

## 감사의 말

- 최대 호환성을 위해 Bash로 제작
- 효율적인 Android 개발 워크플로우의 필요성에서 영감을 받음
- Android 개발 커뮤니티에 특별한 감사

## 지원

- **이슈**: [GitHub Issues](https://github.com/luminousvault/adb-extensions/issues)
- **토론**: [GitHub Discussions](https://github.com/luminousvault/adb-extensions/discussions)
