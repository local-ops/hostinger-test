#!/usr/bin/env bash
# Ensures required host packages and deploy tooling exist (idempotent).
# Intended for Debian/Ubuntu-based deploy hosts.

set -euo pipefail

TASK_VERSION="${TASK_VERSION:-v3.43.3}"
YQ_VERSION="${YQ_VERSION:-v4.44.6}"
SOPS_VERSION="${SOPS_VERSION:-v3.10.2}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

log() {
  printf '[bootstrap-host] %s\n' "$*"
}

require_root_or_sudo() {
  if [[ "$(id -u)" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    log "error: need root or sudo for package installation"
    exit 1
  fi
}

run_privileged() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

detect_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo amd64 ;;
    aarch64 | arm64) echo arm64 ;;
    *)
      log "error: unsupported architecture: $(uname -m)"
      exit 1
      ;;
  esac
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

install_binary() {
  local url="$1"
  local name="$2"
  local dest="${INSTALL_DIR}/${name}"

  if [[ -x "$dest" ]]; then
    log "${name} already installed at ${dest}"
    return 0
  fi

  log "installing ${name} -> ${dest}"
  require_root_or_sudo
  run_privileged curl -fsSL "$url" -o "$dest"
  run_privileged chmod 755 "$dest"
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

ensure_task() {
  if command -v task >/dev/null 2>&1; then
    log "task already installed ($(task --version 2>&1 | head -1))"
    return 0
  fi

  log "installing go-task (${TASK_VERSION})"
  require_root_or_sudo
  if [[ "$(id -u)" -eq 0 ]]; then
    sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b "${INSTALL_DIR}" "${TASK_VERSION}"
  else
    sudo sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b "${INSTALL_DIR}" "${TASK_VERSION}"
  fi
}

ensure_yq() {
  if command -v yq >/dev/null 2>&1; then
    log "yq already installed ($(yq --version 2>&1 | head -1))"
    return 0
  fi

  local arch
  arch="$(detect_arch)"
  install_binary \
    "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${arch}" \
    "yq"
}

ensure_sops() {
  if command -v sops >/dev/null 2>&1; then
    log "sops already installed ($(sops --version 2>&1 | head -1))"
    return 0
  fi

  local arch
  arch="$(detect_arch)"
  install_binary \
    "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.${arch}" \
    "sops"
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
  export CHSH=no
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
}

main() {
  ensure_debian_packages
  ensure_task
  ensure_yq
  ensure_sops
  ensure_oh_my_zsh
  log "host bootstrap finished (task, yq, sops, docker compose required for deploy)"
}

main "$@"
