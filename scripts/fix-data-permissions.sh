#!/usr/bin/env bash
# Set ownership on bind-mount data dirs for container UIDs (postgres/redis: 999).
# Local dev uses compose/99_local.yml (named volumes) via task dev:* — skip is optional.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA="${ROOT_DIR}/data"

if [[ -f "${ROOT_DIR}/docker-compose.override.yml" ]]; then
  echo "fix-data-permissions: docker-compose.override.yml present, skipping bind-mount chown"
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "fix-data-permissions: docker not available, skipping" >&2
  exit 0
fi

fix_dir() {
  local host_path="$1"
  local uid="$2"
  local gid="${3:-$2}"
  mkdir -p "$host_path"
  if docker run --rm -v "${host_path}:/mnt" alpine:3 chown -R "${uid}:${gid}" /mnt 2>/dev/null; then
    echo "fix-data-permissions: ${host_path} -> ${uid}:${gid}"
    return 0
  fi
  return 1
}

failed=0
fix_dir "${DATA}/auth/postgres" 999 || failed=1
fix_dir "${DATA}/auth/redis" 999 || failed=1

if ((failed)); then
  echo "fix-data-permissions: chown failed (common on macOS/Colima virtiofs)." >&2
  echo "  Use task dev:start (loads compose/99_local.yml with named DB volumes)." >&2
  exit 0
fi
