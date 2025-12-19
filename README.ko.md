[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/luminousvault/adb-extensions)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)
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

또는 tap 없이 직접 설치:

```bash
brew install https://raw.githubusercontent.com/luminousvault/adb-extensions/main/Formula/ak.rb
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
# APK 설치
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

### 사용 가능한 명령어

#### APK 관리

**install** - APK 파일 설치

```bash
ak install [options] [apk_files...]

# 예시
ak install app.apk              # 단일 APK 설치
ak install -l                   # 최신 APK 설치
ak install -a                   # 모든 APK 설치
ak install -p debug             # 패턴으로 필터링
ak install -m app.apk           # 모든 디바이스에 설치
```

옵션:
- `-l` - 최신 APK 파일 설치
- `-a` - 모든 APK 파일 설치
- `-p <pattern>` - 패턴으로 APK 필터링
- `-m` - 모든 연결된 디바이스에 설치
- `-r` - 기존 앱 교체 (기본값)
- `-t` - 테스트 APK 허용
- `-d` - 버전 다운그레이드 허용

**pull** - 디바이스에서 APK 추출

```bash
ak pull [package|filename] [filename|package]

# 예시 (순서 무관)
ak pull                         # 포그라운드 앱 추출
ak pull myapp.apk               # 포그라운드 앱을 myapp.apk로 추출
ak pull com.example.app         # 특정 패키지 추출
ak pull com.example.app my.apk  # 패키지와 파일명 지정
ak pull my.apk com.example.app  # 위와 동일 (순서 무관)
```

#### 앱 정보

**info** - 앱 정보 표시

```bash
ak info [package]

# 표시 내용: 버전, SDK 정보, 디버그 가능 여부, 설치자
```

**permissions** - 앱 권한 목록

```bash
ak permissions [package]

# 허용된 권한 표시
```

**signature** - 앱 서명 표시

```bash
ak signature [package|apk_file]

# 예시
ak signature com.example.app    # 설치된 앱 확인
ak signature app.apk            # 로컬 APK 파일 확인
```

**activities** - 액티비티 스택 표시

```bash
ak activities [--all]

# 예시
ak activities                   # 포그라운드 태스크 액티비티
ak activities --all             # 모든 태스크 액티비티
```

#### 앱 제어

**launch** - 앱 실행

```bash
ak launch <package>

# 메인 액티비티 실행
```

**kill** - 앱 강제 종료

```bash
ak kill [packages...]

# 예시
ak kill                         # 포그라운드 앱 종료
ak kill com.app1 com.app2      # 여러 앱 종료
```

**clear** - 앱 데이터 삭제

```bash
ak clear [packages...]

# 예시
ak clear                        # 포그라운드 앱 데이터 삭제
ak clear com.app1 com.app2     # 여러 앱 데이터 삭제
```

**uninstall** - 앱 제거

```bash
ak uninstall [package]

# 패키지를 지정하지 않으면 인터랙티브 선택
```

#### 디바이스 관리

**devices** - 연결된 디바이스 목록

```bash
ak devices

# 표시 내용: 브랜드, 모델, ID, Android 버전, CPU 아키텍처
```

### 글로벌 옵션

```bash
ak --version, -v                # 버전 정보 표시
ak --help, -h                   # 도움말 표시
ak <command> --help             # 명령어별 도움말
```

## 인터랙티브 UI 기능

### APK 선택

- **방향키** (위/아래) - APK 탐색
- **Space** - 선택 토글
- **A** - 전체 선택/해제
- **숫자키** (1-9) - 빠른 선택 (단일 항목, 9개 이하 APK)
- **Enter** - 선택 확정
- **Ctrl+C** - 취소

### 디바이스 선택

- **방향키** (위/아래) - 디바이스 탐색
- **숫자키** (1-9) - 빠른 선택 (9개 이하 디바이스)
- **Enter** - 선택 확정
- **Ctrl+C** - 취소

## 사용 예시

### 최신 디버그 APK 설치

```bash
ak install -l -p debug
```

### 모든 디바이스에 설치

```bash
ak install -m app.apk
```

### APK 추출 및 서명 확인

```bash
ak pull com.example.app
ak signature com.example.app.apk
```

### 여러 앱 종료

```bash
ak kill com.app1 com.app2 com.app3
```

### 액티비티 스택 조회

```bash
ak activities --all
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
