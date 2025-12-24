#!/bin/bash
#@@BUILD_EXCLUDE_START
# ═══════════════════════════════════════════════════
# Interactive UI
# 인터랙티브 사용자 선택 UI 함수
# ═══════════════════════════════════════════════════
#@@BUILD_EXCLUDE_END

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
  
  # 화면 갱신: 깔끔한 선택 UI를 위해 이전 내용 지우기
  clear
  # 스크롤백 버퍼 지우기 (ANSI escape sequence - macOS/Linux 호환)
  printf '\033[3J'

  local mode="$1"
  local prompt="$2"
  shift 2
  local items=("$@")
  local item_count=${#items[@]}
  local focused=0
  local key=""
  
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
  
  # 터미널 크기 변경 감지용 플래그
  TERM_RESIZED=0
  trap 'TERM_RESIZED=1' WINCH

  tput civis # 커서 숨김
  
  # 이전 스크롤 모드 추적 (모드 전환 시 화면 초기화용)
  local prev_scroll_mode=0

  while true; do
    # 터미널 크기 변경 플래그 확인
    if [ $TERM_RESIZED -eq 1 ]; then
      TERM_RESIZED=0
    fi
    
    # 매 루프마다 터미널 높이 재측정
    local terminal_height=$(tput lines)
    local reserved_lines=6  # 헤더(2) + 카운터(1) + 빈줄(1) + 안내문(2)
    local min_required_height=8
    local use_scroll_mode=0
    local max_visible_items
    
    # 최소 높이 검증
    if [ $terminal_height -lt $min_required_height ]; then
      # 터미널이 너무 작으면 일반 스크롤 모드로 전환
      use_scroll_mode=1
      max_visible_items=$item_count
    else
      max_visible_items=$((terminal_height - reserved_lines))
    fi
    
    # 스크롤 모드에서 일반 모드로 전환될 때 화면 초기화
    if [ $prev_scroll_mode -eq 1 ] && [ $use_scroll_mode -eq 0 ]; then
      clear
      printf '\033[3J'
    fi
    prev_scroll_mode=$use_scroll_mode
    
    # 스크롤 윈도우 범위 계산
    local window_start=0
    local window_end=$item_count
    
    if [ $item_count -gt $max_visible_items ] && [ $use_scroll_mode -eq 0 ]; then
      # 포커스된 항목이 보이도록 윈도우 계산
      window_start=$((focused - max_visible_items / 2))
      
      # 윈도우가 범위를 벗어나지 않도록 조정
      if [ $window_start -lt 0 ]; then
        window_start=0
      fi
      
      window_end=$((window_start + max_visible_items))
      
      if [ $window_end -gt $item_count ]; then
        window_end=$item_count
        window_start=$((item_count - max_visible_items))
        if [ $window_start -lt 0 ]; then
          window_start=0
        fi
      fi
    fi

    # 일반 모드에서만 커서를 화면 맨 위로 이동 (화면 덮어쓰기)
    if [ $use_scroll_mode -eq 0 ]; then
      tput cup 0 0
    fi

    # 헤더 출력
    echo -e "\033[K${BLUE}==> ${BOLD}${prompt}${NC}"
    echo -e "\033[K"
    
    # 선택된 항목 수 계산 (멀티 모드)
    local selected_count=0
    if [ "$mode" = "multi" ]; then
      for status in "${selection_status[@]}"; do
        if [ $status -eq 1 ]; then
          ((selected_count++))
        fi
      done
    fi
    
    # 항목 수 인디케이터 (항상 표시)
    if [ $item_count -gt $max_visible_items ] && [ $use_scroll_mode -eq 0 ]; then
      # 스크롤이 필요한 경우
      if [ "$mode" = "multi" ]; then
        echo -e "\033[K${DIM}Showing $((window_start + 1))-${window_end} / ${item_count} | ${GREEN}${selected_count} selected${NC}"
      else
        echo -e "\033[K${DIM}Showing $((window_start + 1))-${window_end} / ${item_count}${NC}"
      fi
    else
      # 모든 항목이 보이는 경우
      if [ "$mode" = "multi" ]; then
        echo -e "\033[K${DIM}${item_count} item(s) | ${GREEN}${selected_count} selected${NC}"
      else
        echo -e "\033[K${DIM}${item_count} item(s)${NC}"
      fi
    fi

    # 윈도우 범위 내의 항목만 출력
    for ((i=window_start; i<window_end && i<item_count; i++)); do
      local number=$((i + 1))
      local number_prefix=""
      local checkbox=""
      
      # 멀티 모드: 체크박스 표시
      if [ "$mode" = "multi" ]; then
        if [ ${selection_status[$i]} -eq 1 ]; then
          checkbox="[✓] "
        else
          checkbox="[ ] "
        fi
      fi
      
      # 자리수 맞춤 (예: 100개 항목이면 "  1. ", " 10. ", "100. ")
      number_prefix=$(printf "%${max_digits}d. " "$number")

      if [ $i -eq $focused ]; then
        # 포커스된 항목 (하이라이트)
        echo -e "\033[K${CYAN}➤ ${checkbox}${BOLD}${number_prefix}${items[$i]}${NC}"
      else
        # 일반 항목
        if [ "$mode" = "multi" ] && [ ${selection_status[$i]} -eq 1 ]; then
          # 멀티 모드 & 선택됨: 초록색 체크박스
          echo -e "\033[K  ${GREEN}${checkbox}${NC}${number_prefix}${items[$i]}"
        else
          # 선택안됨 또는 단일 모드
          echo -e "\033[K  ${checkbox}${number_prefix}${items[$i]}"
        fi
      fi
    done

    # 하단 안내문
    echo -e "\033[K"
    if [ "$mode" = "multi" ]; then
      if [ $item_count -le 9 ]; then
        echo -e "\033[K${DIM}↑/↓: Move  1-${item_count}: Quick select  Space: Toggle  A: Toggle All  Enter: Confirm  Ctrl+C: Exit${NC}"
      else
        echo -e "\033[K${DIM}↑/↓: Move  Space: Toggle  A: Toggle All  Enter: Confirm  Ctrl+C: Exit${NC}"
      fi
    else
      if [ $item_count -le 9 ]; then
        echo -e "\033[K${DIM}↑/↓: Navigate  1-${item_count}: Quick select  Enter: Confirm  Ctrl+C: Exit${NC}"
      else
        echo -e "\033[K${DIM}↑/↓: Navigate  Enter: Confirm  Ctrl+C: Exit${NC}"
      fi
    fi

    # 일반 모드에서만 화면 아래 잔여 내용 지우기 (현재 커서 위치부터 화면 끝까지)
    if [ $use_scroll_mode -eq 0 ]; then
      printf '\033[J'
    fi

    # 키 입력 대기
    IFS= read -rsn1 key

    # ESC 시퀀스 처리 (방향키 등)
    if [[ $key == $'\x1b' ]]; then
      IFS= read -rsn2 key
      if [[ $key == "[A" ]]; then # 위쪽 화살표
        ((focused--))
        if [ $focused -lt 0 ]; then focused=$((item_count - 1)); fi
      elif [[ $key == "[B" ]]; then # 아래쪽 화살표
        ((focused++))
        if [ $focused -ge $item_count ]; then focused=0; fi
      fi
    fi

    # 키 동작 처리
    case "$key" in
      "") # Enter 키
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
            selection_status[$focused]=1
            selection_order+=("$focused")
          fi
        fi
        break
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
        fi
        ;;
      " ") # Space 키 - 선택/해제 토글 (멀티 모드만)
        if [ "$mode" = "multi" ]; then
          if [ ${selection_status[$focused]} -eq 0 ]; then
            selection_status[$focused]=1
            selection_order+=("$focused")
          else
            selection_status[$focused]=0
            # selection_order에서 제거
            local new_order=()
            for idx in "${selection_order[@]}"; do
              if [ "$idx" -ne "$focused" ]; then
                new_order+=("$idx")
              fi
            done
            selection_order=("${new_order[@]}")
          fi
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
  done

  # 트랩 정리
  trap - WINCH
  
  tput cnorm # 커서 보이기
  
  # Alternate screen 종료 (원래 터미널로 복귀)
  tput rmcup
  echo  # 마지막 줄바꿈

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
    SELECTED_ITEM="${items[$focused]}"
    SELECTED_INDEX=$focused
  fi
}
