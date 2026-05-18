#!/usr/bin/env bash
# Wipe Authentik Postgres (and optional Redis/media) for a fresh install.
# Requires AUTH_AUTHENTIK_BOOTSTRAP_* in .env (from config.secrets) — only read on first worker start.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA="${ROOT_DIR}/data/auth"
COMPOSE=(docker compose)

if [[ "${1:-}" != "--yes" ]]; then
  cat <<'EOF'
This will DELETE all Authentik data in:
  data/auth/postgres/
  data/auth/redis/        (sessions/cache)
  data/auth/authentik/media/

After restart, akadmin is recreated via AUTHENTIK_BOOTSTRAP_* (worker env).
Blueprints in config/auth/authentik/blueprints/ are re-applied automatically.

Run again with:  bash ./scripts/reset-authentik-db.sh --yes
EOF
  exit 1
fi

cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "reset-authentik-db: missing .env — run: task system:secrets-export" >&2
  exit 1
fi

if ! grep -q '^AUTH_AUTHENTIK_BOOTSTRAP_PASSWORD=' .env; then
  echo "reset-authentik-db: AUTH_AUTHENTIK_BOOTSTRAP_PASSWORD missing in .env" >&2
  echo "Add auth.authentik.bootstrap_password to config.secrets, re-export, then retry." >&2
  exit 1
fi

echo "Stopping stack..."
"${COMPOSE[@]}" down

echo "Removing Authentik data directories..."
rm -rf \
  "${DATA}/postgres/"* \
  "${DATA}/redis/"* \
  "${DATA}/authentik/media/"*

mkdir -p "${DATA}/postgres" "${DATA}/redis" "${DATA}/authentik/media"

if [[ -x "${ROOT_DIR}/scripts/fix-data-permissions.sh" ]]; then
  bash "${ROOT_DIR}/scripts/fix-data-permissions.sh"
fi

echo "Starting stack (Postgres init + Authentik bootstrap + blueprints)..."
"${COMPOSE[@]}" up -d --build

echo ""
echo "Done. Wait ~1–2 min, then:"
echo "  Admin: https://\${AUTH_AUTHENTIK_DOMAIN:-auth.example.com}"
echo "  User:  akadmin"
echo "  Pass:  value of AUTH_AUTHENTIK_BOOTSTRAP_PASSWORD in .env"
echo ""
echo "Check blueprint: docker logs sbs-authentik-worker-1 2>&1 | tail -30 | grep -i blueprint"
