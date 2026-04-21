#!/usr/bin/env bash
# stop-verifier.sh - Stop hook
# 작업 완료(Stop) 시 실제 상태 확인 + 체크리스트 주입
#
# Hook event: Stop
# stdout: JSON with "additionalContext" for verification reminder
# exit 0: always allow

set -u
trap 'exit 0' ERR  # Stop 훅은 항상 allow — 에러 시 세션 종료 차단 방지

# headless (-p) 모드에서는 타입체크 등 무거운 작업 skip
if [ "${CLAUDE_HEADLESS:-}" = "true" ] || [ -z "${CLAUDE_PROJECT_DIR:-}" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
CHECKS=""

# 1. PROJECT_STATUS.md 오늘 업데이트 여부
if [ -n "$PROJECT_DIR" ] && command -v git &>/dev/null && [ -d "$PROJECT_DIR/.git" ]; then
  TODAY=$(date -u +%Y-%m-%dT00:00:00Z)
  TODAY_STATUS=$(git -C "$PROJECT_DIR" log --since="$TODAY" --oneline -- PROJECT_STATUS.md 2>/dev/null | head -1 || true)
  if [ -n "$TODAY_STATUS" ]; then
    CHECKS="$CHECKS\n- [OK] PROJECT_STATUS.md: 오늘 업데이트 완료"
  else
    CHECKS="$CHECKS\n- [!!] PROJECT_STATUS.md: 오늘 미업데이트. /상태저장 실행을 권장합니다"
  fi

  # 2. 미커밋 변경사항 확인
  DIRTY=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | head -5 || true)
  if [ -n "$DIRTY" ]; then
    DIRTY_COUNT=$(echo "$DIRTY" | wc -l | tr -d ' ')
    CHECKS="$CHECKS\n- [!!] 미커밋 변경 ${DIRTY_COUNT}개 파일 있음. 커밋 필요 여부 확인하세요"
  else
    CHECKS="$CHECKS\n- [OK] 워킹 트리 클린"
  fi
fi

# 3. 빌드 명령 확인 (coda.config.json — env var 경유)
BUILD_CMD="pnpm build"
if [ -n "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/coda/coda.config.json" ]; then
  CMD=$(CODA_CONFIG="$PROJECT_DIR/coda/coda.config.json" python3 -c "
import os, json
try:
    with open(os.environ['CODA_CONFIG']) as f:
        print(json.load(f).get('build_cmd','pnpm build'))
except:
    print('pnpm build')
" 2>/dev/null || echo "pnpm build")
  [ -n "$CMD" ] && BUILD_CMD="$CMD"
fi

# 4. TypeScript 타입 체크 빠른 확인 (P1-3)
TSC_STATUS=""
if [ -n "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/apps/frontend/package.json" ]; then
  TSC_RESULT=$(cd "$PROJECT_DIR" && pnpm --filter @theboim/frontend type-check 2>&1 | tail -3) || true
  if echo "$TSC_RESULT" | grep -qE "error TS"; then
    TSC_ERR_COUNT=$(cd "$PROJECT_DIR" && pnpm --filter @theboim/frontend type-check 2>&1 | grep -cE "error TS" || echo "?")
    CHECKS="$CHECKS\n- [!!] TypeScript 타입 에러 ${TSC_ERR_COUNT}개 존재. 커밋 전 수정 필요"
  else
    CHECKS="$CHECKS\n- [OK] TypeScript 타입 체크 통과"
  fi
fi

HOOK_CHECKS="$CHECKS" HOOK_BUILD_CMD="$BUILD_CMD" python3 -c "
import json, os
checks = os.environ.get('HOOK_CHECKS', '')
build_cmd = os.environ.get('HOOK_BUILD_CMD', 'pnpm build')
reminder = f'''[완료 전 체크리스트]
- 빌드 확인했나요? ({build_cmd} 에러 0개)
- TypeScript 컴파일 에러 없나요?
- 관련 테스트를 실행했나요?
- 실제 출력을 확인했나요? (추정 금지)
{checks}
- memory/에 기록할 패턴이나 실수가 있었나요? (있으면 기록 후 종료)'''
print(json.dumps({'additionalContext': reminder}))
"

exit 0
