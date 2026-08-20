#!/bin/bash
set -euo pipefail

if ! command -v brew &>/dev/null; then
    echo "Homebrew not found, skipping package install" >&2
    exit 0
fi

PACKAGES=(starship eza bat uv neovim fish gh)
for pkg in "${PACKAGES[@]}"; do
    if ! brew list "$pkg" &>/dev/null; then
        brew install "$pkg"
    fi
done
