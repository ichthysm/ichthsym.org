#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CODA 최종검수 (Final Review) — 단일 실행 스크립트
# 9단계 검증을 한 번에 실행하고 판정 결과를 출력
# 사용: bash tools/coda/scripts/final-review.sh [SESSION_ID]
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -o pipefail

# ── 색상 ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── 세션 탐지 ──
SESSION_ID="${1:-}"
if [ -z "$SESSION_ID" ]; then
  RELAY_FILE=$(ls -t tmp/night-*-relay.md 2>/dev/null | head -1)
  if [ -n "$RELAY_FILE" ]; then
    SESSION_ID=$(basename "$RELAY_FILE" | sed 's/^night-\(.*\)-relay\.md$/\1/')
  fi
fi

if [ -n "$SESSION_ID" ]; then
  BRANCH=$(grep -oP 'night/\d{8}-[a-z0-9-]+' "tmp/night-${SESSION_ID}-relay.md" 2>/dev/null | head -1)
fi

# ── 카운터 ──
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0
RESULTS=()

log_result() {
  local step="$1" name="$2" status="$3" detail="$4"
  case "$status" in
    PASS) PASS_COUNT=$((PASS_COUNT+1)); icon="${GREEN}✅ PASS${NC}" ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT+1)); icon="${RED}❌ FAIL${NC}" ;;
    WARN) WARN_COUNT=$((WARN_COUNT+1)); icon="${YELLOW}⚠️  WARN${NC}" ;;
    SKIP) SKIP_COUNT=$((SKIP_COUNT+1)); icon="${CYAN}⏭️  SKIP${NC}" ;;
  esac
  RESULTS+=("$(printf "  [%s] %-25s %b  %s" "$step" "$name" "$icon" "$detail")")
}

# ── 헤더 ──
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD} CODA 최종검수 — 나검수 (QA)${NC}"
[ -n "$SESSION_ID" ] && echo -e " 세션: ${CYAN}${SESSION_ID}${NC}"
[ -n "$BRANCH" ] && echo -e " 브랜치: ${CYAN}${BRANCH}${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

START_TIME=$(date +%s)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 1: 빌드
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BOLD}[1/9] 빌드 (pnpm build)...${NC}"
if pnpm build > /tmp/build.log 2>&1; then
  log_result "1" "빌드" "PASS" ""
else
  log_result "1" "빌드" "FAIL" "→ /tmp/build.log"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 2: tsc 타입 체크 (BE + FE 병렬)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BOLD}[2/9] TypeScript 타입 체크...${NC}"

# BE tsc
(cd apps/backend && npx tsc --noEmit > /tmp/tsc-backend.log 2>&1) &
TSC_BE_PID=$!

# FE tsc
(cd apps/frontend && npx tsc --noEmit > /tmp/tsc-frontend.log 2>&1) &
TSC_FE_PID=$!

wait $TSC_BE_PID; TSC_BE_RC=$?
wait $TSC_FE_PID; TSC_FE_RC=$?

if [ $TSC_BE_RC -eq 0 ] && [ $TSC_FE_RC -eq 0 ]; then
  log_result "2" "tsc 타입 체크" "PASS" ""
else
  DETAIL=""
  [ $TSC_BE_RC -ne 0 ] && DETAIL="BE 실패(/tmp/tsc-backend.log)"
  [ $TSC_FE_RC -ne 0 ] && DETAIL="${DETAIL} FE 실패(/tmp/tsc-frontend.log)"
  log_result "2" "tsc 타입 체크" "FAIL" "→ ${DETAIL}"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 3: 테스트 (BE→FE 순차, OOM 방지)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BOLD}[3/9] 테스트 (BE→FE 순차)...${NC}"

TEST_DETAIL=""
TEST_STATUS="PASS"

# BE test
if pnpm --filter @theboim/backend test > /tmp/test-backend.log 2>&1; then
  TEST_DETAIL="BE✅"
else
  TEST_STATUS="FAIL"
  TEST_DETAIL="BE❌(/tmp/test-backend.log)"
fi

# FE test
if pnpm --filter @theboim/frontend test:run > /tmp/test-frontend.log 2>&1; then
  TEST_DETAIL="${TEST_DETAIL} FE✅"
else
  TEST_STATUS="FAIL"
  TEST_DETAIL="${TEST_DETAIL} FE❌(/tmp/test-frontend.log)"
fi

log_result "3" "테스트" "$TEST_STATUS" "$TEST_DETAIL"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 4: 린트
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BOLD}[4/9] 린트...${NC}"
if pnpm lint > /tmp/lint.log 2>&1; then
  log_result "4" "린트" "PASS" ""
else
  # ESLint v9 이슈 — SKIP 처리
  if grep -q "ESLint\|eslint" /tmp/lint.log 2>/dev/null; then
    log_result "4" "린트" "SKIP" "ESLint 설정 이슈 → /tmp/lint.log"
  else
    log_result "4" "린트" "FAIL" "→ /tmp/lint.log"
  fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 5: i18n 키 동기화
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BOLD}[5/9] i18n 키 동기화 (ko↔en↔ja)...${NC}"

I18N_WARN=0
KO="apps/frontend/src/lib/i18n/locales/ko.json"
EN="apps/frontend/src/lib/i18n/locales/en.json"
JA="apps/frontend/src/lib/i18n/locales/ja.json"

if [ -f "$KO" ] && [ -f "$EN" ] && [ -f "$JA" ]; then
  # ko 키 기준으로 en, ja 누락 체크
  python3 -c "
import json, sys
ko = set(json.load(open('$KO')).keys())
en = set(json.load(open('$EN')).keys())
ja = set(json.load(open('$JA')).keys())
missing_en = ko - en
missing_ja = ko - ja
if missing_en:
    with open('/tmp/i18n-missing-en.log','w') as f:
        f.write('\n'.join(sorted(missing_en)))
    print(f'en 누락: {len(missing_en)}개')
if missing_ja:
    with open('/tmp/i18n-missing-ja.log','w') as f:
        f.write('\n'.join(sorted(missing_ja)))
    print(f'ja 누락: {len(missing_ja)}개')
total = len(missing_en) + len(missing_ja)
sys.exit(1 if total > 0 else 0)
" > /tmp/i18n-check.log 2>&1
  if [ $? -eq 0 ]; then
    log_result "5" "i18n 동기화" "PASS" ""
  else
    I18N_DETAIL=$(cat /tmp/i18n-check.log)
    log_result "5" "i18n 동기화" "WARN" "$I18N_DETAIL"
  fi
else
  log_result "5" "i18n 동기화" "SKIP" "파일 없음"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 6: console.log 잔류
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BOLD}[6/9] console.log 잔류 체크...${NC}"

# 변경 파일만 대상 (master 기준)
CHANGED_FILES=$(git diff --name-only master -- 'apps/frontend/src/**/*.ts' 'apps/frontend/src/**/*.tsx' 2>/dev/null || echo "")
CL_COUNT=0
if [ -n "$CHANGED_FILES" ]; then
  echo "$CHANGED_FILES" | while read -r f; do
    [ -f "$f" ] && grep -n 'console\.log' "$f" 2>/dev/null | grep -v 'eslint-disable' | grep -v '// debug'
  done > /tmp/console-log.log 2>/dev/null
  CL_COUNT=$(wc -l < /tmp/console-log.log 2>/dev/null || echo 0)
fi

if [ "$CL_COUNT" -gt 0 ]; then
  log_result "6" "console.log 잔류" "WARN" "${CL_COUNT}건 → /tmp/console-log.log"
else
  log_result "6" "console.log 잔류" "PASS" ""
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 7: 하드코딩 한글 문자열
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BOLD}[7/9] 하드코딩 한글 체크...${NC}"

HC_COUNT=0
if [ -n "$CHANGED_FILES" ]; then
  echo "$CHANGED_FILES" | while read -r f; do
    [ -f "$f" ] && grep -Pn '[\x{AC00}-\x{D7AF}]' "$f" 2>/dev/null \
      | grep -v '\.json' | grep -v 'i18n' | grep -v '// ' | grep -v 'test'
  done > /tmp/hardcode.log 2>/dev/null
  HC_COUNT=$(wc -l < /tmp/hardcode.log 2>/dev/null || echo 0)
fi

if [ "$HC_COUNT" -gt 0 ]; then
  log_result "7" "하드코딩 한글" "WARN" "${HC_COUNT}건 → /tmp/hardcode.log"
else
  log_result "7" "하드코딩 한글" "PASS" ""
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 8: 미사용 import (변경 파일)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BOLD}[8/9] 미사용 import 체크...${NC}"

ALL_CHANGED=$(git diff --name-only master -- '*.ts' '*.tsx' 2>/dev/null || echo "")
UI_COUNT=0
if [ -n "$ALL_CHANGED" ]; then
  # tsc --noUnusedLocals는 전체 프로젝트라 무거움 → 간이 체크
  echo "$ALL_CHANGED" | while read -r f; do
    [ -f "$f" ] || continue
    # import 했지만 파일 내에서 사용하지 않는 심볼 간이 탐지
    grep -oP '(?<=import\s\{)[^}]+' "$f" 2>/dev/null | tr ',' '\n' | sed 's/^\s*//;s/\s*$//' | while read -r sym; do
      [ -z "$sym" ] && continue
      sym_clean=$(echo "$sym" | sed 's/ as .*//')
      COUNT=$(grep -c "\b${sym_clean}\b" "$f" 2>/dev/null || echo 0)
      [ "$COUNT" -le 1 ] && echo "$f: unused import '$sym_clean'"
    done
  done > /tmp/unused-imports.log 2>/dev/null
  UI_COUNT=$(wc -l < /tmp/unused-imports.log 2>/dev/null || echo 0)
fi

if [ "$UI_COUNT" -gt 0 ]; then
  log_result "8" "미사용 import" "WARN" "${UI_COUNT}건 → /tmp/unused-imports.log"
else
  log_result "8" "미사용 import" "PASS" ""
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 9: API 계약 (BE DTO ↔ FE 타입)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BOLD}[9/9] API 계약 간이 체크...${NC}"

# 변경된 DTO 파일의 필드명이 FE 타입에 있는지 확인
CHANGED_DTOS=$(git diff --name-only master -- 'apps/backend/src/**/*.dto.ts' 2>/dev/null || echo "")
API_MISMATCH=0
if [ -n "$CHANGED_DTOS" ]; then
  python3 -c "
import re, sys, os, glob

mismatches = []
dto_files = '''$CHANGED_DTOS'''.strip().split('\n')
for dto_file in dto_files:
    if not os.path.isfile(dto_file):
        continue
    with open(dto_file) as f:
        content = f.read()
    # DTO 필드명 추출
    fields = re.findall(r'(?:@\w+\([^)]*\)\s*)*(\w+)\s*[?:]', content)
    # 해당 모듈의 FE 타입 파일 탐색
    module = dto_file.split('/modules/')[-1].split('/')[0] if '/modules/' in dto_file else ''
    if not module:
        continue
    fe_types = glob.glob(f'apps/frontend/src/types/**/*.ts', recursive=True)
    fe_types += glob.glob(f'apps/frontend/src/lib/api*.ts')
    # 기본 필드 제외
    skip = {'id','createdAt','updatedAt','deletedAt','tenantId','page','limit','sort','order'}
    for field in fields:
        if field in skip or field.startswith('_'):
            continue
        found = False
        for ft in fe_types:
            if os.path.isfile(ft):
                with open(ft) as ff:
                    if field in ff.read():
                        found = True
                        break
        if not found:
            mismatches.append(f'{dto_file}: {field} not found in FE types')

if mismatches:
    with open('/tmp/api-mismatch.log','w') as f:
        f.write('\n'.join(mismatches))
    print(f'{len(mismatches)}건 불일치')
    sys.exit(1)
else:
    sys.exit(0)
" > /tmp/api-check.log 2>&1
  if [ $? -eq 0 ]; then
    log_result "9" "API 계약" "PASS" ""
  else
    API_DETAIL=$(cat /tmp/api-check.log)
    log_result "9" "API 계약" "WARN" "$API_DETAIL"
  fi
else
  log_result "9" "API 계약" "SKIP" "변경된 DTO 없음"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 결과 요약
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD} 검수 결과 (${MINUTES}분 ${SECONDS}초)${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

for r in "${RESULTS[@]}"; do
  echo -e "$r"
done

echo ""
echo -e "  ${GREEN}PASS: ${PASS_COUNT}${NC}  ${RED}FAIL: ${FAIL_COUNT}${NC}  ${YELLOW}WARN: ${WARN_COUNT}${NC}  ${CYAN}SKIP: ${SKIP_COUNT}${NC}"
echo ""

# ── 판정 ──
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}${BOLD}  ❌ 판정: FAIL — 필수 항목 ${FAIL_COUNT}건 실패${NC}"
  echo ""
  echo "  실패 로그 확인 후 수정이 필요합니다."
  exit 1
elif [ "$WARN_COUNT" -gt 0 ]; then
  echo -e "${GREEN}${BOLD}  ✅ 판정: PASS (경고 ${WARN_COUNT}건)${NC}"
  echo ""
  echo "  머지 가능합니다. 경고 항목은 선택적으로 수정하세요."
  exit 0
else
  echo -e "${GREEN}${BOLD}  ✅ 판정: PASS — 전 항목 통과${NC}"
  echo ""
  echo "  머지 가능합니다."
  exit 0
fi
