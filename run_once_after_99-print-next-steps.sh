#!/bin/bash
set -euo pipefail

cat <<'EOF'

==========================================================
Dotfiles bootstrap complete. A few things still need you:

1. gh auth login
   (needed for git push over https://github.com, since
   dot_gitconfig uses `gh auth git-credential` as the
   credential helper)

2. Restore ~/.ssh/config and your SSH keys manually
   (not tracked in dotfiles for security reasons)

3. If using cmux as your terminal, set its font manually:
   Cmd+, -> Terminal/Appearance -> Font -> JetBrainsMono Nerd Font Mono
   (cmux has no scriptable config file for this)
==========================================================
EOF
