#!/bin/bash
#
# Unified entry point for dotfiles deployment.
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/YOUR_USER/dotfiles-public/master/bin/install.sh)"
#
# Requires: GITHUB_USERNAME environment variable set.
# Supports: macOS, Ubuntu/Debian, Windows WSL.

set -xueE -o pipefail
shopt -s extglob

# ── Platform detection ──────────────────────────────────────

detect_platform() {
  case "$(uname -s)" in
    Darwin)
      PLATFORM=macos
      ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        PLATFORM=wsl
      elif [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "$ID" in
          ubuntu|debian) PLATFORM=ubuntu ;;
          *)             PLATFORM=unsupported ;;
        esac
      else
        PLATFORM=unsupported
      fi
      ;;
    *)
      PLATFORM=unsupported
      ;;
  esac
}

# ── Base dependency installation ────────────────────────────

install_base_deps_macos() {
  if ! command -v git &>/dev/null; then
    echo "Installing Xcode Command Line Tools (provides git)..."
    xcode-select --install 2>/dev/null || true
    echo "Please wait for Xcode CLT installation to complete, then re-run this script."
    exit 1
  fi
}

install_base_deps_linux() {
  if ! command -v git &>/dev/null || ! command -v curl &>/dev/null; then
    sudo apt-get update
    sudo apt-get install -y git curl
  fi
  if ! command -v zsh &>/dev/null; then
    sudo apt-get install -y zsh
  fi
}

# ── Bare repo cloning ──────────────────────────────────────

clone_repo() {
  local repo=$1
  local git_dir="$HOME/.$repo"
  local uri="git@github.com:$GITHUB_USERNAME/$repo.git"

  if [[ -e "$git_dir" ]]; then
    echo "Repository $repo already exists at $git_dir, skipping clone."
    return 0
  fi

  echo "Cloning $repo..."
  git --git-dir="$git_dir" init -b master
  git --git-dir="$git_dir" config core.bare false
  git --git-dir="$git_dir" config status.showuntrackedfiles no
  git --git-dir="$git_dir" remote add origin "$uri"
  git --git-dir="$git_dir" fetch
  git --git-dir="$git_dir" reset origin/master
  git --git-dir="$git_dir" branch -u origin/master
  git --git-dir="$git_dir" checkout -- .
  git --git-dir="$git_dir" submodule update --init --recursive
}

# ── SSH key setup (WSL) ────────────────────────────────────

setup_ssh_keys_wsl() {
  if [[ -e ~/.ssh/id_rsa ]]; then
    return 0
  fi

  local win_home downloads
  win_home="$(cd /mnt/c && cmd.exe /c "echo %HOMEDRIVE%%HOMEPATH%" 2>/dev/null | sed 's/\r$//')"
  downloads="$(wslpath "$win_home")/Downloads"

  mkdir -p ~/.ssh
  (
    umask 0077
    : >~/.ssh/id_rsa.tmp
  )

  if [[ -f "$downloads"/id_rsa ]]; then
    cat -- "$downloads"/id_rsa >~/.ssh/id_rsa.tmp
  elif [[ -f "$downloads"/id_rsa.txt ]]; then
    cat -- "$downloads"/id_rsa.txt >~/.ssh/id_rsa.tmp
  else
    echo "ERROR: Put your SSH key at ~/.ssh/id_rsa or ${downloads}/id_rsa and retry." >&2
    exit 1
  fi

  mv -- ~/.ssh/id_rsa.tmp ~/.ssh/id_rsa
}

# ── Main ────────────────────────────────────────────────────

main() {
  # Guard: non-root
  if [[ "$(id -u)" == 0 ]]; then
    echo "ERROR: please run as non-root" >&2
    exit 1
  fi

  # Guard: GITHUB_USERNAME
  if [[ -z "${GITHUB_USERNAME:-}" ]]; then
    echo "ERROR: GITHUB_USERNAME not set. Export it before running:" >&2
    echo "  export GITHUB_USERNAME=your-username" >&2
    exit 1
  fi

  # Detect platform
  detect_platform
  echo "Detected platform: $PLATFORM"

  if [[ "$PLATFORM" == "unsupported" ]]; then
    echo "ERROR: Unsupported platform. Only macOS, Ubuntu/Debian, and WSL are supported." >&2
    exit 1
  fi

  # Install base dependencies
  case "$PLATFORM" in
    macos)  install_base_deps_macos ;;
    ubuntu|wsl) install_base_deps_linux ;;
  esac

  # SSH key setup for WSL
  if [[ "$PLATFORM" == "wsl" ]]; then
    setup_ssh_keys_wsl
  fi

  # Clone bare repos
  mkdir -p -m 700 ~/.ssh
  clone_repo dotfiles-public
  clone_repo dotfiles-private

  # Add upstream remote for dotfiles-public (if not the original author)
  if [[ "$GITHUB_USERNAME" != romkatv ]]; then
    git --git-dir="$HOME"/.dotfiles-public \
      remote add upstream 'https://github.com/romkatv/dotfiles-public.git' 2>/dev/null || true
  fi

  # Run setup
  echo "Running setup..."
  bash ~/bin/setup-machine.sh

  # WSL restart prompt
  if [[ -t 0 && -n "${WSL_DISTRO_NAME-}" ]]; then
    read -p "Need to restart WSL to complete installation. Terminate WSL now? [y/N] " -n 1 -r
    echo
    if [[ ${REPLY,,} == @(y|yes) ]]; then
      wsl.exe --terminate "$WSL_DISTRO_NAME"
    fi
  fi

  echo ""
  echo "=== Installation complete ==="
  echo "Start a new shell or run: exec zsh"
}

main "$@"
