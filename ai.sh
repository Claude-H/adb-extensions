#!/bin/bash

# ─────────────────────────────────────────────────────────────────────────────
# ADB Installer (ai)
# ADB를 활용하여 안드로이드 디바이스에 APK를 설치할 수 있는 CLI 도구입니다.
#    여러 디바이스 선택, APK 탐색, 설치 옵션 등을 지원합니다.
#
# 🧑‍💻 작성자: Claude Hwang
# ─────────────────────────────────────────────────────────────────────────────

VERSION="2.6.3"
RELEASE_DATE="2025-07-02"

# 색상 및 스타일 정의
RED='\033[1;31m' # 빨간색
GREEN='\033[1;32m' # 초록색
YELLOW='\033[1;33m' # 노란색
BLUE='\033[1;34m' # 파란색
PURPLE='\033[1;35m' # 보라색
CYAN='\033[1;36m' # 볼드와 옥색
BOLD='\033[1m' # 볼드
NC='\033[0m' # 색상 없음

BARROW="${BLUE}==>${NC}"
GARROW="${GREEN}==>${NC}"
ERROR="${RED}==>${NC} ${BOLD}Error:${NC}"

show_version() {
  local script_name=$(basename "$0")
  local os_info=$(uname -s)
  local shell_info=$(basename "$SHELL")
  local adb_version=$(adb version 2>/dev/null | head -n 1 | awk '{print $5}' || echo "Not found")
  local uptime_info=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}' | xargs)
  
  echo
  
  echo -e "        ${GREEN}::${NC}                   ${GREEN}.::${NC}        ${BOLD}${script_name}${NC} ${GREEN}${VERSION}${NC} - Released on ${RELEASE_DATE}"
  echo -e "       ${GREEN}:#*+.${NC}                ${GREEN}:+*#.${NC}       ------------------------------------"
  echo -e "        ${GREEN}:**+:${NC}    ${GREEN}......${NC}    ${GREEN}-+**.${NC}        ${BOLD}${YELLOW}ADB Version:${NC} ${adb_version}"
  echo -e "         ${GREEN}.*+=---::::::::---+*+${NC}          ${BOLD}${YELLOW}Author:${NC} Claude Hwang"
  echo -e "        ${YELLOW}:-=----:--------:---==-.${NC}        ${BOLD}${YELLOW}License:${NC} MIT"
  echo -e "      ${YELLOW}:++=---==============---=+=.${NC}      ${BOLD}${YELLOW}Language:${NC} Bash"
  echo -e "    ${RED}.+*+=+*%#++++++++++++++##+=+**-${NC}     ${BOLD}${YELLOW}Supported OS:${NC} macOS, Linux"
  echo -e "   ${RED}.****+%@@%+++++++++++++*@@@#+**#+${NC}    ${BOLD}${YELLOW}Dependencies:${NC} adb"
  echo -e "   ${CYAN}*#*****#*+++++++++++++++*##*****#=${NC}   ${BOLD}${YELLOW}Repository:${NC} https://github.com/Claude-H/adb-extensions"
  echo -e "  ${BLUE}-%#*****++++++++++++++++++++****##%.${NC}  "
  echo -e "                                        ${BOLD}${YELLOW}Purpose:${NC} APK installation tool"
  echo -e "                                        ${BOLD}${YELLOW}Features:${NC} Multi-device, Interactive selection"
  echo
}

# 스크립트 설명과 사용법
show_help() {
  echo -e "${BOLD}Usage:${NC} $0 [options] [apk_files...]"
  echo "This script installs APK files on a selected Android device using adb."
  echo
  echo -e "${BOLD}Script Version:${NC}"
  echo -e "  Current Version: $VERSION"
  echo
  echo -e "${BOLD}General Options:${NC}"
  echo -e "  -v --version\tDisplay the current version of script."
  echo -e "  -h --help\tShow this help message and exit."
  echo -e "  --install\tInstall this script to '/usr/local/bin' with executable permission."
  echo -e "\t\tAlso removes macOS quarantine attributes using xattr."
  echo -e "\t\tRecommended usage: ${BOLD}sudo ./ai.sh --install${NC}"
  echo
  echo -e "${BOLD}APK Selection Options (mutually exclusive):${NC}"
  echo -e "  -l\t\tInstall the latest APK file from the current directory."
  echo -e "  -a\t\tInstall all APK files from the current directory."
  echo -e "  -s [pattern]\tSelect APK files from the current directory interactively."
  echo -e "\t\tOptional pattern to filter APK files."
  echo -e "\t\tExamples:"
  echo -e "\t\t  -s debug\t\tFind APKs containing 'debug'"
  echo -e "\t\t  -s \"myapp release\"\tFind APKs containing both 'myapp' and 'release'"
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

initialize_variables() {
  install_opt="-r"
  opt_l_used=0
  opt_a_used=0
  opt_m_used=0
  opt_s_used=0
  filter_pattern=""  # 필터 패턴을 저장할 변수 추가
}

process_options() {
  while getopts ":vhlamsrtd-:" opt; do
    case ${opt} in
      h ) show_help; exit 0 ;;
      v ) show_version; exit 0 ;;
      l ) opt_l_used=1 ;;
      a ) opt_a_used=1 ;;
      m ) opt_m_used=1 ;;
      s ) opt_s_used=1 ;;
      t | d ) install_opt+=" -$opt" ;;
      r ) ;; # '-r' 옵션은 이미 기본값으로 설정되어 있으므로 무시
      - ) case "${OPTARG}" in
            version ) show_version; exit 0 ;;
            help ) show_help; exit 0 ;;
            install ) install_script; exit 0 ;;
            * ) echo "Invalid option: --${OPTARG}" 1>&2; exit 1 ;;
          esac
        ;;
      \? ) echo "Invalid option: $OPTARG" 1>&2; exit 1 ;;
    esac
  done
  # 처리된 옵션을 제거한다.
  shift $((OPTIND -1))

  # -s 옵션 사용 시 첫 번째 인자를 필터 패턴으로 사용
  if [ $opt_s_used -eq 1 ] && [ $# -gt 0 ]; then
    filter_pattern="$1"
    shift
  fi
}

# 옵션 조합을 처리하는 함수
handle_option_combinations() {
  # '-l', '-a', '-s' 옵션 사용 여부 확인
  if [ $opt_l_used -eq 1 ] && [ $opt_a_used -eq 1 ] && [ $opt_s_used -eq 1 ]; then
    echo -e "${ERROR} Options -l, -a, and -s cannot be used together."
    exit 1
  fi

  if [ $opt_l_used -eq 1 ] && [ $opt_a_used -eq 1 ]; then
    echo -e "${ERROR} Options -l and -a cannot be used together."
    exit 1
  fi

  if [ $opt_l_used -eq 1 ] && [ $opt_s_used -eq 1 ]; then
    echo -e "${ERROR} Options -l and -s cannot be used together."
    exit 1
  fi

  if [ $opt_a_used -eq 1 ] && [ $opt_s_used -eq 1 ]; then
    echo -e "${ERROR} Options -a and -s cannot be used together."
    exit 1
  fi

  validate_apk_files "$@"
}

# APK 파일이 아닌지, APK 파일인데 다른 옵션과 같이 사용되었는지 판단한다.
validate_apk_files() {
  for arg in "$@"; do
    # 파일 존재 여부
    if [ -f "$arg" ]; then
      extension="${arg##*.}"  # 확장자 추출
      
      if [[ "$extension" != "apk" ]]; then
        # 확장자가 APK 파일이 아닌 경우
        echo -e "${ERROR} Invalid file detected: '$arg'. Only APK files are allowed."
        exit 1
      elif [ $opt_l_used -eq 1 ] || [ $opt_a_used -eq 1 ] || [ $opt_s_used -eq 1 ]; then
        # '-l', '-a', '-s' 옵션 사용 시 APK 파일 인자를 허용하지 않음
        echo -e "${ERROR} Options -l, -a, or -s cannot be used with APK file arguments: '$arg'."
        exit 1
      fi
    fi
  done
}

# 옵션에 따라 APK 파일을 선택하는 함수
select_apk_files() {
  apk_files=()

  # '-s' 옵션 또는 인자가 없는 경우 APK 파일 선택
  if [ $opt_s_used -eq 1 ]; then
    select_apk_interactively
    apk_files=("${selected_apks[@]}")
  fi

  # '-l' 옵션 사용되었을 경우 최신 APK 파일 선택
  if [ $opt_l_used -eq 1 ]; then
    latest_apk=$(ls -t *.apk 2>/dev/null | head -n 1)
    [ -n "$latest_apk" ] && apk_files+=("$latest_apk")      
  fi

  # '-a' 옵션 사용되었을 경우 모든 APK 파일 선택
  if [ $opt_a_used -eq 1 ]; then
    while IFS= read -r -d '' file; do
      apk_files+=("$(basename "$file")")
    done < <(find . -maxdepth 1 -type f -name "*.apk" -print0)
  fi

  # 선택된 APK 파일이 없을 경우 사용자가 인자로 APK 파일을 넣었는지 검사한다.
  if [ ${#apk_files[@]} -eq 0 ]; then
    validate_and_collect_apk_files "$@"
  fi

  # APK 파일이 여전히 없을 경우 프로그램 종료
  if [ ${#apk_files[@]} -eq 0 ]; then
    # echo -e "${ERROR} No valid APK files found in the current directory."
    show_help
    exit 1
  fi
}

# 인자로 APK 파일이 있는지 확인한다.
validate_and_collect_apk_files() {
  for arg in "$@"; do
    # 인자가 파일이면서 .apk 확장자를 가지고 있는지 판단한다.
    if [ -f "$arg" ] && [[ "$arg" == *.apk ]]; then
      apk_files+=("$arg")
    # else
    #   echo -e "${ERROR} '$arg' is not a valid APK file in the current directory."
    fi
  done
}

# APK 선택 함수: 사용자로부터 APK 파일 선택을 받음
select_apk_interactively() {
  echo -e "${BARROW} ${BOLD}List of APK files in the current directory:${NC}"
  while IFS= read -r -d '' file; do
    apk_list+=("$(basename "$file")")
  done < <(find . -maxdepth 1 -type f -name "*.apk" -print0)

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
    echo -e "${BARROW} Only one APK file found: ${YELLOW}${apk_list[0]}${NC}"
    return 0
  fi

  # APK 파일 목록 출력
  local i=1
  for apk in "${apk_list[@]}"; do
    echo -e "[${i}] ${YELLOW}${apk}${NC}"
    ((i++))
  done

  echo
  read -p "Select APK files to install (enter numbers separated by comma [,]): " apk_selection

  # 선택된 APK 파일을 배열로 저장
  selected_apks=()
  IFS=',' read -ra choices <<< "$apk_selection"
  for choice in "${choices[@]}"; do
    if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -le ${#apk_list[@]} ] && [ $choice -ge 1 ]; then
      selected_apks+=("${apk_list[$((choice - 1))]}")
    else
      echo -e "${ERROR} Invalid selection: $choice"
    fi
  done

  # 유효한 선택이 없으면 종료
  if [ ${#selected_apks[@]} -eq 0 ]; then
    echo -e "${ERROR} No valid APK files selected."
    exit 1
  fi
}

# 연결된 디바이스 찾기 및 선택
find_and_select_device() {
  devices=$(adb devices | grep 'device$' | cut -f1)
  # devices=$(adb devices | grep -v devices | grep device | cut -f 1)
  device_array=($devices)
  device_count=${#device_array[@]}
  declare -a device_list=()

  case $device_count in
    0 ) # 연결된 장치가 없을 경우 에러 메시지 출력
      echo -e "${ERROR} No connected devices found."; exit 1 ;;
    1 ) # 연결된 장치가 하나일 경우 해당 장치 선택
      selected_device=("${device_array[0]}") ;;
    * ) # 여러 장치가 연결된 경우 사용자에게 선택지 제공
        # -m 옵션이 있는 경우 모든 디바이스를 선택
      if [ $opt_m_used -eq 1 ]; then
        selected_device=("${device_array[@]}")
      else
        present_device_selection
      fi
      ;;
  esac
}

present_device_selection() {
  # 사용자에게 선택지 제공
  echo
  echo -e "${BARROW} ${BOLD}List of connected devices: $device_count${NC}"
  # `$devices` 변수에 있는 디바이스 목록을 줄 단위로 분리하여 `device_list` 배열에 저장. IFS는 입력 필드 구분자를 설정.
  IFS=$'\n' read -rd '' -a device_list <<< "$devices"
  
  local i=1
  for device_info in "${device_list[@]}"; do
    echo -e "[${BOLD}$i${NC}] ${YELLOW}$(pretty_device $device_info)${NC}"
    ((i++))
  done
  echo
  read -r -p "Please select a device (enter number): " device_choice
  
  # 사용자가 입력한 번호가 유효하지 않으면 오류 메시지를 출력하고 스크립트를 종료.
  if [ -z "${device_list[device_choice - 1]}" ]; then
    echo -e "${ERROR} Invalid selection."
    exit 1
  fi
  # 선택된 디바이스를 배열로 저장
  selected_device=("${device_list[device_choice - 1]}")
}

# 디바이스 정보 출력 함수
pretty_device() {
  local device_id="$1"
  local props brand model version api

  props=$(adb -s "$device_id" shell getprop)

  brand=$(echo "$props" | awk -F'[][]' '$2 == "ro.product.brand" {print $4}' | tr -d '\r\n')
  model=$(echo "$props" | awk -F'[][]' '$2 == "ro.product.model" {print $4}' | tr -d '\r\n')
  version=$(echo "$props" | awk -F'[][]' '$2 == "ro.build.version.release" {print $4}' | tr -d '\r\n')
  api=$(echo "$props" | awk -F'[][]' '$2 == "ro.build.version.sdk" {print $4}' | tr -d '\r\n')

  echo "$brand $model ($device_id) Android $version, API $api"
}

pretty_print_apk_files() {
  # APK 파일들을 출력한다.
  echo -e "${BARROW} ${BOLD}The APK files to install.${NC}"
  local i=1
  for apk_file in "${apk_files[@]}"; do
    echo "[${i}] ${apk_file}"
    ((i++))
  done
}

# 선택된 디바이스들을 출력하는 함수
pretty_print_selected_devices() {
  echo -e "${BARROW} ${BOLD}Selected devices for installation:${NC}"
  local i=1
  for device in "${selected_device[@]}"; do
    echo "[${i}] $(pretty_device $device)"
    ((i++))
  done
}

# APK 파일 설치
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
        echo -e "${GARROW} Detected an .idsig file associated with ${YELLOW}'${apk_file}'${NC}."
        echo -e "    Applying the ${CYAN}${BOLD}'--no-incremental'${NC} option for compatibility.${NC}"
        inner_opt+=" --no-incremental"
      fi

      # 각 APK 파일에 대한 설치 명령 실행
      execute_install_command "-s $d" "$inner_opt" "$apk_file"
    done
  done
}

# 각 APK 파일에 대한 설치 명령을 실행하는 함수
execute_install_command() {
  local device_opt=$1
  local install_opt=$2
  local apk_file=$3

  echo
  echo -e "${BARROW} Install command: ${BOLD}adb install ${install_opt} ${apk_file}${NC}"
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

# 설치 실패 시 다시 시도하는 함수
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
  echo -e "${BARROW} Install command: ${BOLD}adb install ${inner_opt} ${apk_file}${NC}"

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
  echo -n "Do you want to uninstall and reinstall the application [y/n]? "
  stty -echo -icanon
  choice=$(dd bs=1 count=1 2>/dev/null)
  stty echo icanon
  echo "$choice"

  if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    # 패키지 이름 추출
    local package_name
    package_name=$(aapt dump badging ${apk_file} | grep package:\ name | awk -F"'" '{print $2}')

    echo
    echo -e "${BARROW} Uninstalling package: ${BOLD}${package_name}${NC}"
    adb ${device_opt} uninstall "${package_name}" >/dev/null 2>&1

    if [[ $? -eq 0 ]]; then
      echo -e "${GARROW} Uninstallation successful."
      echo
      echo -e "${BARROW} Install command: ${BOLD}adb install ${install_opt} ${apk_file}${NC}"
      start_adb_install "$device_opt" "$install_opt" "$apk_file"
    else
      echo -e "${ERROR} Failed to uninstall the existing application."
    fi
  else
    echo -e "${GARROW} Installation aborted by user."
  fi
}

# INSTALL_FAILED_UPDATE_INCOMPATIBLE 오류 처리 함수
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
  echo -n "Do you want to uninstall the existing application [y/n]? "
  stty -echo -icanon
  choice=$(dd bs=1 count=1 2>/dev/null)
  stty echo icanon
  echo "$choice"

  if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    # 패키지 이름 추출
    local package_name
    package_name=$(echo "$result" | sed -n 's/.*package \([^ ]*\).*/\1/p')

    echo
    echo -e "${BARROW} Uninstalling package: ${BOLD}${package_name}${NC}"
    adb ${device_opt} uninstall "${package_name}" >/dev/null 2>&1

    if [[ $? -eq 0 ]]; then
      echo -e "${GARROW} Uninstallation successful."
      echo
      echo -e "${BARROW} Install command: ${BOLD}adb install ${install_opt} ${apk_file}${NC}"
      start_adb_install "$device_opt" "$install_opt" "$apk_file"
    else
      echo -e "${ERROR} Failed to uninstall the existing application."
    fi
  else
    echo -e "${GARROW} Installation aborted by user."
  fi
}

start_adb_install() {
  local device_opt=$1
  local install_opt=$2
  local apk_file=$3
  # adb install 실행 결과를 반환
  adb ${device_opt} install ${install_opt} "${apk_file}" 2>&1
}

# 스크립트를 /usr/local/bin 에 설치하고 실행 권한 및 격리 해제를 수행합니다.
install_script() {
  local src_path
  src_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  local filename
  filename="$(basename "$src_path")"
  filename="${filename%.sh}"  # .sh 확장자 제거
  local dest_path="/usr/local/bin/$filename"

  echo -e "${BARROW} Installing '${YELLOW}${filename}${NC}' to ${CYAN}/usr/local/bin${NC}..."

  if [ ! -w "/usr/local/bin" ]; then
    echo -e "${ERROR} Permission denied. Try running with 'sudo'."
    return 1
  fi

  cp "$src_path" "$dest_path"
  chmod +x "$dest_path"
  xattr -d com.apple.quarantine "$dest_path" 2>/dev/null

  echo -e "${GARROW} Installed successfully at '${CYAN}${dest_path}${NC}'"
}

main() {
   # 설치 옵션 처리
  initialize_variables
  process_options "$@"
  handle_option_combinations "$@"
  select_apk_files "$@"

  # 설치할 디바이스 선택
  find_and_select_device

  # APK 설치 실행
  execute_installation
}

main "$@"
