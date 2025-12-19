#!/bin/bash
#@@BUILD_EXCLUDE_START
# ═══════════════════════════════════════════════════
# DEVICES Command
# 연결된 디바이스 목록
# ═══════════════════════════════════════════════════
#@@BUILD_EXCLUDE_END

# Completion definition: command name and description
: <<'AK_COMPLETION_DESC'
devices:Show connected devices
AK_COMPLETION_DESC

# Completion handler: zsh completion code for devices command
: <<'AK_COMPLETION'
        devices)
          _arguments '(- *)'{-h,--help}'[Show help for this command]'
          ;;
AK_COMPLETION

show_help_devices() {
    echo -e "${CYAN}${BOLD}Usage:${NC} ak devices [-h|--help]"
    echo
    echo "Description: Show connected device list with model and Android version."
    echo
    echo "Options:"
    echo "  -h, --help  Show this help message"
    echo
    exit 1
}

cmd_devices() {
    # 옵션 파싱
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help_devices
                ;;
            -*)
                echo -e "${ERROR} Invalid option: $1"
                echo "Try 'ak devices --help' for more information."
                exit 1
                ;;
            *)
                echo -e "${ERROR} Unexpected argument: $1"
                echo "Try 'ak devices --help' for more information."
                exit 1
                ;;
        esac
    done
    
    find_and_list_devices
}
