#!/usr/bin/env bash
# Flatten config YAML into .env for docker compose.
# Prod (system):  config.yml [+ SOPS .secrets.tmp.yaml]
# Local (dev):     config.yml + config.local.yml + config.secrets.local.yml [+ SOPS]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${ROOT_DIR}/config.yml"
CONFIG_LOCAL="${ROOT_DIR}/config.local.yml"
SECRETS_LOCAL="${ROOT_DIR}/config.secrets.local.yml"
SECRETS_TMP="${ROOT_DIR}/.secrets.tmp.yaml"
ENV_OUT="${ROOT_DIR}/.env"
MERGE_TMP="${ROOT_DIR}/.config.merge.tmp.yaml"

USE_LOCAL=0
if [[ "${SBS_EXPORT_LOCAL:-}" == "1" ]] || [[ "${1:-}" == "--local" ]]; then
  USE_LOCAL=1
fi

if ! command -v yq >/dev/null 2>&1; then
  echo "export_config: yq is required" >&2
  exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
  echo "export_config: missing $CONFIG" >&2
  exit 1
fi

cp "$CONFIG" "$MERGE_TMP"
merge_file() {
  local extra="$1"
  yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
    "$MERGE_TMP" "$extra" > "${MERGE_TMP}.merged"
  mv "${MERGE_TMP}.merged" "$MERGE_TMP"
}

if ((USE_LOCAL)) && [[ -f "$CONFIG_LOCAL" ]]; then
  merge_file "$CONFIG_LOCAL"
fi

if ((USE_LOCAL)) && [[ -f "$SECRETS_LOCAL" ]]; then
  merge_file "$SECRETS_LOCAL"
fi

if [[ -f "$SECRETS_TMP" ]]; then
  merge_file "$SECRETS_TMP"
fi

yq eval '.. | select(tag != "!!map" and tag != "!!seq") | (path | join(".")) + "=" + (. | tostring)' \
  "$MERGE_TMP" | while IFS= read -r line; do
  path="${line%%=*}"
  value="${line#*=}"
  name="$(echo "$path" | tr '[:lower:]' '[:upper:]' | tr '.' '_')"
  printf '%s=%s\n' "$name" "$value"
done | LC_ALL=C sort -u > "$ENV_OUT"

rm -f "$MERGE_TMP"
chmod 600 "$ENV_OUT"
if ((USE_LOCAL)); then
  echo "export_config: wrote $ENV_OUT (local: config.yml + config.local.yml + secrets)"
else
  echo "export_config: wrote $ENV_OUT (prod: config.yml + SOPS if present)"
fi
