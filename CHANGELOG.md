# Changelog

모든 주요 변경 사항이 이 파일에 기록됩니다.

## [2025-12-16]

### ADB Installer (ai) v2.7.1

**UX 개선:**
- **숫자키 빠른 선택 기능 추가**
  - 1-9개 APK: 숫자 키(1-9) 입력 시 즉시 선택 및 설치
  - 10개 이상 APK: 멀티 선택 전용 (숫자키 비활성화)
  - 파워 유저의 빠른 단일 선택 지원

**UI 개선:**
- 선택 순서 번호(#1, #2) UI 제거로 깔끔한 인터페이스
- 항목 번호 표시 추가 (`[✓] 1. Item name` 형태)
- DIM 색상 추가로 안내문 가독성 개선
- 조건부 안내문 표시
  - 9개 이하: "1-N: Quick select" 가이드 표시
  - 10개 이상: "Quick select" 가이드 제거

**동작 방식:**
- 기존 기능 모두 유지 (Space, A, Enter)
- 숫자키는 기존 선택을 초기화하고 즉시 확정
- 멀티 선택이 필요하면 Space + Enter 사용

### ADB Kit (ak) v1.7.0

**새로운 명령어:**
- **activities 명령어 추가**
  - 현재 실행 중인 Activity 스택 조회
  - 포그라운드 태스크의 액티비티 스택 표시 (기본)
  - `--all` 옵션으로 모든 태스크 표시 가능
  - 전체 패키지명/액티비티명 표시로 명확한 정보 제공
  - Task별 그룹핑 및 색상 구분으로 가독성 향상

**사용 예시:**
```bash
ak activities           # 포그라운드 앱의 액티비티 스택
ak activities --all     # 모든 태스크 표시
```

**출력 형식:**
- Task ID 표시
- Current Screen 정보
- Stack 순서 (Top → Bottom)
- [#N] 형식으로 Activity 히스토리 번호 표시
- 색상 구분으로 가독성 향상

**디바이스 선택 UI 개선:**
- **인터랙티브 디바이스 선택 추가**
  - 방향키(↑/↓)로 디바이스 탐색
  - Enter 키로 선택 확정
  - 숫자키(1-9)로 빠른 선택
  - 하이브리드 선택 방식 지원

**UI 개선:**
- 기존 숫자 입력 방식을 인터랙티브 UI로 대체
- 디바이스 정보를 보면서 선택 가능
- 포커스 하이라이트 (➤ 표시)
- 항목 번호 표시 (1. 2. 3...)

**기술 세부사항:**
- `select_single_interactive` 함수 추가
- `present_device_selection` 함수 전면 개선
- `show_activities`, `parse_and_display_activities`, `parse_and_display_all_tasks` 함수 추가
- DIM, BARROW, GARROW, ERROR 색상 변수 추가
- clear 명령으로 화면 갱신

**제한사항:**
- 10개 이상 디바이스 연결 시 숫자키는 방향키로만 선택
- 실무상 10개 이상 연결은 1% 미만으로 영향 최소화

## [2025-12-12]

### ADB Installer (ai) v2.7.0 - BREAKING CHANGES

**주요 UX 개선:**
- 인터랙티브 APK 선택이 이제 기본 동작입니다
  - `ai` 실행 시 인터랙티브 APK 선택 화면 표시
  - 이전에는 `ai` 실행 시 help 출력 → 이제 `ai -h` 또는 `ai --help` 사용

**새로운 옵션:**
- `-p <pattern>` 옵션 추가 (필터링된 인터랙티브 선택)
  - 패턴 인자 필수 (예: `ai -p debug`)
  - 단일 패턴: `ai -p release`
  - 다중 패턴: `ai -p "myapp debug"`
  - 디렉토리와 함께 사용 가능: `ai -p debug /path/to/folder`

**새로운 기능:**
- 디렉토리 지정 기능 추가 (옵션 없이 자동 감지)
  - 특정 폴더 지정: `ai /path/to/folder`
  - 여러 폴더 지정: `ai /folder1 /folder2 /folder3`
  - 폴더 + 패턴: `ai -p debug /path/to/folder`
  - 폴더 + APK 파일 혼용: `ai app.apk /folder` (모두 인터랙티브 선택)
  - 모든 조합 가능: `ai /folder1 /folder2 app.apk`

**UX 개선:**
- Esc 키 종료 기능 제거 → Ctrl+C로만 종료
- APK 선택 후 디바이스 선택 화면 갱신 (clear)

**제거된 옵션:**
- `-s` 옵션 완전히 제거 (이전: `-s [pattern]`)
  - 마이그레이션: `ai -s` → `ai`
  - 마이그레이션: `ai -s pattern` → `ai -p pattern`

**동작 요약:**
- `ai` → 현재 폴더 APK 인터랙티브 선택 (새로운 기본값)
- `ai /folder` → 지정 폴더 APK 인터랙티브 선택 (NEW!)
- `ai /folder1 /folder2` → 여러 폴더 APK 모두 수집하여 인터랙티브 선택 (NEW!)
- `ai -p <pattern>` → 현재 폴더에서 패턴 필터링 (패턴 필수)
- `ai -p debug /folder` → 지정 폴더에서 패턴 필터링 (NEW!)
- `ai app.apk /folder` → APK + 폴더 APK 모두 인터랙티브 선택 (NEW!)
- `ai /folder1 app.apk /folder2` → 모든 조합 가능 (NEW!)
- `ai -l` → 최신 APK (변경 없음)
- `ai -a` → 모든 APK (변경 없음)
- `ai file.apk` → 직접 설치 (변경 없음)

**마이그레이션 가이드:**
```bash
# 이전 동작 → 새로운 동작
ai -s           →  ai
ai -s debug     →  ai -p debug
ai -s "pattern" →  ai -p "pattern"
ai              →  ai -h  (help 표시)
```

## [2025-09-09]

### ADB Kit (ak) v1.6.7
- `signature` 명령어 기능 확장
  - 로컬 APK 파일 경로 지원 추가
  - `.apk` 확장자로 끝나는 경로 입력 시 로컬 APK 파일로 자동 인식
  - 로컬 APK 파일 사용 시 ADB 디바이스 연결 불필요
  - 파일 존재 여부 검증 및 절대 경로 변환 기능
- 사용자 인터페이스 개선
  - 모든 이모티콘 제거하여 텍스트 기반 출력으로 변경
  - 오류 메시지를 `ERROR:` 접두사로 통일
  - 경고 메시지를 `WARNING:` 접두사로 통일
  - 터미널 호환성 및 가독성 향상

## [2025-01-24]

### ADB Kit (ak) v1.6.6 & ADB Installer (ai) v2.6.3
- 버전 정보 표시 기능 대폭 개선 (`--version`, `-v` 옵션)
  - Neofetch 스타일의 시각적 버전 정보 표시 도입

## [2025-06-30]

### ADB Kit (ak) v1.6.5
- 다중 패키지 처리 기능 개선
  - `kill` 명령어 개선
    - 패키지명 생략 시 현재 포그라운드 앱 자동 감지 지원
    - 여러 패키지 동시 종료 시 중복 패키지 자동 제거
    - 잘못된 패키지명이나 미설치 패키지 건너뛰기 기능
  - `clear` 명령어 개선
    - 여러 패키지의 데이터를 한 번에 삭제 가능
    - `kill` 명령어와 동일한 검증 로직 적용
    - 패키지명 생략 시 포그라운드 앱 자동 감지 유지
- 사용법 메시지 개선
  - `kill`, `clear` 명령어의 다중 패키지 지원 설명 추가
  - 일관된 사용법 표기 방식 적용
- `devices` 명령어 출력 개선
  - 이모지 아이콘을 활용한 시각적 상태 표시 (✅ 정상, 🔒 인증필요, 📴 오프라인)
  - 구조화된 2줄 형태로 디바이스 정보 표시
  - 첫 번째 줄: 브랜드/모델명 (색상 적용)
  - 두 번째 줄: ID, Android 버전, CPU 정보 (값만 볼드 처리)
- 코드 구조 및 가독성 개선
  - 주석 처리된 구버전 코드 제거
  - 변수 정의 최적화

## [2025-06-27]

### ADB Kit (ak) v1.6.4
- 앱 정보 출력 기능 개선 (`info` 명령어)
  - `minSdk` 항목 추가 - 앱의 최소 지원 SDK 버전 표시
  - `debuggable` 항목 추가 - 앱의 디버그 가능 여부 표시
  - `versionName`, `versionCode`, `installer` 항목의 공백 제거 처리 (`xargs` 추가)
  - 불필요한 정보 제거 (`firstInstallTime`, `lastUpdateTime`, `dataDir` 출력 제거)
  - 출력 정보 최적화로 핵심 정보에 집중
- 디바이스 정보 출력 개선 (`devices` 명령어)
  - CPU 아키텍처 정보 추가 (예: arm64-v8a, armeabi-v7a 등)
  - 디바이스 식별에 도움이 되는 하드웨어 정보 제공

## [2025-06-26]

### ADB Kit (ak) v1.6.3
- 앱 데이터 삭제 기능 추가 (`clear` 명령어)
  - `adb shell pm clear` 명령어를 통한 앱 데이터 및 캐시 삭제
  - 패키지명 생략 시 현재 포그라운드 앱 자동 감지
  - 성공/실패 상태 메시지 출력
  - `usage_clear_data()` 함수로 사용법 안내 제공

## [2025-06-13]

### ADB Installer (ai) v2.6.2
- APK 파일 선택 시 사용자 입력 안내 메시지 개선
  - 쉼표 구분자 표시 방식 개선
- `-s` 옵션에 패턴 검색 기능 추가
  - 단일 패턴 검색 지원 (예: `-s debug`)
  - 다중 패턴 검색 지원 (예: `-s "myapp release"`)
  - 필터링된 APK 목록 표시

### ADB Kit (ak) v1.6.2
- 디바이스 상태 표시 기능 개선
  - unauthorized와 offline 상태 처리 로직 추가
  - 디바이스 상태가 unauthorized나 offline일 경우 디바이스 ID만 표시
  - 변수명 개선 (status_color → colored_status)
- 사용자 인터페이스 개선
  - 오류 메시지 포맷팅 개선
  - 도움말 메시지 가독성 향상

### 프로젝트 관리
- `.gitignore` 파일 추가
  - IDE 관련 파일 제외 (.vscode, .cursor, .idea 등)
  - 운영체제 관련 파일 제외 (.DS_Store, Thumbs.db 등)
  - 임시 파일 및 로그 파일 제외
  - 빌드 출력물 제외
  - 환경 설정 파일 제외

## [2025-06-04]

### ADB Kit (ak) v1.6.1
- aapt를 사용한 패키지 네임 추출 버그 수정

## [2025-05-28]

### 문서
- README.md 업데이트
  - 설치 방법 및 사용법 개선
  - 예제 코드 추가

## [2025-05-27]

### ADB Installer (ai) v2.6.0
- APK 선택 인터페이스 개선
  - 사용자 친화적인 선택 방식
  - 선택된 APK 목록 표시 개선
- APK 파일 직접 지정 설치 기능
  - 옵션 없이 APK 파일 경로를 직접 지정하여 설치
  - 예: `ai app1.apk app2.apk`

### ADB Kit (ak) v1.6.0
- 앱 서명 정보 추출 기능 (`signature` 명령어)
  - SHA-256 서명 해시 추출
  - apksigner 통합
- 패키지 검증 로직 강화
  - 패키지명 형식 검증
  - 설치 여부 확인

### 설치 및 배포
- 스크립트에 `--install` 옵션 추가
  - `/usr/local/bin`에 자동 설치
  - 실행 권한 자동 설정
  - macOS 격리 속성 제거 (xattr 명령어 추가)
- 도움말 및 버전 정보 개선
  - `--version` 및 `--help` 옵션 설명 추가
  - 중복 문구 제거
  - 주석 추가로 코드 가독성 향상

## [2025-05-23]

### ADB Kit (ak) v1.6.0
- APK 관리용 ADB 유틸리티 스크립트 추가
  - pull, info, permissions, uninstall, kill, devices, launch, signature 등 명령 지원
  - packageName 생략 시 현재 포그라운드 앱 자동 사용
  - apksigner 활용한 SHA-256 서명 해시 추출 기능 포함
  - 개발자가 빠르게 앱 정보 확인 및 조작 가능하도록 구성

### ADB Installer (ai) v2.6.0
- ADB 옵션을 활용한 APK 설치 스크립트 추가
  - 현재 디렉토리에서 단일, 전체, 선택 APK 설치 지원
  - 모든 연결된 디바이스 또는 특정 디바이스 설치 옵션 제공
  - -r, -t, -d 등의 adb 설치 플래그 지원
  - .idsig 파일 존재 시 --no-incremental 옵션 자동 적용

### 문서
- README 개선
  - 설치 방법 및 사용법 상세화
  - 예제 코드 추가
- MIT License 추가 