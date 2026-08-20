#!/bin/bash
set -euo pipefail

FONT_CASK="font-jetbrains-mono-nerd-font"
FONT_POSTSCRIPT_NAME="JetBrainsMonoNFM-Regular"

if ! command -v brew &>/dev/null; then
    echo "Homebrew not found, skipping Nerd Font install" >&2
    exit 0
fi

if ! brew list --cask "$FONT_CASK" &>/dev/null; then
    brew install --cask "$FONT_CASK"
fi

if osascript -e 'application "Terminal" is running' &>/dev/null || [ -d "/System/Applications/Utilities/Terminal.app" ]; then
    osascript <<OSA
tell application "Terminal"
	set font name of default settings to "$FONT_POSTSCRIPT_NAME"
	set font name of startup settings to "$FONT_POSTSCRIPT_NAME"
end tell
OSA
fi
