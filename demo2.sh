#!/usr/bin/env bash
# demo2.sh — Speaker C's demos, one command per Enter key.
#
# Usage:  ./demo2.sh auto [repo-dir]   # slide 9:  git bisect run
#         ./demo2.sh skip [repo-dir]   # slide 11: a commit that won't run
# Default repo-dir: ./cart-demo   (create it with ./make_demo_repo.sh)
# Press Ctrl+C to stop; the next run resets the bisect automatically.

set -u
MODE="${1:-}"
REPO="${2:-cart-demo}"
case "$MODE" in auto|skip) ;; *) echo "Usage: ./demo2.sh auto|skip [repo-dir]"; exit 1;; esac
cd "$REPO" || { echo "No repo at '$REPO'. Run ./make_demo_repo.sh first."; exit 1; }

BOLD=$'\033[1m'; DIM=$'\033[2m'; CYAN=$'\033[36m'; RESET=$'\033[0m'

step() {   # step "comment" "command"
  echo
  echo "${DIM}# $1${RESET}"
  printf '%s$ %s%s' "$BOLD$CYAN" "$2" "$RESET"
  read -r _
  eval "$2"
}

git bisect reset >/dev/null 2>&1
git checkout -q main
clear

if [ "$MODE" = auto ]; then
  step "One line: bad commit first, then good"   "git bisect start HEAD v1.0"
  step "Let git run the test at every step"      "git bisect run python3 test.py"
  step "Back to where we started"                "git bisect reset"
else
  step "This old commit was half-finished code"  "git checkout -q 68b080a && git log --oneline -1"
  step "Our test can't even start here"          "python3 test.py"
  step "The wrapper turns that into exit 125"    "cat bisect-check.sh"
  step "Run it and check the exit code"          "./bisect-check.sh; echo \"exit code: \$?\""
  step "Back to the latest code"                 "git checkout -q main"
  step "Full bisect with the wrapper"            "git bisect start HEAD v1.0 && git bisect run ./bisect-check.sh"
  step "Back to where we started"                "git bisect reset"
fi
echo
