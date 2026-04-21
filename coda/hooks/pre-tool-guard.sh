#!/usr/bin/env bash
# pre-tool-guard.sh - PreToolUse hook (matcher: Edit|Write)
# 보호 대상 파일에 대한 Edit/Write 시도를 차단
#
# Hook event: PreToolUse
# stdin: JSON with "tool_name" and "tool_input" fields
# exit 0: allow
# exit 2: block with reason message on stdout

set -u
trap 'exit 0' ERR  # 파싱 실패 시 allow (보안 체크는 패턴 매칭에서 수행)

# python3 없으면 패턴 매칭 불가 → 경고만 출력하고 allow
if ! command -v python3 &>/dev/null; then
  exit 0
fi

INPUT=$(cat || true)

# Extract file path from tool input (env var to prevent injection)
FILE_PATH=$(echo "$INPUT" | HOOK_INPUT="$INPUT" python3 -c "
import sys, json, os
try:
    data = json.load(sys.stdin)
    inp = data.get('tool_input', {})
    print(inp.get('file_path', ''))
except:
    print('')
" 2>/dev/null || echo "")

# 파일 경로 파싱 실패 → allow (Claude Code가 정상 JSON을 보내지 못한 경우)
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

# Block .env files (secrets) — allow .example templates
if echo "$BASENAME" | grep -qiE '^\.env'; then
  # .env.example, .env.production.example 등 템플릿은 허용
  if echo "$BASENAME" | grep -qiE '\.example$'; then
    exit 0
  fi
  echo "[BLOCKED] .env 파일 수정이 차단되었습니다: $FILE_PATH"
  echo "  → 대안: Bash 도구로 'cp .env.example .env' 실행하세요"
  exit 2
fi

# Block files with 'secret' or 'credential' in name
if echo "$BASENAME" | grep -qiE 'secret|credential'; then
  echo "[BLOCKED] 민감 정보 파일 수정이 차단되었습니다: $FILE_PATH"
  exit 2
fi

# Block private key files
if echo "$BASENAME" | grep -qiE '\.pem$|\.key$|id_rsa|id_ed25519'; then
  echo "[BLOCKED] 개인키 파일 수정이 차단되었습니다: $FILE_PATH"
  exit 2
fi

# Block writes outside project directory (with configurable allowed paths)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
if [ -n "$PROJECT_DIR" ]; then
  # Normalize paths to prevent traversal (../../etc/passwd)
  FILE_PATH=$(realpath -m "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
  PROJECT_DIR=$(realpath "$PROJECT_DIR" 2>/dev/null || echo "$PROJECT_DIR")

  # 1. Always allow project directory and .claude config
  case "$FILE_PATH" in
    "$PROJECT_DIR"/*|"$HOME/.claude"/*) exit 0 ;;
  esac

  # 2. Auto-allow sibling projects (same parent directory)
  PARENT_DIR=$(dirname "$PROJECT_DIR")
  case "$FILE_PATH" in
    "$PARENT_DIR"/*) exit 0 ;;
  esac

  # 3. Load additional allowed paths from coda.config.json
  CONFIG_FILE="$PROJECT_DIR/coda/coda.config.json"
  if [ -f "$CONFIG_FILE" ]; then
    ALLOWED_PATHS=$(CODA_CONFIG="$CONFIG_FILE" python3 -c "
import os, json
try:
    with open(os.environ['CODA_CONFIG']) as f:
        paths = json.load(f).get('allowed_paths', [])
        print('\n'.join(paths))
except:
    pass
" 2>/dev/null || echo "")

    if [ -n "$ALLOWED_PATHS" ]; then
      while IFS= read -r allowed_pattern; do
        # Expand ~ to $HOME
        allowed_pattern="${allowed_pattern/#\~/$HOME}"
        # Simple glob matching: convert /some/path/* to prefix match
        if [[ "$allowed_pattern" == *\* ]]; then
          prefix="${allowed_pattern%\*}"
          if [[ "$FILE_PATH" == "$prefix"* ]]; then
            exit 0
          fi
        else
          # Exact match
          if [[ "$FILE_PATH" == "$allowed_pattern" ]]; then
            exit 0
          fi
        fi
      done <<< "$ALLOWED_PATHS"
    fi
  fi

  # 4. Block everything else
  echo "[BLOCKED] 프로젝트 외부 경로에 파일 쓰기가 차단되었습니다: $FILE_PATH"
  echo "허용된 경로:"
  echo "  - 프로젝트 디렉토리: $PROJECT_DIR/*"
  echo "  - Claude 설정: $HOME/.claude/*"
  echo "  - 형제 프로젝트: $PARENT_DIR/*"
  echo "  - 추가 허용 경로: coda.config.json의 allowed_paths 참조"
  exit 2
fi

# Allow everything else
exit 0
