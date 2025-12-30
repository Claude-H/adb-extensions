#!/bin/bash
#@@BUILD_EXCLUDE_START
# ═══════════════════════════════════════════════════
# Interactive UI
# 인터랙티브 사용자 선택 UI 함수
# ═══════════════════════════════════════════════════
#@@BUILD_EXCLUDE_END

# 디버그 초기화
debug_init

# 통합 인터랙티브 선택 함수: 단일/멀티 선택 지원
# 사용법: 
#   select_interactive "single" "프롬프트" "${array[@]}"  # 단일 선택
#   select_interactive "multi" "프롬프트" "${array[@]}"   # 멀티 선택
# 
# 결과:
#   Single - SELECTED_ITEM, SELECTED_INDEX
#   Multi - SELECTED_ITEMS[], SELECTED_INDICES[]
select_interactive() {

  
  # Alternate screen 진입 (이전 터미널 히스토리와 완전 분리)
  tput smcup
  
  # 디버그 로그 시작
  debug_log "=== select_interactive START ==="
  debug_log "mode_arg=$1, prompt=$2, item_count=${#}"
  
  # 입력 에코 차단 (방향키 시퀀스가 화면에 표시되지 않도록)
  local old_stty=$(stty -g)
  stty -echo
  
  # 화면 갱신: 깔끔한 선택 UI를 위해 이전 내용 지우기
  clear
  # 스크롤백 버퍼 지우기 (ANSI escape sequence - macOS/Linux 호환)
  printf '\033[3J'

  local mode_arg="$1"
  local prompt="$2"
  shift 2
  local items=("$@")
  local item_count=${#items[@]}
  local focused=0
  local key=""
  
  # 모드와 필터 옵션 파싱
  local mode="${mode_arg%%:*}"        # single 또는 multi
  local enable_filter=1               # 기본값: 활성화
  if [[ "$mode_arg" == *":nofilter"* ]]; then
    enable_filter=0
  fi
  
  # nocasematch 설정 저장 및 활성화 (필터링 성능 최적화)
  local old_nocasematch=$(shopt -p nocasematch 2>/dev/null || echo "shopt -u nocasematch")
  shopt -s nocasematch
  
  # 숫자 표시를 위한 자리수 계산
  local max_digits=${#item_count}
  
  # 멀티 선택 모드용 상태 추적
  declare -a selection_status=()
  declare -a selection_order=()
  if [ "$mode" = "multi" ]; then
    for ((i=0; i<item_count; i++)); do
      selection_status[$i]=0
    done
  fi
  
  # 필터 모드 관련 변수
  local filter_mode=0          # 0: 일반 모드, 1: 필터 입력 모드
  local filter_text=""         # 현재 필터 문자열
  local filter_text_lower=""   # 소문자 변환된 필터 텍스트 (캐시)
  local filter_cursor=0        # 필터 텍스트 내 커서 위치
  declare -a filtered_indices=()  # 필터된 항목의 원본 인덱스
  declare -a display_items=()     # 화면에 표시할 항목 (필터 적용)
  declare -a highlighted_items=() # 하이라이트 적용된 항목 (사전 계산)
  
  # 터미널 크기 변경 감지용 플래그
  TERM_RESIZED=0
  trap 'TERM_RESIZED=1' WINCH
  
  # 마지막 렌더링 라인 추적 (종료 시 커서 위치 조정용)
  local last_render_line=0
  
  # 안전한 종료를 위한 함수들
  # 정상 종료 (선택 완료): 화면 복원 후 return
  restore_terminal() {
    trap - WINCH INT TERM
    # 커서를 마지막 렌더링 위치로 이동 (모든 UI 내용 보존)
    if [ $last_render_line -gt 0 ]; then
      tput cup $last_render_line 0
    fi
    tput cnorm
    stty "$old_stty"
    tput rmcup  # alternate screen 종료 (이전 화면 복원)
  }
  
  # 중단 (Ctrl+C): UI 내용 유지하고 프로그램 종료
  interrupt_handler() {
    trap - WINCH INT TERM
    # 커서를 마지막 렌더링 위치로 이동 (모든 UI 내용 보존)
    if [ $last_render_line -gt 0 ]; then
      tput cup $last_render_line 0
    fi
    tput cnorm
    stty "$old_stty"
    # tput rmcup 생략 → UI 내용이 터미널에 남음
    printf '\n'  # 프롬프트와 구분
    exit 130  # Ctrl+C 표준 exit code
  }
  
  # Ctrl+C만 trap (EXIT는 제거)
  trap interrupt_handler INT TERM

  tput civis # 커서 숨김
  
  # 초기 필터 적용 (전체 항목)
  apply_filter
  
  # #region agent log H2
  debug_log "AGENT_LOG H2: After apply_filter - filtered_indices count=${#filtered_indices[@]}, item_count=$item_count"
  # #endregion
  
  # 초기 항목 수 저장 (패딩 계산 기준)
  local initial_item_count=${#filtered_indices[@]}
  
  # #region agent log H1
  debug_log "AGENT_LOG H1: initial_item_count set to $initial_item_count"
  # #endregion
  
  # 렌더링 상태 추적 변수
  local prev_focused=-1          # 이전 포커스 위치
  local prev_filter_mode=-1      # 이전 필터 모드 상태
  local prev_window_start=-1     # 이전 윈도우 시작 위치
  local need_full_render=1       # 전체 렌더링 필요 플래그
  
  # ═══════════════════════════════════════════════════
  # 렌더링 함수들
  # ═══════════════════════════════════════════════════
  
  # 헤더 렌더링 함수
  render_header() {
    tput cup 0 0
    echo -e "\033[K${BLUE}==> ${BOLD}${prompt}${NC}"
    echo -e "\033[K"
  }
  
  # 필터 박스 렌더링 함수
  render_filter_box() {
    if [ $filter_mode -eq 1 ]; then
      local terminal_width=$(tput cols)
      local line_width=$((terminal_width - 1))
      
      # 상단 라인
      local top_line=$(printf '─%.0s' $(seq 1 $line_width))
      echo -e "\033[K${DIM}${top_line}${NC}"
      
      # 텍스트 내용 준비
      local before_cursor="${filter_text:0:$filter_cursor}"
      local at_cursor="${filter_text:$filter_cursor:1}"
      local after_cursor="${filter_text:$((filter_cursor + 1))}"
      
      # 커서 표시가 포함된 텍스트 (블록 커서 + 색상 반전)
      local display_text=""
      if [ -z "$at_cursor" ]; then
        display_text="${before_cursor}"$'\033[7m'" "$'\033[0m'
      else
        display_text="${before_cursor}"$'\033[7m'"${at_cursor}"$'\033[0m'"${after_cursor}"
      fi
      
      echo -e "\033[K> ${display_text}"
      
      # 하단 라인
      local bottom_line=$(printf '─%.0s' $(seq 1 $line_width))
      echo -e "\033[K${DIM}${bottom_line}${NC}"
    fi
  }
  
  # 필터 박스만 부분 업데이트 (커서 이동 시, 고정 라인 위치)
  render_filter_box_only() {
    if [ $filter_mode -eq 1 ]; then
      # 필터박스 위치: 헤더(2) + 카운터(1) + 아이템공간(max_visible_items) + 헬퍼(2)
      local filter_line=$((3 + max_visible_items + 2))
      debug_log "filter_box_only position: line=$filter_line, max_visible=$max_visible_items"
      
      tput cup $filter_line 0
      local terminal_width=$(tput cols)
      local line_width=$((terminal_width - 1))
      
      # 상단 라인
      local top_line=$(printf '─%.0s' $(seq 1 $line_width))
      echo -e "\033[K${DIM}${top_line}${NC}"
      
      # 텍스트 내용 준비
      local before_cursor="${filter_text:0:$filter_cursor}"
      local at_cursor="${filter_text:$filter_cursor:1}"
      local after_cursor="${filter_text:$((filter_cursor + 1))}"
      
      # 커서 표시가 포함된 텍스트 (블록 커서 + 색상 반전)
      local display_text=""
      if [ -z "$at_cursor" ]; then
        display_text="${before_cursor}"$'\033[7m'" "$'\033[0m'
      else
        display_text="${before_cursor}"$'\033[7m'"${at_cursor}"$'\033[0m'"${after_cursor}"
      fi
      
      echo -e "\033[K> ${display_text}"
      
      # 하단 라인
      local bottom_line=$(printf '─%.0s' $(seq 1 $line_width))
      echo -e "\033[K${DIM}${bottom_line}${NC}"
    fi
  }
  
  # 도움말 렌더링 함수
  render_help() {
    if [ $filter_mode -eq 1 ]; then
      if [ "$mode" = "multi" ]; then
        echo -e "\033[K${DIM}↑/↓: Move  Tab: Toggle  Enter: Confirm  /: Exit filter${NC}"
      else
        echo -e "\033[K${DIM}↑/↓: Move  Enter: Confirm  /: Exit filter${NC}"
      fi
    else
      if [ "$mode" = "multi" ]; then
        if [ $item_count -le 9 ]; then
          if [ $enable_filter -eq 1 ]; then
            echo -e "\033[K${DIM}↑/↓: Move  1-${item_count}: Quick select  Tab/Space: Toggle  A: Toggle All  /: Filter  Enter: Confirm  Ctrl+C: Exit${NC}"
          else
            echo -e "\033[K${DIM}↑/↓: Move  1-${item_count}: Quick select  Tab/Space: Toggle  A: Toggle All  Enter: Confirm  Ctrl+C: Exit${NC}"
          fi
        else
          if [ $enable_filter -eq 1 ]; then
            echo -e "\033[K${DIM}↑/↓: Move  Tab/Space: Toggle  A: Toggle All  /: Filter  Enter: Confirm  Ctrl+C: Exit${NC}"
          else
            echo -e "\033[K${DIM}↑/↓: Move  Tab/Space: Toggle  A: Toggle All  Enter: Confirm  Ctrl+C: Exit${NC}"
          fi
        fi
      else
        if [ $item_count -le 9 ]; then
          if [ $enable_filter -eq 1 ]; then
            echo -e "\033[K${DIM}↑/↓: Navigate  1-${item_count}: Quick select  /: Filter  Enter: Confirm  Ctrl+C: Exit${NC}"
          else
            echo -e "\033[K${DIM}↑/↓: Navigate  1-${item_count}: Quick select  Enter: Confirm  Ctrl+C: Exit${NC}"
          fi
        else
          if [ $enable_filter -eq 1 ]; then
            echo -e "\033[K${DIM}↑/↓: Navigate  /: Filter  Enter: Confirm  Ctrl+C: Exit${NC}"
          else
            echo -e "\033[K${DIM}↑/↓: Navigate  Enter: Confirm  Ctrl+C: Exit${NC}"
          fi
        fi
      fi
    fi
  }
  
  # 카운터 정보 렌더링 함수
  render_counter() {
    local filtered_count=${#filtered_indices[@]}
    local selected_count=0
    
    if [ "$mode" = "multi" ]; then
      for status in "${selection_status[@]}"; do
        if [ $status -eq 1 ]; then
          ((selected_count++))
        fi
      done
    fi
    
    if [ $filtered_count -gt $max_visible_items ]; then
      if [ "$mode" = "multi" ]; then
        if [ -n "$filter_text" ]; then
          echo -e "\033[K${DIM}Showing $((window_start + 1))-${window_end} / ${filtered_count} (filtered from ${item_count}) | ${GREEN}${selected_count} selected${NC}"
        else
          echo -e "\033[K${DIM}Showing $((window_start + 1))-${window_end} / ${filtered_count} | ${GREEN}${selected_count} selected${NC}"
        fi
      else
        if [ -n "$filter_text" ]; then
          echo -e "\033[K${DIM}Showing $((window_start + 1))-${window_end} / ${filtered_count} (filtered from ${item_count})${NC}"
        else
          echo -e "\033[K${DIM}Showing $((window_start + 1))-${window_end} / ${filtered_count}${NC}"
        fi
      fi
    else
      if [ "$mode" = "multi" ]; then
        if [ -n "$filter_text" ]; then
          echo -e "\033[K${DIM}${filtered_count} item(s) (filtered from ${item_count}) | ${GREEN}${selected_count} selected${NC}"
        else
          echo -e "\033[K${DIM}${filtered_count} item(s) | ${GREEN}${selected_count} selected${NC}"
        fi
      else
        if [ -n "$filter_text" ]; then
          echo -e "\033[K${DIM}${filtered_count} item(s) (filtered from ${item_count})${NC}"
        else
          echo -e "\033[K${DIM}${filtered_count} item(s)${NC}"
        fi
      fi
    fi
  }
  
  # 단일 항목 렌더링 함수
  render_single_item() {
    local display_idx=$1
    local original_idx=${filtered_indices[$display_idx]}
    local number=$((original_idx + 1))
    local checkbox=""
    
    if [ "$mode" = "multi" ]; then
      if [ ${selection_status[$original_idx]} -eq 1 ]; then
        checkbox="[✓] "
      else
        checkbox="[ ] "
      fi
    fi
    
    local number_prefix=$(printf "%${max_digits}d. " "$number")
    local highlighted_item="${highlighted_items[$display_idx]}"
    
    if [ $display_idx -eq $focused ]; then
      echo -e "\033[K${CYAN}➤ ${checkbox}${BOLD}${number_prefix}${highlighted_item}${NC}"
    else
      if [ "$mode" = "multi" ] && [ ${selection_status[$original_idx]} -eq 1 ]; then
        echo -e "\033[K  ${GREEN}${checkbox}${NC}${number_prefix}${highlighted_item}"
      else
        echo -e "\033[K  ${checkbox}${number_prefix}${highlighted_item}"
      fi
    fi
  }
  
  # 모든 항목 렌더링 함수
  render_items() {
    local filtered_count=${#filtered_indices[@]}
    for ((display_idx=window_start; display_idx<window_end && display_idx<filtered_count; display_idx++)); do
      render_single_item "$display_idx"
    done
  }
  
  # 공백 패딩 렌더링 함수 (하단 요소 위치 고정용)
  render_padding() {
    # #region agent log H1,H5
    debug_log "AGENT_LOG H1,H5: render_padding called - filter_mode=$filter_mode, initial_item_count=$initial_item_count, window_start=$window_start, window_end=$window_end"
    # #endregion
    
    # 필터 모드가 아니면 패딩 없음 (스크롤 모드에서는 패딩 불필요)
    if [ $filter_mode -ne 1 ]; then
      debug_log "Padding: skipped (not in filter mode)"
      return 0
    fi
    
    local visible_count=$((window_end - window_start))
    local filtered_count=${#filtered_indices[@]}
    
    # 필터링된 항목이 화면을 가득 채우면 패딩 불필요
    if [ $filtered_count -ge $max_visible_items ]; then
      debug_log "Padding: skipped (filtered items >= max_visible, $filtered_count >= $max_visible_items)"
      return 0
    fi
    
    # 패딩 계산: 화면 크기 - 필터링된 항목 수
    local padding_lines=$((max_visible_items - filtered_count))
    
    # #region agent log H1
    debug_log "AGENT_LOG H1: Padding calculation (filter mode) - visible_count=$visible_count, filtered_count=$filtered_count, max_visible_items=$max_visible_items, padding_lines=$padding_lines"
    # #endregion
    
    debug_log "Padding: filter_mode=1, filtered=$filtered_count, max=$max_visible_items, padding=$padding_lines"
    
    for ((i=0; i<padding_lines; i++)); do
      echo -e "\033[K"
    done
  }
  
  # 전체 화면 렌더링 함수
  render_full() {
    debug_log "=== render_full START ==="
    tput cup 0 0
    render_header        # 2줄 (헤더 + 빈줄)
    render_counter       # 1줄
    render_items         # 가변 (실제 표시 항목)
    echo -e "\033[K"     # 항목과 헬퍼 사이 빈줄
    render_padding       # 공백 패딩
    render_help          # 2줄 (도움말 + 빈줄)
    render_filter_box    # 필터모드시 4줄
    printf '\033[J'  # 화면 아래 잔여 내용 지우기
    
    # 마지막 렌더링 라인 계산 (종료 시 커서 위치 조정용)
    # 헤더(2) + 카운터(1) + 항목영역 + 패딩 + 헬퍼(1) + [필터박스(3)]
    local visible_count=$((window_end - window_start))
    local padding_lines=$((initial_item_count - visible_count))
    if [ $padding_lines -lt 0 ]; then
      padding_lines=0
    fi
    last_render_line=$((3 + visible_count + padding_lines + 1))
    if [ $filter_mode -eq 1 ]; then
      last_render_line=$((last_render_line + 3))
    fi
    debug_log "last_render_line calculated: $last_render_line"
    debug_log "=== render_full END ==="
  }
  
  # 카운터만 부분 업데이트 함수
  render_counter_only() {
    tput cup 2 0  # 헤더(2줄) 다음
    render_counter
  }
  
  # 포커스 변경 부분 렌더링 함수 (이전 포커스와 새 포커스만 업데이트)
  render_focus_change() {
    local old_focus=$1
    local new_focus=$2
    
    # 항목 시작 라인 계산 (필터 모드와 관계없이 통일)
    # 헤더(2) + 카운터(1) = 3
    local items_start_line=3
    debug_log "render_focus_change: old=$old_focus, new=$new_focus, items_start_line=$items_start_line"
    
    local filtered_count=${#filtered_indices[@]}
    
    # window 내에서만 렌더링
    # 이전 포커스 라인 업데이트 (일반 항목으로)
    if [ $old_focus -ge $window_start ] && [ $old_focus -lt $window_end ] && [ $old_focus -lt $filtered_count ]; then
      local old_line=$((items_start_line + old_focus - window_start))
      tput cup $old_line 0
      render_single_item "$old_focus"
    fi
    
    # 새 포커스 라인 업데이트 (포커스된 항목으로)
    if [ $new_focus -ge $window_start ] && [ $new_focus -lt $window_end ] && [ $new_focus -lt $filtered_count ]; then
      local new_line=$((items_start_line + new_focus - window_start))
      tput cup $new_line 0
      render_single_item "$new_focus"
    fi
  }

  while true; do
    # 터미널 크기 변경 플래그 확인
    if [ $TERM_RESIZED -eq 1 ]; then
      TERM_RESIZED=0
      debug_log "Terminal resized - triggering full render"
      clear
      printf '\033[3J'
      need_full_render=1
    fi
    
    # 매 루프마다 터미널 높이 재측정
    local terminal_height=$(tput lines)
    
    # reserved_lines는 항상 필터 모드 기준 (최대값)으로 고정
    # 이렇게 해야 모드 전환 시 아이템 공간이 일정하고 하단 요소만 변경됨
    local reserved_lines=9  # 헤더(2) + 카운터(1) + 헬퍼(2) + 필터박스(4)
    
    # #region agent log H4
    debug_log "AGENT_LOG H4: terminal_height=$terminal_height, reserved_lines=$reserved_lines, filter_mode=$filter_mode"
    # #endregion
    
    debug_log "terminal_height=$terminal_height, filter_mode=$filter_mode, reserved_lines=$reserved_lines(fixed)"
    
    local max_visible_items=$((terminal_height - reserved_lines))
    
    if [ $max_visible_items -lt 5 ]; then
      max_visible_items=5
    fi
    
    # #region agent log H4
    debug_log "AGENT_LOG H4: max_visible_items calculated as $max_visible_items"
    # #endregion
    
    debug_log "max_visible_items=$max_visible_items"
    
    local filtered_count=${#filtered_indices[@]}
    
    # 스크롤 윈도우 범위 계산
    local window_start=0
    local window_end=$filtered_count
    
    if [ $filtered_count -gt $max_visible_items ]; then
      window_start=$((focused - max_visible_items / 2))
      
      if [ $window_start -lt 0 ]; then
        window_start=0
      fi
      
      window_end=$((window_start + max_visible_items))
      
      if [ $window_end -gt $filtered_count ]; then
        window_end=$filtered_count
        window_start=$((filtered_count - max_visible_items))
        if [ $window_start -lt 0 ]; then
          window_start=0
        fi
      fi
    fi
    
    # #region agent log H3
    debug_log "AGENT_LOG H3: Window calculation - filtered_count=$filtered_count, max_visible_items=$max_visible_items, window_start=$window_start, window_end=$window_end, focused=$focused"
    # #endregion
    
    debug_log "Window: start=$window_start, end=$window_end, filtered_count=$filtered_count, focused=$focused"

    # 렌더링 결정: 전체 렌더링이 필요한가?
    if [ $need_full_render -eq 1 ] || [ $prev_filter_mode -ne $filter_mode ] || [ $prev_window_start -ne $window_start ]; then
      debug_log "Full render: need_full=$need_full_render, filter_mode_changed=$([[ $prev_filter_mode -ne $filter_mode ]] && echo 1 || echo 0), window_changed=$([[ $prev_window_start -ne $window_start ]] && echo 1 || echo 0)"
      render_full
      need_full_render=0
      prev_filter_mode=$filter_mode
      prev_window_start=$window_start
      prev_focused=$focused
    elif [ $prev_focused -ne $focused ]; then
      # 포커스만 변경: 부분 렌더링
      debug_log "Partial render: focus change only"
      render_focus_change "$prev_focused" "$focused"
      prev_focused=$focused
    fi
    # 아무 변경 없으면 렌더링하지 않음

    # 버퍼에 쌓인 이전 키 입력 제거 (방향키 반응 속도 개선)
    while IFS= read -rsn1 -t 0; do :; done
    
    # 키 입력 대기
    IFS= read -rsn1 key

    # 필터 모드와 일반 모드에 따라 키 처리 분기
    if [ $filter_mode -eq 1 ]; then
      # ===== 필터 입력 모드 =====
      
      # ESC 시퀀스 처리 (2단계 읽기 - 타임아웃 없음으로 안정화)
      if [[ $key == $'\x1b' ]]; then
        # ESC 후 [A, [B 등을 한번에 읽음 (타임아웃 없음)
        IFS= read -rsn2 seq
        
        if [[ $seq == "[A" ]]; then # 위쪽 화살표
          if [ $filtered_count -gt 0 ]; then
            ((focused--))
            if [ $focused -lt 0 ]; then focused=$((filtered_count - 1)); fi
          fi
        elif [[ $seq == "[B" ]]; then # 아래쪽 화살표
          if [ $filtered_count -gt 0 ]; then
            ((focused++))
            if [ $focused -ge $filtered_count ]; then focused=0; fi
          fi
        elif [[ $seq == "[C" ]]; then # 오른쪽 화살표
          if [ $filter_cursor -lt ${#filter_text} ]; then
            ((filter_cursor++))
            render_filter_box_only
          fi
        elif [[ $seq == "[D" ]]; then # 왼쪽 화살표
          if [ $filter_cursor -gt 0 ]; then
            ((filter_cursor--))
            render_filter_box_only
          fi
        elif [[ $seq == "[H" ]]; then # Home 키
          filter_cursor=0
          render_filter_box_only
        elif [[ $seq == "[F" ]]; then # End 키
          filter_cursor=${#filter_text}
          render_filter_box_only
        elif [[ $seq == "[3" ]]; then # Delete 키 시퀀스 시작
          IFS= read -rsn1 # ~ 읽기
          if [ $filter_cursor -lt ${#filter_text} ]; then
            filter_text="${filter_text:0:$filter_cursor}${filter_text:$((filter_cursor + 1))}"
            apply_filter
            need_full_render=1
          fi
        fi
      elif [[ $key == $'\x7f' ]] || [[ $key == $'\x08' ]]; then
        # Backspace
        if [ $filter_cursor -gt 0 ]; then
          filter_text="${filter_text:0:$((filter_cursor - 1))}${filter_text:$filter_cursor}"
          ((filter_cursor--))
          apply_filter
          need_full_render=1
        fi
      elif [[ $key == $'\x01' ]]; then
        # Ctrl+A: 커서를 맨 앞으로
        filter_cursor=0
        render_filter_box_only
      elif [[ $key == $'\x05' ]]; then
        # Ctrl+E: 커서를 맨 뒤로
        filter_cursor=${#filter_text}
        render_filter_box_only
      elif [[ $key == "/" ]]; then
        # / 키: 필터 모드 종료 (토글) 및 필터 초기화
        debug_log "Exiting filter mode"
        filter_text=""
        filter_cursor=0
        filter_mode=0
        apply_filter  # 전체 리스트로 복원
        need_full_render=1
      elif [[ $key == "" ]]; then
        # Enter: 필터링된 결과로 확정
        if [ $filtered_count -eq 0 ]; then
          # 필터링 결과가 없으면 아무것도 하지 않음
          continue
        fi
        
        if [ "$mode" = "multi" ]; then
          # 멀티 모드: 선택된 항목 수 확인
          local selected_count=0
          for status in "${selection_status[@]}"; do
            if [ $status -eq 1 ]; then
              ((selected_count++))
            fi
          done

          # 아무것도 선택하지 않았으면 현재 포커스된 항목 선택
          if [ $selected_count -eq 0 ]; then
            local original_idx=${filtered_indices[$focused]}
            selection_status[$original_idx]=1
            selection_order+=("$original_idx")
          fi
        fi
        break
      elif [[ $key == $'\t' ]]; then
        # Tab 키 - 선택/해제 토글 (멀티 모드만, 필터 모드에서)
        if [ "$mode" = "multi" ] && [ $filtered_count -gt 0 ]; then
          local original_idx=${filtered_indices[$focused]}
          if [ ${selection_status[$original_idx]} -eq 0 ]; then
            # 선택 (Toggle ON)
            selection_status[$original_idx]=1
            selection_order+=("$original_idx")
            # 부분 렌더링: 카운터 + 현재 항목만
            render_counter_only
            # 항목 위치 계산
            local items_start_line=3
            local item_line=$((items_start_line + focused - window_start))
            tput cup $item_line 0
            render_single_item "$focused"
          else
            # 해제 (Toggle OFF)
            selection_status[$original_idx]=0
            # selection_order에서 제거
            local new_order=()
            for idx in "${selection_order[@]}"; do
              if [ "$idx" -ne "$original_idx" ]; then
                new_order+=("$idx")
              fi
            done
            selection_order=("${new_order[@]}")
            apply_filter  # 해제 시에만 호출 → 필터 매칭 체크 (선택됨+미매칭 항목 재정렬)
            need_full_render=1
          fi
        fi
      else
        # 일반 문자/숫자/특수문자 입력
        # 출력 가능한 문자만 허용 (ASCII 32-126)
        local char_code=$(printf '%d' "'$key")
        if [ $char_code -ge 32 ] && [ $char_code -le 126 ]; then
          filter_text="${filter_text:0:$filter_cursor}${key}${filter_text:$filter_cursor}"
          ((filter_cursor++))
          apply_filter
          need_full_render=1
        fi
      fi
      
    else
      # ===== 일반 선택 모드 =====
      
      # ESC 시퀀스 처리 (2단계 읽기 - 타임아웃 없음으로 안정화)
      if [[ $key == $'\x1b' ]]; then
        # ESC 후 [A, [B 등을 한번에 읽음 (타임아웃 없음)
        IFS= read -rsn2 seq
        
        if [[ $seq == "[A" ]]; then # 위쪽 화살표
          ((focused--))
          if [ $focused -lt 0 ]; then focused=$((filtered_count - 1)); fi
        elif [[ $seq == "[B" ]]; then # 아래쪽 화살표
          ((focused++))
          if [ $focused -ge $filtered_count ]; then focused=0; fi
        fi
      fi

      # 키 동작 처리
      case "$key" in
        "") # Enter 키
          if [ $filtered_count -eq 0 ]; then
            # 필터링 결과가 없으면 아무것도 하지 않음
            continue
          fi
          
          if [ "$mode" = "multi" ]; then
            # 멀티 모드: 선택된 항목 수 확인
            local selected_count=0
            for status in "${selection_status[@]}"; do
              if [ $status -eq 1 ]; then
                ((selected_count++))
              fi
            done

            # 아무것도 선택하지 않았으면 현재 포커스된 항목 선택
            if [ $selected_count -eq 0 ]; then
              local original_idx=${filtered_indices[$focused]}
              selection_status[$original_idx]=1
              selection_order+=("$original_idx")
            fi
          fi
          break
          ;;
        "/") # 필터 모드 진입 (enable_filter가 1일 때만)
          if [ $enable_filter -eq 1 ]; then
            debug_log "Entering filter mode"
            filter_mode=1
            need_full_render=1
          fi
          ;;
        "a"|"A") # A/a 키 - 전체 선택/해제 토글 (멀티 모드만)
          if [ "$mode" = "multi" ]; then
            # 모든 항목이 선택되어 있는지 확인
            local all_selected=1
            for status in "${selection_status[@]}"; do
              if [ $status -eq 0 ]; then
                all_selected=0
                break
              fi
            done

            if [ $all_selected -eq 1 ]; then
              # 모두 해제
              for ((i=0; i<item_count; i++)); do
                selection_status[$i]=0
              done
              selection_order=()
            else
              # 모두 선택 (순서대로)
              for ((i=0; i<item_count; i++)); do
                selection_status[$i]=1
                selection_order+=("$i")
              done
            fi
            need_full_render=1
          fi
          ;;
        $'\t'|' ') # Tab/Space 키 - 선택/해제 토글 (멀티 모드만)
          if [ "$mode" = "multi" ] && [ $filtered_count -gt 0 ]; then
            local original_idx=${filtered_indices[$focused]}
            if [ ${selection_status[$original_idx]} -eq 0 ]; then
              selection_status[$original_idx]=1
              selection_order+=("$original_idx")
            else
              selection_status[$original_idx]=0
              # selection_order에서 제거
              local new_order=()
              for idx in "${selection_order[@]}"; do
                if [ "$idx" -ne "$original_idx" ]; then
                  new_order+=("$idx")
                fi
              done
              selection_order=("${new_order[@]}")
            fi
            # 현재 포커스 항목과 카운터만 업데이트 (부분 렌더링)
            render_counter_only
            # 항목 위치로 이동 후 렌더링
            local items_start_line=3
            local item_line=$((items_start_line + focused - window_start))
            tput cup $item_line 0
            render_single_item "$focused"
          fi
          ;;
        [1-9]) # 숫자 키 1-9
          local selected_num=$((key))
          # 유효한 범위인지 확인
          if [ $selected_num -le $item_count ]; then
            if [ "$mode" = "multi" ]; then
              # 멀티 모드: 9개 이하일 때만 해당 항목만 선택하고 확정
              if [ $item_count -le 9 ]; then
                local selected_idx=$((selected_num - 1))
                # 해당 항목만 선택 상태로 변경
                for ((i=0; i<item_count; i++)); do
                  selection_status[$i]=0
                done
                selection_status[$selected_idx]=1
                selection_order=("$selected_idx")
                break
              fi
            else
              # 단일 모드: 9개 이하일 때만 즉시 선택하고 확정
              if [ $item_count -le 9 ]; then
                focused=$((selected_num - 1))
                break
              fi
            fi
          fi
          ;;
      esac
    fi
  done

  # 정상 종료 시 터미널 복원
  restore_terminal
  
  # nocasematch 원래 설정 복원 (안전한 방법)
  if [ -n "$old_nocasematch" ]; then
    eval "$old_nocasematch"
  fi

  # 선택된 항목을 전역 변수에 저장
  if [ "$mode" = "multi" ]; then
    # 멀티 선택: 배열로 저장
    SELECTED_ITEMS=()
    SELECTED_INDICES=()
    for idx in "${selection_order[@]}"; do
      SELECTED_ITEMS+=("${items[$idx]}")
      SELECTED_INDICES+=("$idx")
    done
  else
    # 단일 선택: 단일 값으로 저장
    # focused는 필터링된 배열의 인덱스이므로 원본 인덱스로 변환
    if [ ${#filtered_indices[@]} -gt 0 ]; then
      local original_idx=${filtered_indices[$focused]}
      SELECTED_ITEM="${items[$original_idx]}"
      SELECTED_INDEX=$original_idx
    else
      # 필터링 결과가 없는 경우 (에러 케이스)
      SELECTED_ITEM=""
      SELECTED_INDEX=-1
    fi
  fi
}
