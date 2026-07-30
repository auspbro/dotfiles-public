# dotfiles-public

Personal shell environment, editor configs, and machine provisioning scripts.

Forked from [romkatv/dotfiles-public](https://github.com/romkatv/dotfiles-public). The core bare-repo model and bootstrap flow are preserved; the tooling and configs have been extended for multi-platform use (macOS, WSL, Ubuntu/Debian).

## Architecture

This is **not a normal project** — there's no build, lint, or test system. The repo files live at the repo root and map 1:1 to `$HOME` paths (e.g., `.zshrc` → `~/.zshrc`, `.config/ghostty/config.ghostty` → `~/.config/ghostty/config.ghostty`).

### Bare Repo Model

The repo is cloned as a **bare git repo** at `~/.dotfiles-public` with `GIT_WORK_TREE=~`. This means:

- No `.git/` directory in your home — all git metadata lives in `~/.dotfiles-public`.
- `git status`, `git diff`, `git add`, `git commit` all work from any directory, operating on your home files.
- A companion **private repo** (`~/.dotfiles-private`) holds secrets: SSH keys, private shell config, zsh history.

```text
~/
├── .dotfiles-public/    ← bare git repo (GIT_DIR)
├── .dotfiles-private/   ← bare git repo (secrets)
├── .zshrc               ← checked out from dotfiles-public
├── .tmux.conf           ← checked out from dotfiles-public
├── ...
```

### Public / Private Split

Public config files (`.zshrc`, `.bashrc`, `.tmux.conf`, etc.) source or include their private counterparts:

- `.zshrc` → sources `.zshrc-private`
- `.zshenv` → sources `.zshenv-private`
- `.ssh/config` → includes `config-private`

Private files live in `~/.dotfiles-private` and are **never** committed to the public repo.

## Quick Start

### Prerequisites

- A GitHub account
- `git` and `curl` installed

> SSH key generation (Ed25519) and GitHub registration are handled automatically by `install.sh`.
> If you already have an SSH key (`~/.ssh/id_ed25519` or `~/.ssh/id_rsa`), it will be reused.

### One-Line Install

Set your GitHub username and run:

```bash
GITHUB_USERNAME=auspbro bash -c \
  "$(curl -fsSL 'https://raw.githubusercontent.com/auspbro/dotfiles-public/master/bin/install.sh')"
```

This single command will:

1. Detect your platform (macOS / WSL / Ubuntu)
2. Generate an Ed25519 SSH key and register it with GitHub (via `gh` CLI)
3. Install base dependencies (`git`, `zsh`, `curl`)
4. Clone both `dotfiles-public` and `dotfiles-private` as bare repos
5. Check out all config files into `$HOME`
6. Run `setup-machine.sh` to install additional software

### Post-Install Configuration

After install completes:

1. **Restart your shell** — close and reopen terminal, or `exec zsh`
2. **Powerlevel10k configuration** — the p10k wizard should launch automatically on first zsh start. If not, run `p10k configure`.
3. **zsh4humans update** — run `z4h update` to ensure the latest z4h framework.

## What's Included

### Shell

| Component | Config File(s) | Notes |
|-----------|---------------|-------|
| **Zsh** (primary) | `.zshrc`, `.zshenv` | Via [zsh4humans](https://github.com/romkatv/zsh4humans) (z4h) |
| **Powerlevel10k** | `.p10k.zsh`, `.p10k-ascii.zsh`, `.p10k-8color.zsh`, `.p10k-ascii-8color.zsh` | Multiple prompt profiles for different terminal capabilities |
| **Bash** (fallback) | `.bashrc`, `.bash_profile`, `.bash_aliases` | Minimal bash environment |
| **Zsh functions** | `dotfiles/functions/` | Autoloaded: `sync-dotfiles`, `toggle-dotfiles`, `bench`, `arith-eval`, `zman` |

### Terminal Emulators

| Emulator | Config File | Notes |
|----------|------------|-------|
| **Ghostty** | `.config/ghostty/config.ghostty` | Maple Mono NF CN font, Solarized theme, transparent background, quick-terminal (`Ctrl+backtick`) |
| **Windows Terminal** | `dotfiles/microsoft-terminal-settings*.json` | Multiple machine-specific profiles (Legion, Surface 4, XPS 13) |
| **Apple Terminal** | `dotfiles/apple-terminal-profile.terminal` | macOS Terminal profile |

### tmux

Main config: `.tmux.conf`

| Feature | Binding |
|---------|---------|
| Pane navigation | `h/j/k/l` (vim-style) |
| Fast pane nav | `Ctrl+Alt+h/j/k/l` |
| Split horizontal | `\|` |
| Split vertical | `-` |
| Second prefix | `` ` `` (backtick) |
| Floating terminal | `Alt+backtick` (80% width, 70% height) |
| Plugin manager | [TPM](https://github.com/tmux-plugins/tpm) |

Alternative profiles switchable via aliases:

```zsh
tmux-min    # minimal config → .config/tmux/tmux.min.conf
tmux-fancy  # fancy config  → .config/tmux/tmux.fancy.conf
```

### Editors

| Editor | Config File | Notes |
|--------|------------|-------|
| **Vim** | `.vimrc` | Leader=Space, `jk`/`vv` for Esc, 4-space indent, system clipboard, relative line numbers |
| **VS Code** | `.config/Code/User/settings.json` | VS Code settings |
| **Neovim (VSCode extension)** | `.config/nvim/init_vscode.vim` | For VSCode Neovim plugin |
| **Clang-format** | `.clang-format` | Google style, 100-column limit, left pointer alignment |

### Docker Development Environment

`bin/build_docker_env.sh` builds a Docker image (`alanenv`) based on Ubuntu 22.04 with common development tools pre-installed.

```bash
bash ~/bin/build_docker_env.sh          # build
bash ~/bin/build_docker_env.sh rebuild   # rebuild without cache
```

### Utility Scripts (`bin/`)

| Script | Purpose |
|--------|---------|
| `install.sh` | Unified bootstrap entry point (platform-aware) |
| `setup-machine.sh` | Install all software (apt packages, tools, fonts, Docker). Idempotent, safe to re-run. |
| `bootstrap-dotfiles.sh` | Clone both dotfiles repos as bare repos |
| `bootstrap-machine.sh` | Legacy entry point (deprecated, use `install.sh`) |
| `build_docker_env.sh` | Build `alanenv` Docker development image |
| `num-cpus` | Return CPU count (used by `make`/`cmake` aliases for `-j`) |
| `cpu-temp` | Show CPU temperature |
| `diff-so-fancy` | Git diff beautifier |
| `redit` | Open file in editor from remote session |
| `rdp` | Remote desktop helper |
| `slurp` / `barf` | Clipboard utilities |
| `punzip` | Parallel unzip |
| `pick-random-lines` | Random line picker from file |

## File Structure

```text
.
├── .bash_aliases              # Bash aliases
├── .bash_profile              # Bash profile
├── .bashrc                    # Bash config (fallback shell)
├── .clang-format              # C/C++ formatting rules
├── .config/
│   ├── Code/User/             # VS Code settings
│   ├── ghostty/               # Ghostty terminal config
│   ├── git/                   # Git global ignores
│   ├── nvim/                  # Neovim (VSCode extension) config
│   └── tmux/                  # Alternative tmux profiles
├── .hushlogin                 # Suppress login message
├── .p10k.zsh                  # Powerlevel10k config (default)
├── .p10k-ascii.zsh            # Powerlevel10k config (ASCII-only)
├── .p10k-8color.zsh           # Powerlevel10k config (8-color terminal)
├── .p10k-ascii-8color.zsh     # Powerlevel10k config (ASCII + 8-color)
├── .purepower                 # Pure Power theme config
├── .ssh/                      # SSH config (public part)
├── .tmux.conf                 # tmux main config
├── .vimrc                     # Vim config
├── .zshenv                    # Zsh environment (sourced first)
├── .zshrc                     # Zsh config (main)
├── CLAUDE.md                  # Claude Code project context
├── README.md                  # This file
├── bin/                       # Utility scripts
└── dotfiles/
    ├── apple-terminal-profile.terminal
    ├── functions/             # Autoloaded zsh functions
    └── microsoft-terminal-settings*.json  # Per-machine Windows Terminal configs
```

## Daily Usage

### Sync Dotfiles

Pull, merge upstream changes, and push both repos:

```zsh
sync-dotfiles
```

This function (in `dotfiles/functions/sync-dotfiles`) also commits zsh history from the private repo before syncing.

### Toggle Between Dotfiles Repos

Bound to `Alt+P`, cycles `GIT_DIR`/`GIT_WORK_TREE` between three states:

```zsh
toggle-dotfiles          # back to normal (unset)
toggle-dotfiles public   # switch to public dotfiles repo
toggle-dotfiles private  # switch to private dotfiles repo
```

This lets you run `git add/commit/diff` on dotfiles from any directory.

### Full Maintenance

Run periodically to keep everything up to date:

```zsh
sync-dotfiles && bash ~/bin/setup-machine.sh && z4h update
```

Pro tip: Copy-paste this command including the comment. Use `Ctrl+R` and type `#maintenance` to find it later.

```zsh
sync-dotfiles && bash ~/bin/setup-machine.sh && z4h update #maintenance
```

## Machine-Specific Setup

### Platform Support Matrix

| Platform | `install.sh` | `setup-machine.sh` | Notes |
|----------|:---:|:---:|-------|
| **macOS** | ✅ | ✅ | Uses Homebrew; Xcode CLT installed automatically |
| **WSL (Ubuntu)** | ✅ | ✅ | Primary development platform |
| **Ubuntu/Debian** | ✅ | ✅ | Native Linux |
| **RHEL/Fedora/CentOS** | ❌ | ✅ | Partial support in setup script |

### Windows / WSL Setup

All Windows setup is handled by `install.sh`. Manual steps:

1. Install WSL 2 with Ubuntu 22.04:
   ```powershell
   wsl.exe --set-default-version 1
   wsl.exe --install -d Ubuntu-22.04
   ```
2. Download your SSH private key (`id_rsa`) into the Windows `Downloads` folder.
3. Run the one-line install command from [Quick Start](#quick-start).

#### Windows Terminal Configuration

After install, configure Windows Terminal:

1. Open Windows Terminal → `Ctrl+,` → change *Profiles > Ubuntu > Appearance > Text Formatting > Intense text style* to **"Bold font"**
2. `Ctrl+Shift+,` → replace `settings.json` with the appropriate file from `dotfiles/microsoft-terminal-settings*.json`.

#### SSH Connectivity

If `ssh -T git@github.com` fails, add this to `~/.ssh/config`:

```text
Host github.com
  Hostname ssh.github.com
  Port 443
  User git
  IdentityFile ~/.ssh/id_rsa
```

#### Optional: Windows Defender Exclusion

For better WSL filesystem performance, exclude the WSL distro folder from Windows Defender scanning:

1. *Windows Security* → *Virus & threat protection* → *Manage settings*
2. *Exclusions* → *Add an exclusion > Folder*
3. Select `%USERPROFILE%\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu22.04LTS_79rhkp1fndgsc`

### WSL Removal

To completely remove and recreate your WSL distro:

```powershell
wsl.exe --list                    # find distro name
wsl.exe --terminate DISTRO        # stop it
wsl.exe --unregister DISTRO       # delete it
```

Then follow the [Windows / WSL Setup](#windows--wsl-setup) steps above to recreate.

## Acknowledgments

- [romkatv/dotfiles-public](https://github.com/romkatv/dotfiles-public) — the foundation this repo is built on
- [zsh4humans](https://github.com/romkatv/zsh4humans) — the zsh framework
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k) — the prompt theme
