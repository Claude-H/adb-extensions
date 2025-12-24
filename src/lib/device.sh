#!/bin/bash
#@@BUILD_EXCLUDE_START
# ═══════════════════════════════════════════════════
# Device Management
# ADB 디바이스 관리 함수
# ═══════════════════════════════════════════════════
#@@BUILD_EXCLUDE_END

# 디바이스 정보 출력 함수
# 표시 레벨: minimal(브랜드 모델명) | short(+ID) | normal(+Android/API) | full(+CPU)
pretty_device() {
    local device_id="$1"
    local level="${2:-normal}"  # 기본값 normal
    local props brand model version api cpu
    local device_status

    # 디바이스 상태 확인
    device_status=$(adb devices | grep "$device_id" | awk '{print $2}')
    if [[ "$device_status" == "unauthorized" ]] || [[ "$device_status" == "offline" ]]; then
        echo "($device_id)"
        return
    fi

    props=$(adb -s "$device_id" shell getprop)

    brand=$(echo "$props" | awk -F'[][]' '$2 == "ro.product.brand" {print $4}' | tr -d '\r\n')
    # 변경 후: bash 3.2 호환 (awk 사용)
    brand=$(echo "$brand" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
    model=$(echo "$props" | awk -F'[][]' '$2 == "ro.product.model" {print $4}' | tr -d '\r\n')
    version=$(echo "$props" | awk -F'[][]' '$2 == "ro.build.version.release" {print $4}' | tr -d '\r\n')
    api=$(echo "$props" | awk -F'[][]' '$2 == "ro.build.version.sdk" {print $4}' | tr -d '\r\n')

    case "$level" in
        minimal)
            echo "$brand $model"
            ;;
        short)
            echo "$brand $model ($device_id)"
            ;;
        full)
            cpu=$(echo "$props" | awk -F'[][]' '$2 == "ro.product.cpu.abi" {print $4}' | tr -d '\r\n')
            echo "$brand $model ($device_id) Android $version, API $api, CPU $cpu"
            ;;
        *)  # normal (default)
            echo "$brand $model ($device_id) Android $version, API $api"
            ;;
    esac
}

# ─────────────────────────────────────────────────────
# 단일 디바이스 선택 (대부분의 커맨드용)
# ─────────────────────────────────────────────────────

# 연결된 디바이스 찾기 및 선택 (단일 디바이스)
# 결과: G_SELECTED_DEVICE 변수에 선택된 디바이스 ID 저장
find_and_select_device() {
    local devices
    devices=$(adb devices | grep 'device$' | cut -f1)
    local device_array=($devices)
    local device_count=${#device_array[@]}

    case $device_count in
        0 ) # 연결된 장치가 없을 경우 에러 메시지 출력
            echo -e "${ERROR} No connected devices found."; exit 1 ;;
        1 ) # 연결된 장치가 하나일 경우 해당 장치 선택
            G_SELECTED_DEVICE="${device_array[0]}" ;;
        * ) # 여러 장치가 연결된 경우 사용자에게 선택지 제공
            present_device_selection_single "$devices"
            ;;
    esac
}

# 단일 디바이스 선택 UI
present_device_selection_single() {
    local devices="$1"
    declare -a device_list
    
    # 디바이스 목록을 줄 단위로 분리하여 배열에 저장
    IFS=$'\n' read -rd '' -a device_list <<< "$devices"
    
    # 디바이스 정보를 pretty_device로 포맷팅한 배열 생성
    local -a formatted_devices=()
    for device_info in "${device_list[@]}"; do
      formatted_devices+=("$(pretty_device $device_info)")
    done
    
    # 인터랙티브 단일 선택 실행
    select_interactive "single" "Select a device" "${formatted_devices[@]}"
    
    # 선택된 인덱스를 사용하여 실제 디바이스 ID 설정
    G_SELECTED_DEVICE="${device_list[$SELECTED_INDEX]}"
}

# ─────────────────────────────────────────────────────
# 멀티 디바이스 선택 (install 커맨드용)
# ─────────────────────────────────────────────────────

# 연결된 디바이스 찾기 및 선택 (멀티 디바이스 지원)
# 결과: selected_device 배열에 선택된 디바이스 ID들 저장
find_and_select_devices_multi() {
    local opt_m_used=$1  # -m 옵션 사용 여부
    local devices
    devices=$(adb devices | grep 'device$' | cut -f1)
    local device_array=($devices)
    local device_count=${#device_array[@]}

    case $device_count in
        0 ) # 연결된 장치가 없을 경우 에러 메시지 출력
            echo -e "${ERROR} No connected devices found."; exit 1 ;;
        1 ) # 연결된 장치가 하나일 경우 해당 장치 선택
            selected_device=("${device_array[0]}") ;;
        * ) # 여러 장치가 연결된 경우
            # -m 옵션이 있는 경우 모든 디바이스를 선택
            if [ $opt_m_used -eq 1 ]; then
                selected_device=("${device_array[@]}")
            else
                present_device_selection_multi "$devices"
            fi
            ;;
    esac
}

# 멀티 디바이스 선택 UI
present_device_selection_multi() {
    local devices="$1"
    declare -a device_list
    
    # 디바이스 목록을 줄 단위로 분리하여 배열에 저장
    IFS=$'\n' read -rd '' -a device_list <<< "$devices"
    
    # 디바이스 정보를 pretty_device로 포맷팅한 배열 생성
    local -a formatted_devices=()
    for device_info in "${device_list[@]}"; do
      formatted_devices+=("$(pretty_device $device_info)")
    done
    
    # 인터랙티브 멀티 선택 실행
    select_interactive "multi" "Select devices for installation" "${formatted_devices[@]}"
    
    # 선택된 인덱스를 사용하여 실제 디바이스 ID 배열 생성
    selected_device=()
    for idx in "${SELECTED_INDICES[@]}"; do
      selected_device+=("${device_list[$idx]}")
    done
}

# ─────────────────────────────────────────────────────
# 디바이스 목록 출력 (devices 커맨드용)
# ─────────────────────────────────────────────────────

# 연결된 디바이스를 모델명, Android 버전, 상태와 함께 출력
find_and_list_devices() {
    local line device_id status
    
    local devices_list=()
    while IFS= read -r line; do
        [[ "$line" =~ ^List ]] && continue
        [[ -z "$line" ]] && continue
        devices_list+=("$line")
    done < <(adb devices)
    
    if [ -z "${devices_list[*]}" ]; then
        echo -e "${RED}ERROR: No connected devices found.${NC}"
        return
    fi

    echo
    echo -e "${CYAN}${BOLD}Connected Devices:${NC}"
    echo
    
    for line in "${devices_list[@]}"; do
        device_id=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $2}')
        
        case "$status" in
            device)
                local props brand model version api cpu
                props=$(adb -s "$device_id" shell getprop 2>/dev/null)
                
                brand=$(echo "$props" | awk -F'[][]' '$2 == "ro.product.brand" {print $4}' | tr -d '\r\n')
                # 변경 후: bash 3.2 호환 (awk 사용)
                brand=$(echo "$brand" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
                model=$(echo "$props" | awk -F'[][]' '$2 == "ro.product.model" {print $4}' | tr -d '\r\n')
                cpu=$(echo "$props" | awk -F'[][]' '$2 == "ro.product.cpu.abi" {print $4}' | tr -d '\r\n')
                version=$(echo "$props" | awk -F'[][]' '$2 == "ro.build.version.release" {print $4}' | tr -d '\r\n')
                api=$(echo "$props" | awk -F'[][]' '$2 == "ro.build.version.sdk" {print $4}' | tr -d '\r\n')
                
                echo -e "  ${GREEN}${brand} ${model}${NC}"
                echo -e "     ID: ${BOLD}${device_id}${NC}  │  Android: ${BOLD}${version} (API ${api})${NC}  │  CPU: ${BOLD}${cpu}${NC}"
                ;;
            unauthorized)
                echo -e "  ${RED}UNAUTHORIZED DEVICE${NC} (USB debugging not authorized)"
                echo -e "     ID: ${BOLD}${device_id}${NC}"
                ;;
            offline)
                echo -e "  ${PURPLE}OFFLINE DEVICE${NC} (Device disconnected)"
                echo -e "     ID: ${BOLD}${device_id}${NC}"
                ;;
            *)
                echo -e "  ${YELLOW}UNKNOWN STATUS${NC} (${status})"
                echo -e "     ID: ${BOLD}${device_id}${NC}"
                ;;
        esac
        echo
    done
}

# 선택된 디바이스들을 출력하는 함수 (install 커맨드용)
pretty_print_selected_devices() {
  echo -e "${BARROW} ${BOLD}Selected devices for installation:${NC}"
  local i=1
  for device in "${selected_device[@]}"; do
    echo "${i}. $(pretty_device $device)"
    ((i++))
  done
}
