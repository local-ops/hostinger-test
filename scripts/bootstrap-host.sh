#!/usr/bin/env bash
# Ensures required host packages and tooling exist (idempotent).
# Intended for Debian/Ubuntu-based deploy hosts.

set -euo pipefail

log() {
  printf '[bootstrap-host] %s\n' "$*"
}

require_root_or_sudo() {
  if [[ "$(id -u)" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    log "error: need root or sudo for package installation"
    exit 1
  fi
}

apt_install() {
  local pkgs=("$@")
  if [[ "$(id -u)" -eq 0 ]]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y --no-install-recommends "${pkgs[@]}"
  else
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}"
  fi
}

ensure_debian_packages() {
  if [[ ! -f /etc/debian_version ]]; then
    log "warning: non-Debian host; skipping apt installs (install zsh/git/curl manually if missing)"
    return 0
  fi

  local packages=()
  command -v zsh >/dev/null 2>&1 || packages+=(zsh)
  command -v git >/dev/null 2>&1 || packages+=(git)
  command -v curl >/dev/null 2>&1 || packages+=(curl)

  if ((${#packages[@]})); then
    log "installing packages: ${packages[*]}"
    require_root_or_sudo
    apt_install "${packages[@]}"
  else
    log "apt packages already satisfied (zsh, git, curl)"
  fi
}

ensure_oh_my_zsh() {
  local zsh_dir="${ZSH:-$HOME/.oh-my-zsh}"
  if [[ -d "$zsh_dir" ]]; then
    log "oh-my-zsh already present at $zsh_dir"
    return 0
  fi

  log "installing oh-my-zsh (unattended)"
  command -v curl >/dev/null 2>&1 || {
    log "error: curl is required for oh-my-zsh install"
    exit 1
  }

  export RUNZSH=no
  # Avoid interactive chsh prompts on servers without passwordless sudo.
  export CHSH=no
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
}

main() {
  ensure_debian_packages
  ensure_oh_my_zsh
  log "host bootstrap finished"
}

main "$@"
