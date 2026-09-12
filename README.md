# Rovde Lager

Rails-applikasjon for registrering og sesonglagring av kjøretøy og båter.

## Status

Applikasjonen har nå en fungerende MVP-flyt:

1. Innlogging med PIN-kode
2. Registrering av ett eller flere lagringsobjekter
3. Beregning av total meter og pris
4. Kundeinformasjon og kontraktsgodkjenning
5. Valg av faktura eller simulert Vipps-betaling i utvikling
6. Kvittering med referansenummer

Aktiv avtale er knyttet til nettleserøkten. En bruker får derfor ikke tilgang til en annen brukers siste avtale.

## Starte lokalt

```bash
bin/rails db:prepare
bin/rails server
```

Åpne `http://localhost:3000`. På Mac kan kameraet testes i Chrome eller Safari ved å velge «Åpne kamera» og tillate kameratilgang.

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
- registrering, kundeinformasjon, faktura og kvittering fungerer sammen
- en økt får ikke tilgang til en annen økts avtale

## Kjente begrensninger

- Vipps er bare simulert i utviklings- og testmiljø.
- E-postsending er ikke implementert.
- Bilder lagres lokalt. Produksjon må bruke varig ekstern fillagring.
- Kjøretøyoppslag avhenger av ekstern API-konfigurasjon.
- Det bør ryddes i eksisterende whitespace-avvik før en streng lint-sjekk tas i bruk.

## Neste naturlige steg

1. Implementere reell Vipps-integrasjon.
2. Sende kontrakt og kvittering på e-post.
3. Aktivere og sikre bildeopplasting.
4. Legge til administrasjon og oversikt over avtaler.
5. Utvide testdekning for valideringsfeil og betalingsscenarier.
