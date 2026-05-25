name: Feature request
about: Forslå en forbedring eller ny funktion
title: '[FEAT] Tilføj avanceret søgefunktion til opskrifter'
labels: enhancement
assignees: ''

## Beskrivelse
Tilføj en avanceret søgefunktion, så brugere kan filtrere opskrifter efter ingredienser, kategori, tilberedningstid og sværhedsgrad.

## Motivation
Det vil gøre det lettere for brugere hurtigt at finde relevante opskrifter og forbedre brugeroplevelsen i applikationen. I øjeblikket kan brugerne kun browse manuelt gennem opskrifterne, hvilket bliver upraktisk ved mange opskrifter.

## Forslag til løsning
Implementer filtre i frontend med dropdown-menuer og søgefelt. Backend API’et kan udvides med query-parametre som:
- `/recipes?ingredient=tomat`
- `/recipes?difficulty=easy`
- `/recipes?time<30`

## Eventuelle alternativer
Et alternativ kunne være kun at implementere tekstsøgning uden avancerede filtre for at holde løsningen mere simpel.

## Yderligere information
Funktionen kan designes med inspiration fra populære recipe-apps som f.eks. Mealime eller Tasty.