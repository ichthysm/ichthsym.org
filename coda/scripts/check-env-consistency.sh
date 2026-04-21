#!/usr/bin/env bash
# check-env-consistency.sh - process.env.* 사용과 .env.example 정합성 체크
# Layer 2 QA Gate 체크
#
# 사용법:
#   ./tools/coda/scripts/check-env-consistency.sh
#
# 환경변수:
#   CODA_CONFIG_FILE: config 파일 경로 (기본: coda/coda.config.json)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# parse-config.sh 로드
source "$SCRIPT_DIR/parse-config.sh"

# 기본값
EXIT_CODE=0
MISSING_COUNT=0

# 색상 (터미널 지원 시)
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  GREEN='\033[0;32m'
  CYAN='\033[0;36m'
  NC='\033[0m'
else
  RED=''
  YELLOW=''
  GREEN=''
  CYAN=''
  NC=''
fi

echo "=== Env Consistency Check ==="

# Config 로드
load_layer2_config || true

# 체크 활성화 여부 확인
if ! is_check_enabled "env_consistency"; then
  echo "[SKIP] env_consistency check is disabled"
  exit 0
fi

# 설정 읽기
SEARCH_DIRS=$(get_check_option "env_consistency" "search_dirs" '["apps/backend/src", "apps/frontend/src"]')
ENV_FILES=$(get_check_option "env_consistency" "env_files" '["apps/backend/.env.example", "apps/frontend/.env.example", "infra/docker/.env.example"]')
IGNORE_VARS=$(get_check_option "env_consistency" "ignore_vars" '["NODE_ENV", "PORT"]')

# JSON 배열 파싱
readarray -t SEARCH_DIR_ARRAY < <(python3 -c "
import json
dirs = json.loads('$SEARCH_DIRS')
for d in dirs:
    print(d)
" 2>/dev/null || echo -e "apps/backend/src\napps/frontend/src")

readarray -t ENV_FILE_ARRAY < <(python3 -c "
import json
files = json.loads('$ENV_FILES')
for f in files:
    print(f)
" 2>/dev/null || echo -e "apps/backend/.env.example\napps/frontend/.env.example\ninfra/docker/.env.example")

readarray -t IGNORE_VAR_ARRAY < <(python3 -c "
import json
vars = json.loads('$IGNORE_VARS')
for v in vars:
    print(v)
" 2>/dev/null || echo -e "NODE_ENV\nPORT")

echo "Search directories: ${SEARCH_DIR_ARRAY[*]}"
echo "Env files: ${ENV_FILE_ARRAY[*]}"
echo "Ignored vars: ${IGNORE_VAR_ARRAY[*]}"
echo ""

cd "$PROJECT_ROOT"

# 1. process.env.* 패턴 추출
extract_env_vars() {
  local search_dir="$1"
  local env_vars=()

  if [[ ! -d "$PROJECT_ROOT/$search_dir" ]]; then
    return
  fi

  # process.env.VAR_NAME 패턴 추출
  while IFS= read -r line; do
    [[ -n "$line" ]] && env_vars+=("$line")
  done < <(grep -rhoE 'process\.env\.([A-Z][A-Z0-9_]*)' "$PROJECT_ROOT/$search_dir" \
    --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" 2>/dev/null \
    | sed 's/process\.env\.//' | sort -u || true)

  printf '%s\n' "${env_vars[@]}"
}

# 2. .env.example에서 변수 추출
extract_env_example_vars() {
  local env_file="$1"
  local vars=()

  if [[ ! -f "$PROJECT_ROOT/$env_file" ]]; then
    return
  fi

  while IFS= read -r line; do
    # 주석과 빈 줄 제외
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    # KEY=value 형식에서 KEY 추출
    if [[ "$line" =~ ^([A-Z][A-Z0-9_]*)= ]]; then
      vars+=("${BASH_REMATCH[1]}")
    fi
  done < "$PROJECT_ROOT/$env_file"

  printf '%s\n' "${vars[@]}"
}

# 3. 무시할 변수인지 체크
should_ignore_var() {
  local var="$1"

  for ignored in "${IGNORE_VAR_ARRAY[@]}"; do
    if [[ "$var" == "$ignored" ]]; then
      return 0
    fi
  done

  return 1
}

# 4. 모든 .env.example 변수 수집
declare -A ALL_ENV_VARS

for env_file in "${ENV_FILE_ARRAY[@]}"; do
  if [[ -f "$PROJECT_ROOT/$env_file" ]]; then
    while IFS= read -r var; do
      [[ -n "$var" ]] && ALL_ENV_VARS["$var"]=1
    done < <(extract_env_example_vars "$env_file")
  fi
done

echo -e "${CYAN}Found ${#ALL_ENV_VARS[@]} variables in .env.example files${NC}"
echo ""

# 5. 코드에서 사용하는 환경변수 수집 및 체크
declare -A USED_ENV_VARS
declare -a MISSING_VARS=()

for search_dir in "${SEARCH_DIR_ARRAY[@]}"; do
  if [[ ! -d "$PROJECT_ROOT/$search_dir" ]]; then
    echo "[WARN] Search directory not found: $search_dir"
    continue
  fi

  echo "Scanning: $search_dir"

  while IFS= read -r var; do
    [[ -z "$var" ]] && continue
    USED_ENV_VARS["$var"]=1
  done < <(extract_env_vars "$search_dir")
done

echo ""
echo "Checking ${#USED_ENV_VARS[@]} unique environment variables..."
echo ""

# 6. 누락된 변수 찾기
for var in "${!USED_ENV_VARS[@]}"; do
  # 무시 목록 체크
  if should_ignore_var "$var"; then
    continue
  fi

  # .env.example에 있는지 체크
  if [[ -z "${ALL_ENV_VARS[$var]:-}" ]]; then
    MISSING_VARS+=("$var")
    ((MISSING_COUNT++))
  fi
done

# 7. 결과 출력
echo "=== Results ==="
echo ""

if [[ $MISSING_COUNT -gt 0 ]]; then
  echo -e "${YELLOW}[ENV-MISS]${NC} Found $MISSING_COUNT environment variable(s) not in .env.example:"
  echo ""

  for var in "${MISSING_VARS[@]}"; do
    echo -e "  ${YELLOW}[ENV-MISS]${NC} $var"

    # 어디서 사용되는지 찾기
    for search_dir in "${SEARCH_DIR_ARRAY[@]}"; do
      if [[ -d "$PROJECT_ROOT/$search_dir" ]]; then
        locations=$(grep -rl "process\.env\.$var" "$PROJECT_ROOT/$search_dir" \
          --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" 2>/dev/null \
          | head -3 | sed "s|$PROJECT_ROOT/||g" || true)

        if [[ -n "$locations" ]]; then
          echo "$locations" | while read -r loc; do
            echo "             → $loc"
          done
        fi
      fi
    done
  done

  echo ""
  echo "These variables are used in code but not documented in .env.example files."
  echo "Consider adding them to the appropriate .env.example file."
  echo ""
  echo "To ignore specific variables, add them to layer2_checks.env_consistency.ignore_vars"
  echo "in coda.config.json"

  # Warning only, not blocking
  EXIT_CODE=0
else
  echo -e "${GREEN}[OK]${NC} All environment variables are documented in .env.example"
fi

echo ""
echo "=== Summary ==="
echo "Variables in .env.example: ${#ALL_ENV_VARS[@]}"
echo "Variables used in code: ${#USED_ENV_VARS[@]}"
echo "Missing from .env.example: $MISSING_COUNT"

exit $EXIT_CODE
