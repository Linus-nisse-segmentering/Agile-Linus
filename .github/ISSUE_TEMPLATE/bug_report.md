name: Bug report
about: Rapporter en fejl i applikationen
title: '[BUG] Login virker ikke efter deployment'
labels: bug
assignees: ''

## Beskrivelse
Brugere kan ikke logge ind i applikationen efter deployment til produktionsmiljøet. Login-knappen reagerer, men brugeren bliver ikke viderestillet til dashboardet.

## Trin til at reproducere
1. Gå til login-siden
2. Indtast gyldigt brugernavn og password
3. Klik på "Login"
4. Observer fejlen

## Forventet adfærd
Brugeren burde blive logget ind og viderestillet til dashboardet.

## Faktisk adfærd
Siden loader kortvarigt, men brugeren forbliver på login-siden uden fejlbesked.

## Miljø
- Version/commit: latest deployment
- Browser/OS: Google Chrome / Windows 11

## Yderligere information
Fejlen opstod efter seneste deployment. Konsollen viser muligvis en 500-fejl fra backend API'et ved login-request.