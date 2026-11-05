#!/usr/bin/env bash
set -euo pipefail

upstream_url=${BFCLASH_UPSTREAM_URL:-https://github.com/chen08209/Clash.Meta.git}
upstream_ref=${BFCLASH_UPSTREAM_REF:-FlClash}
git fetch "$upstream_url" "$upstream_ref"
if git merge-base --is-ancestor FETCH_HEAD HEAD; then
  echo 'updated=false' >> "$GITHUB_OUTPUT"
else
  git config user.name 'github-actions[bot]'
  git config user.email 'github-actions[bot]@users.noreply.github.com'
  git merge --no-edit --no-ff FETCH_HEAD
  echo 'updated=true' >> "$GITHUB_OUTPUT"
fi
