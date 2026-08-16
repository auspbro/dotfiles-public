#!/bin/bash
#
# Uninstalls dotfiles: backs up tracked files, removes them from $HOME,
# and deletes the bare repo directories (~/.dotfiles-public, ~/.dotfiles-private).
#
# Usage:
#   bash ~/bin/uninstall-dotfiles.sh           # interactive (asks for confirmation)
#   AUTO_YES=1 bash ~/bin/uninstall-dotfiles.sh  # skip confirmation
#   bash ~/bin/uninstall-dotfiles.sh --dry-run   # show what would be deleted
#
# What this script does NOT do:
#   - Remove apt/brew packages installed by setup-machine.sh
#   - Revert system changes (sudoers, locale, default shell, systemd)
#   - Remove git global config entries
#
# To fully revert system-level changes, see setup-machine.sh or do it manually.

set -euo pipefail

# ── Color helpers ────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { printf "${CYAN}[info]${RESET}  %s\n" "$*"; }
ok()    { printf "${GREEN}[ok]${RESET}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[warn]${RESET}  %s\n" "$*"; }
err()   { printf "${RED}[error]${RESET} %s\n" "$*" >&2; }

# ── Parse args ───────────────────────────────────────────────

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    *) err "Unknown argument: $arg"; exit 1 ;;
  esac
done

# ── Preflight checks ────────────────────────────────────────

PUBLIC_REPO="$HOME/.dotfiles-public"
PRIVATE_REPO="$HOME/.dotfiles-private"

has_public=0
has_private=0
[[ -d "$PUBLIC_REPO" ]]  && has_public=1
[[ -d "$PRIVATE_REPO" ]] && has_private=1

if [[ $has_public -eq 0 && $has_private -eq 0 ]]; then
  err "No dotfiles repos found. Nothing to uninstall."
  err "  Expected: $PUBLIC_REPO and/or $PRIVATE_REPO"
  exit 1
fi

# ── Collect tracked files ────────────────────────────────────

collect_tracked_files() {
  local repo_dir="$1"
  if [[ ! -d "$repo_dir" ]]; then
    return
  fi
  git --git-dir="$repo_dir" ls-tree -r --name-only HEAD 2>/dev/null || true
}

info "Scanning tracked files..."

tracked_files=()
if [[ $has_public -eq 1 ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && tracked_files+=("$f")
  done < <(collect_tracked_files "$PUBLIC_REPO")
  info "  dotfiles-public:  ${#tracked_files[@]} tracked files"
fi

private_files=()
if [[ $has_private -eq 1 ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && private_files+=("$f")
  done < <(collect_tracked_files "$PRIVATE_REPO")
  info "  dotfiles-private: ${#private_files[@]} tracked files"
fi

all_files=("${tracked_files[@]}" "${private_files[@]}")

# Filter to files that actually exist in $HOME
existing_files=()
for f in "${all_files[@]}"; do
  [[ -e "$HOME/$f" ]] && existing_files+=("$f")
done

if [[ ${#existing_files[@]} -eq 0 && $has_public -eq 0 && $has_private -eq 0 ]]; then
  info "No tracked files found in $HOME. Nothing to do."
  exit 0
fi

# ── Summary ──────────────────────────────────────────────────

echo ""
printf "${BOLD}Dotfiles Uninstall Summary${RESET}\n"
echo "─────────────────────────────────────────"
printf "  Tracked files to remove:  ${BOLD}%d${RESET}\n" "${#existing_files[@]}"
[[ $has_public  -eq 1 ]] && printf "  Bare repo to remove:      %s\n" "$PUBLIC_REPO"
[[ $has_private -eq 1 ]] && printf "  Bare repo to remove:      %s\n" "$PRIVATE_REPO"
echo ""

# Show first 20 files as preview
preview_count=20
if [[ ${#existing_files[@]} -gt 0 ]]; then
  printf "  ${CYAN}Files (showing first %d):${RESET}\n" "$preview_count"
  for f in "${existing_files[@]:0:$preview_count}"; do
    printf "    %s\n" "$f"
  done
  remaining=$(( ${#existing_files[@]} - preview_count ))
  if [[ $remaining -gt 0 ]]; then
    printf "    ${CYAN}... and %d more${RESET}\n" "$remaining"
  fi
  echo ""
fi

# ── Confirmation ─────────────────────────────────────────────

if [[ $DRY_RUN -eq 1 ]]; then
  info "Dry run complete. No changes made."
  exit 0
fi

if [[ "${AUTO_YES:-0}" != "1" ]]; then
  printf "${YELLOW}Proceed with uninstall? This will backup and delete the files above. [y/N]${RESET} "
  read -r reply
  if [[ "$reply" != [yY]* ]]; then
    info "Aborted."
    exit 0
  fi
fi

# ── Backup ───────────────────────────────────────────────────

timestamp=$(date +%Y%m%d-%H%M%S)
backup_file="$HOME/dotfiles-backup-${timestamp}.tar.gz"

info "Creating backup: $backup_file"

# Build list of files that exist for tar
tar_files=()
for f in "${existing_files[@]}"; do
  tar_files+=("$f")
done

if [[ ${#tar_files[@]} -gt 0 ]]; then
  # Use -C so paths are relative in the archive
  printf '%s\n' "${tar_files[@]}" | tar -czf "$backup_file" -C "$HOME" -T - 2>/dev/null || {
    # Some files may be symlinks or inaccessible; try one-by-one
    tar_files_safe=()
    for f in "${tar_files[@]}"; do
      [[ -e "$HOME/$f" || -L "$HOME/$f" ]] && tar_files_safe+=("$f")
    done
    if [[ ${#tar_files_safe[@]} -gt 0 ]]; then
      printf '%s\n' "${tar_files_safe[@]}" | tar -czf "$backup_file" -C "$HOME" -T -
    fi
  }
  ok "Backup created: $backup_file ($(du -h "$backup_file" | cut -f1))"
else
  warn "No files to backup."
fi

# ── Remove tracked files ─────────────────────────────────────

info "Removing tracked files from \$HOME..."

removed=0
for f in "${existing_files[@]}"; do
  target="$HOME/$f"
  if [[ -e "$target" || -L "$target" ]]; then
    rm -f "$target"
    ((removed++)) || true
  fi
done
ok "Removed $removed files."

# ── Clean up empty directories ───────────────────────────────

info "Cleaning up empty directories..."

# Collect parent directories of tracked files, deepest first
declare -A dirs_seen=()
for f in "${existing_files[@]}"; do
  dir=$(dirname "$f")
  while [[ "$dir" != "." && -n "$dir" ]]; do
    dirs_seen["$dir"]=1
    dir=$(dirname "$dir")
  done
done

# Sort by depth (deepest first) and remove if empty
dirs_cleaned=0
for d in $(printf '%s\n' "${!dirs_seen[@]}" | awk -F'/' '{print NF, $0}' | sort -rn | awk '{print $2}'); do
  target="$HOME/$d"
  if [[ -d "$target" ]] && [[ -z "$(ls -A "$target" 2>/dev/null)" ]]; then
    rmdir "$target" 2>/dev/null && ((dirs_cleaned++)) || true
  fi
done
[[ $dirs_cleaned -gt 0 ]] && ok "Removed $dirs_cleaned empty directories."

# ── Remove bare repos ───────────────────────────────────────

info "Removing bare repo directories..."

if [[ $has_public -eq 1 ]]; then
  rm -rf "$PUBLIC_REPO"
  ok "Removed $PUBLIC_REPO"
fi

if [[ $has_private -eq 1 ]]; then
  rm -rf "$PRIVATE_REPO"
  ok "Removed $PRIVATE_REPO"
fi

# ── Done ─────────────────────────────────────────────────────

echo ""
printf "${GREEN}${BOLD}✓ Dotfiles uninstalled successfully.${RESET}\n"
echo ""
printf "  Backup:    %s\n" "$backup_file"
printf "  Files:     %d removed\n" "$removed"
[[ $dirs_cleaned -gt 0 ]] && printf "  Dirs:      %d empty dirs removed\n" "$dirs_cleaned"
echo ""
printf "${YELLOW}Note:${RESET} System-level changes (apt packages, sudoers, locale, default shell)\n"
printf "      were NOT reverted. See setup-machine.sh or revert manually if needed.\n"
printf "      To restore dotfiles later, run: install.sh\n"
echo ""
