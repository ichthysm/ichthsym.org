#!/usr/bin/env bash
# pre-commit-check.sh - PreToolUse hook (Bash matcher)
# git commit 실행 전 TypeScript 타입 체크 수행
#
# Hook event: PreToolUse
# Matcher: Bash
# stdin: JSON with "tool_input.command" field
# stdout: JSON with "decision" (approve/block) and optional "reason"
# exit 0: always (decision in stdout)

set -u
trap 'echo "{}"; exit 0' ERR

# Read tool input from stdin
INPUT=$(cat || true)
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null || echo "")

# Only intercept git commit commands (not git commit --amend checks, status, etc.)
if ! echo "$COMMAND" | grep -qE '^\s*git\s+commit\s'; then
  exit 0  # Not a commit — pass through silently
fi

# Find project root (git root or pwd)
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Check if this is a TypeScript project with type-check script
if [ ! -f "$PROJECT_ROOT/package.json" ] && [ ! -f "$PROJECT_ROOT/apps/frontend/package.json" ]; then
  exit 0  # Not a TS project
fi

# Run type check
TSC_OUTPUT=""
TSC_EXIT=0

# Try pnpm filter first (monorepo), then direct tsc
if [ -f "$PROJECT_ROOT/apps/frontend/package.json" ]; then
  TSC_OUTPUT=$(cd "$PROJECT_ROOT" && pnpm --filter @theboim/frontend type-check 2>&1) || TSC_EXIT=$?
elif [ -f "$PROJECT_ROOT/tsconfig.json" ]; then
  TSC_OUTPUT=$(cd "$PROJECT_ROOT" && npx tsc --noEmit 2>&1) || TSC_EXIT=$?
else
  exit 0  # No tsconfig
fi

if [ $TSC_EXIT -ne 0 ]; then
  # Extract first 10 error lines for the reason
  ERROR_SUMMARY=$(echo "$TSC_OUTPUT" | grep -E "error TS" | head -10)
  ERROR_COUNT=$(echo "$TSC_OUTPUT" | grep -cE "error TS" || echo "0")

  REASON="TypeScript 타입 체크 실패 (${ERROR_COUNT}개 에러). 커밋 전 타입 에러를 수정하세요.
${ERROR_SUMMARY}"

  # Block the commit
  REASON="$REASON" python3 -c "
import json, os
reason = os.environ.get('REASON', 'tsc failed')
print(json.dumps({'decision': 'block', 'reason': reason}))
"
  exit 0
fi

# ── P1-1: i18n 키 동기화 검증 ──────────────────────────
# 커밋에 i18n 파일이 포함된 경우 키 개수 불일치 경고
I18N_DIR="$PROJECT_ROOT/apps/frontend/src/lib/i18n/locales"
if [ -d "$I18N_DIR" ]; then
  # 스테이징된 파일 중 i18n 관련 파일이 있는지 확인
  STAGED=$(cd "$PROJECT_ROOT" && git diff --cached --name-only 2>/dev/null || true)
  if echo "$STAGED" | grep -q "i18n/locales/"; then
    I18N_WARN=""
    # dashboard.json 키 개수 비교
    for ns in dashboard common threats assets scans services settings; do
      KO_FILE="$I18N_DIR/ko/${ns}.json"
      EN_FILE="$I18N_DIR/en/${ns}.json"
      JA_FILE="$I18N_DIR/ja/${ns}.json"
      [ -f "$KO_FILE" ] || continue
      [ -f "$EN_FILE" ] || continue
      KO_KEYS=$(python3 -c "
import json
def count_keys(obj, prefix=''):
    c = 0
    for k, v in obj.items():
        if isinstance(v, dict):
            c += count_keys(v, prefix + k + '.')
        else:
            c += 1
    return c
with open('$KO_FILE') as f:
    print(count_keys(json.load(f)))
" 2>/dev/null || echo "0")
      EN_KEYS=$(python3 -c "
import json
def count_keys(obj, prefix=''):
    c = 0
    for k, v in obj.items():
        if isinstance(v, dict):
            c += count_keys(v, prefix + k + '.')
        else:
            c += 1
    return c
with open('$EN_FILE') as f:
    print(count_keys(json.load(f)))
" 2>/dev/null || echo "0")
      JA_KEYS="0"
      if [ -f "$JA_FILE" ]; then
        JA_KEYS=$(python3 -c "
import json
def count_keys(obj, prefix=''):
    c = 0
    for k, v in obj.items():
        if isinstance(v, dict):
            c += count_keys(v, prefix + k + '.')
        else:
            c += 1
    return c
with open('$JA_FILE') as f:
    print(count_keys(json.load(f)))
" 2>/dev/null || echo "0")
      fi
      if [ "$KO_KEYS" != "$EN_KEYS" ] || ([ -f "$JA_FILE" ] && [ "$KO_KEYS" != "$JA_KEYS" ]); then
        I18N_WARN="${I18N_WARN}${ns}.json 키 불일치: ko=${KO_KEYS} en=${EN_KEYS} ja=${JA_KEYS}\n"
      fi
    done
    if [ -n "$I18N_WARN" ]; then
      REASON="i18n 키 개수 불일치 감지. 모든 locale 파일의 키를 동기화하세요.
${I18N_WARN}"
      REASON="$REASON" python3 -c "
import json, os
reason = os.environ.get('REASON', 'i18n mismatch')
print(json.dumps({'decision': 'block', 'reason': reason}))
"
      exit 0
    fi
  fi
fi

exit 0  # All checks passed
