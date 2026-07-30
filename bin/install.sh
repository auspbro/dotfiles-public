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

# ── Proxy detection ─────────────────────────────────────────

# Common local proxy ports to probe, in priority order.
readonly PROXY_CANDIDATES=(
  "http://127.0.0.1:7890"    # Clash (HTTP)
  "http://127.0.0.1:7891"    # Clash (mixed)
  "http://127.0.0.1:10809"   # v2ray (HTTP)
  "http://127.0.0.1:1080"    # Generic SOCKS-to-HTTP
  "socks5://127.0.0.1:7890"  # Clash (SOCKS5)
  "socks5://127.0.0.1:10809" # v2ray (SOCKS5)
  "socks5://127.0.0.1:1080"  # Generic SOCKS5
)

# Detect and configure proxy for GitHub access.
# Sets http_proxy/https_proxy env vars and git http.proxy config.
detect_and_configure_proxy() {
  # ── Step 1: Env vars already set? ──
  local existing_proxy="${http_proxy:-${HTTP_PROXY:-${https_proxy:-${HTTPS_PROXY:-}}}}"
  if [[ -n "$existing_proxy" ]]; then
    echo "Using existing proxy from environment: $existing_proxy"
    _apply_proxy "$existing_proxy"
    return 0
  fi

  # ── Step 2: Try direct connection ──
  echo "Testing direct connection to GitHub..."
  if curl -s --connect-timeout 5 -o /dev/null -w '' https://github.com 2>/dev/null; then
    echo "Direct connection to GitHub OK — no proxy needed."
    return 0
  fi
  echo "Direct connection failed. Probing for local proxy..."

  # ── Step 3: Probe local proxy ports ──
  local candidate
  for candidate in "${PROXY_CANDIDATES[@]}"; do
    # Extract host:port for a quick TCP connect test
    local addr="${candidate#*//}"        # 127.0.0.1:7890
    local host="${addr%%:*}"             # 127.0.0.1
    local port="${addr##*:}"             # 7890

    # Quick TCP check — is the port open?
    if ! (echo >/dev/tcp/"$host"/"$port") 2>/dev/null; then
      continue
    fi

    # Port is open — verify it actually proxies to GitHub
    if curl -s --connect-timeout 5 -o /dev/null -w '' --proxy "$candidate" https://github.com 2>/dev/null; then
      echo "Found working proxy: $candidate"
      _apply_proxy "$candidate"
      return 0
    fi
  done

  # ── Step 4: Nothing worked ──
  echo ""
  echo "WARNING: Cannot reach GitHub directly or via any local proxy." >&2
  echo "The script will continue but may fail on GitHub operations." >&2
  echo "" >&2
  echo "To fix, set proxy manually before running this script:" >&2
  echo "  export http_proxy=http://127.0.0.1:7890" >&2
  echo "  export https_proxy=http://127.0.0.1:7890" >&2
  echo "" >&2
  return 0
}

# Apply proxy to environment and git config.
_apply_proxy() {
  local proxy="$1"

  export http_proxy="$proxy"
  export https_proxy="$proxy"
  export HTTP_PROXY="$proxy"
  export HTTPS_PROXY="$proxy"

  # git config — only set if not already configured
  local current_git_proxy
  current_git_proxy="$(git config --global http.proxy 2>/dev/null || true)"
  if [[ -z "$current_git_proxy" ]]; then
    git config --global http.proxy "$proxy"
    git config --global https.proxy "$proxy"
    echo "Git proxy configured: $proxy"
  else
    echo "Git proxy already configured: $current_git_proxy (keeping existing)"
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

# ── SSH key setup ───────────────────────────────────────────

# Install gh CLI early (before setup-machine.sh) so we can register SSH keys.
install_gh_for_ssh() {
  command -v gh &>/dev/null && return 0

  case "$PLATFORM" in
    macos)
      if command -v brew &>/dev/null; then
        brew install gh
      else
        echo "WARNING: Homebrew not found. Install gh manually: https://cli.github.com" >&2
        return 1
      fi
      ;;
    ubuntu|wsl)
      # Add GitHub CLI apt source and install
      if ! command -v gpg &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y gpg
      fi
      local keyring=/usr/share/keyrings/githubcli-archive-keyring.gpg
      if [[ ! -f "$keyring" ]]; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
          | sudo dd of="$keyring" 2>/dev/null
        sudo chmod go+r "$keyring"
        echo "deb [arch=$(dpkg --print-architecture) signed-by=$keyring] https://cli.github.com/packages stable main" \
          | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      fi
      sudo apt-get update && sudo apt-get install -y gh
      ;;
  esac
}

# Resolve the SSH key file to use: ed25519 preferred, RSA as fallback.
resolve_ssh_key_file() {
  if [[ -f ~/.ssh/id_ed25519 ]]; then
    echo ~/.ssh/id_ed25519
  elif [[ -f ~/.ssh/id_rsa ]]; then
    echo ~/.ssh/id_rsa
  fi
}

# Generate an Ed25519 key pair and register the public key with GitHub.
setup_ssh_keys() {
  mkdir -p -m 700 ~/.ssh ~/.ssh/s

  # ── Step 1: Check for existing key ──
  local key_file
  key_file="$(resolve_ssh_key_file)"

  if [[ -z "$key_file" ]]; then
    # No key exists — generate Ed25519
    key_file=~/.ssh/id_ed25519
    echo "Generating Ed25519 SSH key..."
    ssh-keygen -t ed25519 -C "$GITHUB_USERNAME@$(hostname)" -f "$key_file" -N ""
  else
    echo "Existing SSH key found: $key_file"
  fi

  # Start ssh-agent and add key
  eval "$(ssh-agent -s)" > /dev/null
  ssh-add "$key_file" 2>/dev/null || true

  # ── Step 2: Ensure gh CLI is available ──
  if ! command -v gh &>/dev/null; then
    echo "Installing GitHub CLI (gh) for SSH key registration..."
    install_gh_for_ssh || {
      echo ""
      echo "Could not install gh CLI automatically."
      echo "To register your SSH key manually:"
      echo "  1. Copy this key:  cat ${key_file}.pub"
      echo "  2. Go to: https://github.com/settings/keys"
      echo "  3. Click 'New SSH key' and paste"
      return 0
    }
  fi

  # ── Step 3: Ensure gh is authenticated (with ssh key scope) ──
  if ! gh auth status &>/dev/null; then
    echo "Authenticating with GitHub CLI..."
    if [[ -t 0 ]] && [[ -n "${DISPLAY-}${WSL_DISTRO_NAME-}${SSH_TTY-}" ]]; then
      gh auth login --web -h github.com -p ssh -s admin:public_key || {
        echo "WARNING: gh auth login failed. Register your SSH key manually:" >&2
        echo "  cat ${key_file}.pub   # copy the output" >&2
        echo "  https://github.com/settings/keys" >&2
        return 0
      }
    else
      echo "Non-interactive environment detected. Register your SSH key manually:" >&2
      echo "  cat ${key_file}.pub   # copy the output" >&2
      echo "  https://github.com/settings/keys" >&2
      return 0
    fi
  elif ! gh ssh-key list &>/dev/null; then
    # Already authenticated but missing scope — refresh once
    echo "Adding admin:public_key scope to GitHub CLI token..."
    gh auth refresh -h github.com -s admin:public_key || {
      echo "WARNING: Could not refresh token scope. Register your SSH key manually:" >&2
      echo "  cat ${key_file}.pub   # copy the output" >&2
      echo "  https://github.com/settings/keys" >&2
      return 0
    }
  fi

  # ── Step 5: Register key if not already present ──
  local pub_key_fingerprint
  pub_key_fingerprint="$(ssh-keygen -lf "${key_file}.pub" | awk '{print $2}')"

  if gh ssh-key list | grep -qF "$pub_key_fingerprint"; then
    echo "SSH key already registered with GitHub."
  else
    local title
    title="$(hostname)-$(date +%Y%m%d)"
    echo "Registering SSH key with GitHub as '$title'..."
    gh ssh-key add "${key_file}.pub" --title "$title"
    echo "SSH key registered successfully."
  fi
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

  # Pre-authenticate sudo (keeps credentials cached for the script's lifetime)
  sudo -v

  # Detect platform
  detect_platform
  echo "Detected platform: $PLATFORM"

  if [[ "$PLATFORM" == "unsupported" ]]; then
    echo "ERROR: Unsupported platform. Only macOS, Ubuntu/Debian, and WSL are supported." >&2
    exit 1
  fi

  # Detect and configure proxy (before any GitHub access)
  detect_and_configure_proxy

  # Install base dependencies
  case "$PLATFORM" in
    macos)  install_base_deps_macos ;;
    ubuntu|wsl) install_base_deps_linux ;;
  esac

  # SSH key setup (all platforms)
  setup_ssh_keys

  # Clone bare repos
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

  # WSL restart prompt (skip with AUTO_YES=1)
  if [[ -t 0 && -n "${WSL_DISTRO_NAME-}" ]]; then
    if [[ "${AUTO_YES:-}" == "1" ]]; then
      wsl.exe --terminate "$WSL_DISTRO_NAME"
    else
      read -p "Need to restart WSL to complete installation. Terminate WSL now? [y/N] " -n 1 -r
      echo
      if [[ ${REPLY,,} == @(y|yes) ]]; then
        wsl.exe --terminate "$WSL_DISTRO_NAME"
      fi
    fi
  fi

  echo ""
  echo "=== Installation complete ==="
  echo "Start a new shell or run: exec zsh"
}

main "$@"
