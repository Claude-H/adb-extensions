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
  # 화면 갱신: 깔끔한 선택 UI를 위해 이전 내용 지우기
  clear

  local mode="$1"
  local prompt="$2"
  shift 2
  local items=("$@")
  local item_count=${#items[@]}
  local focused=0
  local key=""
  
  # 멀티 선택 모드용 상태 추적
  declare -a selection_status=()
  declare -a selection_order=()
  if [ "$mode" = "multi" ]; then
    for ((i=0; i<item_count; i++)); do
      selection_status[$i]=0
    done
  fi

  tput civis # 커서 숨김

  while true; do
    # 헤더 출력
    echo -e "${BLUE}==> ${BOLD}${prompt}${NC}"
    echo

    # 항목 출력
    for i in "${!items[@]}"; do
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
        number_prefix="${number}. "
      else
        # 단일 모드: 숫자 표시
        if [ $number -le 9 ]; then
          number_prefix="${number}. "
        else
          number_prefix="○ "
        fi
      fi

      if [ $i -eq $focused ]; then
        # 포커스된 항목 (하이라이트)
        echo -e "${CYAN}➤ ${checkbox}${BOLD}${number_prefix}${items[$i]}${NC}"
      else
        # 일반 항목
        if [ "$mode" = "multi" ] && [ ${selection_status[$i]} -eq 1 ]; then
          # 멀티 모드 & 선택됨: 초록색 체크박스
          echo -e "  ${GREEN}${checkbox}${NC}${number_prefix}${items[$i]}"
        else
          # 선택안됨 또는 단일 모드
          echo -e "  ${checkbox}${number_prefix}${items[$i]}"
        fi
      fi
    done

    # 하단 안내문
    echo
    if [ "$mode" = "multi" ]; then
      if [ $item_count -le 9 ]; then
        echo -e "${DIM}↑/↓: Move  1-${item_count}: Quick select  Space: Toggle  A: Toggle All  Enter: Confirm  Ctrl+C: Exit${NC}"
      else
        echo -e "${DIM}↑/↓: Move  Space: Toggle  A: Toggle All  Enter: Confirm  Ctrl+C: Exit${NC}"
      fi
    else
      if [ $item_count -le 9 ]; then
        echo -e "${DIM}↑/↓: Navigate  1-${item_count}: Quick select  Enter: Confirm  Ctrl+C: Exit${NC}"
      else
        echo -e "${DIM}↑/↓: Navigate  1-9: Quick select  Enter: Confirm  Ctrl+C: Exit${NC}"
      fi
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
            # 단일 모드: 즉시 선택하고 확정
            focused=$((selected_num - 1))
            break
          fi
        fi
        ;;
    esac

    # 화면 갱신을 위해 커서 이동 및 줄 지우기
    local total_lines=$((item_count + 4))
    for ((i=0; i<total_lines; i++)); do
      echo -ne "\033[1A"  # 한 줄 위로
      echo -ne "\033[2K"  # 현재 줄 지우기
    done
  done

  tput cnorm # 커서 보이기
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
