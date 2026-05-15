# sbs — Agent-Kontext (hostinger-test)

## Projekt

Monolithisches Docker-Compose-Projekt **sbs**: Traefik (TLS), Authentik (Auth + ForwardAuth), n8n, statische Site `ai-consult-11ty`. Registry-Images in `compose/`; eigener Code nur unter `apps/`.

## Host-Pfade

| Pfad | Zweck |
|------|--------|
| `/docker/config/` | Git-Repository (dieses Repo auf dem Server) |
| `/docker/data/` | Bind-Mount-Daten pro Layer/Service |
| `/docker/backup/` | Backup-Ziel (v1: Ordner nur, Logik OOS) |

## Repo-Layout

- `docker-compose.yml` — Root mit `include:` aktiver Layer
- `config.yml` — nicht-secret, echte Werte im Repo
- `config.secrets.enc.yml` — SOPS-verschlüsselt; entschlüsseln mit `task system:secrets-export`
- `compose/00_network.yml` … `06_monitoring.yml` — Layer; `03`, `04`, `06` reserved (include auskommentiert)
- `apps/static|dynamic|service/` — nur eigener Code (`static/ai-consult-11ty`); keine Registry-Apps
- `scripts/export_config.sh` — YAML → `.env` (yq)
- `Taskfile.yml` — `system:*` und `maintenance:*`

## UID-Tabelle (Host-System-User)

| Ebene | Bereich | Beispiel | Daten unter |
|-------|---------|----------|-------------|
| Proxy | 1000–1099 | 1000 traefik | `/docker/data/proxy/` |
| Auth | 2000–2099 | 2000 authentik | `/docker/data/auth/` |
| Secrets | 3000–3099 | 3000 vaultwarden | `/docker/data/secrets/` |
| Datenbanken | 4000–4099 | 4000 postgres, 4001 redis | `/docker/data/auth/postgres`, `…/redis` |
| Monitoring | 5000–5099 | 5000 grafana | `/docker/data/monitoring/` |
| Apps | 6000–6099 | 6000 n8n | `/docker/data/apps/` |
| Files | 6100–6199 | 6100 nextcloud | `/docker/data/files/` |

`task system:init` legt Verzeichnisse an; UID/`user:` in Compose schrittweise. **Ausnahme Traefik:** Zugriff auf `/var/run/docker.sock` — Abweichung von „nur eigener Ordner“; bei weiteren Ausnahmen in AGENTS.md dokumentieren.

## yq-Flatten (`config.yml` → `.env`)

1. Nur Skalar-Blätter exportieren.
2. Pfad `a.b.c` → Env-Name `A_B_C` (Punkte → Unterstrich, Großbuchstaben).
3. Merge: zuerst `config.yml`, dann Secrets; bei Kollision gewinnt Secret.
4. `.env`: `NAME=wert`, keine Anführungszeichen; gitignored, `chmod 600`.
5. Jeder exportierte Key muss im Service unter `environment:` stehen (nicht nur in Traefik-Labels).

Beispiel: `auth.authentik.domain` → `AUTH_AUTHENTIK_DOMAIN`.

## Config & Secrets

- **config.yml** — Domains, ACME-Mail, TZ (committed).
- **config.secrets.enc.yml** — `postgres_password`, `secret_key` (SOPS).
- Erzeugen: `task system:secrets-export` (nach `sops --encrypt …`).
- `task system:start` ruft `export-config` auf (Secrets nur bei geändertem `.enc.yml` neu decrypten).

## Befehle (go-task)

- Produktion: `task system:start`, `task system:stop`, `task system:pull`
- Wartung (v1 Stubs): `task maintenance:update`, `maintenance:restore`, `maintenance:update-zsh`
- Lokale Site-Entwicklung: `task -d apps/static/ai-consult-11ty dev`

## Deployment

- GitHub Actions: SSH → `cd /docker/config && git pull && task system:start`
- Kein Produktions-Deploy simulieren ohne ausdrückliche Anfrage.

## Routing

- Traefik-Labels in Compose; öffentlich ohne ForwardAuth: `ai-consult-web`
- n8n: `authentik-forwardauth@docker` (Middleware auf `authentik-server`)
- Subdomains bevorzugt; PathPrefix nur wenn die App Base-Path unterstützt.

## DNS & TLS (Go-Live)

- Jede `*_DOMAIN` in `config.yml` als DNS A/AAAA auf den Host
- Ports 80/443 offen
- ACME HTTP-01: `/.well-known/acme-challenge` nicht durch Auth blockieren

## Backup

v1: nur `/docker/backup/{layer}/` anlegen; `task maintenance:backup` nicht implementiert.

## Host-Migration (von alten Stacks)

Siehe README — Abschnitt „Migration vom Legacy-Layout“.
