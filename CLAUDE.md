# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles management system. It uses the **bare-git-repo approach**: the repo is cloned as `~/.dotfiles-public` (a bare git repo) with `GIT_WORK_TREE=~`. Files in the repo root (`.zshrc`, `.tmux.conf`, etc.) are checked out directly into `$HOME`. A companion private repo (`~/.dotfiles-private`) holds secrets (ssh keys, private shell config, zsh history).

Originally forked from [romkatv/dotfiles-public](https://github.com/romkatv/dotfiles-public).

## Architecture

### Dotfiles management model

- **Not a normal project** — there's no build, lint, or test system. This repo defines shell environments, editor configs, and machine provisioning scripts.
- The repo files live at the repo root and map 1:1 to `$HOME` paths. For example, `.zshrc` → `~/.zshrc`, `.config/ghostty/config.ghostty` → `~/.config/ghostty/config.ghostty`.
- `bin/` scripts are checked out to `~/bin/` and used for bootstrapping and maintenance.

### Key bootstrap flow

1. `bin/bootstrap-machine.sh` — entry point, run from a fresh machine. Sets up SSH keys, installs base packages (git, zsh, tmux), clones both dotfiles repos via `bin/bootstrap-dotfiles.sh`, then runs `bin/setup-machine.sh`.
2. `bin/bootstrap-dotfiles.sh` — clones `dotfiles-public` and `dotfiles-private` as bare repos into `~/.dotfiles-public` and `~/.dotfiles-private`.
3. `bin/setup-machine.sh` — installs all software (apt packages, tools, fonts, Docker, etc.). Safe to re-run; idempotent.
4. `bin/build_docker_env.sh` — builds a Docker development image (`alanenv`) based on Ubuntu 22.04.

### Shell configuration

- **Primary shell**: Zsh via [zsh4humans](https://github.com/romkatv/zsh4humans) (z4h). Config in `.zshrc` and `.zshenv`.
- **Prompt**: [Powerlevel10k](https://github.com/romkatv/powerlevel10k) with multiple p10k configs (`.p10k.zsh`, `.p10k-ascii.zsh`, `.p10k-8color.zsh`, `.p10k-ascii-8color.zsh`).
- **Bash**: `.bashrc`, `.bash_profile`, `.bash_aliases` provide a fallback bash environment.
- **Functions**: `dotfiles/functions/` contains autoloaded zsh functions (`sync-dotfiles`, `toggle-dotfiles`, `bench`, `arith-eval`, `zman`).

### Dotfiles sync and toggle

- **`sync-dotfiles`** (zsh function, in `dotfiles/functions/sync-dotfiles`) — pulls, merges upstream, and pushes both repos. Commits zsh history from private repo before syncing.
- **`toggle-dotfiles`** (zsh function, bound to `Alt+P`) — cycles `GIT_DIR`/`GIT_WORK_TREE` between unset (normal), `~/.dotfiles-public` (public), and `~/.dotfiles-private` (private). This lets you run `git add/commit/diff` on dotfiles from any directory.

### tmux

- Main config: `.tmux.conf` — vim-style pane navigation (`h/j/k/l`), `Ctrl+Alt+h/j/k/l` for fast nav, `|` and `-` for splits, backtick as second prefix, TPM plugin manager.
- Alternative profiles: `.config/tmux/tmux.min.conf` and `.config/tmux/tmux.fancy.conf`, switchable via `tmux-min` / `tmux-fancy` aliases.
- Floating terminal: `Alt+backtick` opens a popup terminal (80% width, 70% height).

### Terminal emulators

- **Ghostty**: `.config/ghostty/config.ghostty` — Maple Mono NF CN font, Solarized theme, transparent background, quick-terminal with `Ctrl+backtick`.
- **Windows Terminal**: `dotfiles/microsoft-terminal-settings*.json` for various machines.
- **Apple Terminal**: `dotfiles/apple-terminal-profile.terminal`.

### Editor configs

- **Vim**: `.vimrc` — leader=Space, `jk`/`vv` for Esc, 4-space indent, system clipboard, relative line numbers.
- **VS Code**: `.config/Code/User/settings.json`.
- **Neovim (VSCode extension)**: `.config/nvim/init_vscode.vim`.
- **Clang-format**: `.clang-format` — Google style, 100-column limit, left pointer alignment.

### SSH

- `.ssh/config` — includes `config-private` for host-specific settings, uses `ControlMaster`/`ControlPersist` for connection multiplexing via `~/.ssh/s/`.
- SSH teleportation (z4h feature) configured for specific hosts in `.zshrc`.

## Maintenance Commands

```zsh
# Sync dotfiles with GitHub and update zsh4humans
sync-dotfiles && bash ~/bin/setup-machine.sh && z4h update

# Toggle between dotfiles repos (public/private/normal) — bound to Alt+P
toggle-dotfiles public   # switch to public dotfiles
toggle-dotfiles private  # switch to private dotfiles
toggle-dotfiles          # back to normal

# Switch tmux config
tmux-min    # minimal config
tmux-fancy  # fancy config
```

## Important Patterns

- Private config files (e.g., `.zshrc-private`, `.zshenv-private`, `~/.ssh/config-private`) are sourced/included by their public counterparts but live in the private repo.
- The `.config/git/ignore` file contains global git ignores (`.zwc` compiled zsh files, `.claude/settings.local.json`).
- `~` aliases: `$` and `%` are aliased to space (for quick home directory navigation in zsh).
- `make` and `cmake` are aliased to run with `-j` set to the number of CPUs (`~/bin/num-cpus`).
