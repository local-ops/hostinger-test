# hostinger-test

## Core-Essenz

Dieses Repository verwaltet eine Docker-Compose-basierte Server-Landschaft für den Betrieb von:

- **Traefik** als Reverse Proxy + TLS (Let's Encrypt)
- **n8n** als Automatisierungsplattform
- **Authentik** als Identity-/Access-Management
- **ai-consult-11ty** als statische Willkommens-/Beratungs-Onepager (Eleventy-Build in Docker, nginx)

Ziel ist ein klar strukturierter, reproduzierbarer Betrieb mehrerer Stacks auf einem Host unter `/docker`.

## Wo steht was?

- `/traefik-bjsa/docker-compose.yml`  
  Traefik-Stack (Ports 80/443, ACME/TLS, Docker Provider)
- `/n8n-018u/docker-compose.yml`  
  n8n-Stack inkl. Traefik-Routing-Labels
- `/authentik-oa2n/docker-compose.yml`  
  Authentik-Stack inkl. Postgres, Redis und Traefik-Routing-Labels
- `/ai-consult-11ty/docker-compose.yml`  
  Statische KI-Beratungs-Onepager (Multi-Stage-Build: Eleventy → nginx), öffentlich ohne Authentik-ForwardAuth; Befehle über **`Taskfile.yml`** ([go-task](https://taskfile.dev/)): `task install`, `task dev`, `task build`, `task up`, `task down` (siehe `task --list` im Ordner)
- `*/.env.example`  
  Beispielwerte für notwendige Umgebungsvariablen je Stack
- `/scripts/bootstrap-host.sh`  
  Optionales Host-Bootstrap-Skript (Debian/Ubuntu, installiert Basis-Tools + oh-my-zsh)
- `/.github/workflows/deploy.yml`  
  Automatisches Deployment bei Push auf `main`
- `/.github/workflows/restart-all-stacks.yml`  
  Manueller Restart aller Stacks via GitHub Actions

## Wie wird es ausgeliefert?

Die Auslieferung erfolgt über **GitHub Actions + SSH** auf den Zielhost:

1. Workflow `deploy.yml` läuft bei Push auf `main`.
2. Auf dem Host wird das Netzwerk `traefik_proxy` sichergestellt.
3. Für jeden Stack unter `/docker/*` (außer `script`/`scripts`):
   - `git pull --ff-only origin main`
   - optional `scripts/bootstrap-host.sh`
4. Danach pro Stack mit Compose-Datei:
   - `docker compose pull`
   - `docker compose up -d --build` (damit Stacks mit `Dockerfile` wie `ai-consult-11ty` nach jedem Pull neu gebaut werden)

Für einen reinen Neustart ohne Pull kann `restart-all-stacks.yml` manuell ausgelöst werden (inkl. `ai-consult-11ty` mit `--build`).

### Lokale Entwicklung (ai-consult-11ty)

Im Ordner `ai-consult-11ty/`:

1. `.env` aus `.env.example` anlegen (nur für `task up` / Docker auf dem Host nötig).
2. `task install` — Node-Abhängigkeiten.
3. `task dev` — Eleventy mit Live-Reload (Standard: http://localhost:8080).
4. Produktion lokal testen: `task up` (Docker-Build + nginx hinter Traefik-Labels).
