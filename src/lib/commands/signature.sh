#!/bin/bash
#@@BUILD_EXCLUDE_START
# ═══════════════════════════════════════════════════
# SIGNATURE Command
# 앱 서명 정보 추출
# ═══════════════════════════════════════════════════
#@@BUILD_EXCLUDE_END

# Completion definition: command name and description
: <<'AK_COMPLETION_DESC'
signature:Extract signature hash
AK_COMPLETION_DESC

# Completion handler: zsh completion code for signature command
: <<'AK_COMPLETION'
        signature)
          _arguments \
            '(- *)'{-h,--help}'[Show help for this command]' \
            '1:package name or APK file:_files -g "*.apk"'
          ;;
AK_COMPLETION

show_help_signature() {
    echo -e "${CYAN}${BOLD}Usage:${NC} ak signature [-h|--help] [packageName|/path/to/app.apk]"
    echo
    echo "Description: Extract the SHA-256 certificate digest using apksigner."
    echo "You can provide either a package name or a local APK file path."
    echo
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo
    echo "Arguments:"
    echo "  packageName      - Package name installed on the device (e.g., com.example.app)"
    echo "  /path/to/app.apk - Local APK file path (must end with .apk)"
    echo "  (no argument)    - Auto-detect the current foreground app"
    echo
    echo "Note: Requires Android SDK build-tools (apksigner)"
    echo "      Set ANDROID_HOME or ensure 'adb' is in PATH"
    echo
    exit 1
}

cmd_signature() {
    # 옵션 파싱
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help_signature
                ;;
            -*)
                echo -e "${ERROR} Invalid option: $1"
                echo "Try 'ak signature --help' for more information."
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    local input_param=$1
    local tmp_apk apk_path apksigner signature_output is_local_apk=false
    
    # 로컬 APK 파일인지 먼저 확인
    if [[ "$input_param" == *.apk ]] && [ -f "$input_param" ]; then
        is_local_apk=true
    fi
    
    # 로컬 APK가 아닌 경우에만 디바이스 선택
    if [ "$is_local_apk" = false ]; then
        find_and_select_device
    fi

    echo
    
    # 입력 파라미터가 없으면 포그라운드 앱 자동 감지
    if [ -z "$input_param" ]; then
        input_param=$(detect_foreground_package)
        echo -e "${YELLOW}Auto-detected package:${NC} $input_param"
    # 입력이 .apk로 끝나면 로컬 APK 파일로 간주
    elif [[ "$input_param" == *.apk ]]; then
        is_local_apk=true
        echo -e "${BLUE}Using local APK file:${NC} $input_param"
        
        # 로컬 APK 파일 존재 여부 확인
        if [ ! -f "$input_param" ]; then
            echo -e "${RED}ERROR: Local APK file not found:${NC} $input_param"
            echo
            exit 1
        fi
        
        # 절대 경로로 변환
        apk_path=$(realpath "$input_param")
        echo -e "${GREEN}==> Using APK file:${NC} $apk_path"
    else
        echo -e "${BLUE}Using specified package:${NC} $input_param"
        validate_package_or_exit "$input_param"
    fi

    echo

    # 로컬 APK 파일이 아닌 경우 디바이스에서 APK 추출
    if [ "$is_local_apk" = false ]; then
        tmp_apk="tmp_signature_${input_param}.apk"
        apk_path=$(get_apk_path "$input_param") || exit 1
        if [ -z "$apk_path" ]; then
            echo -e "${RED}ERROR: Could not determine APK path for package:${NC} $input_param"
            exit 1
        fi

        echo -e "${BLUE}==> Pulling APK from device...${NC}"
        adb -s "$G_SELECTED_DEVICE" pull "$apk_path" "$tmp_apk" > /dev/null
        if [ $? -ne 0 ]; then
            echo
            echo -e "${RED}ERROR: Failed to pull APK from device. Check device connection and permissions.${NC}"
            rm -f "$tmp_apk"
            exit 1
        fi
        apk_path="$tmp_apk"
        echo
    fi

    # Find apksigner using auto-detection
    apksigner=$(find_apksigner)
    if [ -z "$apksigner" ]; then
        echo -e "${RED}Error: apksigner not found${NC}"
        echo "Please install Android SDK build-tools or set ANDROID_HOME"
        [ "$is_local_apk" = false ] && rm -f "$tmp_apk"
        exit 1
    fi

    echo -e "${BLUE}==> Extracting signature with apksigner...${NC}"
    signature_output=$("$apksigner" verify --print-certs "$apk_path" 2>&1)

    echo "$signature_output" | grep -v '^WARNING:' | while IFS= read -r line; do
        if echo "$line" | grep -q 'SHA-256'; then
            echo -e "${GREEN}${BOLD}${line}${NC}"
        else
            echo "$line"
        fi
    done

    if echo "$signature_output" | grep -q 'DOES NOT VERIFY'; then
        echo -e "${YELLOW}WARNING: APK is not fully verifiable. It may be a pre-installed system app or missing v1 signature.${NC}"
    fi

    echo
    # 임시 파일이 생성된 경우에만 삭제
    [ "$is_local_apk" = false ] && rm -f "$tmp_apk"
    echo -e "${GREEN}Signature extraction complete.${NC}"
}
