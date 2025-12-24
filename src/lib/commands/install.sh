#!/bin/bash
#@@BUILD_EXCLUDE_START
# ═══════════════════════════════════════════════════
# Install Command
# APK 설치 커맨드 (ai.sh의 핵심 기능)
# ═══════════════════════════════════════════════════
#@@BUILD_EXCLUDE_END

# Completion definition: command name and description
: <<'AK_COMPLETION_DESC'
install:Install APK files
AK_COMPLETION_DESC

# Completion handler: zsh completion code for install command
: <<'AK_COMPLETION'
        install)
          local -a apk_files
          apk_files=(*.apk(N-.))
          _arguments -C \
            '(- *)'{-h,--help}'[Show help for this command]' \
            '(-a -p)-l[Install latest APK]' \
            '(-l -p)-a[Install all APKs]' \
            '(-l -a)-p[Filter APKs by pattern]:pattern' \
            '-m[Install on all devices]' \
            '-r[Replace existing app]' \
            '-t[Allow test APKs]' \
            '-d[Allow version downgrade]' \
            '*:APK files:compadd -a apk_files'
          ;;
AK_COMPLETION

# install 커맨드 도움말
show_help_install() {
  echo -e "${BOLD}Usage:${NC} ak install [options] [apk_files...]"
  echo "Install APK files on a selected Android device using adb."
  echo
  echo -e "${BOLD}General Options:${NC}"
  echo -e "  -h\t\tShow this help message and exit."
  echo
  echo -e "${BOLD}APK Selection Options (mutually exclusive):${NC}"
  echo -e "  (none)\tSelect APK files interactively from the current directory (default)."
  echo -e "  <directories>\tSelect APK files interactively from the specified directories."
  echo -e "  <apk files>\tDirectly specify APK files to install."
  echo -e "  -l\t\tInstall the latest APK file from the current directory."
  echo -e "  -a\t\tInstall all APK files from the current directory."
  echo -e "  -p <pattern>\tFilter and select APK files matching the pattern interactively."
  echo -e "\t\t\tPattern is REQUIRED. Can be used with directory."
  echo -e "\t\t\tExamples:"
  echo -e "\t\t\t  -p debug\t\t\tFind APKs containing 'debug' in current dir"
  echo -e "\t\t\t  -p \"myapp release\"\t\tFind APKs containing both 'myapp' and 'release'"
  echo -e "\t\t\t  -p debug /path/to/folder\tFind APKs in specified folder"
  echo
  echo -e "${BOLD}Device Options:${NC}"
  echo -e "  -m\t\tInstall APK files on all connected devices."
  echo
  echo -e "${BOLD}ADB Install Options:${NC}"
  echo -e "  -r\t\tReplace an existing application without removing its data (default)."
  echo -e "  -t\t\tAllow test APKs to be installed."
  echo -e "  -d\t\tAllow version code downgrade (requires 'pm' permission)."
  echo
  echo -e "${BOLD}Compatibility Notes:${NC}"
  echo -e "  If a '.idsig' file is present for the APK, the '--no-incremental' option is added to"
  echo -e "  the install command to ensure compatibility."
}

# 변수 초기화
initialize_install_variables() {
  install_opt="-r"
  opt_l_used=0
  opt_a_used=0
  opt_m_used=0
  opt_p_used=0
  filter_pattern=""
}

# 옵션 파싱
process_install_options() {
  while getopts ":hlamprtd" opt; do
    case ${opt} in
      h ) show_help_install; exit 0 ;;
      l ) opt_l_used=1 ;;
      a ) opt_a_used=1 ;;
      m ) opt_m_used=1 ;;
      p ) opt_p_used=1 ;;
      t | d ) install_opt+=" -$opt" ;;
      r ) ;; # '-r' 옵션은 이미 기본값으로 설정되어 있으므로 무시
      \? ) echo "Invalid option: $OPTARG" 1>&2; exit 1 ;;
    esac
  done

  # -p 옵션은 필수 패턴 인자 필요
  if [ $opt_p_used -eq 1 ]; then
    filter_pattern="${!OPTIND}"
    if [ -z "$filter_pattern" ]; then
      echo -e "${ERROR} Option -p requires a pattern argument."
      echo
      echo -e "${BOLD}Usage:${NC} ak install -p <pattern> [directory]"
      echo -e "${BOLD}Example:${NC}"
      echo -e "  ak install -p debug"
      echo -e "  ak install -p \"myapp release\""
      echo -e "  ak install -p debug /path/to/folder"
      echo
      echo "For interactive selection of all APKs, use: ak install"
      exit 1
    fi
    ((OPTIND++))
  fi
}

# 옵션 조합 검증
handle_option_combinations() {
  # '-l', '-a', '-p' 옵션 사용 여부 확인
  if [ $opt_l_used -eq 1 ] && [ $opt_a_used -eq 1 ] && [ $opt_p_used -eq 1 ]; then
    echo -e "${ERROR} Options -l, -a, and -p cannot be used together."
    exit 1
  fi

  if [ $opt_l_used -eq 1 ] && [ $opt_a_used -eq 1 ]; then
    echo -e "${ERROR} Options -l and -a cannot be used together."
    exit 1
  fi

  if [ $opt_l_used -eq 1 ] && [ $opt_p_used -eq 1 ]; then
    echo -e "${ERROR} Options -l and -p cannot be used together."
    exit 1
  fi

  if [ $opt_a_used -eq 1 ] && [ $opt_p_used -eq 1 ]; then
    echo -e "${ERROR} Options -a and -p cannot be used together."
    exit 1
  fi

  validate_install_apk_files "$@"
}

# APK 파일이 아닌지, APK 파일인데 다른 옵션과 같이 사용되었는지 판단
validate_install_apk_files() {
  for arg in "$@"; do
    # 파일 존재 여부
    if [ -f "$arg" ]; then
      extension="${arg##*.}"  # 확장자 추출
      
      if [[ "$extension" != "apk" ]]; then
        # 확장자가 APK 파일이 아닌 경우
        echo -e "${ERROR} Invalid file detected: '$arg'. Only APK files are allowed."
        exit 1
      elif [ $opt_l_used -eq 1 ] || [ $opt_a_used -eq 1 ] || [ $opt_p_used -eq 1 ]; then
        # '-l', '-a', '-p' 옵션 사용 시 APK 파일 인자를 허용하지 않음
        echo -e "${ERROR} Options -l, -a, or -p cannot be used with APK file arguments: '$arg'."
        exit 1
      fi
    fi
  done
}

# 옵션에 따라 APK 파일을 선택
select_apk_files() {
  apk_files=()

  # '-p' 옵션 사용 시: 인자가 있으면 `validate_and_collect_apk_files`에서 처리 (디렉토리 지원)
  # 인자가 없으면 select_apk_interactively 호출 (현재 디렉토리)
  if [ $opt_p_used -eq 1 ]; then
    if [ $# -eq 0 ]; then
      select_apk_interactively
      apk_files=("${selected_apks[@]}")
    fi
    # 인자가 있으면 아래에서 validate_and_collect_apk_files로 처리됨
  fi

  # '-l' 옵션 사용되었을 경우 최신 APK 파일 선택
  if [ $opt_l_used -eq 1 ]; then
    get_apk_list "." "time-newest"
    [ ${#APK_LIST[@]} -gt 0 ] && apk_files+=("${APK_LIST[0]}")
  fi

  # '-a' 옵션 사용되었을 경우 모든 APK 파일 선택
  if [ $opt_a_used -eq 1 ]; then
    get_apk_list "." ""
    apk_files+=("${APK_LIST[@]}")
  fi

  # 옵션 없음 또는 -p 옵션 + 인자 있음 → APK 파일 또는 디렉토리 인자 확인
  if [ ${#apk_files[@]} -eq 0 ]; then
    validate_and_collect_apk_files "$@"
  fi

  # 여전히 APK 없음 AND 인자 없음 → 인터랙티브 선택 (기본 동작)
  if [ ${#apk_files[@]} -eq 0 ] && [ $# -eq 0 ]; then
    select_apk_interactively
    apk_files=("${selected_apks[@]}")
  fi

  # 여전히 APK 없음 → 에러 메시지 출력 후 종료
  if [ ${#apk_files[@]} -eq 0 ]; then
    echo -e "${ERROR} No APK files found."
    exit 1
  fi
}

# 인자로 APK 파일이 있는지 확인
validate_and_collect_apk_files() {
  local has_directories=false
  local has_apk_files=false
  local apk_list=()

  # 1단계: 모든 인자를 검사하여 디렉토리와 APK 파일을 분류
  for arg in "$@"; do
    if [ -d "$arg" ]; then
      # 디렉토리 발견 - 해당 디렉토리의 APK 수집
      has_directories=true

      get_apk_list "$arg" ""
      apk_list+=("${APK_LIST[@]}")

    elif [ -f "$arg" ] && [[ "$arg" == *.apk ]]; then
      # APK 파일 발견
      has_apk_files=true
      apk_list+=("$arg")
    fi
  done

  # 2단계: 디렉토리나 APK가 있으면 처리
  if [ "$has_directories" = true ] || [ "$has_apk_files" = true ]; then
    # APK가 없으면 에러
    if [ ${#apk_list[@]} -eq 0 ]; then
      echo -e "${ERROR} No APK files found in the specified directories."
      exit 1
    fi

    # APK가 1개만 있으면 자동 선택
    if [ ${#apk_list[@]} -eq 1 ]; then
      apk_files=("${apk_list[0]}")
      echo -e "${BARROW} Only one APK file found: ${YELLOW}$(basename "${apk_list[0]}")${NC}"
      return 0
    fi

    # 여러 APK가 있으면 인터랙티브 선택
    # 패턴 필터링이 있으면 적용
    if [ -n "$filter_pattern" ]; then
      filtered_apks=()
      for apk in "${apk_list[@]}"; do
        all_patterns_match=true
        IFS=' ' read -ra patterns <<< "$filter_pattern"
        for pattern in "${patterns[@]}"; do
          if ! echo "$apk" | grep -i -q "$pattern"; then
            all_patterns_match=false
            break
          fi
        done
        if [ "$all_patterns_match" = true ]; then
          filtered_apks+=("$apk")
        fi
      done
      apk_list=("${filtered_apks[@]}")

      if [ ${#apk_list[@]} -eq 0 ]; then
        echo -e "${ERROR} No APK files found matching all patterns: ${filter_pattern}"
        exit 1
      fi

      # 필터링 후 APK가 1개만 남으면 자동 선택
      if [ ${#apk_list[@]} -eq 1 ]; then
        apk_files=("${apk_list[0]}")
        echo -e "${BARROW} Only one APK file found: ${YELLOW}$(basename "${apk_list[0]}")${NC}"
        return 0
      fi
    fi

    # select_interactive 멀티 모드 호출
    # 표시용 basename 배열 생성
    local display_list=()
    for apk in "${apk_list[@]}"; do
      display_list+=("$(basename "$apk")")
    done
    
    echo -e "${BARROW} ${BOLD}Select APK files to install${NC}\n"
    select_interactive "multi" "Select APK files" "${display_list[@]}"
    
    # 선택된 인덱스를 사용하여 원본 경로 매핑
    apk_files=()
    for idx in "${SELECTED_INDICES[@]}"; do
      apk_files+=("${apk_list[$idx]}")
    done
  fi
}

# APK 인터랙티브 선택
select_apk_interactively() {
  echo -e "${BARROW} ${BOLD}Scanning APK files in the current directory...${NC}"
  get_apk_list "." ""
  local apk_list=("${APK_LIST[@]}")

  # 현재 폴더에 APK 파일이 없는 경우 에러 출력 후 종료
  if [ ${#apk_list[@]} -eq 0 ]; then
    echo -e "${ERROR} No APK files found in the current directory."
    exit 1
  fi

  # 필터 패턴이 있는 경우 필터링
  if [ -n "$filter_pattern" ]; then
    filtered_apks=()
    for apk in "${apk_list[@]}"; do
      # 패턴을 공백으로 분리하여 각각의 패턴을 검색
      all_patterns_match=true
      IFS=' ' read -ra patterns <<< "$filter_pattern"
      for pattern in "${patterns[@]}"; do
        if ! echo "$apk" | grep -i -q "$pattern"; then
          all_patterns_match=false
          break
        fi
      done
      if [ "$all_patterns_match" = true ]; then
        filtered_apks+=("$apk")
      fi
    done
    apk_list=("${filtered_apks[@]}")

    if [ ${#apk_list[@]} -eq 0 ]; then
      echo -e "${ERROR} No APK files found matching all patterns: '$filter_pattern'"
      exit 1
    fi
  fi

  # 현재 폴더에 APK 파일이 1개인 경우 자동으로 선택
  if [ ${#apk_list[@]} -eq 1 ]; then
    selected_apks=("${apk_list[0]}")
    echo -e "${BARROW} Only one APK file found: ${YELLOW}$(basename "${apk_list[0]}")${NC}"
    return 0
  fi

  # 인터랙티브 선택 실행
  # 표시용 basename 배열 생성
  local display_list=()
  for apk in "${apk_list[@]}"; do
    display_list+=("$(basename "$apk")")
  done
  
  select_interactive "multi" "Select APK files to install" "${display_list[@]}"

  # 선택된 인덱스를 사용하여 원본 경로 매핑
  selected_apks=()
  for idx in "${SELECTED_INDICES[@]}"; do
    selected_apks+=("${apk_list[$idx]}")
  done

  # 유효한 선택이 없으면 종료
  if [ ${#selected_apks[@]} -eq 0 ]; then
    echo -e "${ERROR} No valid APK files selected."
    exit 1
  fi
}

# APK 파일 목록 출력
pretty_print_apk_files() {
  echo -e "${BARROW} ${BOLD}The APK files to install.${NC}"
  local i=1
  for apk_file in "${apk_files[@]}"; do
    echo "${i}. $(basename "$apk_file")"
    ((i++))
  done
}

# APK 설치 실행
execute_installation() {
  # 먼저 디바이스 정보를 시각화하여 출력
  if [ ${#selected_device[@]} -gt 1 ]; then
    echo
    pretty_print_selected_devices
  fi

  # 설치할 APK 파일들 출력
  echo
  pretty_print_apk_files

  # 설치 프로세스 시작 안내 메시지 출력
  echo
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${PURPLE}    🚀 Starting the install process for the selected devices... 🚀${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${NC}"

  for d in "${selected_device[@]}"; do
    echo
    echo -e "${BARROW} ${BOLD}Selected device: ${CYAN}$(pretty_device $d)${NC}"  

    for apk_file in "${apk_files[@]}"; do
      local inner_opt=$install_opt

      # APK 파일에 .idsig 파일이 있는 경우 '--no-incremental' 옵션 추가
      if [ -f "${apk_file}.idsig" ]; then
        echo
        echo -e "${GARROW} Detected an .idsig file associated with ${YELLOW}'$(basename "$apk_file")'${NC}."
        echo -e "    Applying the ${CYAN}${BOLD}'--no-incremental'${NC} option for compatibility.${NC}"
        inner_opt+=" --no-incremental"
      fi

      # 각 APK 파일에 대한 설치 명령 실행
      execute_install_command "-s $d" "$inner_opt" "$apk_file"
    done
  done
}

# 각 APK 파일에 대한 설치 명령 실행
execute_install_command() {
  local device_opt=$1
  local install_opt=$2
  local apk_file=$3

  echo
  echo -e "${BARROW} Install command: ${BOLD}adb install ${install_opt} $(basename "$apk_file")${NC}"
  local result
  result=$(start_adb_install "$device_opt" "$install_opt" "$apk_file")

  case "$result" in
    # 테스트 전용 설치 실패 시 처리
    *INSTALL_FAILED_TEST_ONLY*)
      retry_install "INSTALL_FAILED_TEST_ONLY" "-t" "${device_opt}" "${install_opt}" "${apk_file}"
      ;;
    # 버전 다운그레이드 설치 실패 시 처리
    *INSTALL_FAILED_VERSION_DOWNGRADE*)
      if [[ "$install_opt" == *"-d"* ]]; then
        resolve_downgrade "${device_opt}" "${install_opt}" "${apk_file}"
      else
        retry_install "INSTALL_FAILED_VERSION_DOWNGRADE" "-d" "${device_opt}" "${install_opt}" "${apk_file}"
      fi
      ;;
    # 설치 불가능한 기존 앱과 충돌 발생 시 처리
    *INSTALL_FAILED_UPDATE_INCOMPATIBLE*)
      resolve_conflict "${device_opt}" "${install_opt}" "${apk_file}" "${result}"
      ;;
    *) echo "$result" ;;
  esac
}

# 설치 실패 시 다시 시도
retry_install() {
  local failure_reason=$1
  local retry_option=$2
  local device_opt=$3
  local install_opt=$4
  local apk_file=$5

  local inner_opt="${install_opt} ${retry_option}"
  
  echo
  echo -e "${GARROW} Installation failed due to ${YELLOW}'${failure_reason}'${NC}. Retrying with ${CYAN}${BOLD}'${retry_option}'${NC} option."
  echo
  echo -e "${BARROW} Install command: ${BOLD}adb install ${inner_opt} $(basename "$apk_file")${NC}"

  # 옵션을 추가하여 재설치
  local result
  result=$(start_adb_install "$device_opt" "$inner_opt" "$apk_file")

   case "$result" in
    # 버전 다운그레이드 설치 실패 시 처리
    *INSTALL_FAILED_VERSION_DOWNGRADE*)
      resolve_downgrade "${device_opt}" "${install_opt}" "${apk_file}"
      ;;
    *) echo "$result" ;;
  esac
}

# 다운그레이드 실패 처리
resolve_downgrade() {
  local device_opt=$1
  local install_opt=$2
  local apk_file=$3

  echo
  echo -e "${RED}${BOLD}Application Installation Failed${NC}"
  echo
  echo -e "The adb install -d option is not supported on newer Android OS versions."
  echo -e "You need to uninstall the existing application before reinstalling it."
  echo
  echo -e "${YELLOW}${BOLD}WARNING:${NC} Uninstalling will remove all application data!"
  echo
  echo -n "Do you want to uninstall and reinstall the application? [Y/n]: "
  read -rsn1 choice
  echo "$choice"
  
  # 엔터키나 y/Y면 진행, n/N이면 중단
  if [[ -z "$choice" ]] || [[ "$choice" == "y" ]] || [[ "$choice" == "Y" ]]; then
    # aapt 도구 찾기
    local aapt=$(find_aapt)
    if [ -z "$aapt" ]; then
      echo
      echo -e "${ERROR} aapt not found."
      echo
      echo -e "${YELLOW}aapt is included in Android SDK build-tools.${NC}"
      echo
      echo -e "${BOLD}Solutions:${NC}"
      echo -e "  1. Install Android Studio and add build-tools via SDK Manager"
      echo -e "  2. Set ANDROID_HOME environment variable:"
      echo -e "     ${DIM}export ANDROID_HOME=\$HOME/Library/Android/sdk  # macOS${NC}"
      echo -e "     ${DIM}export ANDROID_HOME=\$HOME/Android/Sdk          # Linux${NC}"
      echo
      return 1
    fi
    
    # 패키지 이름 추출
    local package_name
    package_name=$("$aapt" dump badging "${apk_file}" | grep package:\ name | awk -F"'" '{print $2}')

    echo
    echo -e "${BARROW} Uninstalling package: ${BOLD}${package_name}${NC}"
    adb ${device_opt} uninstall "${package_name}" >/dev/null 2>&1

    if [[ $? -eq 0 ]]; then
      echo -e "${GARROW} Uninstallation successful."
      echo
      echo -e "${BARROW} Install command: ${BOLD}adb install ${install_opt} $(basename "$apk_file")${NC}"
      start_adb_install "$device_opt" "$install_opt" "$apk_file"
    else
      echo -e "${ERROR} Failed to uninstall the existing application."
    fi
  else
    echo -e "${GARROW} Installation aborted by user."
  fi
}

# INSTALL_FAILED_UPDATE_INCOMPATIBLE 오류 처리
resolve_conflict() {
  local device_opt=$1
  local install_opt=$2
  local apk_file=$3
  local result=$4
  
  echo
  echo -e "${RED}${BOLD}Application Installation Failed${NC}"
  echo
  echo -e "The device already has an application with the same package but a different signature."
  echo -e "In order to proceed, you will have to uninstall the existing application."
  echo
  echo -e "${YELLOW}${BOLD}WARNING:${NC} Uninstalling will remove the application data!"
  echo
  echo -n "Do you want to uninstall the existing application? [Y/n]: "
  read -rsn1 choice
  echo "$choice"

  # 엔터키나 y/Y면 진행, n/N이면 중단
  if [[ -z "$choice" ]] || [[ "$choice" == "y" ]] || [[ "$choice" == "Y" ]]; then
    # 패키지 이름 추출
    local package_name
    package_name=$(echo "$result" | sed -n 's/.*package \([^ ]*\).*/\1/p')

    echo
    echo -e "${BARROW} Uninstalling package: ${BOLD}${package_name}${NC}"
    adb ${device_opt} uninstall "${package_name}" >/dev/null 2>&1

    if [[ $? -eq 0 ]]; then
      echo -e "${GARROW} Uninstallation successful."
      echo
      echo -e "${BARROW} Install command: ${BOLD}adb install ${install_opt} $(basename "$apk_file")${NC}"
      start_adb_install "$device_opt" "$install_opt" "$apk_file"
    else
      echo -e "${ERROR} Failed to uninstall the existing application."
    fi
  else
    echo -e "${GARROW} Installation aborted by user."
  fi
}

# adb install 실행
start_adb_install() {
  local device_opt=$1
  local install_opt=$2
  local apk_file=$3
  # adb install 실행 결과를 반환
  adb ${device_opt} install ${install_opt} "${apk_file}" 2>&1
}

# ─────────────────────────────────────────────────────
# install 커맨드 메인 진입점
# ─────────────────────────────────────────────────────

cmd_install() {
  # --help 옵션 체크 (getopts 전에)
  for arg in "$@"; do
    if [ "$arg" = "--help" ] || [ "$arg" = "-h" ]; then
      show_help_install
      return 0
    fi
  done
  
  # 변수 초기화
  initialize_install_variables
  
  # 옵션 파싱
  process_install_options "$@"
  shift $((OPTIND -1))
  
  # 옵션 조합 검증
  handle_option_combinations "$@"
  
  # APK 파일 선택
  select_apk_files "$@"

  # 설치할 디바이스 선택 (멀티 디바이스 지원)
  find_and_select_devices_multi $opt_m_used

  # APK 설치 실행
  execute_installation
}
