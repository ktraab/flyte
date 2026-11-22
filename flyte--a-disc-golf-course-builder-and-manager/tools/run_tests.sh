#!/usr/bin/env bash
# Headless smoke tests for Flyte.
#
#   tools/run_tests.sh            # run everything
#   tools/run_tests.sh story      # only tests whose "suite::name" contains "story"
#
# HOME is pointed at a throwaway dir so user:// (settings.cfg, courses/*.json)
# never touches your real save. Exit code: 0 = all passed, 1 = failures,
# 2 = setup problem, 3 = script/parse errors in the log.
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [ ! -x "$GODOT" ]; then
  GODOT="$(command -v godot || command -v godot4 || true)"
fi
[ -x "$GODOT" ] || { echo "Godot not found — set GODOT=/path/to/godot"; exit 2; }

TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/flyte_test_home.XXXXXX")"
LOG="$TEST_HOME/test.log"
trap 'rm -rf "$TEST_HOME"' EXIT

# Import pass first so newly added assets/scripts (and class_names) are registered.
HOME="$TEST_HOME" "$GODOT" --headless --path . --import >"$TEST_HOME/import.log" 2>&1

FLYTE_TEST_FILTER="${1:-}" HOME="$TEST_HOME" "$GODOT" --headless --path . -s tests/run_tests.gd >"$LOG" 2>&1 &
PID=$!
# Watchdog: a hung run (e.g. an OS security prompt) must not block forever.
( sleep "${FLYTE_TEST_TIMEOUT:-300}"; kill "$PID" 2>/dev/null ) &
WATCH=$!
wait "$PID"; CODE=$?
kill "$WATCH" 2>/dev/null; wait "$WATCH" 2>/dev/null

# Show test lines, then any engine/script errors (minus known-benign noise).
grep -E "^  (ok|FAIL) |^====|^ABORT" "$LOG"
# Each engine error = "ERROR:/SCRIPT ERROR:" line + "at:" line. Pair them, drop benign ones.
ERRS="$(awk '/^(SCRIPT )?ERROR:|^WARNING:/{msg=$0; getline loc; print msg " | " loc}' "$LOG" \
  | grep -vE "godotsteam|GDExtension|dynamic library|resources still in use|ObjectDB instances leaked|Steam init failed" \
  | sed -E 's/[[:space:]]+/ /g' | sort | uniq -c | sort -rn || true)"
if [ -n "$ERRS" ]; then
  echo ""
  echo "---- engine errors/warnings (count | message | location) ----"
  echo "$ERRS" | head -40
  [ "$CODE" -eq 0 ] && grep -qE "ERROR" <<<"$ERRS" && CODE=3
fi
if ! grep -q "^====" "$LOG"; then
  echo "Runner did not finish (exit $CODE). Last log lines:"; tail -30 "$LOG"
  [ "$CODE" -eq 0 ] && CODE=2
fi
exit "$CODE"
