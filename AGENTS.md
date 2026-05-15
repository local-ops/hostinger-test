# sbs — Agent-Kontext

## Projekt

**sbs** = *small business solution*. Monolithisches Docker-Compose-Projekt: Traefik (TLS), Authentik (Auth + ForwardAuth), n8n, statische Site `ai-consult-11ty`. Registry-Images in `compose/`; eigener Code nur unter `apps/`.

Repo: `local-ops/sbs` · Server: `/docker/sbs` · Compose-Projektname: `sbs` (`docker-compose.yml`).

## Repo-Layout (Git-Root = Arbeitsverzeichnis)

| Pfad | Zweck | Git |
|------|--------|-----|
| `config.yml` | Prod: Domains, ACME, TZ | committed |
| `config.local.yml` | Local overrides (`.localhost` etc.) | **gitignored** |
| `config.secrets.enc.yml` | Prod-Secrets (SOPS) | committed |
| `config.secrets.local.yml` | Local-Secrets | **gitignored** |
| `config/{layer}/{service}/` | Service-Config-Dateien | committed |
| `compose/00…05`, `06` | Prod-Compose-Layer | committed |
| `compose/99_local.yml` | Local-Compose (DB Named Volumes) | committed, **nur dev** |
| `data/`, `backup/` | Laufzeit / Backups | **gitignored** |
| `apps/` | Eigener Code | committed |

**Hinweis:** `config.yml` (Variablen) ≠ Ordner `config/` (Dateien pro Service).

## Prod vs. Local

| | **Prod** (`system:*`, Deploy) | **Local** (`dev:*`) |
|--|-------------------------------|---------------------|
| Config | `config.yml` + SOPS → `.env` | `config.yml` + `config.local.yml` + `config.secrets.local.yml` → `.env` |
| Compose | `docker-compose.yml` | `COMPOSE_FILE=…:compose/99_local.yml` |
| `config.local.yml` auf Server | **nein** | ja (gitignored) |

`task system:*` setzt `SBS_EXPORT_LOCAL=0` — lokale Dateien werden **nicht** gemerged.

## yq-Flatten (`config.yml` → `.env`)

1. Nur Skalar-Blätter exportieren.
2. Pfad `a.b.c` → `A_B_C`.
3. Merge-Reihenfolge **local:** `config.yml` → `config.local.yml` → `config.secrets.local.yml` → SOPS-tmp.
4. Merge-Reihenfolge **prod:** `config.yml` → SOPS-tmp nur.
5. Jeder Key im Service unter `environment:`.

## UID-Tabelle

| Ebene | Bereich | Daten unter |
|-------|---------|-------------|
| Proxy | 1000–1099 | `data/proxy/` |
| Auth | 2000–2099 | `data/auth/` |
| Apps | 6000–6099 | `data/apps/` |

Traefik: Ausnahme Docker-Socket.

## Befehle (go-task)

| Namespace | Zweck |
|-----------|--------|
| **system** | Prod-Server: `deploy` (CI), `start`, `stop`, `secrets-export`, `init`, `bootstrap-host` |
| **dev** | Lokal: `setup`, `start`, `stop`, `export-config`, `site-dev` |
| **maintenance** | Stubs: `restore`, `update-zsh` |

- Prod (CI): `task system:deploy` — immer `secrets-export` (wenn `config.secrets.enc.yml`), dann `compose up`
- Prod (manuell): `task system:start` — Secrets nur bei geändertem Stamp
- Lokal einmalig: `task dev:setup`
- Lokal: `task dev:start` (nicht `system:start` — lädt `99_local.yml`)
- Buildx macOS: `docker buildx use colima-docker`

## Deployment

Prod-Pfad auf dem Server: `/docker/sbs`. GitHub Actions → `bootstrap-host.sh` → `task system:deploy` (ohne `dev:*`). SOPS Age-Key muss auf dem Host liegen.

## Routing / DNS

Siehe README. Local: `*.localhost` in `config.local.yml` + `/etc/hosts`.

## Host-Migration

README — „Migration vom Legacy-Layout“.
