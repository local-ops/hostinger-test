# sbs — small business solution

Monolithisches Docker-Compose-Projekt (**sbs**) für Traefik, Authentik, n8n, die statische Site **ai-consult-11ty** und fünf **Auth-Demos** zum Testen von Schutzvarianten.

GitHub: [`local-ops/sbs`](https://github.com/local-ops/sbs) · Prod auf dem Server: `/docker/sbs`

## Prod vs. Local

| | Produktion (`system:*`) | Lokal (`dev:*`) |
|--|-------------------------|-----------------|
| Variablen | `config.yml` + `config.secrets.enc.yml` (SOPS) | zusätzlich `config.local.yml` + `config.secrets.local.yml` |
| Compose | `docker-compose.yml` | + `compose/99_local.yml` (Postgres/Redis als Named Volumes) |
| Auf Server | `task system:start` | — |

`config.yml` bleibt unverändert die Prod-Quelle; lokal überschreibt nur `config.local.yml` (z. B. `*.localhost`).

## Repository

```
config.yml / config.local.example.yml
config.secrets.enc.yml / config.secrets.local.example.yml
compose/00…05.yml, compose/05_apps_demos.yml, compose/99_local.yml
data/ backup/                             # gitignored
apps/static/ai-consult-11ty/
apps/static/demo-base/                    # nginx demos (auth-none, auth-forward, …)
apps/static/auth-oidc/                    # native OIDC client demo
apps/static/auth-jwt-api/               # Bearer JWT API demo
Taskfile.yml                              # system:*, dev:*, maintenance:*
```

Details: [AGENTS.md](AGENTS.md).

## Ersteinrichtung (Server)

1. Repo klonen nach `/docker/sbs`:
   ```bash
   git clone git@github.com:local-ops/sbs.git /docker/sbs
   ```
2. `config.yml` mit echten Domains.
3. SOPS: `config.secrets.example.yml` → encrypt → `config.secrets.enc.yml`.
4. SOPS Age-Key auf dem Host (z. B. `~/.config/sops/age/keys.txt`)
5. `bash ./scripts/bootstrap-host.sh` (installiert `task`, `yq`, `sops`)
6. `task system:deploy` (oder einmalig manuell `secrets-export` + `start`)

## Lokaler Test (Colima)

```bash
docker buildx use colima-docker    # einmalig, falls acr-builder aktiv war
task dev:setup                     # config.local.yml + config.secrets.local.yml
task dev:start                     # Colima + Stack mit 99_local.yml
```

`/etc/hosts` (Beispiel):

```
127.0.0.1 authentik.localhost n8n.localhost ai.localhost \
  auth-none.localhost auth-forward.localhost auth-forward-ops.localhost \
  auth-oidc.localhost auth-jwt-api.localhost
```

Nur Eleventy ohne Stack: `task dev:site-dev`

## Auth-Demos

| Demo | Host (local) | Schutz |
|------|----------------|--------|
| `auth-none` | `auth-none.localhost` | keiner |
| `auth-forward` | `auth-forward.localhost` | Traefik Forward Auth (jeder eingeloggte User) |
| `auth-forward-ops` | `auth-forward-ops.localhost` | Forward Auth + Authentik-Gruppe `ops` |
| `auth-oidc` | `auth-oidc.localhost` | App als OIDC-Client |
| `auth-jwt-api` | `auth-jwt-api.localhost` | `GET /api/status` mit `Authorization: Bearer` |

Prod-Hosts: `auth-*.rust-infra.de` (siehe `config.yml`). DNS A/AAAA auf den Server legen.

Payload-Referenz (Obsidian): `projekte/sbs/auth-demos/01-auth-demo-payloads` im Vault **Main**.

### Authentik setup (demos)

Einmalig in der Authentik-UI (`https://authentik.localhost` bzw. Prod-Domain):

1. **Proxy Provider** (Integration: Forward auth / Traefik)
2. **Applications** mit External URL = jeweilige Demo-Domain:
   - `auth-forward` → Policy: Require authentication
   - `auth-forward-ops` → Policy: User has group `ops` (Testuser anlegen)
3. **Outpost** (Proxy): Provider zuordnen, beide Forward-Applications aktivieren
4. **OIDC Provider** Slug `auth-oidc-demo` (wie `config.yml` → `provider_slug`):
   - Redirect URIs: `https://auth-oidc.localhost/callback` und `https://auth-oidc.rust-infra.de/callback`
   - Client ID/Secret = `apps.static.auth_demos.oidc` in Secrets
5. **OIDC Provider** Slug `auth-jwt-api-demo` für API-Tokens (Client Credentials oder Token aus Flow):
   - JWKS: `https://<AUTH_DOMAIN>/application/o/auth-jwt-api-demo/jwks/`

Secrets lokal: `config.secrets.local.example.yml` → `config.secrets.local.yml` (wird von `task dev:setup` angelegt). Prod: Werte in SOPS `config.secrets.enc.yml` ergänzen und neu deployen.

**JWT-API testen:**

```bash
# Token holen (Client Credentials — Provider in Authentik anlegen)
TOKEN="$(curl -s -X POST "https://authentik.localhost/application/o/token/" \
  -d "grant_type=client_credentials" \
  -d "client_id=auth-jwt-api-demo" \
  -d "client_secret=YOUR_SECRET" | jq -r .access_token)"
curl -si -H "Authorization: Bearer $TOKEN" https://auth-jwt-api.localhost/api/status
```

## Alltagsbefehle

| Befehl | Zweck |
|--------|--------|
| `task system:start` | Prod-Stack (Server) |
| `task system:stop` | Prod stoppen |
| `task dev:setup` | Local-Config-Dateien anlegen |
| `task dev:start` | Local-Stack |
| `task dev:stop` | Local stoppen |
| `task dev:export-config` | `.env` aus Prod + Local mergen |

## Deployment

Push auf `main` → GitHub Actions → `bootstrap-host.sh` → `task system:deploy` (kein `dev:*`).

## Migration vom Legacy-Layout

Siehe frühere README-Abschnitte: Daten von Named Volumes nach `./data/…`, dann `task system:start`.

## Tools

Docker Compose, [go-task](https://taskfile.dev/), [yq](https://github.com/mikefarah/yq), [sops](https://github.com/getsops/sops), [Colima](https://github.com/abiosoft/colima)
