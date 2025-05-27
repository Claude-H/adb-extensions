#!/bin/bash

# ─────────────────────────────────────────────────────────────────────────────
# ADB Kit (ak)
# ADB를 활용하여 안드로이드 디바이스에서 APK 추출, 버전 조회, 권한 확인,
#    앱 종료 및 실행 등을 지원하는 CLI 도구입니다.
#
# 🧑‍💻 작성자: Claude Hwnag
# ─────────────────────────────────────────────────────────────────────────────

VERSION="1.6.0"

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
        echo -e "${RED}✘ Invalid package name format:${NC} $package_name"
        echo ""
        exit 1
    fi
    if ! is_package_installed "$package_name"; then
        echo -e "${RED}✘ Package not installed on the device:${NC} $package_name"
        echo ""
        exit 1
    fi
}

# 지정한 패키지의 base.apk 경로를 추출하여 반환합니다. 실패 시 1을 반환
get_apk_path() {
    local package_name=$1
    local apk_path
    apk_path=$(adb -s "$G_SELECTED_DEVICE" shell pm list packages -f --user 0 | grep -x "package:.*=$package_name")

    if [ -z "$apk_path" ]; then
        echo -e "${RED}✘ Package not found:${NC} $package_name"
        echo ""
        return 1
    fi

    apk_path=$(echo "$apk_path" | sed -n 's/package:\(.*base\.apk\)=.*/\1/p')

    if [ -z "$apk_path" ]; then
        echo -e "${RED}✘ Failed to extract APK path for package:${NC} $package_name"
        echo ""
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
    echo -e "  ${BOLD}kill${NC} <packageName1> [packageName2 ...]"
    echo -e "      Force-stop one or more specified packages."
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
    echo
}
# uninstall 커맨드 사용법 출력 함수
usage_uninstall() {
    echo -e "${CYAN}${BOLD}Usage:${NC} $0 uninstall [packageName]"
    echo ""
    echo "If 'packageName' is not provided, the script will auto-detect the currently foreground app."
    echo ""
    exit 1
}

# pull 커맨드 사용법 출력 함수
usage_pull() {
    echo -e "${CYAN}${BOLD}Usage:${NC} $0 pull [packageName] [saveApkFileName]"
    echo ""
    echo "If 'packageName' is not provided, the script will auto-detect the currently foreground app."
    echo "If 'saveApkFileName' is not provided, the APK will be saved as '<packageName>.apk'."
    echo ""
    exit 1
}

# version 커맨드 사용법 출력 함수
usage_appinfo() {
    echo -e "${CYAN}${BOLD}Usage:${NC} $0 info [packageName]"
    echo ""
    echo "If 'packageName' is not provided, the script will auto-detect the currently foreground app."
    echo ""
    exit 1
}

# signature 커맨드 사용법 출력 함수
usage_signature() {
    echo -e "${CYAN}${BOLD}Usage:${NC} $0 signature [packageName]"
    echo ""
    echo "Description: Pull the APK of the specified package, extract the SHA-256"
    echo "certificate digest using apksigner, then remove the temporary APK file."
    echo "ANDROID_HOME must be set and contain valid build-tools with apksigner."
    echo ""
    exit 1
}

# permissions 커맨드 사용법 출력 함수
usage_permissions() {
    echo -e "${CYAN}${BOLD}Usage:${NC} $0 permissions [packageName]"
    echo ""
    echo "If 'packageName' is not provided, the script will auto-detect the currently foreground app."
    echo ""
    exit 1
}

# kill 커맨드 사용법 출력 함수
usage_kill() {
    echo -e "${CYAN}${BOLD}Usage:${NC} $0 kill <packageName1> [packageName2] ..."
    echo ""
    echo "Description: Force-stops one or more specified packages on the connected device."
    echo ""
    exit 1
}

# launch 커맨드 사용법 출력 함수
usage_launch() {
    echo -e "${CYAN}${BOLD}Usage:${NC} $0 launch <packageName>"
    echo ""
    echo "Description: Launch the specified package using its launcher activity."
    echo ""
    exit 1
}

# pull 커맨드 함수
pull_apk() {
    local package_name=$1
    local save_apk_file_name=$2
        
    if [ -z "$package_name" ]; then
        package_name=$(detect_foreground_package)
        echo -e "${YELLOW}ℹ Auto-detected package:${NC} $package_name"
    else
        echo -e "${BLUE}✓ Using specified package:${NC} $package_name"
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
        echo -e "${RED}✘ Failed to pull APK from device. Check device connection and permissions.${NC}"
        exit 1
    fi

    echo -e "${GREEN}✔ APK file saved as:${NC} $save_apk_file_name"
}

# appinfo 커맨드 함수
get_app_info() {
    local package_name=$1
    local version_name version_code target_sdk first_install_time last_update_time installer data_dir

    if [ -z "$package_name" ]; then
        package_name=$(detect_foreground_package)
        echo -e "${YELLOW}ℹ Auto-detected package:${NC} $package_name"
    else
        echo -e "${BLUE}✓ Using specified package:${NC} $package_name"
    fi
    
    echo
    validate_package_or_exit "$package_name"

    local dumpsys_output
    dumpsys_output=$(adb -s "$G_SELECTED_DEVICE" shell dumpsys package "$package_name")

    version_name=$(echo "$dumpsys_output" | grep versionName | head -n 1 | cut -d'=' -f2)
    version_code=$(echo "$dumpsys_output" | grep versionCode | head -n 1 | awk '{print $1}' | cut -d'=' -f2)
    target_sdk=$(echo "$dumpsys_output" | grep "targetSdk=" | head -n 1 | sed -n 's/.*targetSdk=\([0-9]*\).*/\1/p')
    first_install_time=$(echo "$dumpsys_output" | grep firstInstallTime | cut -d'=' -f2)
    last_update_time=$(echo "$dumpsys_output" | grep lastUpdateTime | cut -d'=' -f2)
    installer=$(echo "$dumpsys_output" | grep installerPackageName | cut -d'=' -f2)
    data_dir=$(echo "$dumpsys_output" | grep dataDir | head -n 1 | cut -d'=' -f2)

    # 필수 필드 중 하나라도 누락 시 오류
    if [ -z "$version_name" ] || [ -z "$version_code" ] || [ -z "$target_sdk" ]; then
        echo -e "${RED}✘ Critical app info missing for package:${NC} $package_name"
        echo -e "${RED}  → versionName, versionCode, or targetSdk could not be retrieved.${NC}"
        echo ""
        exit 1
    fi

    echo -e "${CYAN}APK Detailed Info:${NC}"
    echo -e "  ${GREEN}versionName:${NC} ${version_name}"
    echo -e "  ${GREEN}versionCode:${NC} ${version_code}"
    echo -e "  ${GREEN}targetSdk:${NC} ${target_sdk}"
    echo -e "  ${GREEN}firstInstallTime:${NC} ${first_install_time:-${YELLOW}(not available)${NC}}"
    echo -e "  ${GREEN}lastUpdateTime:${NC} ${last_update_time:-${YELLOW}(not available)${NC}}"
    echo -e "  ${GREEN}installerPackageName:${NC} ${installer:-${YELLOW}(not available)${NC}}"
    echo -e "  ${GREEN}dataDir:${NC} ${data_dir:-${YELLOW}(not available)${NC}}"
    echo ""
}

# signature 커맨드 함수 - APK 추출 후 apksigner로 SHA-256 서명 해시 추출
get_signature_info() {
    local package_name=$1
    local tmp_apk apk_path apksigner signature_output

    if [ -z "$package_name" ]; then
        package_name=$(detect_foreground_package)
        echo -e "${YELLOW}ℹ Auto-detected package:${NC} $package_name"
    else
        echo -e "${BLUE}✓ Using specified package:${NC} $package_name"
    fi

    echo
    validate_package_or_exit "$package_name"

    tmp_apk="tmp_signature_${package_name}.apk"
    apk_path=$(get_apk_path "$package_name") || exit 1
    if [ -z "$apk_path" ]; then
        echo -e "${RED}✘ Could not determine APK path for package:${NC} $package_name"
        exit 1
    fi

    echo -e "${BLUE}→ Pulling APK...${NC}"
    adb -s "$G_SELECTED_DEVICE" pull "$apk_path" "$tmp_apk" > /dev/null
    if [ $? -ne 0 ]; then
        echo
        echo -e "${RED}✘ Failed to pull APK from device. Check device connection and permissions.${NC}"
        rm -f "$tmp_apk"
        exit 1
    fi
    echo

    # Find latest apksigner
    apksigner=$(find "$ANDROID_HOME/build-tools" -name apksigner | sort -V | tail -n 1)
    if [ ! -x "$apksigner" ]; then
        echo -e "${RED}✘ apksigner not found or not executable.${NC}"
        rm -f "$tmp_apk"
        exit 1
    fi

    echo -e "${BLUE}→ Extracting signature with apksigner...${NC}"
    signature_output=$("$apksigner" verify --print-certs "$tmp_apk" 2>&1)

    echo "$signature_output" | grep -v '^WARNING:' | while IFS= read -r line; do
        if echo "$line" | grep -q 'SHA-256'; then
            echo -e "${GREEN}${BOLD}${line}${NC}"
        else
            echo "$line"
        fi
    done

    if echo "$signature_output" | grep -q 'DOES NOT VERIFY'; then
        echo -e "${YELLOW}⚠ APK is not fully verifiable. It may be a pre-installed system app or missing v1 signature.${NC}"
    fi

    echo
    rm -f "$tmp_apk"
    echo -e "${GREEN}✔ Signature extraction complete.${NC}"
}

# uninstall 커맨드 함수
uninstall_package() {
    local package_name=$1
    local uninstall_output

    if [ -z "$package_name" ]; then
        package_name=$(detect_foreground_package)
        echo -e "${YELLOW}ℹ Auto-detected package:${NC} $package_name"
    else
        echo -e "${BLUE}✓ Using specified package:${NC} $package_name"
    fi

    echo
    validate_package_or_exit "$package_name"
    
    uninstall_output=$(adb -s "$G_SELECTED_DEVICE" uninstall "$package_name")
    
    if [[ "$uninstall_output" == *"Success"* ]]; then
        echo -e "${GREEN}✔ Successfully uninstalled.${NC}"
    else
        echo -e "${RED}✘ Failed to uninstall:${NC}"
        echo -e "  → $uninstall_output"
    fi
    echo ""
}

# permissions 커맨드 함수
get_permissions() {
    local package_name=$1
    local permissions
    
    if [ -z "$package_name" ]; then
        package_name=$(detect_foreground_package)
        echo -e "${YELLOW}ℹ Auto-detected package:${NC} $package_name"
    else
        echo -e "${BLUE}✓ Using specified package:${NC} $package_name"
    fi
    
    echo
    validate_package_or_exit "$package_name"

    # permissions 추출
    permissions=$(adb -s "$G_SELECTED_DEVICE" shell dumpsys package "$package_name" | grep "granted=true" | awk -F: '{print $1}' | sed 's/^ *//g')

    # 결과 출력
    if [ -z "$permissions" ]; then
        echo -e "${RED}✘ No permissions found or failed to retrieve permissions for package:${NC} $package_name"
        echo ""
        exit 1
    fi

    echo -e "${CYAN}Permissions for package ${package_name}:${NC}"
    echo "$permissions"
    echo ""
}

# kill 커맨드에서 패키지 종료 실행
execute_kill_package() {
    local package_name="$1"

    echo ""
    echo -e "${YELLOW}→ Attempting to kill:${NC} $package_name"
    adb -s "$G_SELECTED_DEVICE" shell am force-stop "$package_name"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✔ Successfully killed${NC}"
    else
        echo -e "${RED}✘ Failed to kill:${NC} $package_name (may not be installed or running)"
    fi
}

# kill 커맨드 함수
kill_packages() {
    local package_name seen_packages=()

    if [ "$#" -lt 1 ]; then
        usage_kill
    fi

    echo -e "${CYAN}Starting to kill packages...${NC}"
    
    for package_name in "$@"; do
        if ! validate_package_name "$package_name"; then
            echo ""
            echo -e "${RED}✘ Invalid package name format:${NC} $package_name"
            continue
        fi
        if ! is_package_installed "$package_name"; then
            echo ""
            echo -e "${RED}✘ Package not installed on the device:${NC} $package_name"
            continue
        fi
        if contains "$package_name" "${seen_packages[@]}"; then
            echo ""
            echo -e "${YELLOW}⚠ Skipping duplicate package:${NC} $package_name"
            continue
        fi

        seen_packages+=("$package_name")
        execute_kill_package "$package_name"
    done
}

 # launch 커맨드에서 앱 실행 수행
launch_package() {
    local package_name=$1
    local launch_intent start_result
    
    if [ -z "$package_name" ]; then
        echo -e "${RED}✘ Package name is required for launch.${NC}"
        echo ""
        echo -e "${CYAN}${BOLD}Usage:${NC} $0 launch [packageName]"
        echo ""
        exit 1
    fi

    find_and_select_device

    if ! is_package_installed "$package_name"; then
        echo ""
        echo -e "${RED}✘ Package not installed on the device:${NC} $package_name"
        exit 1
    fi

    launch_intent=$(adb -s "$G_SELECTED_DEVICE" shell cmd package resolve-activity --brief "$package_name" 2>&1 | tail -n 1)
    start_result=$(adb -s "$G_SELECTED_DEVICE" shell am start --user 0 -n "$launch_intent" 2>&1)
    if echo "$start_result" | grep -q "Exception occurred while executing 'start'"; then
        echo -e "${RED}✘ Failed to launch app. Reason:${NC}"
        echo "  ${start_result//$'\n'/$'\n  '}"
        echo ""
        exit 1
    fi
    echo -e "${GREEN}✔ Successfully launched package:${NC} $package_name"
    echo ""
}

# 연결된 디바이스를 모델명, Android 버전, 상태와 함께 출력
find_and_list_devices() {
    local line device_id status info status_color
    G_DEVICES=()
    while IFS= read -r line; do
        [[ "$line" =~ ^List ]] && continue
        [[ -z "$line" ]] && continue
        G_DEVICES+=("$line")
    done < <(adb devices)
    if [ -z "${G_DEVICES[*]}" ]; then
        echo -e "${RED}✘ No connected devices found.${NC}"
        return
    fi

    echo
    echo -e "${CYAN}Connected Devices:${NC}"
    for line in "${G_DEVICES[@]}"; do
        device_id=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $2}')
        info=$(pretty_device "$device_id")
        case "$status" in
            device) status_color="${GREEN}${BOLD}${status}${NC}" ;;
            unauthorized) status_color="${RED}${BOLD}${status}${NC}" ;;
            offline) status_color="${PURPLE}${BOLD}${status}${NC}" ;;
            *) status_color="${YELLOW}${BOLD}${status}${NC}" ;;
        esac
        echo -e "  ${YELLOW}${info}${NC} - ${status_color}"
    done
    echo ""
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
    local props brand model version api

    props=$(adb -s "$device_id" shell getprop)

    brand=$(echo "$props" | awk -F'[][]' '$2 == "ro.product.brand" {print $4}' | tr -d '\r\n')
    model=$(echo "$props" | awk -F'[][]' '$2 == "ro.product.model" {print $4}' | tr -d '\r\n')
    version=$(echo "$props" | awk -F'[][]' '$2 == "ro.build.version.release" {print $4}' | tr -d '\r\n')
    api=$(echo "$props" | awk -F'[][]' '$2 == "ro.build.version.sdk" {print $4}' | tr -d '\r\n')

    echo "$brand $model ($device_id) Android $version, API $api"
}

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
        kill)
            if [ "$#" -lt 1 ]; then
                usage_kill
            fi
            find_and_select_device
            kill_packages "$@"
            ;;
        devices)
            find_and_list_devices
            exit 0
            ;;
        launch)
            launch_package "$@"
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}✘ Error: Unknown command '${command}'${NC}"
            echo ""
            usage
            exit 1
            ;;
    esac
}

main() {
    process_options "$@"
}

# 스크립트 시작
if [ "$#" -lt 1 ]; then
    usage
    exit 1
fi

main "$@"
