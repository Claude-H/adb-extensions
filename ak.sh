#!/bin/bash

# ─────────────────────────────────────────────────────────────────────────────
# ADB Kit (ak)
# ADB를 활용하여 안드로이드 디바이스에서 APK 추출, 버전 조회, 권한 확인,
#    앱 종료 및 실행 등을 지원하는 CLI 도구입니다.
#
# 🧑‍💻 작성자: Claude Hwnag
# ─────────────────────────────────────────────────────────────────────────────

VERSION="1.6.6"
RELEASE_DATE="2025-07-02"

# 색상 및 스타일 정의
RED='\033[1;31m' # 빨간색
GREEN='\033[1;32m' # 초록색
YELLOW='\033[1;33m' # 노란색
BLUE='\033[1;34m' # 파란색
PURPLE='\033[1;35m' # 보라색
CYAN='\033[1;36m' # 볼드와 옥색
BOLD='\033[1m' # 볼드
NC='\033[0m' # 색상 없음

# 현재 포그라운드 앱의 패키지명을 ADB를 통해 추출
detect_foreground_package() {
    adb -s "$G_SELECTED_DEVICE" shell dumpsys activity activities | grep -i Hist | head -n 1 | sed -n 's/.* u0 \([^\/ ]*\)\/.*/\1/p'
}

# 패키지 이름 형식이 유효한지 확인
validate_package_name() {
    local pkg="$1"
    [[ "$pkg" =~ ^[a-zA-Z0-9_]+(\.[a-zA-Z0-9_]+)+$ ]]
}

# 패키지 설치 여부 확인
is_package_installed() {
    local package_name="$1"
    adb -s "$G_SELECTED_DEVICE" shell pm list packages --user 0 | grep -q "^package:$package_name$"
    return $?
}

# 패키지명 형식과 설치 여부를 확인하고 실패 시 종료
validate_package_or_exit() {
    local package_name="$1"
    if ! validate_package_name "$package_name"; then
        echo -e "${RED}❌ Invalid package name format:${NC} $package_name"
        echo
        exit 1
    fi
    if ! is_package_installed "$package_name"; then
        echo -e "${RED}❌ Package not installed on the device:${NC} $package_name"
        echo
        exit 1
    fi
}

# 지정한 패키지의 base.apk 경로를 추출하여 반환합니다. 실패 시 1을 반환
get_apk_path() {
    local package_name=$1
    local apk_path
    apk_path=$(adb -s "$G_SELECTED_DEVICE" shell pm list packages -f --user 0 | grep -x "package:.*=$package_name")

    if [ -z "$apk_path" ]; then
        echo -e "${RED}❌ Package not found:${NC} $package_name"
        echo
        return 1
    fi

    apk_path=$(echo "$apk_path" | sed -n 's/package:\(.*base\.apk\)=.*/\1/p')

    if [ -z "$apk_path" ]; then
        echo -e "${RED}❌ Failed to extract APK path for package:${NC} $package_name"
        echo
        return 1
    fi

    echo "$apk_path"
}

# 목록에서 중복 확인
contains() {
    local value="$1"
    shift
    local item
    for item in "$@"; do
        if [ "$item" == "$value" ]; then
            return 0
        fi
    done
    return 1
}

show_version() {
  local script_name=$(basename "$0")
  local adb_version=$(adb version 2>/dev/null | head -n 1 | awk '{print $5}' || echo "Not found")
  
  
  echo
  
  echo -e "        ${GREEN}::${NC}                   ${GREEN}.::${NC}        ${BOLD}${script_name}${NC} ${GREEN}${VERSION}${NC} - Released on ${RELEASE_DATE}"
  echo -e "       ${GREEN}:#*+.${NC}                ${GREEN}:+*#.${NC}       ------------------------------------"
  echo -e "        ${GREEN}:**+:${NC}    ${GREEN}......${NC}    ${GREEN}-+**.${NC}        ${BOLD}${YELLOW}ADB Version:${NC} ${adb_version}"
  echo -e "         ${GREEN}.*+=---::::::::---+*+${NC}          ${BOLD}${YELLOW}Author:${NC} Claude Hwang"
  echo -e "        ${YELLOW}:-=----:--------:---==-.${NC}        ${BOLD}${YELLOW}License:${NC} MIT"
  echo -e "      ${YELLOW}:++=---==============---=+=.${NC}      ${BOLD}${YELLOW}Language:${NC} Bash"
  echo -e "    ${RED}.+*+=+*%#++++++++++++++##+=+**-${NC}     ${BOLD}${YELLOW}Supported OS:${NC} macOS, Linux"
  echo -e "   ${RED}.****+%@@%+++++++++++++*@@@#+**#+${NC}    ${BOLD}${YELLOW}Dependencies:${NC} adb, apksigner"
  echo -e "   ${CYAN}*#*****#*+++++++++++++++*##*****#=${NC}   ${BOLD}${YELLOW}Repository:${NC} https://github.com/Claude-H/adb-extensions"
  echo -e "  ${BLUE}-%#*****++++++++++++++++++++****##%.${NC}  "
  echo -e "                                        ${BOLD}${YELLOW}Purpose:${NC} ADB toolkit for Android development"
  echo -e "                                        ${BOLD}${YELLOW}Features:${NC} Device management, App control, APK tools"
  echo
}

# 사용법 출력 함수
usage() {
    echo
    echo -e "${CYAN}${BOLD}Usage:${NC} $0 <command> [arguments...]"
    echo
    echo -e "${BOLD}Script Version:${NC}"
    echo -e "  Current Version: $VERSION"
    echo
    echo -e "${CYAN}${BOLD}Commands:${NC}"
    echo -e "  ${BOLD}pull${NC} [packageName] [saveApkFileName]"
    echo -e "      Pull the APK of the specified package."
    echo -e "      If packageName is omitted, uses the current foreground app."
    echo
    echo -e "  ${BOLD}info${NC} [packageName]"
    echo -e "      Show detailed information of the package (version, SDK, install time, etc.)."
    echo -e "      If packageName is omitted, uses the current foreground app."
    echo
    echo -e "  ${BOLD}permissions${NC} [packageName]"
    echo -e "      List permissions required by the specified package."
    echo -e "      If packageName is omitted, uses the current foreground app."
    echo
    echo -e "  ${BOLD}uninstall${NC} [packageName]"
    echo -e "      Uninstall the specified package."
    echo -e "      If packageName is omitted, uses the current foreground app."
    echo
    echo -e "  ${BOLD}clear${NC} [packageName1] [packageName2 ...]"
    echo -e "      Clear app data and cache for one or more specified packages."
    echo -e "      If no packageName is provided, uses the current foreground app."
    echo
    echo -e "  ${BOLD}kill${NC} [packageName1] [packageName2 ...]"
    echo -e "      Force-stop one or more specified packages."
    echo -e "      If no packageName is provided, uses the current foreground app."
    echo
    echo -e "  ${BOLD}devices${NC}"
    echo -e "      Show connected device list with model and Android version."
    echo
    echo -e "  ${BOLD}launch${NC} <packageName>"
    echo -e "      Launch the specified package using its launcher activity."
    echo
    echo -e "  ${BOLD}signature${NC} [packageName]"
    echo -e "      Extract SHA-256 signature hash of the app using apksigner."
    echo -e "      Requires APK pull and ANDROID_HOME to be set."
    echo -e "      If packageName is omitted, uses the current foreground app."
    echo
    echo -e "${CYAN}${BOLD}Options:${NC}"
    echo -e "  ${BOLD}--install${NC}"
    echo -e "      Install this script to /usr/local/bin with executable permission."
    echo -e "      Also removes macOS quarantine attributes using xattr."
    echo -e "      Recommended usage: ${BOLD}sudo ./ak.sh --install${NC}"
    echo
    echo -e "  ${BOLD}--version${NC}, ${BOLD}-v${NC}"
    echo -e "      Display the script version and release date."
    echo
    echo -e "  ${BOLD}--help${NC}, ${BOLD}-h${NC}"
    echo -e "      Show this help message and usage guide."
    echo
}

# ═══════════════════════════════════════════════════════════════════════════════
# PULL 커맨드 - APK 파일 추출
# ═══════════════════════════════════════════════════════════════════════════════

# pull 커맨드 사용법 출력 함수
usage_pull() {
    echo -e "${CYAN}${BOLD}Usage:${NC} $0 pull [packageName] [saveApkFileName]"
    echo
    echo "Description: Pull the APK file of the specified package to local storage."
    echo "If 'packageName' is not provided, the script will auto-detect the current foreground app."
    echo "If 'saveApkFileName' is not provided, the APK will be saved as '<packageName>.apk'."
    echo
    exit 1
}

# pull 커맨드 함수
pull_apk() {
    local package_name=$1
    local save_apk_file_name=$2

    echo    
    if [ -z "$package_name" ]; then
        package_name=$(detect_foreground_package)
        echo -e "${YELLOW}🔍 Auto-detected package:${NC} $package_name"
    else
        echo -e "${BLUE}✅ Using specified package:${NC} $package_name"
    fi
    
    echo
    validate_package_or_exit "$package_name"
    # save_apk_file_name이 null이거나 빈 문자열인 경우 기본 파일명 설정
    if [ -z "$save_apk_file_name" ]; then
        save_apk_file_name="${package_name}.apk"
    # save_apk_file_name이 주어졌지만 확장자가 .apk가 아닌 경우 확장자 추가
    elif [[ "$save_apk_file_name" != *.apk ]]; then
        save_apk_file_name="${save_apk_file_name}.apk"
    fi

    # 패키지 경로 찾기
    local apk_path
    apk_path=$(get_apk_path "$package_name") || exit 1
    
    # APK 파일 가져오기
    adb -s "$G_SELECTED_DEVICE" pull "$apk_path" "$save_apk_file_name"
    if [ $? -ne 0 ]; then
        echo
        echo -e "${RED}❌ Failed to pull APK from device. Check device connection and permissions.${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ APK file saved as:${NC} $save_apk_file_name"
}

# ═══════════════════════════════════════════════════════════════════════════════
# INFO 커맨드 - 앱 정보 조회
# ═══════════════════════════════════════════════════════════════════════════════

# info 커맨드 사용법 출력 함수
usage_appinfo() {
    echo -e "${CYAN}${BOLD}Usage:${NC} $0 info [packageName]"
    echo
    echo "Description: Show detailed information of the package (version, SDK, debuggable, etc.)."
    echo "If 'packageName' is not provided, the script will auto-detect the current foreground app."
    echo
    exit 1
}

# appinfo 커맨드 함수
get_app_info() {
    local package_name=$1
    local version_name version_code target_sdk min_sdk debuggable installer

    echo
    if [ -z "$package_name" ]; then
        package_name=$(detect_foreground_package)
        echo -e "${YELLOW}🔍 Auto-detected package:${NC} $package_name"
    else
        echo -e "${BLUE}✅ Using specified package:${NC} $package_name"
    fi
    
    echo
    validate_package_or_exit "$package_name"

    local dumpsys_output
    dumpsys_output=$(adb -s "$G_SELECTED_DEVICE" shell dumpsys package "$package_name")

    version_name=$(echo "$dumpsys_output" | grep versionName | head -n 1 | cut -d'=' -f2 | xargs)
    version_code=$(echo "$dumpsys_output" | grep versionCode | head -n 1 | awk '{print $1}' | cut -d'=' -f2 | xargs)
    min_sdk=$(echo "$dumpsys_output" | grep "minSdk=" | head -n 1 | sed -n 's/.*minSdk=\([0-9]*\).*/\1/p')
    target_sdk=$(echo "$dumpsys_output" | grep "targetSdk=" | head -n 1 | sed -n 's/.*targetSdk=\([0-9]*\).*/\1/p')
    debuggable=$(echo "$dumpsys_output" | grep -i "flags=\[" | grep -q "DEBUGGABLE" && echo true || echo false)
    installer=$(echo "$dumpsys_output" | grep installerPackageName | head -n 1 | cut -d'=' -f2 | xargs)
    

    # 필수 필드 중 하나라도 누락 시 오류
    if [ -z "$version_name" ] || [ -z "$version_code" ] || [ -z "$target_sdk" ]; then
        echo -e "${RED}❌ Critical app info missing for package:${NC} $package_name"
        echo -e "${RED}  ==> versionName, versionCode, or targetSdk could not be retrieved.${NC}"
        echo
        exit 1
    fi

    echo -e "${CYAN}APK Detailed Info:${NC}"
    echo -e "  ${GREEN}versionName:${NC} ${version_name}"
    echo -e "  ${GREEN}versionCode:${NC} ${version_code}"
    echo -e "  ${GREEN}minSdk:${NC} ${min_sdk}"
    echo -e "  ${GREEN}targetSdk:${NC} ${target_sdk}"
    echo -e "  ${GREEN}debuggable:${NC} ${debuggable}"
    echo -e "  ${GREEN}installerPackageName:${NC} ${installer:-${YELLOW}(not available)${NC}}"
    echo
}

# ═══════════════════════════════════════════════════════════════════════════════
# SIGNATURE 커맨드 - 앱 서명 정보 추출
# ═══════════════════════════════════════════════════════════════════════════════

# signature 커맨드 사용법 출력 함수
usage_signature() {
    echo -e "${CYAN}${BOLD}Usage:${NC} $0 signature [packageName]"
    echo
    echo "Description: Pull the APK of the specified package, extract the SHA-256"
    echo "certificate digest using apksigner, then remove the temporary APK file."
    echo "ANDROID_HOME must be set and contain valid build-tools with apksigner."
    echo "If 'packageName' is not provided, the script will auto-detect the current foreground app."
    echo
    exit 1
}

# signature 커맨드 함수 - APK 추출 후 apksigner로 SHA-256 서명 해시 추출
get_signature_info() {
    local package_name=$1
    local tmp_apk apk_path apksigner signature_output

    echo
    if [ -z "$package_name" ]; then
        package_name=$(detect_foreground_package)
        echo -e "${YELLOW}🔍 Auto-detected package:${NC} $package_name"
    else
        echo -e "${BLUE}✅ Using specified package:${NC} $package_name"
    fi

    echo
    validate_package_or_exit "$package_name"

    tmp_apk="tmp_signature_${package_name}.apk"
    apk_path=$(get_apk_path "$package_name") || exit 1
    if [ -z "$apk_path" ]; then
        echo -e "${RED}❌ Could not determine APK path for package:${NC} $package_name"
        exit 1
    fi

    echo -e "${BLUE}==> Pulling APK...${NC}"
    adb -s "$G_SELECTED_DEVICE" pull "$apk_path" "$tmp_apk" > /dev/null
    if [ $? -ne 0 ]; then
        echo
        echo -e "${RED}❌ Failed to pull APK from device. Check device connection and permissions.${NC}"
        rm -f "$tmp_apk"
        exit 1
    fi
    echo

    # Find latest apksigner
    apksigner=$(find "$ANDROID_HOME/build-tools" -name apksigner | sort -V | tail -n 1)
    if [ ! -x "$apksigner" ]; then
        echo -e "${RED}❌ apksigner not found or not executable.${NC}"
        rm -f "$tmp_apk"
        exit 1
    fi

    echo -e "${BLUE}==> Extracting signature with apksigner...${NC}"
    signature_output=$("$apksigner" verify --print-certs "$tmp_apk" 2>&1)

    echo "$signature_output" | grep -v '^WARNING:' | while IFS= read -r line; do
        if echo "$line" | grep -q 'SHA-256'; then
            echo -e "${GREEN}${BOLD}${line}${NC}"
        else
            echo "$line"
        fi
    done

    if echo "$signature_output" | grep -q 'DOES NOT VERIFY'; then
        echo -e "${YELLOW}⚠️ APK is not fully verifiable. It may be a pre-installed system app or missing v1 signature.${NC}"
    fi

    echo
    rm -f "$tmp_apk"
    echo -e "${GREEN}✅ Signature extraction complete.${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# UNINSTALL 커맨드 - 앱 제거
# ═══════════════════════════════════════════════════════════════════════════════

# uninstall 커맨드 사용법 출력 함수
usage_uninstall() {
    echo -e "${CYAN}${BOLD}Usage:${NC} $0 uninstall [packageName]"
    echo
    echo "Description: Uninstall the specified package from the device."
    echo "If 'packageName' is not provided, the script will auto-detect the current foreground app."
    echo
    exit 1
}

# uninstall 커맨드 함수
uninstall_package() {
    local package_name=$1
    local uninstall_output

    echo
    if [ -z "$package_name" ]; then
        package_name=$(detect_foreground_package)
        echo -e "${YELLOW}🔍 Auto-detected package:${NC} $package_name"
    else
        echo -e "${BLUE}✅ Using specified package:${NC} $package_name"
    fi

    echo
    validate_package_or_exit "$package_name"
    
    uninstall_output=$(adb -s "$G_SELECTED_DEVICE" uninstall "$package_name" 2>&1)
    
    if [[ "$uninstall_output" == *"Success"* ]]; then
        echo -e "${GREEN}✅ Successfully uninstalled.${NC}"
    else
        echo -e "${RED}❌ Failed to uninstall:${NC}"
        echo -e "  ==> $uninstall_output"
    fi
    echo
}

# ═══════════════════════════════════════════════════════════════════════════════
# PERMISSIONS 커맨드 - 앱 권한 조회
# ═══════════════════════════════════════════════════════════════════════════════

# permissions 커맨드 사용법 출력 함수
usage_permissions() {
    echo -e "${CYAN}${BOLD}Usage:${NC} $0 permissions [packageName]"
    echo
    echo "Description: List all permissions granted to the specified package."
    echo "If 'packageName' is not provided, the script will auto-detect the current foreground app."
    echo
    exit 1
}

# permissions 커맨드 함수
get_permissions() {
    local package_name=$1
    local permissions
    
    echo
    if [ -z "$package_name" ]; then
        package_name=$(detect_foreground_package)
        echo -e "${YELLOW}🔍 Auto-detected package:${NC} $package_name"
    else
        echo -e "${BLUE}✅ Using specified package:${NC} $package_name"
    fi
    
    echo
    validate_package_or_exit "$package_name"

    # permissions 추출
    permissions=$(adb -s "$G_SELECTED_DEVICE" shell dumpsys package "$package_name" | grep "granted=true" | awk -F: '{print $1}' | sed 's/^ *//g')

    # 결과 출력
    if [ -z "$permissions" ]; then
        echo -e "${RED}❌ No permissions found or failed to retrieve permissions for package:${NC} $package_name"
        echo
        exit 1
    fi

    echo -e "${CYAN}Permissions for package ${package_name}:${NC}"
    echo "$permissions"
    echo
}

# ═══════════════════════════════════════════════════════════════════════════════
# KILL 커맨드 - 앱 프로세스 강제 종료
# ═══════════════════════════════════════════════════════════════════════════════

# kill 커맨드 사용법 출력 함수
usage_kill() {
    echo -e "${CYAN}${BOLD}Usage:${NC} $0 kill [packageName1] [packageName2] ..."
    echo
    echo "Description: Force-stops one or more specified packages on the connected device."
    echo "If no packageName is provided, the script will auto-detect the current foreground app."
    echo
    exit 1
}

# kill 커맨드 함수
kill_packages() {
    local package_name seen_packages=()

    # 인수가 없으면 포그라운드 앱 자동 감지
    if [ "$#" -eq 0 ]; then
        package_name=$(detect_foreground_package)
        echo
        echo -e "${YELLOW}🔍 Auto-detected package:${NC} $package_name"
        validate_package_or_exit "$package_name"
        execute_kill_package "$package_name"
        return
    fi

    echo -e "${CYAN}Starting to kill packages...${NC}"
    
    for package_name in "$@"; do
        if ! validate_package_name "$package_name"; then
            echo
            echo -e "${RED}❌ Invalid package name format:${NC} $package_name"
            continue
        fi
        if ! is_package_installed "$package_name"; then
            echo
            echo -e "${RED}❌ Package not installed on the device:${NC} $package_name"
            continue
        fi
        if contains "$package_name" "${seen_packages[@]}"; then
            echo
            echo -e "${YELLOW}⚠️ Skipping duplicate package:${NC} $package_name"
            continue
        fi

        seen_packages+=("$package_name")
        execute_kill_package "$package_name"
    done
}

# kill 커맨드에서 패키지 종료 실행
execute_kill_package() {
    local package_name="$1"

    echo
    echo -e "${YELLOW}==> Attempting to kill:${NC} $package_name"
    adb -s "$G_SELECTED_DEVICE" shell am force-stop "$package_name"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Successfully killed${NC}"
    else
        echo -e "${RED}❌ Failed to kill:${NC} $package_name (may not be installed or running)"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLEAR 커맨드 - 앱 데이터 삭제
# ═══════════════════════════════════════════════════════════════════════════════

# clear 커맨드 사용법 출력 함수
usage_clear_data() {
    echo -e "${CYAN}${BOLD}Usage:${NC} $0 clear [packageName1] [packageName2] ..."
    echo
    echo "Description: Clear app data and cache for one or more specified packages."
    echo "If no packageName is provided, the script will auto-detect the current foreground app."
    echo
    exit 1
}

# clear 커맨드 함수 - 앱 데이터 삭제
clear_data() {
    local package_name seen_packages=()

    # 인수가 없으면 포그라운드 앱 자동 감지
    if [ "$#" -eq 0 ]; then
        package_name=$(detect_foreground_package)
        echo
        echo -e "${YELLOW}🔍 Auto-detected package:${NC} $package_name"
        validate_package_or_exit "$package_name"
        execute_clear_package "$package_name"
        return
    fi

    echo -e "${CYAN}Starting to clear app data...${NC}"
    
    for package_name in "$@"; do
        if ! validate_package_name "$package_name"; then
            echo
            echo -e "${RED}❌ Invalid package name format:${NC} $package_name"
            continue
        fi
        if ! is_package_installed "$package_name"; then
            echo
            echo -e "${RED}❌ Package not installed on the device:${NC} $package_name"
            continue
        fi
        if contains "$package_name" "${seen_packages[@]}"; then
            echo
            echo -e "${YELLOW}⚠️ Skipping duplicate package:${NC} $package_name"
            continue
        fi

        seen_packages+=("$package_name")
        execute_clear_package "$package_name"
    done
}

# clear 커맨드에서 패키지 데이터 삭제 실행
execute_clear_package() {
    local package_name="$1"
    local clear_output

    echo
    echo -e "${YELLOW}==> Attempting to clear data for:${NC} $package_name"
    echo -e "${BLUE}==> Clearing app data...${NC}"
    clear_output=$(adb -s "$G_SELECTED_DEVICE" shell pm clear "$package_name" 2>&1)
    
    if [[ "$clear_output" == *"Success"* ]]; then
        echo -e "${GREEN}✅ Successfully cleared data${NC}"
    else
        echo -e "${RED}❌ Failed to clear app data:${NC} $package_name"
        echo -e "  ==> $clear_output"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# LAUNCH 커맨드 - 앱 실행
# ═══════════════════════════════════════════════════════════════════════════════

# launch 커맨드 사용법 출력 함수
usage_launch() {
    echo -e "${CYAN}${BOLD}Usage:${NC} $0 launch <packageName>"
    echo
    echo "Description: Launch the specified package using its launcher activity."
    echo "Package name is required for this command."
    echo
    exit 1
}

# launch 커맨드에서 앱 실행 수행
launch_package() {
    local package_name=$1
    local launch_intent start_result
    
    if [ -z "$package_name" ]; then
        echo -e "${RED}❌ Package name is required for launch.${NC}"
        echo
        echo -e "${CYAN}${BOLD}Usage:${NC} $0 launch [packageName]"
        echo
        exit 1
    fi

    find_and_select_device

    if ! is_package_installed "$package_name"; then
        echo
        echo -e "${RED}❌ Package not installed on the device:${NC} $package_name"
        exit 1
    fi

    launch_intent=$(adb -s "$G_SELECTED_DEVICE" shell cmd package resolve-activity --brief "$package_name" 2>&1 | tail -n 1)
    start_result=$(adb -s "$G_SELECTED_DEVICE" shell am start --user 0 -n "$launch_intent" 2>&1)
    if echo "$start_result" | grep -q "Exception occurred while executing 'start'"; then
        echo -e "${RED}❌ Failed to launch app. Reason:${NC}"
        echo "  ${start_result//$'\n'/$'\n  '}"
        echo
        exit 1
    fi
    echo -e "${GREEN}✅ Successfully launched package:${NC} $package_name"
    echo
}

# ═══════════════════════════════════════════════════════════════════════════════
# DEVICES 관리 - 디바이스 목록 및 선택
# ═══════════════════════════════════════════════════════════════════════════════

# 연결된 디바이스를 모델명, Android 버전, 상태와 함께 출력
find_and_list_devices() {
    local line device_id status
    
    G_DEVICES=()
    while IFS= read -r line; do
        [[ "$line" =~ ^List ]] && continue
        [[ -z "$line" ]] && continue
        G_DEVICES+=("$line")
    done < <(adb devices)
    if [ -z "${G_DEVICES[*]}" ]; then
        echo -e "${RED}❌ No connected devices found.${NC}"
        return
    fi

    echo
    echo -e "${CYAN}${BOLD}Connected Devices:${NC}"
    echo
    
    for line in "${G_DEVICES[@]}"; do
        device_id=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $2}')
        
        case "$status" in
            device)
                local props brand model version api cpu
                props=$(adb -s "$device_id" shell getprop 2>/dev/null)
                
                brand=$(echo "$props" | awk -F'[][]' '$2 == "ro.product.brand" {print $4}' | tr -d '\r\n')
                model=$(echo "$props" | awk -F'[][]' '$2 == "ro.product.model" {print $4}' | tr -d '\r\n')
                cpu=$(echo "$props" | awk -F'[][]' '$2 == "ro.product.cpu.abi" {print $4}' | tr -d '\r\n')
                version=$(echo "$props" | awk -F'[][]' '$2 == "ro.build.version.release" {print $4}' | tr -d '\r\n')
                api=$(echo "$props" | awk -F'[][]' '$2 == "ro.build.version.sdk" {print $4}' | tr -d '\r\n')
                
                echo -e "  ${GREEN}✅ ${brand} ${model}${NC}"
                echo -e "     ID: ${BOLD}${device_id}${NC}  │  Android: ${BOLD}${version} (API ${api})${NC}  │  CPU: ${BOLD}${cpu}${NC}"
                # printf "     ID: ${BOLD}%-16s${NC}│ Android: ${BOLD}%-16s${NC}│ CPU: ${BOLD}%s${NC}\n" "${device_id}" "${version} (API ${api})" "${cpu}"
                ;;
            unauthorized)
                echo -e "  ${RED}🔒 UNAUTHORIZED DEVICE${NC} (USB debugging not authorized)"
                echo -e "     ID: ${BOLD}${device_id}${NC}"
                ;;
            offline)
                echo -e "  ${PURPLE}📴 OFFLINE DEVICE${NC} (Device disconnected)"
                echo -e "     ID: ${BOLD}${device_id}${NC}"
                ;;
            *)
                echo -e "  ${YELLOW}❓ UNKNOWN STATUS${NC} (${status})"
                echo -e "     ID: ${BOLD}${device_id}${NC}"
                ;;
        esac
        echo
    done
}

# 연결된 디바이스 찾기 및 선택
find_and_select_device() {
    local device_choice
    G_DEVICES=$(adb devices | grep 'device$' | cut -f1)
    G_DEVICE_ARRAY=($G_DEVICES)
    G_DEVICE_COUNT=${#G_DEVICE_ARRAY[@]}

    case $G_DEVICE_COUNT in
        0 ) # 연결된 장치가 없을 경우 에러 메시지 출력
            echo -e "${ERROR} No connected devices found."; exit 1 ;;
        1 ) # 연결된 장치가 하나일 경우 해당 장치 선택
            G_SELECTED_DEVICE=("${G_DEVICE_ARRAY[0]}") ;;
        * ) # 여러 장치가 연결된 경우 사용자에게 선택지 제공
            present_device_selection
            ;;
    esac
}

present_device_selection() {
    local i device_info device_choice
    declare -a G_DEVICE_LIST
    # 사용자에게 선택지 제공
    echo
    echo -e "${BARROW}${BOLD}List of connected devices: $G_DEVICE_COUNT${NC}"
    # `$G_DEVICES` 변수에 있는 디바이스 목록을 줄 단위로 분리하여 `G_DEVICE_LIST` 배열에 저장. IFS는 입력 필드 구분자를 설정.
    IFS=$'\n' read -rd '' -a G_DEVICE_LIST <<< "$G_DEVICES"

    i=1
    for device_info in "${G_DEVICE_LIST[@]}"; do
        echo -e "[${BOLD}$i${NC}] ${YELLOW}$(pretty_device $device_info)${NC}"
        ((i++))
    done
    echo
    read -r -p "Please select a device (enter number): " device_choice
    echo

    # 사용자가 입력한 번호가 유효하지 않으면 오류 메시지를 출력하고 스크립트를 종료.
    if [ -z "${G_DEVICE_LIST[device_choice - 1]}" ]; then
        echo -e "${ERROR} Invalid selection."
        exit 1
    fi
    # 선택된 디바이스를 배열로 저장
    G_SELECTED_DEVICE=("${G_DEVICE_LIST[device_choice - 1]}")
}

# 디바이스 정보 출력 함수
pretty_device() {
    local device_id="$1"
    local props brand model version api cpu
    local device_status

    # 디바이스 상태 확인
    device_status=$(adb devices | grep "$device_id" | awk '{print $2}')
    if [[ "$device_status" == "unauthorized" ]] || [[ "$device_status" == "offline" ]]; then
        echo "($device_id)"
        return
    fi

    props=$(adb -s "$device_id" shell getprop)

    brand=$(echo "$props" | awk -F'[][]' '$2 == "ro.product.brand" {print $4}' | tr -d '\r\n')
    model=$(echo "$props" | awk -F'[][]' '$2 == "ro.product.model" {print $4}' | tr -d '\r\n')
    cpu=$(echo "$props" | awk -F'[][]' '$2 == "ro.product.cpu.abi" {print $4}' | tr -d '\r\n')
    version=$(echo "$props" | awk -F'[][]' '$2 == "ro.build.version.release" {print $4}' | tr -d '\r\n')
    api=$(echo "$props" | awk -F'[][]' '$2 == "ro.build.version.sdk" {print $4}' | tr -d '\r\n')
    

    echo "$brand $model ($device_id) Android $version, API $api, CPU $cpu"
}

# ═══════════════════════════════════════════════════════════════════════════════
# 명령어 처리 및 스크립트 관리
# ═══════════════════════════════════════════════════════════════════════════════

process_options() {
    local command=$1
    shift

    case "$command" in
        pull)
            if [ "$#" -gt 2 ]; then
                usage_pull
            fi
            find_and_select_device
            pull_apk "$@"
            ;;
        info)
            if [ "$#" -gt 1 ]; then
                usage_appinfo
            fi
            find_and_select_device
            get_app_info "$@"
            ;;
        permissions)
            if [ "$#" -gt 1 ]; then
                usage_permissions
            fi
            find_and_select_device
            get_permissions "$@"
            ;;
        uninstall)
            if [ "$#" -gt 1 ]; then
                usage_uninstall
            fi
            find_and_select_device
            uninstall_package "$@"
            ;;
        signature)
            if [ "$#" -gt 1 ]; then
                usage_signature
            fi
            find_and_select_device
            get_signature_info "$@"
            ;;
        clear)
            find_and_select_device
            clear_data "$@"
            ;;
        kill)
            find_and_select_device
            kill_packages "$@"
            ;;
        devices)
            find_and_list_devices
            ;;
        launch)
            launch_package "$@"
            ;;
        --install)
            install_script
            ;;
        --version|-v)
            show_version
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo -e "${RED}❌ Error: Unknown command '${command}'${NC}"
            echo
            usage
            exit 1
            ;;
    esac
}


# 스크립트를 /usr/local/bin 에 설치하고 실행 권한 및 격리 해제를 수행합니다.
install_script() {
  local src_path
  src_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  local filename
  filename="$(basename "$src_path")"
  filename="${filename%.sh}"  # .sh 확장자 제거
  local dest_path="/usr/local/bin/$filename"

  echo -e "${BARROW} Installing '${YELLOW}${filename}${NC}' to ${CYAN}/usr/local/bin${NC}..."

  if [ ! -w "/usr/local/bin" ]; then
    echo -e "${ERROR} Permission denied. Try running with 'sudo'."
    return 1
  fi

  cp "$src_path" "$dest_path"
  chmod +x "$dest_path"
  xattr -d com.apple.quarantine "$dest_path" 2>/dev/null

  echo -e "${GARROW} Installed successfully at '${CYAN}${dest_path}${NC}'"
}

main() {
    if [ "$#" -lt 1 ]; then
        usage
        exit 1
    fi
    
    process_options "$@"
    exit 0
}

# 스크립트 시작
main "$@"
