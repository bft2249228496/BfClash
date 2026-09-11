#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this script as root." >&2
  exit 1
fi

if [[ "$(uname -m)" != "aarch64" ]]; then
  echo "This bootstrap is intended for the Oracle ARM64 host." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl git git-lfs jq unzip xz-utils zip \
  build-essential clang cmake ninja-build pkg-config \
  openjdk-17-jdk-headless golang-go python3 python3-venv shellcheck

git lfs install --system

install -d -m 0755 /root/projects
git config --global init.defaultBranch main
git config --global pull.ff only

cat >/etc/profile.d/lansway-toolchain.sh <<'EOF'
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
export PATH="$JAVA_HOME/bin:$PATH"
EOF
chmod 0644 /etc/profile.d/lansway-toolchain.sh

echo
echo "Base ARM64 development toolchain installed."
echo "Flutter and Android builds intentionally run on GitHub Actions x64 runners."
echo "Next: cd /root/projects/clash-self && bash ops/verify-oracle-arm64.sh"
