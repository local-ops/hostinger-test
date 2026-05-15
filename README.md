# hostinger-test (sbs)

Docker-Compose-Projekt **sbs** für Traefik, Authentik, n8n und die statische Site **ai-consult-11ty**.

## Host-Layout

| Pfad | Inhalt |
|------|--------|
| `/docker/config/` | Dieses Repository |
| `/docker/data/` | Bind-Mount-Daten (nach Layer) |
| `/docker/backup/` | Backup-Ziel (v1: Ordner nur) |

## Repository

```
docker-compose.yml      # include aktiver compose/*.yml
config.yml              # Domains, ACME, TZ (committed)
config.secrets.enc.yml  # SOPS (auf dem Server, siehe Ersteinrichtung)
compose/00…06*.yml      # Layer; 03, 04, 06 reserved
apps/static/ai-consult-11ty/   # Eleventy-Quellcode
scripts/export_config.sh
Taskfile.yml            # system:* und maintenance:*
```

Details für Agenten: [AGENTS.md](AGENTS.md).

## Ersteinrichtung

1. Repository nach `/docker/config` klonen.
2. `config.yml` mit echten Domains anpassen.
3. Secrets:
   ```bash
   cp config.secrets.example.yml config.secrets.yml
   # Werte setzen, dann:
   sops --encrypt --age age1YOURKEY... config.secrets.yml > config.secrets.enc.yml
   rm config.secrets.yml
   ```
4. Auf dem Server: `task system:secrets-export` (einmalig oder nach Secret-Änderung).
5. `task system:start` — legt Datenordner an, erzeugt `.env`, startet Compose.

## Alltagsbefehle

| Befehl | Zweck |
|--------|--------|
| `task system:start` | init + export + `docker compose up -d --build` |
| `task system:stop` | Stack stoppen |
| `task system:pull` | Images pullen |
| `task system:secrets-export` | SOPS decrypt → `.env` |
| `task maintenance:update` | Stub (v1) |

Lokale Entwicklung der statischen Site:

```bash
cd apps/static/ai-consult-11ty
task install
task dev
```

## Deployment

Push auf `main` → GitHub Actions → SSH → `cd /docker/config && git pull && task system:start`.

Manueller Neustart: Workflow **Restart sbs stack**.

## Migration vom Legacy-Layout

Früher lagen Stacks direkt unter `/docker/` (`traefik-bjsa`, `n8n-018u`, `authentik-oa2n`, `ai-consult-11ty`). Neu: ein Repo unter `/docker/config/`.

### Ablauf (Wartungsfenster)

1. Alte Stacks stoppen (Reihenfolge egal, alles stoppen):
   ```bash
   cd /docker/n8n-018u && docker compose down
   cd /docker/authentik-oa2n && docker compose down
   cd /docker/ai-consult-11ty && docker compose down
   cd /docker/traefik-bjsa && docker compose down
   ```
2. Repo nach `/docker/config` klonen oder bestehendes Repo dorthin verschieben.
3. `config.yml` und `config.secrets.enc.yml` auf dem Host bereitstellen.
4. `task system:init`
5. **Daten von Named Volumes nach Bind-Mounts kopieren** (Beispiele; Volume-Namen mit `docker volume ls` prüfen):

   | Alt (Volume) | Neu (Host) |
   |--------------|------------|
   | `traefik-bjsa_traefik-letsencrypt` oder `traefik-letsencrypt` | `/docker/data/proxy/traefik/letsencrypt/` |
   | `n8n-018u_n8n_data` | `/docker/data/apps/n8n/` |
   | `authentik-oa2n_authentik-postgres` | `/docker/data/auth/postgres/` |
   | `authentik-oa2n_authentik-redis` | `/docker/data/auth/redis/` |
   | `authentik-oa2n_authentik-media` | `/docker/data/auth/authentik/media/` |
   | `authentik-oa2n_authentik-templates` | `/docker/data/auth/authentik/templates/` |

   Beispiel Kopie:
   ```bash
   docker run --rm -v VOLUME_NAME:/from -v /docker/data/TARGET:/to alpine cp -a /from/. /to/
   ```

6. `task system:secrets-export && task system:start`
7. Prüfen: TLS, Authentik-Login, n8n (mit ForwardAuth), öffentliche AI-Consult-Site.
8. Alte Verzeichnisse unter `/docker/` und ungenutzte Volumes erst nach Stabilisierung entfernen.

### DNS

Jede Domain in `config.yml` (`AUTH_AUTHENTIK_DOMAIN`, `APPS_N8N_DOMAIN`, `APPS_STATIC_AI_CONSULT_DOMAIN`) muss per DNS auf den Server zeigen; Ports 80/443 offen.

## Tools

- [Docker Compose](https://docs.docker.com/compose/)
- [go-task](https://taskfile.dev/)
- [yq](https://github.com/mikefarah/yq) — `export_config.sh`
- [sops](https://github.com/getsops/sops) — Secrets auf dem Server
