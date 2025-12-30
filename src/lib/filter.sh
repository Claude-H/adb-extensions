#!/bin/bash
#@@BUILD_EXCLUDE_START
# ═══════════════════════════════════════════════════
# Filtering Functions
# 필터링 및 하이라이팅 함수
# ═══════════════════════════════════════════════════
#@@BUILD_EXCLUDE_END

# 순차 매칭 함수: 입력 문자열의 각 문자가 대상 문자열에 순서대로 존재하는지 확인 (Bash 3.2 호환)
matches_sequential() {
  local text_lower="$1"      # 소문자 변환된 항목 텍스트
  local filter_lower="$2"    # 소문자 변환된 필터 텍스트
  
  # 공백 제거 (텍스트와 필터 모두)
  text_lower="${text_lower// /}"
  filter_lower="${filter_lower// /}"
  
  local text_len=${#text_lower}
  local filter_len=${#filter_lower}
  local text_pos=0
  local filter_pos=0
  
  # 필터의 각 문자를 순차적으로 찾음
  while [ $filter_pos -lt $filter_len ] && [ $text_pos -lt $text_len ]; do
    local filter_char="${filter_lower:$filter_pos:1}"
    local text_char="${text_lower:$text_pos:1}"
    
    if [ "$filter_char" = "$text_char" ]; then
      ((filter_pos++))
    fi
    ((text_pos++))
  done
  
  # 모든 필터 문자를 찾았으면 매칭 성공
  [ $filter_pos -eq $filter_len ]
}

# 하이라이트 계산 함수: 순차 매칭된 문자들을 연속된 블록으로 그룹화하여 하이라이팅 (Bash 3.2 호환)
# 연속 블록 우선 매칭: 가능한 한 긴 연속 블록을 형성하도록 매칭
# 공백 무시: 텍스트와 필터의 공백을 무시하고 매칭
compute_highlight() {
  local text="$1"
  local filter_lower="$2"  # 이미 소문자 변환된 필터 텍스트
  
  if [ -z "$filter_lower" ]; then
    echo "$text"
    return
  fi
  
  # 텍스트를 소문자로 변환
  local text_lower=$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')
  
  # 공백이 제거된 버전 (매칭용)
  local text_lower_no_space="${text_lower// /}"
  local filter_lower_no_space="${filter_lower// /}"
  
  local text_len=${#text}
  local text_len_no_space=${#text_lower_no_space}
  local filter_len_no_space=${#filter_lower_no_space}
  local result=""
  
  # 원본 텍스트 위치 → 공백 제거 텍스트 위치 매핑
  declare -a pos_map=()  # pos_map[원본위치] = 공백제거위치
  local no_space_pos=0
  for ((i=0; i<text_len; i++)); do
    local char="${text_lower:$i:1}"
    if [ "$char" != " " ]; then
      pos_map[$i]=$no_space_pos
      ((no_space_pos++))
    else
      pos_map[$i]=-1  # 공백 표시
    fi
  done
  
  # 연속 블록 우선 매칭 전략 (공백 제거된 텍스트 기준)
  declare -a match_positions_no_space=()  # 공백 제거 텍스트에서의 매칭 위치
  
  local filter_pos=0
  local text_pos=0
  local last_match_pos=-2
  
  # 1단계: 연속 블록을 우선하는 매칭 (공백 제거 버전)
  while [ $filter_pos -lt $filter_len_no_space ] && [ $text_pos -lt $text_len_no_space ]; do
    local filter_char="${filter_lower_no_space:$filter_pos:1}"
    local text_char="${text_lower_no_space:$text_pos:1}"
    
    if [ "$text_char" = "$filter_char" ]; then
      # 다음 필터 문자도 연속으로 매칭되는지 lookahead 확인
      local next_consecutive=0
      if [ $filter_pos -lt $((filter_len_no_space - 1)) ]; then
        local next_filter_char="${filter_lower_no_space:$((filter_pos + 1)):1}"
        local next_text_char="${text_lower_no_space:$((text_pos + 1)):1}"
        if [ "$next_text_char" = "$next_filter_char" ]; then
          next_consecutive=1
        fi
      fi
      
      # 현재 위치가 이전 매칭과 연속인지 확인
      local is_continuing=$((last_match_pos + 1 == text_pos))
      
      # 연속 블록을 형성하거나, 다음이 연속 매칭이면 현재 위치를 선택
      if [ $is_continuing -eq 1 ] || [ $next_consecutive -eq 1 ]; then
        match_positions_no_space+=($text_pos)
        last_match_pos=$text_pos
        ((filter_pos++))
        ((text_pos++))
      else
        # 더 나은 연속 매칭을 찾기 위해 앞을 조금 더 탐색
        local look_ahead_limit=10
        local found_better=0
        local check_pos=$((text_pos + 1))
        
        while [ $check_pos -lt $text_len_no_space ] && [ $((check_pos - text_pos)) -lt $look_ahead_limit ]; do
          local check_char="${text_lower_no_space:$check_pos:1}"
          if [ "$check_char" = "$filter_char" ]; then
            # 다음 문자도 연속으로 매칭되는지 확인
            if [ $filter_pos -lt $((filter_len_no_space - 1)) ]; then
              local next_filter="${filter_lower_no_space:$((filter_pos + 1)):1}"
              local next_check="${text_lower_no_space:$((check_pos + 1)):1}"
              if [ "$next_check" = "$next_filter" ]; then
                found_better=1
                text_pos=$check_pos
                break
              fi
            fi
          fi
          ((check_pos++))
        done
        
        # 더 나은 매칭을 못 찾았으면 현재 위치 사용
        if [ $found_better -eq 0 ]; then
          match_positions_no_space+=($text_pos)
          last_match_pos=$text_pos
          ((filter_pos++))
          ((text_pos++))
        fi
      fi
    else
      ((text_pos++))
    fi
  done
  
  # 2단계: 공백 제거 위치 → 원본 위치로 변환
  declare -a match_positions_original=()
  for match_no_space in "${match_positions_no_space[@]}"; do
    # 원본 텍스트에서 해당하는 위치 찾기
    for ((i=0; i<text_len; i++)); do
      if [ ${pos_map[$i]} -eq $match_no_space ]; then
        match_positions_original+=($i)
        break
      fi
    done
  done
  
  # 3단계: 연속 블록 식별 및 하이라이팅 (원본 텍스트 기준)
  if [ ${#match_positions_original[@]} -eq 0 ]; then
    echo "$text"
    return
  fi
  
  local in_block=0
  local last_pos=-2
  
  for i in $(seq 0 $((text_len - 1))); do
    local is_match=0
    
    # 현재 위치가 매칭 위치인지 확인
    for match_pos in "${match_positions_original[@]}"; do
      if [ $i -eq $match_pos ]; then
        is_match=1
        break
      fi
    done
    
    if [ $is_match -eq 1 ]; then
      # 매칭된 문자
      if [ $in_block -eq 0 ] || [ $((last_pos + 1)) -ne $i ]; then
        # 새로운 블록 시작
        if [ $in_block -eq 1 ]; then
          result+=$'\033[0m'
        fi
        result+=$'\033[43m\033[30m'
        in_block=1
      fi
      result+="${text:$i:1}"
      last_pos=$i
    else
      # 매칭되지 않은 문자 (공백 포함)
      if [ $in_block -eq 1 ]; then
        result+=$'\033[0m'
        in_block=0
      fi
      result+="${text:$i:1}"
    fi
  done
  
  # 마지막 블록 종료
  if [ $in_block -eq 1 ]; then
    result+=$'\033[0m'
  fi
  
  echo "$result"
}

# 필터링 함수: filter_text 기반으로 항목 필터링 (Bash 3.2 호환)
apply_filter() {
  debug_log "apply_filter START: filter_text='$filter_text'"
  
  # 입력값이 없으면 필터링을 건너뛰고 전체 항목을 그대로 반환
  if [ -z "$filter_text" ]; then
    filtered_indices=()
    display_items=()
    highlighted_items=()
    filter_text_lower=""
    
    for ((i=0; i<item_count; i++)); do
      filtered_indices+=("$i")
      display_items+=("${items[$i]}")
      highlighted_items+=("${items[$i]}")  # 원본 그대로
    done
    debug_log "apply_filter: no filter, returning all $item_count items"
    return
  fi
  
  # 필터링 로직 (입력값이 있는 경우에만 실행)
  filtered_indices=()
  display_items=()
  highlighted_items=()
  
  # 필터 텍스트를 소문자로 변환 (한 번만)
  filter_text_lower=$(printf '%s' "$filter_text" | tr '[:upper:]' '[:lower:]')
  
  # 중복 체크용 배열 (Bash 3.2 호환)
  declare -a added_flags=()
  for ((i=0; i<item_count; i++)); do
    added_flags[$i]=0
  done
  
  # 1단계: 멀티 모드일 때, 선택됨 + 미매칭 항목을 최상단에 배치
  if [ "$mode" = "multi" ]; then
    for ((i=0; i<item_count; i++)); do
      if [ ${selection_status[$i]} -eq 1 ]; then
        local item_lower=$(printf '%s' "${items[$i]}" | tr '[:upper:]' '[:lower:]')
        # 선택됨 + 필터 미매칭 → 최상단 추가
        if ! matches_sequential "$item_lower" "$filter_text_lower"; then
          filtered_indices+=("$i")
          display_items+=("${items[$i]}")
          highlighted_items+=("$(compute_highlight "${items[$i]}" "$filter_text_lower")")
          added_flags[$i]=1
        fi
      fi
    done
  fi
  
  # 2단계: 필터 조건에 맞는 모든 항목 추가 (선택 여부 무관, 원래 순서 유지)
  for ((i=0; i<item_count; i++)); do
    if [ ${added_flags[$i]} -eq 0 ]; then
      local item_lower=$(printf '%s' "${items[$i]}" | tr '[:upper:]' '[:lower:]')
      
      if matches_sequential "$item_lower" "$filter_text_lower"; then
        filtered_indices+=("$i")
        display_items+=("${items[$i]}")
        # 하이라이트 사전 계산 (서브셸 1회만)
        highlighted_items+=("$(compute_highlight "${items[$i]}" "$filter_text_lower")")
        added_flags[$i]=1
      fi
    fi
  done
  
  # 포커스가 필터 범위를 벗어나면 첫 번째 항목으로 리셋
  if [ ${#filtered_indices[@]} -gt 0 ]; then
    if [ $focused -ge ${#filtered_indices[@]} ]; then
      focused=0
    fi
  else
    focused=0
  fi
  
  debug_log "apply_filter END: filtered ${#filtered_indices[@]} items from $item_count"
}

