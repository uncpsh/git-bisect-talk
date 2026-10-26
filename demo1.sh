#!/usr/bin/env bash
# demo1.sh — Speaker B's manual bisect demo, one command per Enter key.
#
# Usage:  ./demo1.sh [repo-dir]      (default: ./cart-demo)
# Each step prints the command, waits for Enter, then runs it.
# Press Ctrl+C at any time to stop; then run `git bisect reset` inside the repo.

set -u
REPO="${1:-cart-demo}"
cd "$REPO" || { echo "No repo at '$REPO'. Run ./make_demo_repo.sh first."; exit 1; }

BOLD=$'\033[1m'; DIM=$'\033[2m'; CYAN=$'\033[36m'; RESET=$'\033[0m'

step() {   # step "comment" "command"
  echo
  echo "${DIM}# $1${RESET}"
  printf '%s$ %s%s' "$BOLD$CYAN" "$2" "$RESET"
  read -r _
  eval "$2"
}

git bisect reset >/dev/null 2>&1   # start clean even after an aborted rehearsal
clear

step "Begin a bisect session"                  "git bisect start"
step "HEAD fails the test: mark it bad"        "git bisect bad"
step "v1.0 passed: mark it good"               "git bisect good v1.0"
step "Git checked out the middle. Test it"     "python3 test.py"
step "It passes: good"                         "git bisect good"
step "Test the next middle commit"             "python3 test.py"
step "It fails: bad"                           "git bisect bad"
step "Test again"                              "python3 test.py"
step "Passes: good"                            "git bisect good"
step "Test again"                              "python3 test.py"
step "Fails: bad"                              "git bisect bad"
step "Last one"                                "python3 test.py"
step "Fails: bad"                              "git bisect bad"
step "What did the culprit change?"            "git --no-pager show cd58d8b -- cart.py"
step "Done: go back to where we started"       "git bisect reset"
echo
