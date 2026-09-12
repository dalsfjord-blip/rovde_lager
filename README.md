# Rovde Lager

Rails-applikasjon for registrering og sesonglagring av kjøretøy og båter.

## Status

Applikasjonen har nå en fungerende MVP-flyt:

1. Innlogging med PIN-kode
2. Én mobiltilpasset registrering av lagringsobjekt, kundeinfo og hentedato
3. Kamerabilder av lagringsobjektet, knyttet til den aktuelle avtalen
4. Scrollbar leiekontrakt som må leses før den kan godkjennes
5. Valg om avtaleteksten skal sendes på e-post
6. Valg av faktura eller simulert Vipps-betaling i utvikling
7. Kvittering med referansenummer

Aktiv avtale er knyttet til nettleserøkten. En bruker får derfor ikke tilgang til en annen brukers siste avtale.

## Starte lokalt

```bash
bin/rails db:prepare
bin/rails server
```

Åpne `http://localhost:3000`. På Mac kan kameraet testes i Chrome eller Safari ved å velge «Åpne kamera» og tillate kameratilgang. Kamera krever `localhost` eller HTTPS.

I utviklingsmiljøet er PIN-koden `1234`, dersom `TABLET_PASSCODE` ikke er satt. For å bruke en egen PIN:

```bash
TABLET_PASSCODE="din-pin" bin/rails server
```

## Tester og kvalitetssjekker

```bash
bin/rails test
bin/rails zeitwerk:check
bundle exec brakeman --no-pager
```

Bestillingsflyten er dekket av integrasjonstester i `test/integration/booking_flow_test.rb`:

- uautentiserte brukere sendes til innlogging
- samlet registrering lagrer objekt, kundeinfo, kontraktsgodkjenning og faktura
- kamerabilder lagres på den aktuelle avtalen
- kontraktsgodkjenning er obligatorisk før registreringen fullføres
- en økt får ikke tilgang til en annen økts avtale

## Kjente begrensninger

- Vipps er bare simulert i utviklings- og testmiljø.
- Avtaleteksten kan velges for e-post, men e-postsending er ikke implementert.
- Bilder tas direkte med kameraet og lagres lokalt. Produksjon må bruke varig ekstern fillagring.
- Kjøretøyoppslag avhenger av ekstern API-konfigurasjon.
- Det bør ryddes i eksisterende whitespace-avvik før en streng lint-sjekk tas i bruk.

## Neste naturlige steg

1. Implementere reell Vipps-integrasjon.
2. Sende valgt avtaletekst og kvittering på e-post.
3. Konfigurere varig og sikker fillagring for bilder i produksjon.
4. Legge til administrasjon og oversikt over avtaler.
5. Utvide testdekning for valideringsfeil og betalingsscenarier.
