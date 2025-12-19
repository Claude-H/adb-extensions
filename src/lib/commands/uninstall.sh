#!/bin/bash
#@@BUILD_EXCLUDE_START
# ═══════════════════════════════════════════════════
# UNINSTALL Command
# 앱 제거
# ═══════════════════════════════════════════════════
#@@BUILD_EXCLUDE_END

# Completion definition: command name and description
: <<'AK_COMPLETION_DESC'
uninstall:Uninstall package
AK_COMPLETION_DESC

# Completion handler: zsh completion code for uninstall command
: <<'AK_COMPLETION'
        uninstall)
          _arguments \
            '(- *)'{-h,--help}'[Show help for this command]' \
            '1:package name:_message "package name"'
          ;;
AK_COMPLETION

show_help_uninstall() {
    echo -e "${CYAN}${BOLD}Usage:${NC} ak uninstall [-h|--help] [packageName]"
    echo
    echo "Description: Uninstall the specified package from the device."
    echo "If 'packageName' is not provided, the script will auto-detect the current foreground app."
    echo
    echo "Options:"
    echo "  -h, --help  Show this help message"
    echo
    exit 1
}

cmd_uninstall() {
    # 옵션 파싱
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help_uninstall
                ;;
            -*)
                echo -e "${ERROR} Invalid option: $1"
                echo "Try 'ak uninstall --help' for more information."
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
    local uninstall_output

    echo
    if [ -z "$package_name" ]; then
        package_name=$(detect_foreground_package)
        echo -e "${YELLOW}Auto-detected package:${NC} $package_name"
    else
        echo -e "${BLUE}Using specified package:${NC} $package_name"
    fi

    echo
    validate_package_or_exit "$package_name"
    
    uninstall_output=$(adb -s "$G_SELECTED_DEVICE" uninstall "$package_name" 2>&1)
    
    if [[ "$uninstall_output" == *"Success"* ]]; then
        echo -e "${GREEN}Successfully uninstalled.${NC}"
    else
        echo -e "${RED}ERROR: Failed to uninstall:${NC}"
        echo -e "  ==> $uninstall_output"
    fi
    echo
}
