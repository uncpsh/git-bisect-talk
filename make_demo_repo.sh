#!/usr/bin/env bash
# make_demo_repo.sh — build the deterministic demo repo for the git bisect talk.
#
# Usage:   ./make_demo_repo.sh [target-dir]      (default: ./cart-demo)
# Needs:   git 2.28+ and python3 (to run test.py during the demo)
#
# What you get:
#   - a tiny shopping-cart discount calculator (cart.py) and its test (test.py)
#   - 3 commits up to the tag v1.0 (known good), then 30 more commits (HEAD is bad)
#   - one buried bug: a "refactor" that silently changes how cents are rounded
#   - one commit that does not even import (for the git bisect skip demo)
#   - bisect-check.sh: wrapper for `git bisect run` (exit 125 = skip)
#
# Every run produces the same history and the same commit hashes, because the
# author, committer and dates are fixed below.

set -euo pipefail

TARGET="${1:-cart-demo}"
if [ -e "$TARGET" ]; then
  echo "error: '$TARGET' already exists. Remove it or pass another directory." >&2
  exit 1
fi

# ---- fixed identity and clock, so commit hashes are identical everywhere ----
export GIT_AUTHOR_NAME="Demo Dev"
export GIT_AUTHOR_EMAIL="demo@example.com"
export GIT_COMMITTER_NAME="Demo Dev"
export GIT_COMMITTER_EMAIL="demo@example.com"
CLOCK=1790863200            # 2026-10-01 10:00 UTC; each commit is 1 hour later

mkdir -p "$TARGET"
cd "$TARGET"
git init -q -b main
git config core.autocrlf false
git config core.hooksPath /dev/null
git config commit.gpgsign false
git config tag.gpgsign false

commit() {   # commit "message" — stage everything and commit at the next tick
  export GIT_AUTHOR_DATE="$CLOCK +0000"
  export GIT_COMMITTER_DATE="$CLOCK +0000"
  git add -A
  git commit -q -m "$1"
  CLOCK=$((CLOCK + 3600))
}

# ---- cart.py is assembled from parts, so each commit can change one part ----
write_cart() {
  printf '%s\n\n\n%s\n\n\n%s\n\n\n%s\n' "$HEADER" "$SUBTOTAL" "$DISCOUNT" "$TOTAL" > cart.py
  if [ -n "$EXTRAS" ]; then printf '\n\n%s\n' "$EXTRAS" >> cart.py; fi
}

read -r -d '' HEADER <<'EOF' || true
"""Shopping-cart discount calculator."""
from decimal import Decimal, ROUND_HALF_UP

CENT = Decimal("0.01")
EOF

read -r -d '' SUBTOTAL <<'EOF' || true
def subtotal(prices):
    """Sum item prices given as strings, e.g. ["19.99", "5.00"]."""
    return sum((Decimal(p) for p in prices), Decimal("0"))
EOF

read -r -d '' DISCOUNT <<'EOF' || true
def apply_discount(amount, percent):
    """Take `percent` off `amount` and round to the cent."""
    discounted = amount * (Decimal(100) - Decimal(percent)) / Decimal(100)
    return discounted.quantize(CENT, rounding=ROUND_HALF_UP)
EOF

read -r -d '' TOTAL <<'EOF' || true
def total(prices, percent=0):
    """Total to pay for `prices` after a `percent` discount."""
    return apply_discount(subtotal(prices), percent)
EOF

EXTRAS=""

# ============================ up to v1.0 (good) ============================

write_cart
cat > test.py <<'EOF'
"""Test for the cart calculator, written for `git bisect run`.

Exit-code contract:
  0   = good  (every check passes)
  1   = bad   (a check fails)
A crash (e.g. cart.py does not import) also exits 1, so use
bisect-check.sh with `git bisect run` when a commit might not run.
"""
import sys
from decimal import Decimal

from cart import total

CASES = [
    (["19.99", "5.01"], 10, Decimal("22.50")),
    (["100.00"], 10, Decimal("90.00")),
    (["2.25"], 50, Decimal("1.13")),  # 1.125 -> half a cent rounds up
]


def main():
    ok = True
    for prices, percent, expected in CASES:
        got = total(prices, percent)
        if got != expected:
            ok = False
        mark = "ok  " if got == expected else "FAIL"
        print(f"{mark} total({prices}, {percent}% off) = {got}   expected {expected}")
    print("PASS" if ok else "FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
EOF
commit "Initial cart calculator with tests"

cat > README.md <<'EOF'
# cart-demo

A tiny shopping-cart discount calculator.

Run the tests with `python test.py`.
EOF
commit "Add README"

cat > LICENSE <<'EOF'
Demo code for a git bisect talk. Free to use for any purpose.
EOF
commit "Add LICENSE"
git tag v1.0

# ===================== 30 commits after v1.0 (HEAD is bad) =================

cat > CONTRIBUTING.md <<'EOF'
# Contributing

Keep commits small. Run `python test.py` before every commit.
EOF
commit "Add CONTRIBUTING guide"

cat >> README.md <<'EOF'

## Discounts

A discount is a whole percentage taken off the subtotal.
Totals are rounded to the cent, and half a cent rounds up.
EOF
commit "Document discount rules in README"

read -r -d '' SUBTOTAL <<'EOF' || true
def subtotal(prices: list[str]) -> Decimal:
    """Sum item prices given as strings, e.g. ["19.99", "5.00"]."""
    return sum((Decimal(p) for p in prices), Decimal("0"))
EOF
write_cart
commit "Add type hints to subtotal"

printf '__pycache__/\n*.pyc\n' > .gitignore
commit "Add .gitignore"

read -r -d '' EXTRAS <<'EOF' || true
def item_count(prices):
    """Number of items in the cart."""
    return len(prices)
EOF
write_cart
commit "Add item_count helper"

cat >> README.md <<'EOF'

## Helpers

`item_count(prices)` returns the number of items.
EOF
commit "Document item_count"

read -r -d '' DISCOUNT <<'EOF' || true
def apply_discount(amount, percent):
    """Take `percent` off `amount` and round to the cent."""
    after_discount = amount * (Decimal(100) - Decimal(percent)) / Decimal(100)
    return after_discount.quantize(CENT, rounding=ROUND_HALF_UP)
EOF
write_cart
commit "Rename discounted to after_discount"

cat > CHANGELOG.md <<'EOF'
# Changelog

## Unreleased
- Type hints, item_count helper
EOF
commit "Add CHANGELOG"

mkdir -p docs
cat > docs/rounding.md <<'EOF'
# Rounding

Money is rounded to the cent with ROUND_HALF_UP: 1.125 becomes 1.13.
EOF
commit "Explain rounding in docs"

# --- the commit that does not even import (missing colon) ---
read -r -d '' EXTRAS <<'EOF' || true
def item_count(prices):
    """Number of items in the cart."""
    return len(prices)


def apply_coupon(amount, code)
    """WIP: coupons are not finished yet."""
    return amount
EOF
write_cart
commit "WIP: start coupon support"

read -r -d '' EXTRAS <<'EOF' || true
def item_count(prices):
    """Number of items in the cart."""
    return len(prices)


COUPONS = {"SAVE5": Decimal("5.00")}


def apply_coupon(amount, code):
    """Subtract a fixed coupon amount, never going below zero."""
    if code not in COUPONS:
        raise ValueError(f"unknown coupon: {code}")
    return max(amount - COUPONS[code], Decimal("0.00"))
EOF
write_cart
commit "Finish coupon support"

sed -i.bak 's/whole percentage/whole-number percentage/' README.md && rm -f README.md.bak
commit "Fix wording in README"

read -r -d '' TOTAL <<'EOF' || true
def total(prices, percent=0):
    """Total to pay for `prices` after a `percent` discount (0-100)."""
    return apply_discount(subtotal(prices), percent)
EOF
write_cart
commit "Clarify total() docstring"

cat > docs/faq.md <<'EOF'
# FAQ

**Can a discount be over 100%?** No. Keep it between 0 and 100.
EOF
commit "Add FAQ"

read -r -d '' EXTRAS <<'EOF' || true
def item_count(prices):
    """Number of items in the cart."""
    return len(prices)


COUPONS = {"SAVE5": Decimal("5.00")}


def apply_coupon(amount, code):
    """Subtract a fixed coupon amount, never going below zero."""
    if code not in COUPONS:
        raise ValueError(f"unknown coupon: {code}")
    return max(amount - COUPONS[code], Decimal("0.00"))


def format_price(amount):
    """Format a Decimal as a price string, e.g. "$9.50"."""
    return f"${amount:.2f}"
EOF
write_cart
commit "Add format_price helper"

cat >> README.md <<'EOF'

## Example

    >>> total(["19.99", "5.01"], 10)
    Decimal('22.50')
EOF
commit "Add usage example to README"

printf 'test:\n\tpython3 test.py\n' > Makefile
commit "Add Makefile with test target"

cat >> CHANGELOG.md <<'EOF'
- Coupons (SAVE5), format_price helper
EOF
commit "Update CHANGELOG"

# --- THE BUG: a "harmless" refactor that drops ROUND_HALF_UP. ---
# quantize() without `rounding=` uses the default ROUND_HALF_EVEN,
# so 1.125 now becomes 1.12 instead of 1.13: one cent off.
read -r -d '' HEADER <<'EOF' || true
"""Shopping-cart discount calculator."""
from decimal import Decimal

CENT = Decimal("0.01")
EOF
read -r -d '' DISCOUNT <<'EOF' || true
def _round_cents(value):
    return value.quantize(CENT)


def apply_discount(amount, percent):
    """Take `percent` off `amount` and round to the cent."""
    after_discount = amount * (Decimal(100) - Decimal(percent)) / Decimal(100)
    return _round_cents(after_discount)
EOF
write_cart
commit "Extract rounding into _round_cents helper"

read -r -d '' DISCOUNT <<'EOF' || true
def _round_cents(value):
    """Round a Decimal to whole cents."""
    return value.quantize(CENT)


def apply_discount(amount, percent):
    """Take `percent` off `amount` and round to the cent."""
    after_discount = amount * (Decimal(100) - Decimal(percent)) / Decimal(100)
    return _round_cents(after_discount)
EOF
write_cart
commit "Add docstring to _round_cents"

cat >> README.md <<'EOF'

## Coupons

`apply_coupon(amount, "SAVE5")` takes $5.00 off.
EOF
commit "Mention coupons in README"

sed -i.bak 's/Keep commits small./Keep commits small and focused./' CONTRIBUTING.md && rm -f CONTRIBUTING.md.bak
commit "Reword CONTRIBUTING"

cat > docs/coupons.md <<'EOF'
# Coupons

| Code  | Value |
| ----- | ----- |
| SAVE5 | $5.00 |
EOF
commit "Add coupon docs"

sed -i.bak 's/unknown coupon: /no such coupon: /' cart.py && rm -f cart.py.bak
commit "Reword coupon error message"

printf 'root = true\n\n[*.py]\nindent_style = space\nindent_size = 4\n' > .editorconfig
commit "Add .editorconfig"

sed -i.bak 's/^## Helpers$/## Helper functions/' README.md && rm -f README.md.bak
commit "Tidy README headings"

sed -i.bak 's/^CENT = Decimal("0.01")$/CENT = Decimal("0.01")  # smallest unit of money/' cart.py && rm -f cart.py.bak
commit "Comment the CENT constant"

cat >> docs/faq.md <<'EOF'

**Can I stack coupons?** Not yet.
EOF
commit "Add FAQ entry on coupons"

cat >> CHANGELOG.md <<'EOF'
- Internal: rounding helper
EOF
commit "Update CHANGELOG"

cat >> README.md <<'EOF'

Next release: 1.1
EOF
commit "Prepare 1.1 release notes"

# ---- wrapper for `git bisect run` (untracked, survives checkouts) ----
cat > bisect-check.sh <<'EOF'
#!/bin/sh
# bisect-check.sh: wrapper for `git bisect run`
# can't even import cart.py? skip this commit (125)
python3 -c "import cart" 2>/dev/null || exit 125
# otherwise pass test.py's own exit code through (0 good, 1 bad)
python3 test.py
EOF
chmod +x bisect-check.sh
echo "bisect-check.sh" >> .git/info/exclude
rm -rf __pycache__

echo "Created $(pwd) with $(git rev-list --count HEAD) commits."
echo "  good: v1.0 = $(git rev-parse --short v1.0)"
echo "  bad:  HEAD = $(git rev-parse --short HEAD)"
echo "Try:   cd $TARGET && git bisect start HEAD v1.0 && git bisect run python3 test.py"
