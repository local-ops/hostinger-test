#!/usr/bin/env bash
# Ensure bind-mount data/ dirs exist and are owned for container UIDs (recursive).
# Idempotent — run on every deploy via task system:fix-data-permissions.
#
# Mount map mirrors compose/*.yml (../data/... bind mounts).
# Postgres/Redis binds are skipped when compose/99_local.yml is active (named volumes).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA="${ROOT_DIR}/data"
STRICT="${SBS_FIX_PERMS_STRICT:-0}"

# path_relative_to_data|uid|gid
readonly -a MOUNT_SPECS=(
  "proxy/traefik/letsencrypt|0|0"
  "auth/postgres|999|999"
  "auth/redis|999|999"
  "auth/authentik/media|1000|1000"
  "auth/authentik/templates|1000|1000"
  "apps/n8n|1000|1000"
)

skip_db_bind_mounts=0
if [[ -f "${ROOT_DIR}/docker-compose.override.yml" ]]; then
  skip_db_bind_mounts=1
fi
if [[ "${COMPOSE_FILE:-}" == *"99_local.yml"* ]]; then
  skip_db_bind_mounts=1
fi

dir_uid() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    echo ""
    return 0
  fi
  if stat -c '%u' "$path" >/dev/null 2>&1; then
    stat -c '%u' "$path"
  else
    stat -f '%u' "$path"
  fi
}

dir_gid() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    echo ""
    return 0
  fi
  if stat -c '%g' "$path" >/dev/null 2>&1; then
    stat -c '%g' "$path"
  else
    stat -f '%g' "$path"
  fi
}

needs_fix() {
  local path="$1" want_uid="$2" want_gid="$3"
  local have_uid have_gid
  if [[ ! -d "$path" ]]; then
    return 0
  fi
  have_uid="$(dir_uid "$path")"
  have_gid="$(dir_gid "$path")"
  [[ "$have_uid" != "$want_uid" || "$have_gid" != "$want_gid" ]]
}

apply_chown() {
  local host_path="$1" uid="$2" gid="$3"
  mkdir -p "$host_path"
  if [[ $EUID -eq 0 ]]; then
    chown -R "${uid}:${gid}" "$host_path"
    return 0
  fi
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    docker run --rm -v "${host_path}:/mnt" alpine:3 chown -R "${uid}:${gid}" /mnt
    return 0
  fi
  return 1
}

if ! command -v docker >/dev/null 2>&1 && [[ $EUID -ne 0 ]]; then
  echo "fix-data-permissions: need root or docker" >&2
  exit 1
fi

checked=0
fixed=0
failed=0
skipped=0

for spec in "${MOUNT_SPECS[@]}"; do
  IFS='|' read -r rel want_uid want_gid <<< "$spec"
  if ((skip_db_bind_mounts)) && [[ "$rel" == "auth/postgres" || "$rel" == "auth/redis" ]]; then
    echo "fix-data-permissions: skip ${rel} (named volumes / local compose)"
    ((skipped+=1)) || true
    continue
  fi

  host_path="${DATA}/${rel}"
  ((checked+=1)) || true

  if needs_fix "$host_path" "$want_uid" "$want_gid"; then
    have_uid="$(dir_uid "$host_path")"
    have_gid="$(dir_gid "$host_path")"
    if [[ -z "$have_uid" ]]; then
      echo "fix-data-permissions: ${rel} missing -> create ${want_uid}:${want_gid} (recursive)"
    else
      echo "fix-data-permissions: ${rel} ${have_uid}:${have_gid} -> ${want_uid}:${want_gid} (recursive)"
    fi
    if apply_chown "$host_path" "$want_uid" "$want_gid"; then
      ((fixed+=1)) || true
    else
      echo "fix-data-permissions: failed ${host_path}" >&2
      ((failed+=1)) || true
    fi
  else
    echo "fix-data-permissions: ${rel} ok (${want_uid}:${want_gid})"
  fi
done

echo "fix-data-permissions: checked=${checked} fixed=${fixed} skipped=${skipped} failed=${failed}"

if ((failed)); then
  echo "fix-data-permissions: chown failed (common on macOS/Colima virtiofs)." >&2
  echo "  Local: use task dev:start (compose/99_local.yml uses named DB volumes)." >&2
  if [[ "$STRICT" == "1" ]]; then
    exit 1
  fi
  exit 0
fi

exit 0
