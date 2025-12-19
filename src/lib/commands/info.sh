#!/bin/bash
#@@BUILD_EXCLUDE_START
# ═══════════════════════════════════════════════════
# INFO Command
# 앱 정보 조회
# ═══════════════════════════════════════════════════
#@@BUILD_EXCLUDE_END

# Completion definition: command name and description
: <<'AK_COMPLETION_DESC'
info:Show package information
AK_COMPLETION_DESC

# Completion handler: zsh completion code for info command
: <<'AK_COMPLETION'
        info)
          _arguments \
            '(- *)'{-h,--help}'[Show help for this command]' \
            '1:package name:_message "package name"'
          ;;
AK_COMPLETION

show_help_info() {
    echo -e "${CYAN}${BOLD}Usage:${NC} ak info [-h|--help] [packageName]"
    echo
    echo "Description: Show detailed information of the package (version, SDK, debuggable, etc.)."
    echo "If 'packageName' is not provided, the script will auto-detect the current foreground app."
    echo
    echo "Options:"
    echo "  -h, --help  Show this help message"
    echo
    exit 1
}

cmd_info() {
    # 옵션 파싱
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help_info
                ;;
            -*)
                echo -e "${ERROR} Invalid option: $1"
                echo "Try 'ak info --help' for more information."
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    # 디바이스 선택
    find_and_select_device
    
    local package_name=$1
    local version_name version_code target_sdk min_sdk debuggable installer

    echo
    if [ -z "$package_name" ]; then
        package_name=$(detect_foreground_package)
        echo -e "${YELLOW}Auto-detected package:${NC} $package_name"
    else
        echo -e "${BLUE}Using specified package:${NC} $package_name"
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
        echo -e "${RED}ERROR: Critical app info missing for package:${NC} $package_name"
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
