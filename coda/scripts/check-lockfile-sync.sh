#!/usr/bin/env bash
# check-lockfile-sync.sh - pnpm-lock.yaml과 package.json 동기화 체크
# Layer 2 QA Gate 체크
#
# 사용법:
#   ./tools/coda/scripts/check-lockfile-sync.sh
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
HAS_WARNING=0

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

echo "=== Lockfile Sync Check ==="

# Config 로드
load_layer2_config || true

# 체크 활성화 여부 확인
if ! is_check_enabled "lockfile_sync"; then
  echo "[SKIP] lockfile_sync check is disabled"
  exit 0
fi

# 설정 읽기
LOCKFILE=$(get_check_option "lockfile_sync" "lockfile" "pnpm-lock.yaml")
PACKAGE_MANAGER=$(get_check_option "lockfile_sync" "package_manager" "pnpm")

echo "Package manager: $PACKAGE_MANAGER"
echo "Lockfile: $LOCKFILE"
echo ""

cd "$PROJECT_ROOT"

# 1. pnpm 사용 가능 여부 체크
check_pnpm_available() {
  if ! command -v pnpm &>/dev/null; then
    echo -e "${RED}[ERROR]${NC} pnpm is not installed or not in PATH"
    return 1
  fi
  return 0
}

# 2. lockfile 존재 여부 체크
check_lockfile_exists() {
  if [[ ! -f "$PROJECT_ROOT/$LOCKFILE" ]]; then
    echo -e "${YELLOW}[LOCKFILE-WARN]${NC} Lockfile not found: $LOCKFILE"
    echo "  Consider running 'pnpm install' to generate lockfile"
    HAS_WARNING=1
    return 1
  fi
  return 0
}

# 3. package.json 존재 여부 체크
check_package_json_exists() {
  if [[ ! -f "$PROJECT_ROOT/package.json" ]]; then
    echo -e "${RED}[ERROR]${NC} package.json not found in project root"
    return 1
  fi
  return 0
}

# 4. frozen lockfile 동기화 체크
check_lockfile_sync() {
  echo -e "${CYAN}Running lockfile sync check...${NC}"
  echo ""

  # --dry-run으로 실제 설치 없이 체크
  # pnpm install --frozen-lockfile은 lockfile과 package.json이 동기화되지 않으면 실패
  local output
  local exit_status=0

  # stderr도 캡처하기 위해 2>&1 사용
  output=$(pnpm install --frozen-lockfile --dry-run 2>&1) || exit_status=$?

  if [[ $exit_status -ne 0 ]]; then
    echo -e "${YELLOW}[LOCKFILE-WARN]${NC} Lockfile is out of sync with package.json"
    echo ""
    echo "Details:"
    echo "$output" | head -20  # 처음 20줄만 출력

    echo ""
    echo "This typically happens when:"
    echo "  1. package.json was modified but 'pnpm install' wasn't run"
    echo "  2. Dependencies were added/removed without updating lockfile"
    echo "  3. pnpm version mismatch between environments"
    echo ""
    echo "To fix this issue, run:"
    echo -e "  ${CYAN}pnpm install${NC}"
    echo ""

    HAS_WARNING=1
    return 1
  fi

  return 0
}

# 5. lockfile 버전 체크 (pnpm v8+ 형식)
check_lockfile_version() {
  if [[ ! -f "$PROJECT_ROOT/$LOCKFILE" ]]; then
    return 0
  fi

  # lockfileVersion 추출
  local version
  version=$(grep -m1 "^lockfileVersion:" "$PROJECT_ROOT/$LOCKFILE" 2>/dev/null | awk '{print $2}' | tr -d "'\"" || echo "")

  if [[ -n "$version" ]]; then
    echo "Lockfile version: $version"

    # pnpm 버전과 lockfile 버전 호환성 체크
    local pnpm_version
    pnpm_version=$(pnpm --version 2>/dev/null || echo "unknown")
    echo "pnpm version: $pnpm_version"

    # v9 lockfile은 pnpm 9.x 이상 필요
    if [[ "$version" == "9.0" || "$version" == "9" ]]; then
      local major_version
      major_version=$(echo "$pnpm_version" | cut -d'.' -f1)
      if [[ "$major_version" -lt 9 ]]; then
        echo -e "${YELLOW}[LOCKFILE-WARN]${NC} Lockfile version $version requires pnpm 9.x+"
        echo "  Current pnpm version: $pnpm_version"
        HAS_WARNING=1
      fi
    fi
  fi

  return 0
}

# 메인 실행
main() {
  local checks_passed=0
  local checks_total=0

  # pnpm 체크
  ((checks_total++))
  if check_pnpm_available; then
    ((checks_passed++))
  else
    echo ""
    echo -e "${RED}[ERROR]${NC} Cannot perform lockfile sync check without pnpm"
    exit 1
  fi

  # package.json 체크
  ((checks_total++))
  if check_package_json_exists; then
    ((checks_passed++))
  else
    exit 1
  fi

  # lockfile 존재 체크
  ((checks_total++))
  if check_lockfile_exists; then
    ((checks_passed++))
  else
    # lockfile이 없으면 동기화 체크 불가
    echo ""
    echo "=== Summary ==="
    echo "Checks: $checks_passed/$checks_total passed"
    echo -e "${YELLOW}[LOCKFILE-WARN]${NC} Lockfile sync check skipped (no lockfile)"
    exit 0
  fi

  # lockfile 버전 체크
  ((checks_total++))
  check_lockfile_version
  ((checks_passed++))

  echo ""

  # 동기화 체크
  ((checks_total++))
  if check_lockfile_sync; then
    ((checks_passed++))
    echo -e "${GREEN}[OK]${NC} Lockfile is in sync with package.json"
  fi

  # 결과 출력
  echo ""
  echo "=== Summary ==="
  echo "Checks: $checks_passed/$checks_total passed"

  if [[ $HAS_WARNING -gt 0 ]]; then
    echo -e "${YELLOW}Warnings found${NC} - lockfile may need to be regenerated"
    echo ""
    echo "Note: This is a warning check. It does not block the build."
    echo "To disable this check, set layer2_checks.lockfile_sync.enabled = false"
    echo "in coda.config.json"
  else
    echo -e "${GREEN}All checks passed${NC}"
  fi

  exit $EXIT_CODE
}

main "$@"
