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
12. Deployment
13. Fejlfinding
14. Kendte begrænsninger

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
