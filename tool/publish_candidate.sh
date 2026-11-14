#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$script_dir/.." && pwd)"
cd "$root"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <candidate_version> [bridge_tag]"
  echo "Example: $0 1.0.7-beta.4+89"
  exit 1
fi

candidate_version="$1"
bridge_tag="${2:-}"

# 校验版本号格式
if [[ ! "$candidate_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?\+[0-9]+$ ]]; then
  echo "Error: candidate_version must look like '1.0.7-beta.4+89' or '1.0.7+89', got: $candidate_version" >&2
  exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$branch" == "HEAD" ]]; then
  echo "Error: detached HEAD. Please checkout a branch first." >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: Working tree has uncommitted changes. Please commit and push first." >&2
  exit 1
fi

# 检查当前 commit 是否已推送到远程
head_sha="$(git rev-parse HEAD)"
remote_sha="$(git rev-parse "origin/$branch" 2>/dev/null || true)"
if [[ "$head_sha" != "$remote_sha" ]]; then
  echo "Warning: Local HEAD ($head_sha) does not match origin/$branch ($remote_sha)."
  read -r -p "Push origin $branch now? [y/N] " reply
  if [[ "$reply" =~ ^[yY]$ ]]; then
    git push origin "$branch"
  else
    echo "Aborted." >&2
    exit 1
  fi
fi

echo "=========================================="
echo "BfClash One-Click Unified Candidate Release"
echo "Target Version : $candidate_version"
echo "Branch         : $branch ($head_sha)"
if [[ -n "$bridge_tag" ]]; then
  echo "Bridge Tag     : $bridge_tag"
fi
echo "=========================================="

extra_args=()
if [[ -n "$bridge_tag" ]]; then
  extra_args+=(-f "bridge_tag=$bridge_tag")
fi

gh workflow run android.yml --ref "$branch" \
  -f "candidate_version=$candidate_version" \
  -f "include_windows=true" \
  "${extra_args[@]}"

echo "Workflow triggered successfully!"
echo "Android and Windows builds are now running in parallel in GitHub Actions."
echo "Upon completion, the release will be published automatically."
echo "You can monitor the workflow at: https://github.com/bft2249228496/BfClash/actions/workflows/android.yml"
