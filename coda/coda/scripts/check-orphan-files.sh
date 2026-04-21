#!/usr/bin/env bash
# check-orphan-files.sh - 신규 파일이 어디서도 import되지 않는지 체크
# Layer 2 QA Gate 체크
#
# 사용법:
#   ./tools/coda/scripts/check-orphan-files.sh [base_branch]
#
# 환경변수:
#   CODA_CONFIG_FILE: config 파일 경로 (기본: coda/coda.config.json)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# parse-config.sh 로드
source "$SCRIPT_DIR/parse-config.sh"

# 기본값
BASE_BRANCH="${1:-master}"
EXIT_CODE=0
ORPHAN_COUNT=0

# 색상 (터미널 지원 시)
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  GREEN='\033[0;32m'
  NC='\033[0m'
else
  RED=''
  YELLOW=''
  GREEN=''
  NC=''
fi

echo "=== Orphan Files Check ==="

# Config 로드
load_layer2_config || true

# 체크 활성화 여부 확인
if ! is_check_enabled "orphan_files"; then
  echo "[SKIP] orphan_files check is disabled"
  exit 0
fi

# 설정 읽기
EXTENSIONS=$(get_check_option "orphan_files" "extensions" '[]')
IGNORE_PATTERNS=$(get_check_option "orphan_files" "ignore_patterns" '[]')

# extensions 파싱 (JSON 배열 → bash 배열)
readarray -t EXT_ARRAY < <(python3 -c "
import json
exts = json.loads('$EXTENSIONS')
for ext in exts:
    print(ext)
" 2>/dev/null || echo -e ".ts\n.tsx\n.css\n.scss")

# ignore_patterns 파싱
readarray -t IGNORE_ARRAY < <(python3 -c "
import json
patterns = json.loads('$IGNORE_PATTERNS')
for p in patterns:
    print(p)
" 2>/dev/null || echo -e "*.test.*\n*.spec.*\n*.d.ts\nmigrations/*")

echo "Base branch: $BASE_BRANCH"
echo "Extensions: ${EXT_ARRAY[*]:-'.ts .tsx .css .scss'}"
echo "Ignore patterns: ${IGNORE_ARRAY[*]:-'*.test.* *.spec.* *.d.ts migrations/*'}"
echo ""

# git diff로 신규 파일 추출
cd "$PROJECT_ROOT"

# merge-base 찾기 (브랜치가 존재하지 않으면 HEAD 사용)
if git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
  MERGE_BASE=$(git merge-base "$BASE_BRANCH" HEAD 2>/dev/null || echo "HEAD~10")
else
  echo "[WARN] Base branch '$BASE_BRANCH' not found, using HEAD~10"
  MERGE_BASE="HEAD~10"
fi

# 신규 추가된 파일 목록
NEW_FILES=$(git diff --name-only --diff-filter=A "$MERGE_BASE" HEAD 2>/dev/null || true)

if [[ -z "$NEW_FILES" ]]; then
  echo "[OK] No new files found"
  exit 0
fi

# 파일별 체크
check_file_imported() {
  local file="$1"
  local filename
  local basename_noext
  local search_patterns=()

  filename=$(basename "$file")
  basename_noext="${filename%.*}"
  basename_noext="${basename_noext%.test}"  # .test 제거
  basename_noext="${basename_noext%.spec}"  # .spec 제거

  # import 패턴 생성
  # 1. 파일명으로 import (확장자 없이)
  search_patterns+=("from.*['\"].*${basename_noext}['\"]")
  # 2. 상대 경로로 import
  search_patterns+=("import.*['\"].*${basename_noext}['\"]")
  # 3. require로 import
  search_patterns+=("require.*['\"].*${basename_noext}['\"]")
  # 4. CSS/SCSS import
  search_patterns+=("@import.*${basename_noext}")

  # 검색 대상 디렉토리 (apps/, src/, lib/)
  local search_dirs=()
  for dir in apps src lib; do
    [[ -d "$PROJECT_ROOT/$dir" ]] && search_dirs+=("$PROJECT_ROOT/$dir")
  done

  if [[ ${#search_dirs[@]} -eq 0 ]]; then
    search_dirs=("$PROJECT_ROOT")
  fi

  # 각 패턴으로 검색
  for pattern in "${search_patterns[@]}"; do
    if grep -rqE "$pattern" "${search_dirs[@]}" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.css" --include="*.scss" 2>/dev/null; then
      return 0  # imported
    fi
  done

  return 1  # not imported (orphan)
}

# 패턴 매칭 체크
should_ignore() {
  local file="$1"

  for pattern in "${IGNORE_ARRAY[@]}"; do
    # glob 패턴 매칭
    if [[ "$file" == $pattern ]]; then
      return 0
    fi
    # basename 매칭
    if [[ "$(basename "$file")" == $pattern ]]; then
      return 0
    fi
  done

  return 1
}

# 확장자 매칭 체크
has_target_extension() {
  local file="$1"

  for ext in "${EXT_ARRAY[@]}"; do
    if [[ "$file" == *"$ext" ]]; then
      return 0
    fi
  done

  return 1
}

# 메인 체크 루프
echo "Checking new files..."
echo ""

while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  # 대상 확장자인지 확인
  if ! has_target_extension "$file"; then
    continue
  fi

  # ignore 패턴 매칭
  if should_ignore "$file"; then
    continue
  fi

  # 파일이 실제로 존재하는지 확인
  if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
    continue
  fi

  # import 여부 체크
  if ! check_file_imported "$file"; then
    echo -e "${YELLOW}[ORPHAN]${NC} $file"
    echo "         → No import/require found for this file"
    ((ORPHAN_COUNT++))
  fi

done <<< "$NEW_FILES"

echo ""
echo "=== Summary ==="

if [[ $ORPHAN_COUNT -gt 0 ]]; then
  echo -e "${YELLOW}[WARN]${NC} Found $ORPHAN_COUNT orphan file(s)"
  echo ""
  echo "Orphan files are newly added files that are not imported anywhere."
  echo "This might indicate:"
  echo "  - Forgotten import statement"
  echo "  - Dead code that should be removed"
  echo "  - File that needs to be registered (e.g., in index.ts)"
  echo ""
  echo "If these files are intentionally standalone, add them to ignore_patterns"
  echo "in coda.config.json under layer2_checks.orphan_files.ignore_patterns"
  EXIT_CODE=0  # Warning only, not blocking
else
  echo -e "${GREEN}[OK]${NC} No orphan files found"
fi

exit $EXIT_CODE
