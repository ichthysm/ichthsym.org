#!/usr/bin/env bash
# CODA - Claude Orchestrated Development Automation
# install.sh - 설치 + 프로젝트 초기화 통합 스크립트
#
# Usage: bash install.sh [--dry-run] [project_dir]
#        bash install.sh --uninstall [project_dir]
#   project_dir: 프로젝트 루트 (기본: git root 또는 현재 디렉토리)
#   --dry-run:   실제 변경 없이 수행될 작업만 표시
#
# 사전 요구사항:
#   필수:
#     - Claude Code CLI (https://docs.anthropic.com/en/docs/claude-code)
#     - bash (Linux/macOS 기본, Windows는 WSL 필수)
#     - python3 (훅 JSON 파싱, settings.json 머지)
#   권장:
#     - git (세션 상태 추적, 버전 관리)
#   선택:
#     - tmux (/야간작업 스킬에서만 사용)

set -euo pipefail

# ── 색상 ────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── 경로 ────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
COMMANDS_DIR="$CLAUDE_DIR/commands"

# ── 인자 파싱 ───────────────────────────────────────
UNINSTALL=false
DRY_RUN=false
UPDATE=false
PROJECT_DIR=""
for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL=true ;;
    --dry-run) DRY_RUN=true ;;
    --update) UPDATE=true ;;
    *) PROJECT_DIR="$arg" ;;
  esac
done
# 프로젝트 루트 추론: 인자 > git root > pwd
if [ -z "$PROJECT_DIR" ]; then
  GIT_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)
  PROJECT_DIR="${GIT_ROOT:-$(pwd)}"
fi

# CODA 작업 디렉토리
CODA_DIR="$PROJECT_DIR/coda"
BACKUP_DIR="$CODA_DIR/backup"
AGENTS_DIR="$PROJECT_DIR/.claude/agents"
CODA_VERSION_FILE="$CODA_DIR/CODA_VERSION"
SCRIPT_VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "unknown")

# ── 유틸 ────────────────────────────────────────────
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}  ✓${NC} $1"; }
dry()   { echo -e "${YELLOW}  ⊘${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }
ask()   { echo -en "${CYAN}  ?${NC} $1"; }

# ═══════════════════════════════════════════════════
# 업데이트 모드
# ═══════════════════════════════════════════════════
if [ "$UPDATE" = true ]; then
  echo ""
  echo -e "${BOLD}CODA 업데이트${NC}"
  echo ""

  # 설치 여부 확인
  if [ ! -d "$CODA_DIR" ] || [ ! -f "$CODA_VERSION_FILE" ]; then
    err "CODA가 설치되지 않았습니다."
    info "설치: bash install.sh"
    exit 1
  fi

  INSTALLED_VERSION=$(cat "$CODA_VERSION_FILE" 2>/dev/null || echo "0.0.0")
  info "설치된 버전: v$INSTALLED_VERSION"
  info "최신 버전: v$SCRIPT_VERSION"

  # 버전 비교 (동일해도 --force 또는 파일 갱신 위해 계속 진행)
  if [ "$INSTALLED_VERSION" = "$SCRIPT_VERSION" ]; then
    info "동일 버전 — 파일 갱신 모드로 진행"
  else
    info "v$INSTALLED_VERSION → v$SCRIPT_VERSION 업데이트 시작"
  fi

  # 백업 디렉토리 생성
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  UPDATE_BACKUP="$BACKUP_DIR/update-$TIMESTAMP"
  if [ "$DRY_RUN" != true ]; then
    mkdir -p "$UPDATE_BACKUP"
  fi

  # 훅 업데이트 (신규 파일도 설치)
  info "훅 업데이트"
  mkdir -p "$HOOKS_DIR" 2>/dev/null || true
  for hook_file in "$SCRIPT_DIR/hooks/"*.sh; do
    [ -f "$hook_file" ] || continue
    HOOK_NAME=$(basename "$hook_file")
    if [ "$DRY_RUN" = true ]; then
      [ -f "$HOOKS_DIR/$HOOK_NAME" ] && dry "백업: $HOOK_NAME → update-$TIMESTAMP/"
      dry "업데이트: $HOOK_NAME"
    else
      [ -f "$HOOKS_DIR/$HOOK_NAME" ] && cp "$HOOKS_DIR/$HOOK_NAME" "$UPDATE_BACKUP/$HOOK_NAME"
      cp "$hook_file" "$HOOKS_DIR/$HOOK_NAME"
      chmod +x "$HOOKS_DIR/$HOOK_NAME"
    fi
    ok "$HOOK_NAME"
  done

  # 스킬 업데이트 (신규 파일도 설치)
  info "스킬 업데이트"
  mkdir -p "$COMMANDS_DIR" 2>/dev/null || true
  for cmd_file in "$SCRIPT_DIR/commands/"*.md; do
    [ -f "$cmd_file" ] || continue
    CMD_NAME=$(basename "$cmd_file" .md)
    if [ "$DRY_RUN" = true ]; then
      [ -f "$COMMANDS_DIR/$CMD_NAME.md" ] && dry "백업: $CMD_NAME.md → update-$TIMESTAMP/"
      dry "업데이트: $CMD_NAME.md"
    else
      [ -f "$COMMANDS_DIR/$CMD_NAME.md" ] && cp "$COMMANDS_DIR/$CMD_NAME.md" "$UPDATE_BACKUP/$CMD_NAME.md"
      cp "$cmd_file" "$COMMANDS_DIR/$CMD_NAME.md"
    fi
    ok "$CMD_NAME"
  done

  # 에이전트 업데이트 (신규 파일도 설치)
  info "에이전트 업데이트"
  mkdir -p "$AGENTS_DIR" 2>/dev/null || true
  for agent_file in "$SCRIPT_DIR/agents/"*.md; do
    [ -f "$agent_file" ] || continue
    AGENT_NAME=$(basename "$agent_file")
    if [ "$DRY_RUN" = true ]; then
      [ -f "$AGENTS_DIR/$AGENT_NAME" ] && dry "백업: $AGENT_NAME → update-$TIMESTAMP/"
      dry "업데이트: $AGENT_NAME"
    else
      [ -f "$AGENTS_DIR/$AGENT_NAME" ] && cp "$AGENTS_DIR/$AGENT_NAME" "$UPDATE_BACKUP/$AGENT_NAME"
      cp "$agent_file" "$AGENTS_DIR/$AGENT_NAME"
    fi
    ok "$(basename "$AGENT_NAME" .md)"
  done

  # 글로벌 CLAUDE.md 업데이트
  info "글로벌 CLAUDE.md 업데이트"
  if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    if [ "$DRY_RUN" = true ]; then
      dry "백업: CLAUDE.md → update-$TIMESTAMP/"
      dry "업데이트: CLAUDE.md"
    else
      cp "$CLAUDE_DIR/CLAUDE.md" "$UPDATE_BACKUP/CLAUDE.md"
      cp "$SCRIPT_DIR/templates/global-CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    fi
    ok "글로벌 CLAUDE.md"
  fi

  # settings.json 머지 (기존 로직 재사용)
  info "settings.json 업데이트"
  if [ -f "$CLAUDE_DIR/settings.json" ] && [ "$DRY_RUN" != true ]; then
    cp "$CLAUDE_DIR/settings.json" "$UPDATE_BACKUP/settings.json"
    CLAUDE_DIR="$CLAUDE_DIR" SCRIPT_DIR="$SCRIPT_DIR" python3 -c "
import json, os, tempfile

claude_dir = os.environ['CLAUDE_DIR']
script_dir = os.environ['SCRIPT_DIR']

with open(os.path.join(claude_dir, 'settings.json')) as f:
    existing = json.load(f)

with open(os.path.join(script_dir, 'templates', 'settings.json')) as f:
    coda = json.load(f)

# hooks: CODA 훅으로 교체
existing['hooks'] = coda['hooks']

# permissions.allow: 기존에 없는 항목만 추가
existing_allow = set(existing.get('permissions', {}).get('allow', []))
coda_allow = set(coda.get('permissions', {}).get('allow', []))
merged_allow = sorted(existing_allow | coda_allow)
existing.setdefault('permissions', {})['allow'] = merged_allow

# Atomic write: temp file → rename (prevents corruption on interrupt)
target = os.path.join(claude_dir, 'settings.json')
fd, tmp = tempfile.mkstemp(dir=claude_dir, suffix='.tmp')
try:
    with os.fdopen(fd, 'w') as f:
        json.dump(existing, f, indent=2, ensure_ascii=False)
        f.write('\n')
    os.rename(tmp, target)
except:
    os.unlink(tmp)
    raise
"
    ok "settings.json 머지 완료"
  elif [ "$DRY_RUN" = true ]; then
    dry "settings.json 머지"
    ok "settings.json"
  fi

  # .mcp.json 머지 (coda.config.json의 mcp_servers → 프로젝트 .mcp.json)
  info ".mcp.json 업데이트"
  if [ -f "$CODA_DIR/coda.config.json" ]; then
    MCP_JSON="$PROJECT_DIR/.mcp.json"
    if [ "$DRY_RUN" = true ]; then
      dry ".mcp.json 머지 (coda.config.json → .mcp.json)"
    else
      CODA_CONFIG="$CODA_DIR/coda.config.json" MCP_JSON="$MCP_JSON" python3 -c "
import json, os, tempfile

config_path = os.environ['CODA_CONFIG']
mcp_path = os.environ['MCP_JSON']

with open(config_path) as f:
    config = json.load(f)

mcp_servers = config.get('mcp_servers', {})
if not mcp_servers:
    exit(0)

# 기존 .mcp.json 읽기 (없으면 빈 객체)
existing = {}
if os.path.isfile(mcp_path):
    with open(mcp_path) as f:
        existing = json.load(f)

existing.setdefault('mcpServers', {}).update(mcp_servers)

# Atomic write
d = os.path.dirname(mcp_path) or '.'
fd, tmp = tempfile.mkstemp(dir=d, suffix='.tmp')
try:
    with os.fdopen(fd, 'w') as f:
        json.dump(existing, f, indent=2, ensure_ascii=False)
        f.write('\n')
    os.rename(tmp, mcp_path)
except:
    os.unlink(tmp)
    raise
"
    fi
    ok ".mcp.json 머지 완료"
  else
    ok ".mcp.json 스킵 (coda.config.json 없음)"
  fi

  # 버전 파일 업데이트
  if [ "$DRY_RUN" = true ]; then
    dry "echo $SCRIPT_VERSION > $CODA_VERSION_FILE"
  else
    echo "$SCRIPT_VERSION" > "$CODA_VERSION_FILE"
  fi
  ok "버전 업데이트: v$SCRIPT_VERSION"

  echo ""
  echo -e "${BOLD}┌──────────────────────────────────────────────┐${NC}"
  echo -e "${BOLD}│  CODA 업데이트 완료!                          │${NC}"
  echo -e "${BOLD}│  v$INSTALLED_VERSION → v$SCRIPT_VERSION${NC}"
  echo -e "${BOLD}│                                              │${NC}"
  echo -e "${BOLD}│  백업 위치: $UPDATE_BACKUP${NC}"
  echo -e "${BOLD}└──────────────────────────────────────────────┘${NC}"
  if [ "$DRY_RUN" = true ]; then
    echo ""
    warn "DRY RUN 모드 — 실제 파일 변경 없음"
    info "실제 업데이트: bash install.sh --update"
  fi
  echo ""
  exit 0
fi

# ═══════════════════════════════════════════════════
# 제거 모드
# ═══════════════════════════════════════════════════
if [ "$UNINSTALL" = true ]; then
  echo ""
  echo -e "${BOLD}CODA 제거${NC}"
  echo ""

  # CODA 훅 파일 제거
  CODA_HOOKS="session-context-loader.sh keyword-detector.sh pre-tool-guard.sh pre-commit-check.sh stop-verifier.sh"
  info "훅 제거"
  for h in $CODA_HOOKS; do
    if [ -f "$HOOKS_DIR/$h" ]; then
      rm "$HOOKS_DIR/$h"
      ok "$h 삭제"
    fi
  done

  # CODA 스킬 파일 제거
  CODA_CMDS="초기화 상태저장 상태복원 버전업 병렬작업 자율개발 개발환경 프론트가이드 인사이트 새프로젝트"
  info "스킬 제거"
  for c in $CODA_CMDS; do
    if [ -f "$COMMANDS_DIR/$c.md" ]; then
      rm "$COMMANDS_DIR/$c.md"
      ok "$c.md 삭제"
    fi
  done

  # CODA 에이전트 파일 제거
  CODA_AGENTS="pm backend frontend devops security qa docs data-analyst visualization"
  info "에이전트 제거"
  for a in $CODA_AGENTS; do
    if [ -f "$AGENTS_DIR/$a.md" ]; then
      rm "$AGENTS_DIR/$a.md"
      ok "$a.md 삭제"
    fi
  done

  # settings.json에서 hooks 섹션 제거
  info "settings.json 정리"
  if [ -f "$CLAUDE_DIR/settings.json" ]; then
    CLAUDE_DIR="$CLAUDE_DIR" python3 -c "
import json, os
path = os.path.join(os.environ['CLAUDE_DIR'], 'settings.json')
with open(path) as f:
    data = json.load(f)
data.pop('hooks', None)
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" 2>/dev/null && ok "hooks 설정 제거" || warn "settings.json 수동 확인 필요"
  fi

  # 백업에서 복원
  info "백업 복원"
  if [ -d "$BACKUP_DIR" ]; then
    # 글로벌 CLAUDE.md 복원
    if [ -f "$BACKUP_DIR/CLAUDE.md" ]; then
      cp "$BACKUP_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
      ok "글로벌 CLAUDE.md 복원"
    elif [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
      rm "$CLAUDE_DIR/CLAUDE.md"
      ok "CODA 글로벌 CLAUDE.md 삭제"
    fi

    # settings.json 복원
    if [ -f "$BACKUP_DIR/settings.json" ]; then
      cp "$BACKUP_DIR/settings.json" "$CLAUDE_DIR/settings.json"
      ok "settings.json 복원"
    fi

    # hooks 복원
    if [ -d "$BACKUP_DIR/hooks" ] && [ "$(ls -A "$BACKUP_DIR/hooks" 2>/dev/null)" ]; then
      cp "$BACKUP_DIR/hooks/"* "$HOOKS_DIR/" 2>/dev/null
      ok "hooks 복원"
    fi

    # agents 복원
    if [ -d "$BACKUP_DIR/agents" ] && [ "$(ls -A "$BACKUP_DIR/agents" 2>/dev/null)" ]; then
      mkdir -p "$AGENTS_DIR"
      cp "$BACKUP_DIR/agents/"* "$AGENTS_DIR/" 2>/dev/null
      ok "agents 복원"
    fi
  else
    warn "백업 디렉토리 없음 ($BACKUP_DIR)"
    # 글로벌 CLAUDE.md만 삭제
    if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
      rm "$CLAUDE_DIR/CLAUDE.md"
      ok "CODA 글로벌 CLAUDE.md 삭제"
    fi
  fi

  # coda/ 디렉토리 제거 (config + backup 포함)
  if [ -d "$CODA_DIR" ]; then
    rm -rf "$CODA_DIR"
    ok "coda/ 디렉토리 삭제"
  fi

  echo ""
  info "제거 완료. 아래 파일은 사용자 데이터이므로 유지됩니다:"
  echo "  - 프로젝트 CLAUDE.md"
  echo "  - PROJECT_STATUS.md"
  echo "  - VERSION"
  echo "  - memory/ 파일들"
  echo ""
  exit 0
fi

# ── 배너 ────────────────────────────────────────────
echo ""
echo -e "${BOLD}┌──────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}│  CODA - Claude Orchestrated Dev Automation   │${NC}"
if [ "$DRY_RUN" = true ]; then
echo -e "${BOLD}│  v1.3 Installer ${YELLOW}(DRY RUN)${NC}${BOLD}                    │${NC}"
else
echo -e "${BOLD}│  v1.3 Installer                              │${NC}"
fi
echo -e "${BOLD}└──────────────────────────────────────────────┘${NC}"
echo ""

# ═══════════════════════════════════════════════════
# [1/6] 사전 검사
# ═══════════════════════════════════════════════════
info "[1/6] 사전 검사"

# Claude Code CLI 확인
if command -v claude &>/dev/null; then
  CLAUDE_PATH=$(which claude)
  ok "Claude Code CLI 감지 ($CLAUDE_PATH)"
else
  err "Claude Code CLI를 찾을 수 없습니다."
  echo "  설치: https://docs.anthropic.com/en/docs/claude-code/overview"
  exit 1
fi

# python3 확인
if ! command -v python3 &>/dev/null; then
  err "python3이 필요합니다."
  exit 1
fi
ok "python3 감지"

# ~/.claude/ 기존 설정 백업 권고
if [ -d "$CLAUDE_DIR" ] && [ "$(ls -A "$CLAUDE_DIR" 2>/dev/null)" ]; then
  if [ "$DRY_RUN" = true ]; then
    warn "기존 ~/.claude/ 설정이 감지됨 (실제 설치 시 백업 권고)"
  else
    echo ""
    warn "기존 ~/.claude/ 설정이 감지되었습니다."
    echo -e "  CODA는 hooks, settings.json, CLAUDE.md를 수정합니다."
    echo -e "  기존 설정이 많다면 설치 전 전체 백업을 권장합니다:"
    echo ""
    echo -e "    ${CYAN}cp -r ~/.claude ~/.claude.pre-coda${NC}"
    echo ""
    ask "계속 설치하시겠습니까? (Y/n): "
    read -r CONTINUE_INSTALL
    if [[ "$CONTINUE_INSTALL" =~ ^[Nn] ]]; then
      info "설치를 중단합니다. 백업 후 다시 실행해주세요."
      exit 0
    fi
    echo ""
  fi
fi

# ~/.claude/ 디렉토리
if [ "$DRY_RUN" = true ]; then
  dry "mkdir -p $CLAUDE_DIR"
else
  mkdir -p "$CLAUDE_DIR"
fi
ok "~/.claude/ 디렉토리 확인"

# coda/ 백업 디렉토리 생성
if [ "$DRY_RUN" = true ]; then
  dry "mkdir -p $BACKUP_DIR"
else
  mkdir -p "$BACKUP_DIR"
fi
ok "프로젝트 coda/ 디렉토리 생성 ($CODA_DIR)"

# 기존 파일 백업 → coda/backup/
if [ -d "$HOOKS_DIR" ] && [ "$(ls -A "$HOOKS_DIR" 2>/dev/null)" ]; then
  if [ "$DRY_RUN" = true ]; then
    dry "hooks/ → coda/backup/hooks/ 백업"
  else
    mkdir -p "$BACKUP_DIR/hooks"
    cp "$HOOKS_DIR/"* "$BACKUP_DIR/hooks/" 2>/dev/null
  fi
  ok "기존 hooks 백업 → coda/backup/hooks/"
fi

if [ -f "$CLAUDE_DIR/settings.json" ]; then
  if [ "$DRY_RUN" = true ]; then
    dry "settings.json → coda/backup/ 백업"
  else
    cp "$CLAUDE_DIR/settings.json" "$BACKUP_DIR/settings.json"
  fi
  ok "기존 settings.json 백업 → coda/backup/"
fi

if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  if [ "$DRY_RUN" = true ]; then
    dry "CLAUDE.md → coda/backup/ 백업"
  else
    cp "$CLAUDE_DIR/CLAUDE.md" "$BACKUP_DIR/CLAUDE.md"
  fi
  ok "기존 글로벌 CLAUDE.md 백업 → coda/backup/"
fi

if [ -d "$AGENTS_DIR" ] && [ "$(ls -A "$AGENTS_DIR" 2>/dev/null)" ]; then
  if [ "$DRY_RUN" = true ]; then
    dry "agents/ → coda/backup/agents/ 백업"
  else
    mkdir -p "$BACKUP_DIR/agents"
    cp "$AGENTS_DIR/"* "$BACKUP_DIR/agents/" 2>/dev/null
  fi
  ok "기존 agents 백업 → coda/backup/agents/"
fi

echo ""

# ═══════════════════════════════════════════════════
# [2/6] 훅 설치
# ═══════════════════════════════════════════════════
info "[2/6] 훅 설치 → $HOOKS_DIR"

if [ "$DRY_RUN" != true ]; then
  mkdir -p "$HOOKS_DIR"
fi

for hook_file in "$SCRIPT_DIR/hooks/"*.sh; do
  [ -f "$hook_file" ] || continue
  HOOK_NAME=$(basename "$hook_file")
  if [ "$DRY_RUN" = true ]; then
    dry "cp $HOOK_NAME → $HOOKS_DIR/"
  else
    cp "$hook_file" "$HOOKS_DIR/$HOOK_NAME"
    chmod +x "$HOOKS_DIR/$HOOK_NAME"
  fi
  ok "$HOOK_NAME"
done

# settings.json에 훅 머지 (기존 설정 보존)
if [ "$DRY_RUN" = true ]; then
  if [ -f "$CLAUDE_DIR/settings.json" ]; then
    dry "settings.json 머지 (hooks 교체 + permissions 추가)"
  else
    dry "settings.json 새로 생성"
  fi
  ok "settings.json 처리"
else
  if [ -f "$CLAUDE_DIR/settings.json" ]; then
    CLAUDE_DIR="$CLAUDE_DIR" SCRIPT_DIR="$SCRIPT_DIR" python3 -c "
import json, os

claude_dir = os.environ['CLAUDE_DIR']
script_dir = os.environ['SCRIPT_DIR']

with open(os.path.join(claude_dir, 'settings.json')) as f:
    existing = json.load(f)

with open(os.path.join(script_dir, 'templates', 'settings.json')) as f:
    coda = json.load(f)

# hooks: CODA 훅으로 교체 (다른 설정은 보존)
existing['hooks'] = coda['hooks']

# permissions.allow: 기존에 없는 항목만 추가
existing_allow = set(existing.get('permissions', {}).get('allow', []))
coda_allow = set(coda.get('permissions', {}).get('allow', []))
merged_allow = sorted(existing_allow | coda_allow)
existing.setdefault('permissions', {})['allow'] = merged_allow

with open(os.path.join(claude_dir, 'settings.json'), 'w') as f:
    json.dump(existing, f, indent=2, ensure_ascii=False)
    f.write('\n')
"
    ok "settings.json 머지 완료 (기존 설정 보존)"
  else
    cp "$SCRIPT_DIR/templates/settings.json" "$CLAUDE_DIR/settings.json"
    ok "settings.json 생성 완료"
  fi
fi

# 글로벌 CLAUDE.md 설치 (CODA 컨벤션)
if [ "$DRY_RUN" = true ]; then
  dry "global-CLAUDE.md → ~/.claude/CLAUDE.md"
else
  cp "$SCRIPT_DIR/templates/global-CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
fi
ok "글로벌 CLAUDE.md 설치 (CODA 컨벤션)"

echo ""

# ═══════════════════════════════════════════════════
# [3/6] 스킬 설치
# ═══════════════════════════════════════════════════
info "[3/6] 스킬 설치 → $COMMANDS_DIR"

if [ "$DRY_RUN" != true ]; then
  mkdir -p "$COMMANDS_DIR"
fi

for cmd_file in "$SCRIPT_DIR/commands/"*.md; do
  [ -f "$cmd_file" ] || continue
  CMD_NAME=$(basename "$cmd_file" .md)
  if [ "$DRY_RUN" = true ]; then
    dry "cp $CMD_NAME.md → $COMMANDS_DIR/"
  else
    cp "$cmd_file" "$COMMANDS_DIR/$CMD_NAME.md"
  fi
  ok "$CMD_NAME"
done

echo ""

# ═══════════════════════════════════════════════════
# [4/6] 에이전트 설치
# ═══════════════════════════════════════════════════
info "[4/6] 에이전트 설치 → $AGENTS_DIR"

if [ "$DRY_RUN" != true ]; then
  mkdir -p "$AGENTS_DIR"
fi

for agent_file in "$SCRIPT_DIR/agents/"*.md; do
  [ -f "$agent_file" ] || continue
  AGENT_NAME=$(basename "$agent_file")
  if [ "$DRY_RUN" = true ]; then
    dry "cp $AGENT_NAME → $AGENTS_DIR/"
  else
    cp "$agent_file" "$AGENTS_DIR/$AGENT_NAME"
  fi
  ok "$(basename "$AGENT_NAME" .md)"
done

# scripts/ 디렉토리 설치 (Layer 2 체크 스크립트)
SCRIPTS_DEST="$CODA_DIR/scripts"
if [ -d "$SCRIPT_DIR/scripts" ]; then
  if [ "$DRY_RUN" = true ]; then
    dry "mkdir -p $SCRIPTS_DEST"
    for script_file in "$SCRIPT_DIR/scripts/"*; do
      [ -f "$script_file" ] || continue
      dry "cp $(basename "$script_file") → $SCRIPTS_DEST/"
    done
  else
    mkdir -p "$SCRIPTS_DEST"
    for script_file in "$SCRIPT_DIR/scripts/"*; do
      [ -f "$script_file" ] || continue
      cp "$script_file" "$SCRIPTS_DEST/"
      chmod +x "$SCRIPTS_DEST/$(basename "$script_file")"
    done
  fi
  ok "scripts/ 설치 (Layer 2 체크 스크립트)"
fi

echo ""

# ═══════════════════════════════════════════════════
# [5/6] 프로젝트 초기화
# ═══════════════════════════════════════════════════
info "[5/6] 프로젝트 초기화 ($PROJECT_DIR)"

DEFAULT_NAME=$(basename "$PROJECT_DIR")

if [ "$DRY_RUN" = true ]; then
  # dry-run: 기본값 사용, 인터랙티브 프롬프트 스킵
  PROJECT_NAME="$DEFAULT_NAME"
  BUILD_CMD="pnpm build"
  TEST_CMD="pnpm test"
  LINT_CMD="pnpm lint"
  VERSION_FILE="VERSION"
  PKG_FILES="package.json"
  dry "프로젝트명: $PROJECT_NAME (기본값)"
  dry "빌드: $BUILD_CMD | 테스트: $TEST_CMD | 린트: $LINT_CMD"
  dry "버전 파일: $VERSION_FILE | package.json: $PKG_FILES"
  dry "coda/coda.config.json 생성"
  ok "프로젝트 설정 (기본값 사용)"
else
  # 프로젝트명
  ask "프로젝트명 ($DEFAULT_NAME): "
  read -r INPUT_NAME
  PROJECT_NAME="${INPUT_NAME:-$DEFAULT_NAME}"

  # 빌드 명령
  ask "빌드 명령 (pnpm build): "
  read -r INPUT_BUILD
  BUILD_CMD="${INPUT_BUILD:-pnpm build}"

  # 테스트 명령
  ask "테스트 명령 (pnpm test): "
  read -r INPUT_TEST
  TEST_CMD="${INPUT_TEST:-pnpm test}"

  # 린트 명령
  ask "린트 명령 (pnpm lint): "
  read -r INPUT_LINT
  LINT_CMD="${INPUT_LINT:-pnpm lint}"

  # 버전 파일
  ask "버전 파일 (VERSION): "
  read -r INPUT_VER
  VERSION_FILE="${INPUT_VER:-VERSION}"

  # package.json 경로 (쉼표 구분)
  ask "package.json 경로 (package.json): "
  read -r INPUT_PKG
  PKG_FILES="${INPUT_PKG:-package.json}"

  # coda/coda.config.json 생성
  PKG_JSON_ARRAY=$(echo "$PKG_FILES" | python3 -c "
import sys
files = [f.strip() for f in sys.stdin.read().strip().split(',') if f.strip()]
import json
print(json.dumps(files))
")

  cat > "$CODA_DIR/coda.config.json" << EOF
{
  "project_name": "$PROJECT_NAME",
  "pm_domain": "",
  "build_cmd": "$BUILD_CMD",
  "test_cmd": "$TEST_CMD",
  "lint_cmd": "$LINT_CMD",
  "version_file": "$VERSION_FILE",
  "package_files": $PKG_JSON_ARRAY,
  "i18n_files": [],
  "branch_prefix": "night/",
  "layer2_checks": {
    "orphan_files": {
      "enabled": true,
      "extensions": [".ts", ".tsx", ".js", ".jsx", ".css", ".scss"],
      "ignore_patterns": ["node_modules/", "dist/", "build/", ".next/", "coverage/"]
    },
    "env_consistency": {
      "enabled": true,
      "search_dirs": ["src/", "apps/"],
      "env_files": [".env.example"],
      "ignore_vars": ["NODE_ENV", "PORT"]
    },
    "lockfile_sync": {
      "enabled": true,
      "lockfile": "pnpm-lock.yaml",
      "package_manager": "pnpm"
    }
  },
  "mcp_servers": {}
}
EOF
  ok "coda/coda.config.json 생성 (layer2_checks 포함)"
fi

echo ""

# ═══════════════════════════════════════════════════
# [6/6] 프로젝트 파일 생성
# ═══════════════════════════════════════════════════
info "[6/6] 프로젝트 파일 생성"

# CLAUDE.md (없으면 생성)
if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
  if [ "$DRY_RUN" = true ]; then
    dry "CLAUDE.md.template → $PROJECT_DIR/CLAUDE.md"
  else
    sed -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
        -e "s|{{BUILD_CMD}}|$BUILD_CMD|g" \
        -e "s|{{TEST_CMD}}|$TEST_CMD|g" \
        -e "s|{{LINT_CMD}}|$LINT_CMD|g" \
        "$SCRIPT_DIR/templates/CLAUDE.md.template" > "$PROJECT_DIR/CLAUDE.md"
  fi
  ok "CLAUDE.md 생성"
else
  ok "CLAUDE.md 이미 존재 (스킵)"
fi

# PROJECT_STATUS.md (없으면 생성)
if [ ! -f "$PROJECT_DIR/PROJECT_STATUS.md" ]; then
  if [ "$DRY_RUN" = true ]; then
    dry "PROJECT_STATUS.md 템플릿 → $PROJECT_DIR/"
  else
    sed -e "s|(프로젝트명)|$PROJECT_NAME|g" \
        -e "s|(날짜)|$(date +%Y-%m-%d)|g" \
        "$SCRIPT_DIR/templates/PROJECT_STATUS.md" > "$PROJECT_DIR/PROJECT_STATUS.md"
  fi
  ok "PROJECT_STATUS.md 생성"
else
  ok "PROJECT_STATUS.md 이미 존재 (스킵)"
fi

# VERSION (없으면 생성)
if [ ! -f "$PROJECT_DIR/$VERSION_FILE" ]; then
  if [ "$DRY_RUN" = true ]; then
    dry "VERSION 파일 생성 (0.1.0)"
  else
    echo "0.1.0" > "$PROJECT_DIR/$VERSION_FILE"
  fi
  ok "$VERSION_FILE 생성 (0.1.0)"
else
  VER=$(tr -d '[:space:]' < "$PROJECT_DIR/$VERSION_FILE")
  ok "$VERSION_FILE 이미 존재 ($VER)"
fi

# memory 디렉토리
MEMORY_DIR="$CLAUDE_DIR/projects/$(echo "$PROJECT_DIR" | sed 's|/|-|g')/memory"
if [ "$DRY_RUN" = true ]; then
  dry "mkdir -p $MEMORY_DIR"
  if [ ! -f "$MEMORY_DIR/MEMORY.md" ]; then
    dry "MEMORY.md 템플릿 → $MEMORY_DIR/"
    ok "memory/MEMORY.md 생성"
  else
    ok "memory/MEMORY.md 이미 존재 (스킵)"
  fi
  dry "memory/ 서브 파일 4개 확인/생성"
  ok "memory/ 서브 파일 확인"
else
  mkdir -p "$MEMORY_DIR"

  if [ ! -f "$MEMORY_DIR/MEMORY.md" ]; then
    sed "s|(프로젝트명)|$PROJECT_NAME|g" \
        "$SCRIPT_DIR/templates/MEMORY.md" > "$MEMORY_DIR/MEMORY.md"
    ok "memory/MEMORY.md 생성"
  else
    ok "memory/MEMORY.md 이미 존재 (스킵)"
  fi

  # memory 서브 파일들 (빈 파일)
  for mf in backend-patterns.md frontend-patterns.md common-pitfalls.md architecture-decisions.md; do
    if [ ! -f "$MEMORY_DIR/$mf" ]; then
      echo "# $(echo "$mf" | sed 's/.md//' | sed 's/-/ /g')" > "$MEMORY_DIR/$mf"
    fi
  done
  ok "memory/ 서브 파일 확인"
fi

echo ""

# CODA 버전 파일 생성
if [ "$DRY_RUN" = true ]; then
  dry "echo $SCRIPT_VERSION > $CODA_VERSION_FILE"
else
  echo "$SCRIPT_VERSION" > "$CODA_VERSION_FILE"
fi
ok "CODA 버전: v$SCRIPT_VERSION"

echo ""

# ═══════════════════════════════════════════════════
# 완료 메시지
# ═══════════════════════════════════════════════════
echo -e "${BOLD}┌──────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}│  CODA 설치 완료!                              │${NC}"
echo -e "${BOLD}│  Claude Orchestrated Development Automation   │${NC}"
echo -e "${BOLD}│                                              │${NC}"
echo -e "${BOLD}│  팀 페르소나:                                 │${NC}"
echo -e "${BOLD}│  정하윤 PM        박안도 Backend              │${NC}"
echo -e "${BOLD}│  유아이 Frontend  배포준 DevOps               │${NC}"
echo -e "${BOLD}│  나검수 QA        문서인 Docs                 │${NC}"
echo -e "${BOLD}│  Chloe  Security  이지표 Data Analyst         │${NC}"
echo -e "${BOLD}│  송대시 Visualization                         │${NC}"
echo -e "${BOLD}│                                              │${NC}"
echo -e "${BOLD}│  명령어:                                      │${NC}"
echo -e "${BOLD}│  /초기화       코드베이스 분석 → CLAUDE.md     │${NC}"
echo -e "${BOLD}│  /상태저장     세션 종료 전 진행상황 저장       │${NC}"
echo -e "${BOLD}│  /상태복원     이전 세션 이어서 작업            │${NC}"
echo -e "${BOLD}│  /버전업       VERSION + package.json 동기화   │${NC}"
echo -e "${BOLD}│  /병렬작업     병렬 에이전트 실행               │${NC}"
echo -e "${BOLD}│  /자율개발     headless 멀티스텝 자율 코딩      │${NC}"
echo -e "${BOLD}│  /개발환경     포트, Docker, 빌드 가이드        │${NC}"
echo -e "${BOLD}│  /프론트가이드  React 컴포넌트 작성 가이드      │${NC}"
echo -e "${BOLD}│  /인사이트     프로젝트 분석 리포트 생성         │${NC}"
echo -e "${BOLD}│                                              │${NC}"
echo -e "${BOLD}│  첫 사용: claude 실행 후 /초기화              │${NC}"
echo -e "${BOLD}│  업데이트: bash install.sh --update           │${NC}"
echo -e "${BOLD}│  삭제:   bash install.sh --uninstall          │${NC}"
echo -e "${BOLD}└──────────────────────────────────────────────┘${NC}"
if [ "$DRY_RUN" = true ]; then
  echo ""
  warn "DRY RUN 모드 — 실제 파일 변경 없음"
  info "실제 설치: bash install.sh"
fi
echo ""
