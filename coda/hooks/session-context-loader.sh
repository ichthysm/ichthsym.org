#!/usr/bin/env bash
# session-context-loader.sh - SessionStart hook
# 새 세션 시작 시 프로젝트 버전 + 세션 인계 리마인더 자동 주입
#
# Hook event: SessionStart
# matcher: startup|clear (resume/compact 시에는 불필요)
# exit 0: always allow

set -eu

INPUT=$(cat || true)
SOURCE=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('source', 'startup'))
except:
    print('startup')
" 2>/dev/null || echo "startup")

# resume/compact 시에는 이미 컨텍스트가 있으므로 skip
if [ "$SOURCE" = "resume" ] || [ "$SOURCE" = "compact" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"

# 프로젝트 디렉토리 없으면 skip
if [ -z "$PROJECT_DIR" ] || [ ! -d "$PROJECT_DIR" ]; then
  exit 0
fi

CONTEXT=""

# 프로젝트 이름 (coda.config.json 또는 디렉토리명)
PROJECT_NAME=$(basename "$PROJECT_DIR")
if [ -f "$PROJECT_DIR/coda/coda.config.json" ]; then
  NAME=$(python3 -c "import json; print(json.load(open('$PROJECT_DIR/coda/coda.config.json')).get('project_name',''))" 2>/dev/null || echo "")
  [ -n "$NAME" ] && PROJECT_NAME="$NAME"
fi

# 1. 버전 정보
VERSION_FILE="VERSION"
if [ -f "$PROJECT_DIR/coda/coda.config.json" ]; then
  VF=$(python3 -c "import json; print(json.load(open('$PROJECT_DIR/coda/coda.config.json')).get('version_file','VERSION'))" 2>/dev/null || echo "VERSION")
  [ -n "$VF" ] && VERSION_FILE="$VF"
fi

if [ -f "$PROJECT_DIR/$VERSION_FILE" ]; then
  VER=$(tr -d '[:space:]' < "$PROJECT_DIR/$VERSION_FILE")
  CONTEXT="[$PROJECT_NAME v${VER}]"
fi

# 2. 오늘 상태저장 여부 (git 기반)
if command -v git &>/dev/null && [ -d "$PROJECT_DIR/.git" ]; then
  TODAY_STATUS=$(git -C "$PROJECT_DIR" log --since="today 00:00" --oneline -- PROJECT_STATUS.md 2>/dev/null | head -1 || true)
  if [ -n "$TODAY_STATUS" ]; then
    CONTEXT="${CONTEXT} PROJECT_STATUS.md 오늘 업데이트됨."
  else
    CONTEXT="${CONTEXT} PROJECT_STATUS.md 오늘 미업데이트. 이전 작업 이어서 하려면 하단 세션 인계용 섹션을 읽으세요."
  fi
fi

# 3. 세션 데이터 자동 정리
# 텔레메트리 failed_events: 즉시 삭제 (전송 실패 큐, 보존 불필요)
rm -f "${HOME}/.claude/telemetry/1p_failed_events."*.json 2>/dev/null

# 세션 JSONL(30일+), 디버그 로그(7일+): 백그라운드 정리
(
  find "${HOME}/.claude/projects" -name "*.jsonl" -mtime +30 -delete 2>/dev/null
  find "${HOME}/.claude/debug" -name "*.txt" -mtime +7 -delete 2>/dev/null
) &

if [ -n "$CONTEXT" ]; then
  HOOK_CONTEXT="$CONTEXT" python3 -c "
import json, os
ctx = os.environ.get('HOOK_CONTEXT', '')
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'SessionStart',
    'additionalContext': ctx
  }
}))
"
fi

exit 0
