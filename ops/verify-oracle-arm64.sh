#!/usr/bin/env bash
set -euo pipefail

printf '%-14s %s\n' OS "$(. /etc/os-release && echo "$PRETTY_NAME")"
printf '%-14s %s\n' Architecture "$(uname -m)"
printf '%-14s %s\n' Git "$(git --version)"
printf '%-14s %s\n' Java "$(java -version 2>&1 | head -n 1)"
printf '%-14s %s\n' Go "$(go version)"
printf '%-14s %s\n' Python "$(python3 --version)"
printf '%-14s %s\n' OpenClaw "$(command -v openclaw || echo 'not found')"

test "$(uname -m)" = aarch64
git diff --check
git status --short --branch
