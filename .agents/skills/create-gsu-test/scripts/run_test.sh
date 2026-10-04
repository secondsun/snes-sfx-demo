#!/usr/bin/env bash
# Run a GSU test in Mesen CE test runner mode.
# Usage: ./run_test.sh [test_directory] [timeout_seconds]

set -euo pipefail

TEST_DIR="${1:-.}"
TIMEOUT="${2:-10}"

cd "$TEST_DIR"

if [ ! -f "Test.sfc" ]; then
    echo "Error: Test.sfc not found in $TEST_DIR. Run 'make clean all' first." >&2
    exit 1
fi

if [ ! -f "test.lua" ]; then
    echo "Error: test.lua not found in $TEST_DIR." >&2
    exit 1
fi

MESEN_BIN="/home/summers/Programs/Mesen"
if [ ! -x "$MESEN_BIN" ]; then
    MESEN_BIN="$(which Mesen 2>/dev/null || which mesen 2>/dev/null || echo "")"
fi

if [ -z "$MESEN_BIN" ] || [ ! -x "$MESEN_BIN" ]; then
    echo "Error: Mesen executable not found." >&2
    exit 1
fi

echo "Running Mesen test runner in $TEST_DIR (timeout: ${TIMEOUT}s)..."
"$MESEN_BIN" --testRunner --timeout="$TIMEOUT" test.lua Test.sfc
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "=== TEST PASSED ==="
else
    echo "=== TEST FAILED (Exit Code: $EXIT_CODE) ==="
fi

exit $EXIT_CODE
