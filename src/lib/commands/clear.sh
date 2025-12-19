#!/bin/bash
#@@BUILD_EXCLUDE_START
# ═══════════════════════════════════════════════════
# CLEAR Command
# 앱 데이터 삭제
# ═══════════════════════════════════════════════════
#@@BUILD_EXCLUDE_END

# Completion definition: command name and description
: <<'AK_COMPLETION_DESC'
clear:Clear app data and cache
AK_COMPLETION_DESC

# Completion handler: zsh completion code for clear command
: <<'AK_COMPLETION'
        clear)
          _arguments \
            '(- *)'{-h,--help}'[Show help for this command]' \
            '*:package name:_message "package name"'
          ;;
AK_COMPLETION

show_help_clear() {
    echo -e "${CYAN}${BOLD}Usage:${NC} ak clear [-h|--help] [packageName1] [packageName2] ..."
    echo
    echo "Description: Clear app data and cache for one or more specified packages."
    echo "If no packageName is provided, the script will auto-detect the current foreground app."
    echo
    echo "Options:"
    echo "  -h, --help  Show this help message"
    echo
    exit 1
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
        echo -e "${GREEN}Successfully cleared data${NC}"
    else
        echo -e "${RED}ERROR: Failed to clear app data:${NC} $package_name"
        echo -e "  ==> $clear_output"
    fi
}

cmd_clear() {
    # 옵션 파싱
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help_clear
                ;;
            -*)
                echo -e "${ERROR} Invalid option: $1"
                echo "Try 'ak clear --help' for more information."
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    # 디바이스 선택
    find_and_select_device
    
    local package_name seen_packages=()

    # 인수가 없으면 포그라운드 앱 자동 감지
    if [ "$#" -eq 0 ]; then
        package_name=$(detect_foreground_package)
        echo
        echo -e "${YELLOW}Auto-detected package:${NC} $package_name"
        validate_package_or_exit "$package_name"
        execute_clear_package "$package_name"
        return
    fi

    echo -e "${CYAN}Starting to clear app data...${NC}"
    
    for package_name in "$@"; do
        if ! validate_package_name "$package_name"; then
            echo
            echo -e "${RED}ERROR: Invalid package name format:${NC} $package_name"
            continue
        fi
        if ! is_package_installed "$package_name"; then
            echo
            echo -e "${RED}ERROR: Package not installed on the device:${NC} $package_name"
            continue
        fi
        if contains "$package_name" "${seen_packages[@]}"; then
            echo
            echo -e "${YELLOW}WARNING: Skipping duplicate package:${NC} $package_name"
            continue
        fi

        seen_packages+=("$package_name")
        execute_clear_package "$package_name"
    done
}
