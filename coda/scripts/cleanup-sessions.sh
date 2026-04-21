#!/usr/bin/env bash
# cleanup-sessions.sh - Claude Code 세션 파일 유지보수
# Usage: bash cleanup-sessions.sh [--dry-run] [--days N]
#
# 정리 대상:
#   1. ~/.claude/projects/ JSONL 세션 파일 (기본: 30일 이상)
#   2. ~/.claude/telemetry/ failed_events 파일 (항상 정리)
#   3. ~/.claude/debug/ 디버그 로그 (기본: 7일 이상)

set -euo pipefail

DRY_RUN=false
RETENTION_DAYS=30
DEBUG_RETENTION_DAYS=7

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --days) RETENTION_DAYS="${2:-30}"; shift 2 ;;
    *) shift ;;
  esac
done

CLAUDE_DIR="${HOME}/.claude"
PROJECTS_DIR="$CLAUDE_DIR/projects"
TELEMETRY_DIR="$CLAUDE_DIR/telemetry"
DEBUG_DIR="$CLAUDE_DIR/debug"

echo "=== Claude Code 세션 유지보수 ==="
echo "보존 기간: 세션 ${RETENTION_DAYS}일, 디버그 ${DEBUG_RETENTION_DAYS}일"
echo "Dry-run: $DRY_RUN"
echo ""

# 1. JSONL 세션 파일 정리
if [ -d "$PROJECTS_DIR" ]; then
  JSONL_OLD=$(find "$PROJECTS_DIR" -name "*.jsonl" -mtime "+${RETENTION_DAYS}" 2>/dev/null | wc -l)
  JSONL_TOTAL=$(find "$PROJECTS_DIR" -name "*.jsonl" 2>/dev/null | wc -l)
  JSONL_SIZE=$(find "$PROJECTS_DIR" -name "*.jsonl" -mtime "+${RETENTION_DAYS}" -exec du -cm {} + 2>/dev/null | tail -1 | cut -f1 || echo 0)
  echo "[세션] 총 ${JSONL_TOTAL}개, ${RETENTION_DAYS}일 초과 ${JSONL_OLD}개 (${JSONL_SIZE}MB)"

  if [ "$JSONL_OLD" -gt 0 ]; then
    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY-RUN] ${JSONL_OLD}개 파일 삭제 예정"
    else
      find "$PROJECTS_DIR" -name "*.jsonl" -mtime "+${RETENTION_DAYS}" -delete
      echo "  삭제 완료: ${JSONL_OLD}개"
    fi
  fi
else
  echo "[세션] 디렉토리 없음: $PROJECTS_DIR"
fi

# 2. Telemetry 파일 정리
echo ""
if [ -d "$TELEMETRY_DIR" ]; then
  TELEM_SIZE=$(du -sm "$TELEMETRY_DIR" 2>/dev/null | cut -f1 || echo 0)
  TELEM_COUNT=$(find "$TELEMETRY_DIR" -name "1p_failed_events.*.json" 2>/dev/null | wc -l)
  echo "[텔레메트리] ${TELEM_SIZE}MB, failed_events ${TELEM_COUNT}개"

  if [ "$TELEM_COUNT" -gt 0 ]; then
    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY-RUN] ${TELEM_COUNT}개 파일 삭제 예정"
    else
      find "$TELEMETRY_DIR" -name "1p_failed_events.*.json" -delete
      NEW_SIZE=$(du -sm "$TELEMETRY_DIR" 2>/dev/null | cut -f1 || echo 0)
      echo "  삭제 완료: ${TELEM_SIZE}MB → ${NEW_SIZE}MB"
    fi
  fi
else
  echo "[텔레메트리] 디렉토리 없음: $TELEMETRY_DIR"
fi

# 3. Debug 로그 정리
echo ""
if [ -d "$DEBUG_DIR" ]; then
  DEBUG_OLD=$(find "$DEBUG_DIR" -name "*.txt" -mtime "+${DEBUG_RETENTION_DAYS}" 2>/dev/null | wc -l)
  DEBUG_TOTAL=$(find "$DEBUG_DIR" -name "*.txt" 2>/dev/null | wc -l)
  echo "[디버그] 총 ${DEBUG_TOTAL}개, ${DEBUG_RETENTION_DAYS}일 초과 ${DEBUG_OLD}개"

  if [ "$DEBUG_OLD" -gt 0 ]; then
    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY-RUN] ${DEBUG_OLD}개 파일 삭제 예정"
    else
      find "$DEBUG_DIR" -name "*.txt" -mtime "+${DEBUG_RETENTION_DAYS}" -delete
      echo "  삭제 완료: ${DEBUG_OLD}개"
    fi
  fi
else
  echo "[디버그] 디렉토리 없음: $DEBUG_DIR"
fi

echo ""
echo "완료. 정기 실행 권장: 월 1회"
