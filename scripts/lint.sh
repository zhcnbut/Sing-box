#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "shellcheck not found. Please install shellcheck first."
    exit 1
fi

if ! command -v shfmt >/dev/null 2>&1; then
    echo "shfmt not found. Please install shfmt first."
    exit 1
fi

echo "[lint] shellcheck"
find . -type f -name "*.sh" -not -path "./.git/*" -print0 | xargs -0 shellcheck -S error -e SC2148,SC2068,SC2145,SC2199

echo "[lint] shfmt"
shfmt -d -i 4 -ci -sr install.sh sing-box.sh src

echo "[lint] done"
