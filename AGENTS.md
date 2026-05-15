# hostinger-test — Agent-Kontext

## Projekt

Docker-Compose-betriebene Server-Landschaft: **Traefik** (Reverse Proxy, TLS), **n8n**, **Authentik**, **ai-consult-11ty** (statische Beratungs-Onepager, öffentlich). Ziel ist reproduzierbarer Betrieb; auf dem Zielhost liegt die Konvention typischerweise unter `/docker`.

## Repo-Layout

- Jeder Stack in einem **eigenen Unterordner** mit `docker-compose.yml` und `.env.example`.
- Secrets und Host-spezifische Werte nur in **`.env`** (nicht versioniert); Vorlagen aus `.env.example` ableiten.

## Befehle und go-task (Task)

- Alle **Befehle, die man braucht, um einen Stack oder ein Artefakt zu nutzen** (lokal bauen, entwickeln, Container starten/stoppen, Tests, Hilfsskripte usw.), müssen über **[go-task](https://taskfile.dev/)** (`task` CLI) abgebildet werden — nicht nur als freie Shell-Zeilen in der Doku.
- Dazu gehört eine **`Taskfile.yml` im jeweiligen Stack-Ordner** (dort, wo auch `docker-compose.yml` liegt). Namen der Tasks sollen klar und stabil sein (z. B. `dev`, `build`, `up`, `down`).
- README oder Kommentare dürfen `task …` referenzieren; die **kanonische** Schnittstelle für wiederholbare Schritte ist die Task-Definition im Ordner.

## Deployment

- Auslieferung über **GitHub Actions** (SSH), ausgelöst durch Push auf **`main`**; es gibt einen separaten Workflow für manuelle Restarts.
- Deploy führt `docker compose up -d --build` aus, damit Image-Build-Stacks (z. B. **ai-consult-11ty**) nach `git pull` zuverlässig neu gebaut werden.
- Kein Produktions-Deploy oder Host-Zugriff annehmen oder simulieren, wenn der Nutzer das nicht ausdrücklich verlangt.

## Änderungen an Stacks

- Routing/TLS über **Traefik-Labels** in den Compose-Dateien; Änderungen konsistent über alle betroffenen Services halten.
- Das Docker-Netz **`traefik_proxy`** ist deploymentspezifisch und muss auf dem Host zur Compose-Konfiguration passen.

## Unterpfade in Traefik („Sub-Pages“)

- Router-**Rule** um einen Pfad ergänzen (analog zu den bestehenden `Host(...)`-Labels in den Compose-Dateien). Beispiel für die Rule-Zeichenkette in Traefik v2/v3:

  ```text
  Host(`example.com`) && PathPrefix(`/meinpfad`)
  ```

  In Compose-Labels dieselbe `rule=`-Form wie bei den Host-Routern, nur mit `&& PathPrefix(...)` erweitert; Backticks in der Rule wie in den bestehenden Stacks quoten/escapen.
- Wenn der Dienst URLs **ohne** den äußeren Präfix erwartet: **StripPrefix**-Middleware definieren (`stripprefix.prefixes=/meinpfad`) und beim Router unter `middlewares=` einhängen.
- Bei mehreren Routern auf derselben Domain ggf. **`priority`** setzen, damit spezifischere Rules vor allgemeineren greifen.
- Die Anwendung muss einen **Base-Path** / öffentliche URLs mit unterstützen (n8n, Authentik u. a. oft eher eigene Subdomain statt Unterpfad); vorher prüfen.
