# git-bisect-talk

Demo material for the tech talk **Debugging with Version Control History — from git log to git bisect**.

## Try it

Requirements: git 2.28 or newer, Python 3.9 or newer, a Unix shell (macOS, Linux, or Git Bash on Windows).

```
./make_demo_repo.sh            # creates ./cart-demo
cd cart-demo
git bisect start HEAD v1.0     # HEAD is bad, v1.0 is good
git bisect run python3 test.py
git bisect reset
```

Git reports `cd58d8b ... is the first bad commit`: a refactor that changed how cents are rounded.

## What's here

| File | What it is |
| --- | --- |
| `make_demo_repo.sh` | Builds the demo repo: 33 commits, tag `v1.0`, one buried bug, one commit that doesn't import. Same commit hashes on every machine. |
| `CHEATSHEET.md` | Expected output of every demo step. |
| `TUTORIAL.md` | Step-by-step guide to repeat the demo (coming soon). |
