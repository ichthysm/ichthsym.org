#!/usr/bin/env bash
# parse-config.sh - CODA config 파싱 헬퍼
# Layer 2 체크 설정을 읽고 활성화 여부를 확인하는 함수 제공
#
# 사용법:
#   source tools/coda/scripts/parse-config.sh
#   load_layer2_config
#   if is_check_enabled "build"; then ... fi

set -euo pipefail

# 전역 변수
LAYER2_CONFIG=""
CODA_CONFIG_FILE="${CODA_CONFIG_FILE:-coda/coda.config.json}"

# load_layer2_config - layer2_checks 설정을 로드
# Returns: 0 on success, 1 on failure
load_layer2_config() {
  local config_file="${1:-$CODA_CONFIG_FILE}"

  if [[ ! -f "$config_file" ]]; then
    echo "[WARN] Config file not found: $config_file" >&2
    LAYER2_CONFIG="{}"
    return 1
  fi

  LAYER2_CONFIG=$(python3 -c "
import sys
import json

try:
    with open('$config_file', 'r') as f:
        data = json.load(f)
    layer2 = data.get('layer2_checks', {})
    print(json.dumps(layer2))
except Exception as e:
    print('{}', file=sys.stdout)
    print(f'Error loading config: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null) || {
    LAYER2_CONFIG="{}"
    return 1
  }

  return 0
}

# is_check_enabled - 특정 체크가 활성화되어 있는지 확인
# Args:
#   $1: check name (build, test, lint, typecheck 등)
# Returns: 0 if enabled, 1 if disabled
is_check_enabled() {
  local check_name="${1:-}"

  if [[ -z "$check_name" ]]; then
    echo "[ERROR] Check name required" >&2
    return 1
  fi

  # LAYER2_CONFIG가 비어있으면 기본값 true (안전한 기본값)
  if [[ -z "$LAYER2_CONFIG" || "$LAYER2_CONFIG" == "{}" ]]; then
    return 0
  fi

  local enabled
  enabled=$(python3 -c "
import sys
import json

try:
    data = json.loads('$LAYER2_CONFIG')
    check = data.get('$check_name', {})

    # 체크가 없으면 기본 활성화
    if not check:
        print('true')
        sys.exit(0)

    # enabled 필드 확인 (기본값: true)
    enabled = check.get('enabled', True)
    print('true' if enabled else 'false')
except Exception as e:
    # 파싱 오류 시 안전하게 활성화
    print('true')
" 2>/dev/null) || echo "true"

  [[ "$enabled" == "true" ]]
}

# get_check_option - 체크의 특정 옵션 값을 가져옴
# Args:
#   $1: check name
#   $2: option name
#   $3: default value (optional)
# Returns: option value on stdout
get_check_option() {
  local check_name="${1:-}"
  local option_name="${2:-}"
  local default_value="${3:-}"

  if [[ -z "$check_name" || -z "$option_name" ]]; then
    echo "$default_value"
    return
  fi

  # LAYER2_CONFIG가 비어있으면 기본값 반환
  if [[ -z "$LAYER2_CONFIG" || "$LAYER2_CONFIG" == "{}" ]]; then
    echo "$default_value"
    return
  fi

  python3 -c "
import sys
import json

try:
    data = json.loads('$LAYER2_CONFIG')
    check = data.get('$check_name', {})
    value = check.get('$option_name')

    if value is None:
        print('$default_value')
    elif isinstance(value, bool):
        print('true' if value else 'false')
    elif isinstance(value, (list, dict)):
        print(json.dumps(value))
    else:
        print(value)
except:
    print('$default_value')
" 2>/dev/null || echo "$default_value"
}

# 직접 실행 시 테스트
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "=== parse-config.sh 테스트 ==="

  # Config 로드
  if load_layer2_config; then
    echo "[OK] Config loaded successfully"
    echo "LAYER2_CONFIG: $LAYER2_CONFIG"
  else
    echo "[WARN] Config load failed or file not found (using defaults)"
  fi

  # 체크 활성화 테스트
  for check in build test lint typecheck; do
    if is_check_enabled "$check"; then
      echo "[OK] $check: enabled"
    else
      echo "[OK] $check: disabled"
    fi
  done

  echo "=== 테스트 완료 ==="
fi
