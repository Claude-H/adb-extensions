#!/bin/bash
#@@BUILD_EXCLUDE_START
# ═══════════════════════════════════════════════════
# PERMISSIONS Command
# 앱 권한 조회
# ═══════════════════════════════════════════════════
#@@BUILD_EXCLUDE_END

# Completion definition: command name and description
: <<'AK_COMPLETION_DESC'
permissions:List package permissions
AK_COMPLETION_DESC

# Completion handler: zsh completion code for permissions command
: <<'AK_COMPLETION'
        permissions)
          _arguments \
            '(- *)'{-h,--help}'[Show help for this command]' \
            '1:package name:_message "package name"'
          ;;
AK_COMPLETION

show_help_permissions() {
    echo -e "${CYAN}${BOLD}Usage:${NC} ak permissions [-h|--help] [packageName]"
    echo
    echo "Description: List all permissions granted to the specified package."
    echo "If 'packageName' is not provided, the script will auto-detect the current foreground app."
    echo
    echo "Options:"
    echo "  -h, --help  Show this help message"
    echo
    exit 1
}

cmd_permissions() {
    # 옵션 파싱
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help_permissions
                ;;
            -*)
                echo -e "${ERROR} Invalid option: $1"
                echo "Try 'ak permissions --help' for more information."
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
    local permissions
    
    echo
    if [ -z "$package_name" ]; then
        package_name=$(detect_foreground_package)
        echo -e "${YELLOW}Auto-detected package:${NC} $package_name"
    else
        echo -e "${BLUE}Using specified package:${NC} $package_name"
    fi
    
    echo
    validate_package_or_exit "$package_name"

    # permissions 추출
    permissions=$(adb -s "$G_SELECTED_DEVICE" shell dumpsys package "$package_name" | grep "granted=true" | awk -F: '{print $1}' | sed 's/^ *//g')

    # 결과 출력
    if [ -z "$permissions" ]; then
        echo -e "${RED}ERROR: No permissions found or failed to retrieve permissions for package:${NC} $package_name"
        echo
        exit 1
    fi

    echo -e "${CYAN}Permissions for package ${package_name}:${NC}"
    echo "$permissions"
    echo
}
