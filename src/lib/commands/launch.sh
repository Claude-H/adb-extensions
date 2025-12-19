#!/bin/bash
#@@BUILD_EXCLUDE_START
# ═══════════════════════════════════════════════════
# LAUNCH Command
# 앱 실행
# ═══════════════════════════════════════════════════
#@@BUILD_EXCLUDE_END

# Completion definition: command name and description
: <<'AK_COMPLETION_DESC'
launch:Launch package
AK_COMPLETION_DESC

# Completion handler: zsh completion code for launch command
: <<'AK_COMPLETION'
        launch)
          _arguments \
            '(- *)'{-h,--help}'[Show help for this command]' \
            '1:package name:_message "package name"'
          ;;
AK_COMPLETION

show_help_launch() {
    echo -e "${CYAN}${BOLD}Usage:${NC} ak launch [-h|--help] <packageName>"
    echo
    echo "Description: Launch the specified package using its launcher activity."
    echo "Package name is required for this command."
    echo
    echo "Options:"
    echo "  -h, --help  Show this help message"
    echo
    exit 1
}

cmd_launch() {
    # 옵션 파싱
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help_launch
                ;;
            -*)
                echo -e "${ERROR} Invalid option: $1"
                echo "Try 'ak launch --help' for more information."
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    local package_name=$1
    
    # 인자 없음
    if [ -z "$package_name" ]; then
        show_help_launch
    fi
    
    # 디바이스 선택
    find_and_select_device
    
    local launch_intent start_result

    if ! is_package_installed "$package_name"; then
        echo
        echo -e "${RED}ERROR: Package not installed on the device:${NC} $package_name"
        exit 1
    fi

    launch_intent=$(adb -s "$G_SELECTED_DEVICE" shell cmd package resolve-activity --brief "$package_name" 2>&1 | tail -n 1)
    start_result=$(adb -s "$G_SELECTED_DEVICE" shell am start --user 0 -n "$launch_intent" 2>&1)
    if echo "$start_result" | grep -q "Exception occurred while executing 'start'"; then
        echo -e "${RED}ERROR: Failed to launch app. Reason:${NC}"
        echo "  ${start_result//$'\n'/$'\n  '}"
        echo
        exit 1
    fi
    echo -e "${GREEN}Successfully launched package:${NC} $package_name"
    echo
}
