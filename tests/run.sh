#!/usr/bin/env bash
# Test runner for the sticky-note plugin.
#
# 1. node --test over the pure logic seams (state document + bold).
# 2. a live quickshell instance driving NoteStateModel.qml against a real
#    temp file (the QML harness prints SNTEST lines; we watch for the
#    verdict and clean the process up).
#
# Requires a running Wayland session for part 2.

set -u
cd "$(dirname "$0")/.."

fail=0

echo "== node: pure logic seams =="
node --test "tests/"*.test.mjs || fail=1

if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  echo
  echo "== quickshell: state model integration =="
  LOG=$(mktemp)
  quickshell -p tests-harness.qml >"$LOG" 2>&1 &
  QSPID=$!
  for _ in $(seq 1 60); do
    grep -q "SNTEST DONE" "$LOG" && break
    kill -0 "$QSPID" 2>/dev/null || break
    sleep 1
  done
  kill "$QSPID" 2>/dev/null
  wait "$QSPID" 2>/dev/null
  grep -E "SNTEST|ERROR" "$LOG"
  if grep -q "SNTEST VERDICT: ALL PASS" "$LOG"; then
    echo "quickshell integration: PASS"
  else
    echo "quickshell integration: FAIL (full log: $LOG)"
    fail=1
  fi
else
  echo
  echo "== quickshell: state model integration =="
  echo "skipped: no Wayland session"
fi

exit "$fail"