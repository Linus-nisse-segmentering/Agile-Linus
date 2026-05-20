# Branching-strategy

Dette dokument beskriver den branching-strategi holdet bør følge for dette projekt.

Grundprincipper
- `main`: Produktionklar kode. Protected branch — kun merges via Pull Requests.
- `develop` (valgfri): Integrationsbranch for igangværende arbejde (kan udelades for små teams).
- `feature/<navn>`: Bruges til ny funktionalitet eller opgaver. Oprettes fra `develop` eller `main` afhængig af workflow.
- `hotfix/<navn>`: Hurtige fixes til `main` for kritiske produktionsfejl.
- `release/<version>`: Forberede release — bruges hvis I ønsker en release-gennemgang.

Navngivning
- Feature branches: `feature/<kort-beskrivelse>` (fx `feature/add-prometheus-metrics`).
- Hotfix: `hotfix/<issue-nummer>-<kort-beskrivelse>`.

Pull request flow
1. Opret branch fra `develop` (eller `main` hvis I ikke bruger `develop`).
2. Arbejd lokalt, hold commits små og meningsfulde.
3. Åbn en Pull Request mod `develop` (eller `main`).
4. Tilknyt issue, vælg reviewers, og skriv en kort beskrivelse af ændringerne.
5. PR skal godkendes af mindst én reviewer og passere CI (lint/test) før merge.
6. Merge med `Squash and merge` for at holde `main` ren (eller `Merge commit` hvis I vil bevare historik).

Beskyttelsesregler for `main`
- Kræv mindst én godkendelse.
- Kræv CI-pipeline succes (lint + tests).
- Deaktiver direkte push til `main`.

Release og tag
- Når `main` er klar til release, opret et Git tag `v<major>.<minor>.<patch>` og deploy via pipeline.

Anbefalinger
- Hold branches korte-lived (max en til få dage) for nemmere review og mindre merge-konflikter.
- Brug Issues til at beskrive arbejde og link til PR'er.

Eksempel på simpel flow
`feature/x` -> PR -> merge til `develop` -> test -> merge `develop` -> `main` ved release.
