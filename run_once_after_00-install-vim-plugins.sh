#!/bin/bash
set -euo pipefail

if [ ! -d "$HOME/.vim/bundle/Vundle.vim" ]; then
    git clone --depth 1 https://github.com/VundleVim/Vundle.vim.git "$HOME/.vim/bundle/Vundle.vim"
fi

if command -v vim &>/dev/null; then
    vim +PluginInstall +qall || true
fi
