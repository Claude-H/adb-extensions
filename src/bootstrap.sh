#!/bin/bash
# ─────────────────────────────────────────────────────
# Bootstrap - Library Loader
# 라이브러리 로드 및 초기화
# ─────────────────────────────────────────────────────

# 스크립트 디렉토리 찾기
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# lib 디렉토리 찾기 (개발 모드 vs 설치 모드)
if [ -d "${SCRIPT_DIR}/lib" ]; then
  LIB_DIR="${SCRIPT_DIR}/lib"
elif [ -d "/usr/local/lib/ak" ]; then
  LIB_DIR="/usr/local/lib/ak"
else
  echo "ERROR: Cannot find lib directory"
  exit 1
fi

# 필수 라이브러리 로드
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/device.sh"

# 커맨드 모듈 동적 로드 함수
load_command() {
  local cmd=$1
  local cmd_file="${LIB_DIR}/commands/${cmd}.sh"
  
  if [ -f "$cmd_file" ]; then
    source "$cmd_file"
    return 0
  fi
  return 1
}
