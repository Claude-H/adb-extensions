#!/bin/bash
#@@BUILD_EXCLUDE_START
# ═══════════════════════════════════════════════════
# ACTIVITIES Command
# Activity Stack 조회
# ═══════════════════════════════════════════════════
#@@BUILD_EXCLUDE_END

# Completion definition: command name and description
: <<'AK_COMPLETION_DESC'
activities:Show activity stack
AK_COMPLETION_DESC

# Completion handler: zsh completion code for activities command
: <<'AK_COMPLETION'
        activities)
          _arguments \
            '(- *)'{-h,--help}'[Show help for this command]' \
            '(-a --all)'{-a,--all}'[Show all tasks]'
          ;;
AK_COMPLETION

show_help_activities() {
    echo -e "${CYAN}${BOLD}Usage:${NC} ak activities [-h|--help] [-a|--all]"
    echo
    echo "Description: Display the activity stack of running applications."
    echo
    echo "Options:"
    echo "  -h, --help  Show this help message"
    echo "  (none)      Show foreground task's activity stack (default)"
    echo "  -a, --all   Show all tasks' activity stacks"
    echo
    exit 1
}

# 단일 태스크의 activities 파싱 및 출력
parse_and_display_activities() {
  local activities="$1"
  local current_task="$2"
  
  echo -e "${BOLD}==> Activity Stack (Task ${CYAN}#${current_task}${NC})"
  
  local count=0
  local max_hist=0
  
  # 최대 Hist 번호 찾기
  while IFS= read -r line; do
    local hist_num=$(echo "$line" | sed -n 's/.*Hist.*#\([0-9]*\).*/\1/p')
    if [ -n "$hist_num" ] && [ "$hist_num" -gt "$max_hist" ]; then
      max_hist=$hist_num
    fi
  done <<< "$activities"
  
  # 각 Hist 라인 처리
  while IFS= read -r line; do
    # Hist 번호 추출
    local hist_num=$(echo "$line" | sed -n 's/.*Hist.*#\([0-9]*\).*/\1/p')
    
    # 패키지/액티비티 추출
    local full_activity=$(echo "$line" | sed -n 's/.* u0 \(.*\) t[0-9]*}/\1/p')
    
    if [ -n "$full_activity" ]; then
      ((count++))
      
      # Top Activity (최대 번호)
      if [ "$hist_num" -eq "$max_hist" ]; then
        echo -e "  ${CYAN}[#${hist_num}]${NC} ${full_activity}"
      # Root (#0)
      elif [ "$hist_num" -eq 0 ]; then
        echo -e "  ${GREEN}[#${hist_num}]${NC} ${full_activity}"
      # 중간 Activities
      else
        echo -e "  ${YELLOW}[#${hist_num}]${NC} ${full_activity}"
      fi
    fi
  done <<< "$activities"
  
  echo -e "${DIM}Total: ${count} activities in this task${NC}"
  echo
}

# 모든 태스크 파싱 및 출력
parse_and_display_all_tasks() {
  local dumpsys_output="$1"
  
  # 모든 Hist 라인 추출
  local all_activities
  all_activities=$(echo "$dumpsys_output" | grep -i "Hist")
  
  # Task ID 목록 추출 (출력 순서 유지하면서 중복 제거)
  local task_ids
  task_ids=$(echo "$all_activities" | sed -n 's/.* t\([0-9]*\)}/\1/p' | awk '!seen[$0]++')
  
  local task_count=0
  
  # 각 Task별로 출력
  while IFS= read -r task_id; do
    if [ -n "$task_id" ]; then
      ((task_count++))
      
      # 해당 Task의 activities만 필터링
      local task_activities
      task_activities=$(echo "$all_activities" | grep "t${task_id}}")
      
      if [ -n "$task_activities" ]; then
        parse_and_display_activities "$task_activities" "$task_id"
      fi
    fi
  done <<< "$task_ids"
  
  if [ $task_count -eq 0 ]; then
    echo -e "${ERROR} No tasks found."
    exit 1
  fi
}

cmd_activities() {
  local show_all=0
  
  # 옵션 파싱
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)
        show_help_activities
        ;;
      -a|--all)
        show_all=1
        shift
        ;;
      -*)
        echo -e "${ERROR} Invalid option: $1"
        echo "Try 'ak activities --help' for more information."
        exit 1
        ;;
      *)
        echo -e "${ERROR} Unexpected argument: $1"
        echo "Try 'ak activities --help' for more information."
        exit 1
        ;;
    esac
  done
  
  # 디바이스 선택
  find_and_select_device
  
  echo
  echo -e "${BLUE}==> ${BOLD}Fetching activity stack...${NC}"
  echo
  
  # dumpsys 출력 가져오기
  local dumpsys_output
  dumpsys_output=$(adb -s "$G_SELECTED_DEVICE" shell dumpsys activity activities)
  
  # 포그라운드 태스크 ID 찾기
  local foreground_task
  foreground_task=$(echo "$dumpsys_output" | sed -n 's/.* t\([0-9]*\)}/\1/p' | head -n 1)
  
  if [ -z "$foreground_task" ]; then
    echo -e "${ERROR} No foreground activity found."
    exit 1
  fi
  
  # Hist 라인 파싱
  local activities
  if [ $show_all -eq 1 ]; then
    # 모든 태스크의 activities 가져오기
    activities=$(echo "$dumpsys_output" | grep -i "Hist")
  else
    # 포그라운드 태스크만 필터링
    activities=$(echo "$dumpsys_output" | grep -i "Hist" | grep "t${foreground_task}}")
  fi
  
  if [ -z "$activities" ]; then
    echo -e "${ERROR} No activities found."
    exit 1
  fi
  
  # 파싱 및 출력
  if [ $show_all -eq 1 ]; then
    parse_and_display_all_tasks "$dumpsys_output"
  else
    parse_and_display_activities "$activities" "$foreground_task"
  fi
}
