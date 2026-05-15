#!/usr/bin/env bash
# Flatten config.yml (+ optional secrets YAML) into .env for docker compose.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${ROOT_DIR}/config.yml"
SECRETS_TMP="${ROOT_DIR}/.secrets.tmp.yaml"
ENV_OUT="${ROOT_DIR}/.env"
MERGE_TMP="${ROOT_DIR}/.config.merge.tmp.yaml"

if ! command -v yq >/dev/null 2>&1; then
  echo "export_config: yq is required" >&2
  exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
  echo "export_config: missing $CONFIG" >&2
  exit 1
fi

cp "$CONFIG" "$MERGE_TMP"
if [[ -f "$SECRETS_TMP" ]]; then
  yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
    "$MERGE_TMP" "$SECRETS_TMP" > "${MERGE_TMP}.merged"
  mv "${MERGE_TMP}.merged" "$MERGE_TMP"
fi

# Leaf scalars only: path with dots -> ENV name with underscores, uppercase.
yq eval '.. | select(tag != "!!map" and tag != "!!seq") | (path | join(".")) + "=" + (. | tostring)' \
  "$MERGE_TMP" | while IFS= read -r line; do
  path="${line%%=*}"
  value="${line#*=}"
  name="$(echo "$path" | tr '[:lower:]' '[:upper:]' | tr '.' '_')"
  printf '%s=%s\n' "$name" "$value"
done | LC_ALL=C sort -u > "$ENV_OUT"

rm -f "$MERGE_TMP"
chmod 600 "$ENV_OUT"
echo "export_config: wrote $ENV_OUT"
