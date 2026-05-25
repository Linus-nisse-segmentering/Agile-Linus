# Beskrivelse

Denne PR tilføjer forbedringer til projektets DevOps- og kodekvalitetsopsætning. Der er konfigureret linting med RuboCop, automatiske quality checks via GitHub Actions samt standardiserede templates til Pull Requests og issues. Formålet er at forbedre kodekvalitet, automatisering og samarbejde i udviklingsprocessen.

## Type af ændring
- [ ] Bugfix (ikke-breaking change)
- [ ] Ny funktion (kan være breaking)
- [x] Forbedring / refaktorering
- [x] Dokumentation
- [x] Infrastruktur / opsætning

## Hvordan har du testet det?
1. Installerede dependencies lokalt med:
   ```bash
   bundle install

2. Kørte RuboCop linting:

3. bundle exec rubocop
Verificerede at GitHub Actions workflow kører korrekt ved push til repository.
4. Testede issue- og PR-templates ved oprettelse af nye issues og pull requests på GitHub.
Relaterede issues


## Tjekliste (forfatter)
 Koden bygger lokalt
 Nye/ændrede tests er tilføjet og kører
 Kode følger repositorys styleguides
 Eventuelle migrations er dokumenterede
 Ingen følsomme informationer eller hemmeligheder er tilføjet
## Tjekliste (reviewer)
 Ændringen er forståelig og velbeskrevet
 Der er ingen åbenlyse regressionsrisici
 Tests og/eller manuelt scenarie verificeret
## Deployment og Release notes

Der kræves ingen database-migrations eller nye miljøvariabler. GitHub Actions workflows aktiveres automatisk efter merge til main branch.

## Screenshots / eksempler
Eksempel på GitHub Actions workflow
name: Ruby CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  rubocop:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
      - run: bundle install
      - run: bundle exec rubocop