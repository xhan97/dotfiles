# dotfiles

Personal macOS dev environment, managed with [chezmoi](https://www.chezmoi.io/).
One command sets up a brand-new Mac with shell, editor, terminal tools, and theming.

## Quick start (new machine)

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply xhan97
```

This clones the repo, then runs the `run_once_*` scripts below in order to
install Homebrew, packages, oh-my-zsh + plugins, vim/nvim plugins, and fonts.
A few manual steps remain — printed at the end by `99-print-next-steps.sh`
(GitHub auth, restoring `~/.ssh/config`, and setting the terminal font if
using cmux).

## What's managed here

| Area | Files |
|---|---|
| Shell | `dot_zshrc`, `dot_zprofile`, `dot_profile`, `dot_bash_profile` — oh-my-zsh + [starship](https://starship.rs) prompt |
| Vim | `dot_vimrc` — Vundle-managed plugins, Catppuccin Mocha theme |
| Neovim | `dot_config/nvim` — [LazyVim](https://www.lazyvim.org) config, pinned via `lazy-lock.json` |
| Git | `dot_gitconfig`, `dot_config/git/ignore` |
| Terminal tools | `dot_config/bat`, `dot_config/eza`, `dot_config/btop`, `dot_config/starship.toml` — all Catppuccin Mocha themed |
| Conda / uv | `dot_condarc`, `dot_config/uv` |
| Tailscale exit-node helper | `dot_config/tsproxy`, `tsproxy` shell function in `dot_zshrc` |
| Bootstrap scripts | `run_once_before_*` / `run_once_after_*` (see below) |

## Bootstrap scripts

Run once, in filename order, by chezmoi on `apply`:

- `run_once_before_00-install-homebrew.sh` — installs Homebrew if missing
- `run_once_before_01-install-packages.sh` — brews: `starship eza bat uv neovim gh zoxide fzf btop ripgrep fd`
- `run_once_before_02-install-ohmyzsh.sh` — installs oh-my-zsh (unattended) and clones custom plugins: `zsh-autosuggestions`, `zsh-syntax-highlighting`, `zsh-history-substring-search`, `you-should-use`, `fzf-tab`
- `run_once_after_00-install-vim-plugins.sh` — bootstraps Vundle, runs `:PluginInstall`
- `run_once_after_01-install-nvim-plugins.sh` — runs `Lazy! sync` for LazyVim
- `run_once_after_02-install-nerd-font.sh` — installs JetBrainsMono Nerd Font, sets it as Terminal.app's default font
- `run_once_after_99-print-next-steps.sh` — prints remaining manual steps

## Shell plugins (oh-my-zsh)

```
git extract colored-man-pages autopep8 zoxide fzf you-should-use
zsh-history-substring-search fzf-tab zsh-autosuggestions zsh-syntax-highlighting
```

- `zoxide` (`z <dir>`) — frecency-based `cd`
- `fzf` — fuzzy `Ctrl-R` history / `Ctrl-T` file / `Alt-C` dir search
- `fzf-tab` — fuzzy tab-completion menus
- `you-should-use` — nags when you type a command you've aliased
- `zsh-history-substring-search` — ↑/↓ filters history by current input
- `zsh-syntax-highlighting` must stay last in the plugin list

## Theme

Catppuccin Mocha, applied consistently across vim, airline, zsh-syntax-highlighting,
bat, eza, and btop.

## Not tracked here (on purpose)

- `~/.ssh/config` and SSH keys — restore manually, kept out of git for security
- VS Code settings — handled by VS Code's own built-in Settings Sync, not chezmoi
- cmux terminal font — no scriptable config; set manually via Cmd+, → Terminal/Appearance

## Useful chezmoi helpers (defined in `dot_zshrc`)

```sh
dotsync ["commit message"]   # chezmoi re-add + git add -A + commit + push
dotadd <path>...             # chezmoi add <path> + dotsync
```
