# Agile-Linus Cookbook (Ruby/Sinatra)

![Quality Pipeline](https://github.com/Linus-nisse-segmentering/Agile-Linus/actions/workflows/quality.yml/badge.svg)
![SonarCloud](https://sonarcloud.io/api/project_badges/measure?project=Linus-nisse-segmentering_Agile-Linus&metric=alert_status)
![CD Pipeline](https://github.com/Linus-nisse-segmentering/Agile-Linus/actions/workflows/deploy-azure-vm.yml/badge.svg)
![Linted with RuboCop](https://img.shields.io/badge/lint-RuboCop-black)
![Tested with RSpec](https://img.shields.io/badge/test-RSpec-red)

Et studieprojekt med en opskrift-app bygget i Ruby/Sinatra, PostgreSQL og Docker.

Formålet med denne README er at gøre projektet let at forstå, starte og arbejde videre på for studerende.

## Indholdsfortegnelse

1. Projektoverblik
2. Hurtig start
3. Installation og lokale krav
4. Kørsel med Docker
5. Kørsel af monitorering (Prometheus/Grafana)
6. Projektstruktur
7. Web-ruter (HTML)
8. API-ruter (JSON)
9. Database
10. Miljøvariabler
11. Test og kodekvalitet
12. Kørsel på Azure VM
13. Fork og GitHub Secrets (til CI/CD)
14. Deployment
15. Fejlfinding
16. Kendte begrænsninger

## Projektoverblik

Applikationen består af tre centrale dele:

- `sinatra-app`: selve Ruby/Sinatra-applikationen (kører internt på port `1010`).
- `sinatra-db`: PostgreSQL-database med opskrifter, tags, ingredienser og brugere.
- `sinatra-nginx`: reverse proxy, som eksponerer appen på port `80`.

Derudover kan der startes en separat monitoreringsstack:

- Prometheus til metrics.
- Grafana til dashboards.

## Hurtig start

Kør følgende fra projektroden:

```bash
docker compose up --build
```

Åbn derefter:

- App: `http://localhost`
- API docs (Swagger UI): `http://localhost/apidocs`
- OpenAPI schema: `http://localhost/api/schema`

Stop igen med:

```bash
docker compose down
```

## Installation og lokale krav

For at kunne køre projektet anbefales:

- Docker Desktop (eller Docker Engine + Compose plugin).
- Git.
- En terminal (`zsh`, `bash` eller PowerShell).

Valgfrit til lokal udvikling uden Docker:

- Ruby `3.3.x` (se `.ruby-version`).
- Bundler.
- PostgreSQL.

## Kørsel med Docker

### Standard (udvikling på egen maskine)

Start:

```bash
docker compose up --build
```

Kør i baggrunden:

```bash
docker compose up -d --build
```

Se logs:

```bash
docker compose logs -f
```

Stop stack:

```bash
docker compose down
```

### Produktion på VM (Azure)

Projektet indeholder også en produktions-compose fil:

```bash
docker compose -f docker-compose.prod.yaml up -d
```

Stop:

```bash
docker compose -f docker-compose.prod.yaml down
```

## Kørsel af monitorering (Prometheus/Grafana)

Monitorering startes i en separat compose-fil:

```bash
docker compose -f monitoring/docker-compose.yml up -d
```

Adresser:

- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000`

Standard-login i Grafana:

- Bruger: `admin`
- Password: `admin` (kan overskrives med `GRAFANA_ADMIN_PASSWORD`)

Stop monitorering:

```bash
docker compose -f monitoring/docker-compose.yml down
```

## Projektstruktur

```text
.
├── app.rb                         # Sinatra app og API-ruter
├── config.ru                      # Rack entrypoint
├── Dockerfile                     # Build af app-container
├── docker-compose.yaml            # Lokal stack (db + app + nginx)
├── docker-compose.prod.yaml       # Produktionsstack
├── db/
│   ├── schema.pg.sql              # PostgreSQL schema
│   ├── seeds.sql                  # Seed data
│   ├── schema.sql                 # Legacy SQLite schema
│   └── migrate_sqlite_to_postgres.rb
├── views/                         # ERB templates
├── static/                        # CSS og Swagger assets
├── spec/                          # RSpec tests
├── infrastructure/
│   ├── nginx/default.conf         # Reverse proxy config
│   ├── azure-setup.sh             # VM setup
│   └── azure-teardown.sh
├── monitoring/
│   ├── docker-compose.yml         # Prometheus + Grafana
│   └── prometheus.yml
└── docs/                          # Projekt- og procesdokumentation
```

## Web-ruter (HTML)

- `GET /` viser alle opskrifter.
- `GET /recipes/:id/` viser detaljesiden for en opskrift.
- `GET /apidocs` viser Swagger UI.

## API-ruter (JSON)

### Overblik og schema

- `GET /api`
- `GET /api/schema`
- `GET /metrics`

### User

- `POST /api/user/create/`
- `GET /api/user/me/`
- `PUT /api/user/me/`
- `PATCH /api/user/me/`
- `POST /api/user/token/`

### Recipes

- `GET /api/recipe/recipes/`
- `POST /api/recipe/recipes/`
- `GET /api/recipe/recipes/:id/`
- `PUT /api/recipe/recipes/:id/`
- `PATCH /api/recipe/recipes/:id/`
- `DELETE /api/recipe/recipes/:id/`
- `POST /api/recipe/recipes/:id/upload-image/`

### Ingredients

- `GET /api/recipe/ingredients/`
- `PUT /api/recipe/ingredients/:id/`
- `PATCH /api/recipe/ingredients/:id/`
- `DELETE /api/recipe/ingredients/:id/`

### Tags

- `GET /api/recipe/tags/`
- `PUT /api/recipe/tags/:id/`
- `PATCH /api/recipe/tags/:id/`
- `DELETE /api/recipe/tags/:id/`

### Eksempel på API-kald

```bash
curl http://localhost/api/recipe/recipes/
```

## Database

Projektet bruger PostgreSQL som primær database.

Kerne-tabeller:

- `users`
- `recipes`
- `ingredients`
- `tags`
- `recipe_ingredients`
- `recipe_tags`

Schema ligger i `db/schema.pg.sql`, og seed data ligger i `db/seeds.sql`.

Ved opstart med `DB_INIT=true` opretter appen schema og seeder data, hvis databasen er tom.

## Miljøvariabler

Vigtigste variabler til appen:

- `DB_HOST` (default: `localhost`)
- `DB_PORT` (default: `5432`)
- `DB_NAME` (default: `recipe_cookbook`)
- `DB_USER` (default: `recipe_user`)
- `DB_PASSWORD` (default: `recipe_pass`)
- `DB_SSLMODE` (default: `prefer`)
- `DB_INIT` (`true`/`false`, default: `false` i kode)
- `DATABASE_URL` (overstyrer de øvrige DB-felter hvis sat)

## Test og kodekvalitet

Kør lokalt:

```bash
bundle install
bundle exec rubocop
bundle exec rspec
```

Git hooks kan sættes op med:

```powershell
./scripts/setup-git-hooks.ps1
```

CI workflows ligger i:

- `.github/workflows/quality.yml`
- `.github/workflows/deploy-azure-vm.yml`

## Kørsel på Azure VM

Når I vil køre projektet på en VM (fx til demo/eksamen), kan I bruge dette flow:

1. Opret en Linux VM i Azure.
2. Åbn porte i NSG/firewall:
- `80` (app via nginx)
- `3000` (Grafana, hvis brugt)
- `9090` (Prometheus, hvis brugt)
3. SSH ind på VM og clon repo.
4. Kør setup script:
```bash
chmod +x infrastructure/azure-setup.sh
./infrastructure/azure-setup.sh
```
5. Start produktion-stack:
```bash
docker compose -f docker-compose.prod.yaml up -d --build
```
6. Verificer at appen svarer:
```bash
curl -I http://<vm-public-ip>
```

Hvis I også vil have monitorering:

```bash
docker compose -f monitoring/docker-compose.yml up -d
```

## Fork og GitHub Secrets (til CI/CD)

Ja, hvis I deployer fra jeres egen fork, skal I typisk selv sætte secrets i jeres fork-repository.

På GitHub i jeres fork:

`Settings` -> `Secrets and variables` -> `Actions` -> `New repository secret`

Typiske secrets til VM-deploy workflow:

- `AZURE_VM_HOST` (offentlig IP eller DNS)
- `AZURE_VM_USER` (SSH-bruger)
- `AZURE_VM_SSH_KEY` (privat SSH nøgle, hele indholdet)
- `AZURE_VM_PORT` (ofte `22`)

Hvis quality-pipeline bruger SonarCloud:

- `SONAR_TOKEN`

Vigtigt:

- Secrets fra original-repo følger ikke automatisk med til en fork.
- Workflows i fork virker først, når secrets er sat korrekt.
- Kør gerne en test-deploy fra en feature-branch før demo-dagen.

## Deployment

Deployment-strategien er container-baseret:

- Nginx modtager trafik på `:80`.
- Nginx videresender til Sinatra app på intern port `1010`.
- PostgreSQL kører i separat service.

Azure helper scripts:

- `infrastructure/azure-setup.sh`
- `infrastructure/azure-teardown.sh`

Læs mere i:

- `docs/deployment-strategy.md`
- `docs/branching-strategy.md`
- `docs/software-quality.md`
- `docs/issue-management.md`

## Fejlfinding

Hvis appen ikke svarer på `http://localhost`:

1. Tjek containere:
```bash
docker compose ps
```
2. Tjek logs:
```bash
docker compose logs -f app nginx db
```
3. Tjek metrics endpoint direkte mod app-container:
```bash
docker compose exec app ruby -e "require 'net/http'; puts Net::HTTP.get(URI('http://127.0.0.1:1010/metrics'))[0..200]"
```

Hvis databasen er i dårlig tilstand lokalt:

```bash
docker compose down -v
docker compose up --build
```

## Kendte begrænsninger

- Flere API endpoints er demo/stub-lignende og gemmer ikke altid ændringer permanent.
- Auth/token-flow er ikke fuldt produktionsklart.
- Input-validering er begrænset flere steder.
- Appen er god til undervisning og demo, men kræver hardening til produktion.

## License

Projektet er lavet til uddannelsesformål.
