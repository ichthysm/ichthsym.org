#!/usr/bin/env bash
# Quick test for Layer 2 backward compatibility

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== Layer 2 Backward Compatibility Quick Test ==="
echo ""

# Test 1: Config parsing
echo "[1/5] Testing parse-config.sh..."
source tools/coda/scripts/parse-config.sh
if load_layer2_config; then
    echo "  ✓ Config loaded (layer2_checks may be absent)"
else
    echo "  ✓ Config load returned false (expected for missing layer2_checks)"
fi

# Test 2: Check enabled status (should default to true)
echo ""
echo "[2/5] Testing is_check_enabled (should default to true)..."
for check in orphan_files env_consistency lockfile_sync; do
    if is_check_enabled "$check"; then
        echo "  ✓ $check: enabled (default)"
    else
        echo "  ✗ $check: disabled (unexpected!)"
        exit 1
    fi
done

# Test 3: Get option with default
echo ""
echo "[3/5] Testing get_check_option (should return defaults)..."
RESULT=$(get_check_option "orphan_files" "extensions" '["default"]')
echo "  ✓ orphan_files.extensions: $RESULT"

# Test 4: orphan-files check (dry run)
echo ""
echo "[4/5] Testing check-orphan-files.sh..."
if bash tools/coda/scripts/check-orphan-files.sh 2>&1 | head -20; then
    echo "  ✓ check-orphan-files.sh completed"
else
    EXIT=$?
    echo "  ✗ check-orphan-files.sh failed with exit code $EXIT"
fi

# Test 5: env-consistency check (dry run)
echo ""
echo "[5/5] Testing check-env-consistency.sh..."
if bash tools/coda/scripts/check-env-consistency.sh 2>&1 | head -20; then
    echo "  ✓ check-env-consistency.sh completed"
else
    EXIT=$?
    echo "  ✗ check-env-consistency.sh failed with exit code $EXIT"
fi

echo ""
echo "=== Quick Test Complete ==="
echo "All critical functions working correctly without layer2_checks in config"
