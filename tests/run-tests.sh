#!/bin/bash
# Status line test suite. No network, no shared state.
#
# Each case builds a stdin payload and an isolated settings file
# (STATUSBAR_CONFIG), then compares the ANSI-stripped output against an
# expected value. Reset epochs are derived from `now` so countdowns are
# deterministic.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$HERE/../statusline/statusline.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

strip_ansi() { sed $'s/\033\\[[0-9;]*m//g'; }

# config_with FLAG=VAL ... -> path to a settings file
config_with() {
  local f="$WORK/config.$RANDOM.txt"
  printf '%s\n' "$@" > "$f"
  printf '%s' "$f"
}

# check <name> <config> <payload> <expected multi-line output>
check() {
  local name="$1" config="$2" payload="$3" expected="$4" actual
  actual=$(printf '%s' "$payload" | STATUSBAR_CONFIG="$config" bash "$SCRIPT" | strip_ansi)
  if [ "$actual" = "$expected" ]; then
    printf '  ok   %s\n' "$name"
    pass=$((pass + 1))
  else
    printf '  FAIL %s\n' "$name"
    printf '       expected: %s\n' "$(printf '%s' "$expected" | tr '\n' '⏎')"
    printf '       actual:   %s\n' "$(printf '%s' "$actual"   | tr '\n' '⏎')"
    fail=$((fail + 1))
  fi
}

NOW=$(date +%s)
IN_2H=$((NOW + 8010))     # 2h13m30: 30 s of slack keeps the render at "2h13"
IN_3D=$((NOW + 259200))
EMPTY_DIR="$WORK/plain"; mkdir -p "$EMPTY_DIR"

ALL_ON=$(config_with SHOW_DIRECTORY=1 SHOW_BRANCH=1 SHOW_PR=1 SHOW_MODEL=1 \
  SHOW_USAGE=1 SHOW_SEVEN_DAY=1 SHOW_PROGRESS_BAR=1 SHOW_RESET_TIME=1 \
  SHOW_CONTEXT=1 SHOW_GIT_STATUS=1 SHOW_SESSION_NAME=1 SHOW_LINES_CHANGED=1 \
  RESET_COUNTDOWN=1)

echo "== nominal render =="

check "full payload" "$ALL_ON" \
  "{\"workspace\":{\"current_dir\":\"$EMPTY_DIR\"},\"model\":{\"display_name\":\"a-model\"},
    \"session_name\":\"my session\",\"context_window\":{\"used_percentage\":26.4},
    \"cost\":{\"total_lines_added\":649,\"total_lines_removed\":167},
    \"pr\":{\"number\":1424,\"review_state\":\"pending\"},
    \"rate_limits\":{\"five_hour\":{\"used_percentage\":47.2,\"resets_at\":$IN_2H},
                     \"seven_day\":{\"used_percentage\":50.9,\"resets_at\":$IN_3D}}}" \
"plain │ PR #1424 ⋯ │ a-model │ my session
ctx: 26% │ 5h: 47% ▓▓▓▓▓░░░░░ → 2h13 │ 7d: 50% ▓▓▓▓▓░░░░░ → 3d │ +649/-167"

echo "== missing quotas =="

# rate_limits does not exist before the first API response: we must show
# "Usage: ~" and above all NOT a phantom 0% quota.
check "no rate_limits at all" "$ALL_ON" \
  "{\"workspace\":{\"current_dir\":\"$EMPTY_DIR\"},\"model\":{\"display_name\":\"a-model\"},
    \"context_window\":{\"used_percentage\":12}}" \
"plain │ a-model
ctx: 12% │ Usage: ~"

check "5h present, 7d absent" "$ALL_ON" \
  "{\"workspace\":{\"current_dir\":\"$EMPTY_DIR\"},
    \"rate_limits\":{\"five_hour\":{\"used_percentage\":8,\"resets_at\":$IN_2H}}}" \
"plain
5h: 8% ▓░░░░░░░░░ → 2h13"

echo "== thresholds =="

check "context >= 80 raises the warning" "$ALL_ON" \
  "{\"workspace\":{\"current_dir\":\"$EMPTY_DIR\"},\"context_window\":{\"used_percentage\":83.6},
    \"rate_limits\":{\"five_hour\":{\"used_percentage\":100,\"resets_at\":$IN_2H}}}" \
"plain
⚠ ctx: 83% │ 5h: 100% ▓▓▓▓▓▓▓▓▓▓ → 2h13"

check "0% fills no block" "$ALL_ON" \
  "{\"workspace\":{\"current_dir\":\"$EMPTY_DIR\"},
    \"rate_limits\":{\"five_hour\":{\"used_percentage\":0,\"resets_at\":$IN_2H}}}" \
"plain
5h: 0% ░░░░░░░░░░ → 2h13"

echo "== regression: consecutive empty fields =="

# The separator is 0x1F rather than a tab precisely so two empty fields in a
# row cannot shift the ones after them. Here pr, model and session_name are
# all absent: current_dir, read last, must survive.
check "three empty fields in a row do not shift current_dir" "$ALL_ON" \
  "{\"workspace\":{\"current_dir\":\"$EMPTY_DIR\"},\"context_window\":{\"used_percentage\":5},
    \"cost\":{\"total_lines_added\":1,\"total_lines_removed\":0},
    \"rate_limits\":{\"five_hour\":{\"used_percentage\":10,\"resets_at\":$IN_2H}}}" \
"plain
ctx: 5% │ 5h: 10% ▓░░░░░░░░░ → 2h13 │ +1/-0"

echo "== settings =="

check "everything off renders nothing" "$(config_with SHOW_DIRECTORY=0 SHOW_BRANCH=0 SHOW_PR=0 \
  SHOW_MODEL=0 SHOW_USAGE=0 SHOW_CONTEXT=0 SHOW_SESSION_NAME=0 SHOW_LINES_CHANGED=0)" \
  "{\"workspace\":{\"current_dir\":\"$EMPTY_DIR\"},\"model\":{\"display_name\":\"a-model\"},
    \"rate_limits\":{\"five_hour\":{\"used_percentage\":47,\"resets_at\":$IN_2H}}}" \
""

check "bar and reset disabled" "$(config_with SHOW_PROGRESS_BAR=0 SHOW_RESET_TIME=0 \
  SHOW_DIRECTORY=0 SHOW_CONTEXT=0 SHOW_LINES_CHANGED=0)" \
  "{\"workspace\":{\"current_dir\":\"$EMPTY_DIR\"},
    \"rate_limits\":{\"five_hour\":{\"used_percentage\":47,\"resets_at\":$IN_2H}}}" \
"5h: 47%"

echo "== git =="

REPO="$WORK/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q -b main 2>/dev/null
git -C "$REPO" config user.email t@t.t; git -C "$REPO" config user.name t
echo one > "$REPO/a.txt"; git -C "$REPO" add a.txt
git -C "$REPO" commit -qm init
check "clean repository" "$(config_with SHOW_PR=0 SHOW_MODEL=0 SHOW_USAGE=0 SHOW_CONTEXT=0 \
  SHOW_SESSION_NAME=0 SHOW_LINES_CHANGED=0)" \
  "{\"workspace\":{\"current_dir\":\"$REPO\"}}" \
"repo │ ⎇ main"

echo two > "$REPO/b.txt"
check "dirty repository marked with *" "$(config_with SHOW_PR=0 SHOW_MODEL=0 SHOW_USAGE=0 \
  SHOW_CONTEXT=0 SHOW_SESSION_NAME=0 SHOW_LINES_CHANGED=0)" \
  "{\"workspace\":{\"current_dir\":\"$REPO\"}}" \
"repo │ ⎇ main*"

check "outside a repository: no git segment" "$(config_with SHOW_PR=0 SHOW_MODEL=0 SHOW_USAGE=0 \
  SHOW_CONTEXT=0 SHOW_SESSION_NAME=0 SHOW_LINES_CHANGED=0)" \
  "{\"workspace\":{\"current_dir\":\"$EMPTY_DIR\"}}" \
"plain"

echo "== robustness =="

check "empty stdin does not crash" "$ALL_ON" "" \
"Usage: ~"

check "invalid JSON does not crash" "$ALL_ON" "not json at all" \
"Usage: ~"

echo "== independence: no credentials, no network =="

# The core of the fix: not a trace of the old session-cookie mechanism.
code_only=$(grep -vE '^[[:space:]]*#' "$SCRIPT")
if printf '%s' "$code_only" | grep -qiE 'sessionkey|usage-credentials|/api/organizations|fetch-.*-usage|curl |urllib'; then
  echo "  FAIL the script still references a credential or network mechanism"
  printf '%s' "$code_only" | grep -niE 'sessionkey|usage-credentials|/api/organizations|fetch-.*-usage|curl |urllib' | sed 's/^/       /'
  fail=$((fail + 1))
else
  echo "  ok   no session cookie and no network call anywhere in the code"
  pass=$((pass + 1))
fi

# A pristine HOME stands in for a freshly provisioned machine: the status line
# must render quotas without a single credential file.
FAKE_HOME="$WORK/fresh"; mkdir -p "$FAKE_HOME"
out=$(printf '%s' "{\"workspace\":{\"current_dir\":\"$EMPTY_DIR\"},\"rate_limits\":{\"five_hour\":{\"used_percentage\":47,\"resets_at\":$IN_2H}}}" \
  | env HOME="$FAKE_HOME" STATUSBAR_CONFIG="$FAKE_HOME/absent.txt" bash "$SCRIPT" | strip_ansi)
if [ "$out" = "plain
5h: 47% ▓▓▓▓▓░░░░░ → 2h13" ]; then
  echo "  ok   pristine HOME with no credentials: quotas still render"
  pass=$((pass + 1))
else
  echo "  FAIL pristine HOME: got « $(printf '%s' "$out" | tr '\n' '⏎') »"
  fail=$((fail + 1))
fi

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
