#!/bin/bash
set -euo pipefail

if command -v nvim &>/dev/null; then
    nvim --headless "+Lazy! sync" +qa || true
fi
