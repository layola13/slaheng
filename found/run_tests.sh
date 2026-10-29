#!/usr/bin/env bash
# Heng found/ — corpus runner.
# All implementation and checking live in the SLA files; this script
# only sequences `sla` invocations and asserts on evidence lines
# (same thin-wrapper form as sa_plugin_sla's run_tests_batched.sh).
#
# Verdict rule (four-fold): a corpus counts as passed only if the
# runner prints "test result: ok" AND every expected [PASS] line is
# present. A negative corpus counts as passed only if its expected
# panic code appears AND the test itself FAILs (loud failure).
set -u
cd "$(dirname "$0")"

SA_BIN_DIR="${HENG_SA_BIN:-$HOME/workspace/gosyntax-local/sci-local/zig-out/bin}"
ZIG_BIN_DIR="${HENG_ZIG_BIN:-$HOME/workspace/local-sa/zig17}"
SLA="${HENG_SLA:-$HOME/workspace/gosyntax-local/sla-plugin/zig-out/bin/sla}"
export PATH="$SA_BIN_DIR:$ZIG_BIN_DIR:$PATH"

FAILURES=0

check_lib() {
    if timeout 120 "$SLA" check "$1" >/dev/null 2>&1; then
        echo "[OK]   sla check $1"
    else
        echo "[BAD]  sla check $1"
        FAILURES=$((FAILURES + 1))
    fi
}

run_corpus() {
    file="$1"
    expected_passes="$2"
    out="$(timeout 600 "$SLA" test --test-backend sa "$file" 2>&1)"
    npass="$(printf '%s\n' "$out" | grep -c '^\[PASS\]')"
    if printf '%s\n' "$out" | grep -q 'test result: ok' && [ "$npass" -eq "$expected_passes" ]; then
        echo "[OK]   $file ($npass/$expected_passes passed)"
    else
        echo "[BAD]  $file"
        printf '%s\n' "$out" | grep -E 'PASS|FAIL|test result|panic' | sed 's/^/       /'
        FAILURES=$((FAILURES + 1))
    fi
}

run_negative() {
    file="$1"
    code="$2"
    out="$(timeout 600 "$SLA" test --test-backend sa "$file" 2>&1 || true)"
    if printf '%s\n' "$out" | grep -q "panic: code=$code" && printf '%s\n' "$out" | grep -q 'test result: FAILED'; then
        echo "[OK]   $file (loud panic code=$code as designed)"
    else
        echo "[BAD]  $file (expected panic code=$code)"
        printf '%s\n' "$out" | grep -E 'PASS|FAIL|test result|panic' | sed 's/^/       /'
        FAILURES=$((FAILURES + 1))
    fi
}

rm -rf .sla-cache

check_lib bigint.sla
check_lib rational.sla
check_lib quantity.sla

run_corpus test_bigint.sla 6
run_corpus test_rational.sla 5
run_corpus test_quantity.sla 5

run_negative neg_dim_test.sla 8303
run_negative neg_unit_test.sla 8301

if [ "$FAILURES" -eq 0 ]; then
    echo "found/: ALL PASS (3 libs check, 16 corpus tests, 2 negative loud-failure cases)"
else
    echo "found/: $FAILURES item(s) FAILED"
    exit 1
fi
