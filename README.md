# sbs — small business solution

Monolithisches Docker-Compose-Projekt (**sbs**) für Traefik, Authentik, n8n und die statische Site **ai-consult-11ty**.

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
compose/00…05.yml, compose/99_local.yml   # 99 nur für dev
data/ backup/                             # gitignored
apps/static/ai-consult-11ty/
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
4. `task system:secrets-export`
5. `task system:start`

## Lokaler Test (Colima)

```bash
docker buildx use colima-docker    # einmalig, falls acr-builder aktiv war
task dev:setup                     # config.local.yml + config.secrets.local.yml
task dev:start                     # Colima + Stack mit 99_local.yml
```

`/etc/hosts` (Beispiel):

```
127.0.0.1 authentik.localhost n8n.localhost ai.localhost
```

Nur Eleventy ohne Stack: `task dev:site-dev`

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

Push auf `main` → GitHub Actions → `task system:start` (kein `dev:*`).

## Migration vom Legacy-Layout

Siehe frühere README-Abschnitte: Daten von Named Volumes nach `./data/…`, dann `task system:start`.

## Tools

Docker Compose, [go-task](https://taskfile.dev/), [yq](https://github.com/mikefarah/yq), [sops](https://github.com/getsops/sops), [Colima](https://github.com/abiosoft/colima)
