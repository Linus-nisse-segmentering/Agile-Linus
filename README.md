# Recipe Cookbook - Ruby/Sinatra Edition

![Quality Pipeline](https://github.com/Linus-nisse-segmentering/Agile-Linus/actions/workflows/quality.yml/badge.svg)
![CD Pipeline](https://github.com/Linus-nisse-segmentering/Agile-Linus/actions/workflows/deploy-azure-vm.yml/badge.svg)
![Linted with RuboCop](https://img.shields.io/badge/lint-RuboCop-black)
![Tested with RSpec](https://img.shields.io/badge/test-RSpec-red)

A recipe cookbook web application built with Ruby and the Sinatra framework, featuring a retro 90s-style interface and a RESTful API.

## Features

- Browse recipes with ingredients and tags
- View detailed recipe instructions
- RESTful API for recipes, ingredients, tags, and users
- PostgreSQL database with full schema and seed data
- Retro 90s web design aesthetic

## Prerequisites

- Docker
- Docker Compose

## Running on the Azure VM

Use the production compose file on the VM host:

```bash
docker compose -f docker-compose.prod.yaml up -d
```

The application is served through nginx on port 80, so open:

- App: http://<vm-public-ip>
- API docs: http://<vm-public-ip>/apidocs
- API schema: http://<vm-public-ip>/api/schema

The app container still listens internally on port 1010 for container-to-container traffic.

To stop the stack:

```bash
docker compose -f docker-compose.prod.yaml down
```

To view logs:

```bash
docker compose -f docker-compose.prod.yaml logs -f
```

## Monitoring

Prometheus scrapes the backend through nginx on a shared Docker network, and Grafana is pre-provisioned with Prometheus as its datasource.

Start the monitoring stack on the VM in a second terminal:

```bash
docker compose -f monitoring/docker-compose.yml up -d
```

The shared network is created automatically by either compose stack, so you can start the app or monitoring stack first.

Then open:

- Prometheus: http://<vm-public-ip>:9090
- Grafana: http://<vm-public-ip>:3000

Grafana uses `admin` as the default password unless you set `GRAFANA_ADMIN_PASSWORD`.

When deploying to Azure VM, make sure ports 3000 and 9090 are open in the VM NSG and host firewall.

## Project Structure

```
.
├── app.rb              # Main Sinatra application
├── config.ru           # Rack configuration
├── Gemfile             # Ruby dependencies
├── db/
│   ├── schema.sql      # SQLite schema (legacy)
│   ├── schema.pg.sql   # PostgreSQL schema
│   ├── seeds.sql       # Seed data
│   ├── setup.rb        # SQLite setup script (legacy)
│   └── migrate_sqlite_to_postgres.rb # One-time migration script
├── views/
│   ├── layout.erb      # Base layout template
│   ├── home.erb        # Home page template
│   └── recipe_detail.erb  # Recipe detail template
└── static/
    └── style.css       # Stylesheet
├── infrastructure/
│   ├── azure-setup.sh  # Azure VM provisioning helper
│   └── nginx/
│       └── default.conf # nginx reverse proxy configuration
├── docs/
│   └── deployment-strategy.md # Deployment strategy, SLA, and DoD
└── .github/
    └── workflows/
        └── cd.yml     # Continuous deployment pipeline
```

## API Endpoints

### Web Routes
- `GET /` - Home page with all recipes
- `GET /recipes/:id/` - Recipe detail page

### API Routes

#### Users
- `POST /api/user/create/` - Create a new user
- `GET /api/user/me/` - Get current user
- `PUT /api/user/me/` - Update current user
- `PATCH /api/user/me/` - Partial update current user
- `POST /api/user/token/` - Create user token (login)

#### Recipes
- `GET /api/recipe/recipes/` - List all recipes
- `POST /api/recipe/recipes/` - Create a new recipe
- `GET /api/recipe/recipes/:id/` - Get a specific recipe
- `PUT /api/recipe/recipes/:id/` - Update a recipe
- `PATCH /api/recipe/recipes/:id/` - Partial update a recipe
- `DELETE /api/recipe/recipes/:id/` - Delete a recipe
- `POST /api/recipe/recipes/:id/upload-image/` - Upload recipe image

#### Ingredients
- `GET /api/recipe/ingredients/` - List all ingredients
- `PUT /api/recipe/ingredients/:id/` - Update an ingredient
- `PATCH /api/recipe/ingredients/:id/` - Partial update an ingredient
- `DELETE /api/recipe/ingredients/:id/` - Delete an ingredient

#### Tags
- `GET /api/recipe/tags/` - List all tags
- `PUT /api/recipe/tags/:id/` - Update a tag
- `PATCH /api/recipe/tags/:id/` - Partial update a tag
- `DELETE /api/recipe/tags/:id/` - Delete a tag

## Database Schema

The application uses PostgreSQL with the following tables:
- `users` - User accounts
- `recipes` - Recipe information
- `ingredients` - Ingredient master list
- `tags` - Tag master list
- `recipe_ingredients` - Many-to-many relationship between recipes and ingredients
- `recipe_tags` - Many-to-many relationship between recipes and tags

## Development

The database is automatically set up when the production stack starts on the VM. If you need to refresh the deployment on the VM, restart the production stack:
```bash
docker compose -f docker-compose.prod.yaml down
docker compose -f docker-compose.prod.yaml up -d
```

## Database Configuration

The app uses PostgreSQL. These environment variables configure the connection:

- `DB_HOST` (default: `localhost`)
- `DB_PORT` (default: `5432`)
- `DB_NAME` (default: `recipe_cookbook`)
- `DB_USER` (default: `recipe_user`)
- `DB_PASSWORD` (default: `recipe_pass`)
- `DB_SSLMODE` (default: `prefer`)

Set `DB_INIT=true` to create the schema and seed the database on startup. Use it once for new databases and then remove it for shared environments.

## Migrating from SQLite to PostgreSQL

If you have existing SQLite data in `app.db`, migrate it into PostgreSQL with:

```bash
DB_HOST=localhost \
DB_PORT=5432 \
DB_NAME=recipe_cookbook \
DB_USER=recipe_user \
DB_PASSWORD=recipe_pass \
SQLITE_PATH=./app.db \
ruby db/migrate_sqlite_to_postgres.rb
```

If the Postgres database already contains data, set `PG_CLEAR=true` to truncate tables before migrating.

## Quality and Testing

- Test framework: RSpec + Rack::Test
- Linting: RuboCop
- CI quality pipeline: `.github/workflows/quality.yml`
- Shared Git hooks: `.githooks/pre-commit`

Run checks locally:

```bash
bundle exec rubocop
bundle exec rspec
```

Enable shared Git hooks for your clone:

```powershell
./scripts/setup-git-hooks.ps1
```

See [docs/software-quality.md](docs/software-quality.md) for the full quality workflow and standards.

## Deployment Strategy

Deployment is container-based: nginx receives public traffic on port 80 and proxies it to the Sinatra app on port 1010. The Azure VM setup script prepares the host for this compose stack, and the GitHub Actions workflow performs the build-and-deploy flow on `main`.

## SLA and Definition of Done

The service target for this educational deployment is 99.5% availability during the demo window, with a recovery target of 15 minutes for a failed release. A deployment is done only when the compose stack validates, nginx serves the application, and `/metrics` remains reachable for monitoring.

See [docs/deployment-strategy.md](docs/deployment-strategy.md) for the full rollout and rollback notes.

## License

This project is for educational purposes.
