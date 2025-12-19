#!/bin/bash
#@@BUILD_EXCLUDE_START
# ═══════════════════════════════════════════════════
# KILL Command
# 앱 프로세스 강제 종료
# ═══════════════════════════════════════════════════
#@@BUILD_EXCLUDE_END

# Completion definition: command name and description
: <<'AK_COMPLETION_DESC'
kill:Force-stop package
AK_COMPLETION_DESC

# Completion handler: zsh completion code for kill command
: <<'AK_COMPLETION'
        kill)
          _arguments \
            '(- *)'{-h,--help}'[Show help for this command]' \
            '*:package name:_message "package name"'
          ;;
AK_COMPLETION

show_help_kill() {
    echo -e "${CYAN}${BOLD}Usage:${NC} ak kill [-h|--help] [packageName1] [packageName2] ..."
    echo
    echo "Description: Force-stops one or more specified packages on the connected device."
    echo "If no packageName is provided, the script will auto-detect the current foreground app."
    echo
    echo "Options:"
    echo "  -h, --help  Show this help message"
    echo
    exit 1
}

# kill 커맨드에서 패키지 종료 실행
execute_kill_package() {
    local package_name="$1"

    echo
    echo -e "${YELLOW}==> Attempting to kill:${NC} $package_name"
    adb -s "$G_SELECTED_DEVICE" shell am force-stop "$package_name"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully killed${NC}"
    else
        echo -e "${RED}ERROR: Failed to kill:${NC} $package_name (may not be installed or running)"
    fi
}

cmd_kill() {
    # 옵션 파싱
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help_kill
                ;;
            -*)
                echo -e "${ERROR} Invalid option: $1"
                echo "Try 'ak kill --help' for more information."
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
        execute_kill_package "$package_name"
        return
    fi

    echo -e "${CYAN}Starting to kill packages...${NC}"
    
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
        execute_kill_package "$package_name"
    done
}
