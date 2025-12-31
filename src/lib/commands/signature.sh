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
          local -a apk_files
          apk_files=(*.apk(N-.))
          _arguments \
            '(- *)'{-h,--help}'[Show help for this command]' \
            '1:package name or APK file:compadd -a apk_files'
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
    echo "  (no argument)    - Interactive selection: foreground apps from all devices + APK files"
    echo
    echo "Note: Requires Android SDK build-tools (apksigner)"
    echo "      Set ANDROID_HOME or ensure 'adb' is in PATH"
    echo
    exit 1
}

# 인터렉티브 선택: 모든 디바이스의 Foreground App + APK 파일들
select_signature_target_interactively() {
    local display_list=()
    local source_types=()  # "device" 또는 "apk"를 저장
    local source_data=()   # 패키지명 또는 APK 경로 저장
    
    # 1. 모든 연결된 디바이스의 Foreground app 가져오기
    if command -v adb &> /dev/null; then
        local devices
        devices=$(adb devices | grep 'device$' | cut -f1)
        local device_array
        IFS=$'\n' read -rd '' -a device_array <<< "$devices"
        
        if [ ${#device_array[@]} -gt 0 ]; then
            for device_id in "${device_array[@]}"; do
                # 각 디바이스의 foreground package 감지 (개선된 함수 사용)
                local foreground_package
                foreground_package=$(detect_foreground_package "$device_id" 2>/dev/null)
                
                if [ -n "$foreground_package" ] && [ "$foreground_package" != "null" ]; then
                    # 디바이스 정보 포맷팅
                    local device_info
                    device_info=$(pretty_device "$device_id" "minimal")
                    
                    display_list+=("📱 $foreground_package ($device_info)")
                    source_types+=("device")
                    source_data+=("$device_id|$foreground_package")
                fi
            done
        fi
    fi
    
    # 2. 현재 폴더의 APK 파일들 스캔
    echo
    echo -e "${BARROW} ${BOLD}Scanning APK files in the current directory...${NC}"
    get_apk_list "." "name"
    for file in "${APK_LIST[@]}"; do
        display_list+=("📦 $(basename "$file")")
        source_types+=("apk")
        source_data+=("$file")
    done
    
    # 3. 옵션이 없으면 에러
    if [ ${#display_list[@]} -eq 0 ]; then
        echo
        echo -e "${ERROR} No options available:"
        echo -e "  - No foreground app detected on any connected device"
        echo -e "  - No APK files found in current directory"
        echo
        echo "Please specify a package name or APK file path explicitly."
        exit 1
    fi
    
    # 4. 옵션이 1개만 있으면 자동 선택
    if [ ${#display_list[@]} -eq 1 ]; then
        if [ "${source_types[0]}" = "device" ]; then
            IFS='|' read -r device_id package_name <<< "${source_data[0]}"
            SIGNATURE_TARGET="$package_name"
            SIGNATURE_TYPE="package"
            SIGNATURE_DEVICE="$device_id"
            echo -e "${BARROW} Auto-selected: ${YELLOW}$package_name${NC} on ${DIM}$device_id${NC}"
        else
            SIGNATURE_TARGET="${source_data[0]}"
            SIGNATURE_TYPE="apk"
            SIGNATURE_DEVICE=""
            echo -e "${BARROW} Auto-selected: ${YELLOW}$(basename "${source_data[0]}")${NC}"
        fi
        return 0
    fi
    
    # 5. 인터렉티브 선택 (단일 선택)
    echo
    select_interactive "single" "Select target for signature extraction" "${display_list[@]}"
    
    # 6. 선택된 항목 처리
    local selected_idx=$SELECTED_INDEX
    
    if [ "${source_types[$selected_idx]}" = "device" ]; then
        IFS='|' read -r device_id package_name <<< "${source_data[$selected_idx]}"
        SIGNATURE_TARGET="$package_name"
        SIGNATURE_TYPE="package"
        SIGNATURE_DEVICE="$device_id"
    else
        SIGNATURE_TARGET="${source_data[$selected_idx]}"
        SIGNATURE_TYPE="apk"
        SIGNATURE_DEVICE=""
    fi
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
    
    # apksigner 필수 체크 (가장 먼저 확인)
    local apksigner
    apksigner=$(find_apksigner)
    if [ -z "$apksigner" ]; then
        echo
        echo -e "${ERROR} apksigner not found."
        echo
        echo -e "${YELLOW}apksigner is included in Android SDK build-tools.${NC}"
        echo
        echo -e "${BOLD}Solutions:${NC}"
        echo -e "  1. Install Android Studio and add build-tools via SDK Manager"
        echo -e "  2. Set ANDROID_HOME environment variable:"
        echo -e "     ${DIM}export ANDROID_HOME=\$HOME/Library/Android/sdk  # macOS${NC}"
        echo -e "     ${DIM}export ANDROID_HOME=\$HOME/Android/Sdk          # Linux${NC}"
        echo
        exit 1
    fi
    
    local input_param=$1
    local tmp_apk apk_path signature_output is_local_apk=false
    local target_device=""
    
    # 인자가 제공된 경우 - 기존 로직 유지
    if [ -n "$input_param" ]; then
        # 로컬 APK 파일인지 먼저 확인
        if [[ "$input_param" == *.apk ]] && [ -f "$input_param" ]; then
            is_local_apk=true
        fi
        
        # 로컬 APK가 아닌 경우에만 디바이스 선택
        if [ "$is_local_apk" = false ]; then
            find_and_select_device
            target_device="$G_SELECTED_DEVICE"
        fi

        echo
        
        # 입력이 .apk로 끝나면 로컬 APK 파일로 간주
        if [[ "$input_param" == *.apk ]]; then
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
    else
        # 인자가 없는 경우 - 새로운 인터렉티브 로직
        select_signature_target_interactively
        
        if [ "$SIGNATURE_TYPE" = "package" ]; then
            input_param="$SIGNATURE_TARGET"
            target_device="$SIGNATURE_DEVICE"
            is_local_apk=false
            echo
            echo -e "${BLUE}Selected package:${NC} $input_param"
            echo -e "${DIM}Device:${NC} $(pretty_device "$target_device" short)"
            
            # 패키지 검증은 해당 디바이스에서 수행
            G_SELECTED_DEVICE="$target_device"
            validate_package_or_exit "$input_param"
        else
            # APK 파일
            input_param="$SIGNATURE_TARGET"
            is_local_apk=true
            echo
            echo -e "${BLUE}Selected APK file:${NC} $(basename "$input_param")"
            
            # 절대 경로로 변환
            apk_path=$(realpath "$input_param")
            echo -e "${GREEN}==> Using APK file:${NC} $apk_path"
        fi
    fi

    echo

    # 로컬 APK 파일이 아닌 경우 디바이스에서 APK 추출
    if [ "$is_local_apk" = false ]; then
        # target_device가 설정되어 있으면 사용, 아니면 G_SELECTED_DEVICE 사용
        local device_to_use="${target_device:-$G_SELECTED_DEVICE}"
        
        tmp_apk="tmp_signature_${input_param}.apk"
        apk_path=$(get_apk_path_for_package "$input_param" "$device_to_use") || exit 1

        echo -e "${BLUE}==> Pulling APK from device...${NC}"
        adb -s "$device_to_use" pull "$apk_path" "$tmp_apk" > /dev/null
        if [ $? -ne 0 ]; then
            echo
            echo -e "${RED}ERROR: Failed to pull APK from device. Check device connection and permissions.${NC}"
            rm -f "$tmp_apk"
            exit 1
        fi
        apk_path="$tmp_apk"
        echo
    fi

    echo -e "${BLUE}==> Extracting signature with apksigner...${NC}"
    
    # 1차 시도: 옵션 없이 실행 (v2/v3 서명 APK 호환)
    signature_output=$("$apksigner" verify --print-certs "$apk_path" 2>&1)
    
    # 스마트 fallback: 에러 타입에 따라 재시도 여부 결정
    if echo "$signature_output" | grep -q "not supported on API Level"; then
        # MD5/SHA1 등 레거시 알고리즘 → --min-sdk-version 21로 해결 가능
        echo -e "${DIM}   Detected legacy signing algorithm, retrying...${NC}"
        signature_output=$("$apksigner" verify --print-certs --min-sdk-version 21 "$apk_path" 2>&1)
    elif echo "$signature_output" | grep -q "DOES NOT VERIFY\|ERROR"; then
        if ! echo "$signature_output" | grep -q "Signer #1 certificate"; then
            # 기타 에러지만 서명 정보가 없는 경우 → 한 번 더 시도
            echo -e "${DIM}   Retrying with --min-sdk-version 21...${NC}"
            signature_output=$("$apksigner" verify --print-certs --min-sdk-version 21 "$apk_path" 2>&1)
        fi
    fi

    echo "$signature_output" | grep -v '^WARNING:' | while IFS= read -r line; do
        if echo "$line" | grep -q 'SHA-256'; then
            echo -e "${GREEN}${BOLD}${line}${NC}"
        elif echo "$line" | grep -q 'SHA-1'; then
            echo -e "${YELLOW}${BOLD}${line}${NC}"
        else
            echo "$line"
        fi
    done

    # DOES NOT VERIFY 경고 (서명 정보는 추출됨)
    if echo "$signature_output" | grep -q 'DOES NOT VERIFY'; then
        if echo "$signature_output" | grep -q "Signer #1 certificate"; then
            echo
            echo -e "${YELLOW}Note: Signature extracted but verification failed.${NC}"
            echo -e "${DIM}This may occur with system apps or APKs missing v1 signature.${NC}"
        fi
    fi

    echo
    # 임시 파일이 생성된 경우에만 삭제
    [ "$is_local_apk" = false ] && rm -f "$tmp_apk"
    echo -e "${GREEN}Signature extraction complete.${NC}"
}
