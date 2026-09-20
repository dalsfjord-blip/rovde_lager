# Rovde Lager

Rails-applikasjon for registrering og sesonglagring av kjøretøy og båter.

## Status

Applikasjonen har en mobiltilpasset registreringsflyt med:

1. Innlogging med PIN-kode.
2. Registrering av lagringsobjekter, kundeinformasjon og hentedato.
3. Kamerabilder knyttet til den aktuelle avtalen.
4. Leiekontrakt som må leses og godkjennes.
5. Valgfri e-postkopi av avtaleteksten.
6. Privatkundebetaling med Vipps.
7. Bedriftsfaktura med PowerOffice-klargjøring.
8. Kvittering med referansenummer og betalingsstatus.

Aktiv avtale er knyttet til nettleserøkten. En bruker får derfor ikke tilgang til en annen brukers siste avtale.

## Betalingsflyt

### Privatkunde

Privatkunder velger **Vipps**. Avtalen lagres med betalingsmetoden `vipps`. Vipps er foreløpig simulert i utviklings- og testmiljø.

### Bedriftskunde

Bedriftskunder velger **Faktura for bedrift**. Dette åpner et skjema for:

- bedriftsnavn
- organisasjonsnummer

Faktura kan bare velges når begge feltene er oppgitt. Organisasjonsnummer normaliseres til sifre og må bestå av ni sifre. Avtalen lagres med betalingsmetoden `invoice`, betalingsstatus `pending` og fakturasynkroniseringsstatus `queued`.

Ved lagring køsettes `CreatePowerOfficeInvoiceJob`. Jobben er idempotent, slik at en avtale med registrert PowerOffice-faktura ikke skal behandles på nytt.

## PowerOffice-oppsett

`PowerOfficeClient` er klargjort for PowerOffice-credentials i Rails credentials:

```yaml
power_office:
  subscription_key: ""
  application_key: ""
  client_key: ""
```

Legg inn nøklene når demo-tilgang er mottatt:

```bash
bin/rails credentials:edit
```

Nøklene skal aldri lagres i kildekoden, databasen eller logger. Før faktura kan opprettes hos PowerOffice må autentiseringsflyt, API-adresser, nødvendige headere, produkt, MVA-kode og fakturaendepunkter verifiseres i PowerOffice sitt demomiljø.

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
- privatkunde kan fullføre med Vipps
- bedriftsfaktura krever bedriftsnavn og gyldig organisasjonsnummer
- bedriftsfaktura lagrer fakturagrunnlag og køsetter fakturajobb
- kamerabilder lagres på den aktuelle avtalen
- kontraktsgodkjenning er obligatorisk før registreringen fullføres
- en økt får ikke tilgang til en annen økts avtale

## Kjente begrensninger

- Vipps er bare simulert i utviklings- og testmiljø.
- PowerOffice-jobben markerer fakturaen som klar for synkronisering, men oppretter foreløpig ikke kunde, salgsordre eller faktura via API-et.
- Avtaleteksten kan velges for e-post, men e-postsending er ikke implementert.
- Bilder tas direkte med kameraet og lagres lokalt. Produksjon må bruke varig ekstern fillagring.
- Kjøretøyoppslag avhenger av ekstern API-konfigurasjon.

## Neste naturlige steg

1. Verifisere PowerOffice-integrasjonen i demomiljøet og implementere kunde-, salgsordre- og fakturaopprettelse.
2. Implementere reell Vipps-integrasjon for privatkunder.
3. Sende valgt avtaletekst og kvittering på e-post.
4. Konfigurere varig og sikker fillagring for bilder i produksjon.
5. Legge til administrasjon og oversikt over avtaler og fakturasynkronisering.
