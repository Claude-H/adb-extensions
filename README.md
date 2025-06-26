# Android APK Toolkit

ADB 기반으로 Android 앱을 설치하거나 정보를 관리할 수 있는 전문가용 셸 도구입니다.  
**`ai`** (APK Installer)와 **`ak`** (APK Toolkit) 두 개의 명령어로 ADB를 훨씬 더 효율적으로 사용할 수 있습니다.

---

## 설치 방법

`ai.sh`와 `ak.sh` 스크립트는 `--install` 옵션을 지원합니다. 이 옵션을 사용하면 스크립트를 자동으로 `/usr/local/bin`에 복사하고 실행 권한을 부여하며, macOS의 격리 해제도 함께 처리합니다.

```bash
git clone https://github.com/Claude-H/adb-extensions.git
sudo ./ai.sh --install
sudo ./ak.sh --install
```

설치가 완료되면 터미널에서 `ai` 또는 `ak` 명령어를 바로 사용할 수 있습니다.

> 만약 실행 권한 문제가 있거나 macOS에서 다운로드한 스크립트가 격리되어 실행되지 않을 경우, `--install` 옵션을 이용하면 자동으로 해결됩니다.

---

## 주요 기능

### `ai` - APK 설치 도구 (APK Installer)

- 최신 APK, 전체 APK, 선택 APK 설치 지원
- 여러 기기 대상 설치 가능
- `--no-incremental` 자동 적용 (.idsig 파일 존재 시)
- ADB 설치 옵션: `-r`, `-t`, `-d` 지원
- APK 파일 필터링 기능 (`-s` 옵션)
  - 단일 패턴: `-s debug`
  - 다중 패턴: `-s "myapp release"`
- APK 파일 직접 지정 설치
  - 옵션 없이 APK 파일 경로를 직접 지정하여 설치
  - 예: `ai app1.apk app2.apk`

### `ak` - APK 관리 도구 (APK Toolkit)

- APK 추출, 정보 조회, 권한 목록 확인
- 앱 제거, 강제 종료, 실행
- 디바이스 목록 출력
- SHA-256 서명 해시 추출 (apksigner 사용)

---

## 사용법

### `ai` (APK 설치)

```bash
ai [옵션] [apk파일...]
```

#### 일반 옵션

| 옵션            | 설명                                |
|-----------------|-------------------------------------|
| `-v`, `--version` | 스크립트 버전 출력                   |
| `-h`, `--help`    | 도움말 출력                         |

#### APK 선택 옵션 (서로 배타적)

| 옵션 | 설명                                      |
|------|-------------------------------------------|
| `-l` | 현재 디렉토리에서 가장 최신 APK 설치         |
| `-a` | 현재 디렉토리의 모든 APK 설치                |
| `-s [pattern]` | 설치할 APK를 사용자에게 선택하도록 인터랙티브 제공<br>- 단일 패턴: `-s debug`<br>- 다중 패턴: `-s "myapp release"` |
| (없음) | 지정한 APK 파일들을 직접 설치<br>예: `ai app1.apk app2.apk` |

#### 디바이스 옵션

| 옵션 | 설명                                      |
|------|-------------------------------------------|
| `-m` | 연결된 모든 디바이스에 APK 설치             |

#### ADB 설치 옵션

| 옵션 | 설명                                                  |
|------|-------------------------------------------------------|
| `-r` | 기존 앱 덮어쓰기 설치 (`adb install -r`, 기본값)     |
| `-t` | 테스트 APK 설치 허용                                  |
| `-d` | 버전 코드 다운그레이드 허용 (패키지 매니저 권한 필요) |

> `.idsig` 파일이 APK와 함께 있으면 `--no-incremental` 옵션이 자동으로 추가됩니다.

#### 설치 실패 시 동작 안내

> 설치 중 실패가 발생하면 -t, -d 옵션을 활용해 재시도하며, 필요한 경우 기존 앱을 삭제 후 재설치하는 절차를 안내합니다.
> 이 과정에서 앱 데이터 삭제 위험에 대한 경고 메시지를 보여줍니다.

#### 사용 예시

```bash
# 지정한 APK 파일들을 직접 설치
ai app1.apk app2.apk

# 최신 APK를 모든 기기에 설치
ai -l -m

# 디버그 버전 APK 선택하여 설치
ai -s debug

# 특정 앱의 릴리즈 버전 선택하여 설치
ai -s "myapp release"
```

---

### `ak` (APK 유틸리티)

```bash
ak <명령어> [패키지명] [추가 인자...]
```

#### 일반 옵션

| 옵션            | 설명                                |
|-----------------|-------------------------------------|
| `-v`, `--version` | 스크립트 버전 출력                   |
| `-h`, `--help`    | 도움말 출력                         |

#### 명령어 목록

| 명령어        | 사용 예시 | 설명 |
|---------------|-----------|------|
| `pull`        | `ak pull [packageName] [outputFile]` | 지정한 앱의 APK 파일을 로컬로 저장합니다. 출력 파일명을 생략하면 `[packageName].apk`로 저장됩니다. |
| `info`        | `ak info [packageName]` | 앱의 버전, 설치 시점, 데이터 경로 등 핵심 정보를 조회합니다. |
| `permissions` | `ak permissions [packageName]` | 앱이 요청한 권한 목록을 출력합니다. |
| `uninstall`   | `ak uninstall [packageName]` | 앱을 디바이스에서 제거합니다. |
| `clear`       | `ak clear [packageName]` | 앱의 데이터와 캐시를 삭제합니다. |
| `kill`        | `ak kill <packageName1> [packageName2 ...]` | 하나 이상의 앱 프로세스를 강제 종료합니다. 첫 번째 패키지명은 필수이며, 이후는 선택적으로 추가할 수 있습니다. |
| `devices`     | `ak devices` | 연결된 디바이스 목록과 상태 정보를 출력합니다. |
| `launch`      | `ak launch [packageName]` | 앱의 런처 액티비티를 실행합니다. |
| `signature`   | `ak signature [packageName]` | 앱의 SHA-256 서명 해시를 출력합니다. `ANDROID_HOME` 환경 변수가 설정되어 있어야 합니다. |

> `[packageName]`을 생략하면 현재 포그라운드 앱 기준으로 동작합니다.

#### 사용 예시

```bash
# APK 추출 관련
ak pull                                    # 포그라운드 앱의 APK 추출
ak pull com.example.app                    # 특정 앱의 APK 추출
ak pull com.example.app myapp.apk          # 특정 파일명으로 APK 추출

# 앱 정보 조회
ak info                                    # 포그라운드 앱의 상세 정보
ak info com.android.settings               # 설정 앱의 정보 조회
ak signature com.example.app               # SHA-256 서명 해시 출력

# 권한 관리
ak permissions                             # 포그라운드 앱의 권한 목록
ak permissions com.android.chrome          # Chrome 앱의 권한 목록

# 앱 데이터 관리
ak clear                                   # 포그라운드 앱의 데이터 삭제
ak clear com.example.app                   # 특정 앱의 데이터 삭제
ak uninstall                               # 포그라운드 앱 제거
ak uninstall com.example.testapp           # 테스트 앱 제거

# 앱 프로세스 관리
ak kill com.example.app                    # 특정 앱 강제 종료
ak kill com.app1 com.app2 com.app3         # 여러 앱 동시 강제 종료
ak launch com.android.settings             # 설정 앱 실행

# 디바이스 관리
ak devices                                 # 연결된 디바이스 목록 확인
```

---

## 요구 사항

- Android SDK의 `adb` 도구
- 서명 해시 추출에는 `apksigner` 필요
- 일부 명령은 `ANDROID_HOME` 환경 변수 설정 필수

---

## License

This project is licensed under the MIT License.

© 2025 Cladue Hwang

For more details, see the [LICENSE.md](./LICENSE.md) file.

## 변경 이력
자세한 변경 이력은 [CHANGELOG.md](CHANGELOG.md)를 참조하세요.