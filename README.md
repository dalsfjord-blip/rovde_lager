# Rovde Lager

Rails-applikasjon for nettbrettbasert registrering og sesonglagring av kjøretøy og båter.

## Funksjoner

- PIN-beskyttet registrering av kunde, lagringsobjekter og hentedato.
- Registreringsnummer og oppslag mot Statens vegvesens kjøretøydata når API-nøkkel er konfigurert.
- Inntil ti bilder per avtale via Active Storage.
- Avtaletekst på e-post med HTML- og tekstversjon.
- Privatkunde betaler 700 kr per meter uten MVA via Vipps ePayment, eller får manuelt bekreftet kort-, kontant- eller Vippskrav-betaling.
- Bedriftskunde kan velge Vipps med 25 % MVA eller PDF-faktura.
- Brønnøysund-oppslag for bedriftsnavn og organisasjonsnummer.
- Vipps QR-panel på nettbrettet med automatisk lukking ved fullført, avbrutt eller feilet betaling.
- Signaturverifiserte Vipps-webhooks, idempotent capture og betaling først etter `CAPTURED`.
- PDF-faktura og PDF-kvittering med MVA-spesifikasjon. Kvittering for Vipps-betaling sendes bare etter bekreftet capture.

## Betalingsflyt

### Vipps

1. Avtalen lagres med status `payment_pending`.
2. Applikasjonen oppretter et Vipps ePayment-krav og viser betalingslenken som QR-kode.
3. `AUTHORIZED`-webhooken verifiseres mot Vipps og utløser et idempotent capture-kall.
4. Først ved signert `CAPTURED`-webhook settes avtalen til `paid`.
5. For bedriftskunder køes PDF-kvittering etter `CAPTURED`.

### Kort, kontant eller Vippskrav på stedet

For privatkunder kan medarbeideren velge **Kort/kontant/krav** etter å ha kontrollert at betalingen er mottatt via terminal, kontant eller Vippskrav. En bekreftelsesdialog må godkjennes før avtalen lagres med betalingsmetode `manual`, status `paid` og registrert betalingstidspunkt. Knappen er ikke tilgjengelig for bedriftskunder.

### Bedriftsfaktura

Bedriftskunde oppgir navn, organisasjonsnummer og faktura-e-post. Appen beregner 25 % MVA, sender PDF-faktura og lagrer avtalen med status `invoice_sent`. Betaling av faktura avstemmes foreløpig utenfor applikasjonen.

## Lokal oppstart

```bash
bin/rails db:prepare
bin/rails server
```

Åpne `http://localhost:3000`. PIN-koden er `1234` i utvikling når `TABLET_PASSCODE` ikke er satt.

Kopier `.env.example` til `.env.development` og fyll inn nødvendige verdier. Uten Vipps-konfigurasjon brukes lokal demobetaling. Lokale e-poster åpnes med Letter Opener, eller sendes via Resend når `USE_RESEND=true`.

## Konfigurasjon

### Vipps Sandbox

```text
VIPPS_CLIENT_ID
VIPPS_CLIENT_SECRET
VIPPS_SUBSCRIPTION_KEY
VIPPS_MERCHANT_SERIAL_NUMBER
VIPPS_WEBHOOK_SECRET
VIPPS_BASE_URL=https://apitest.vipps.no
APP_HOST=<offentlig-https-host>
```

`VIPPS_WEBHOOK_SECRET` mottas når webhooken registreres og skal aldri legges i git. Vipps webhook må registreres mot `<APP_HOST>/webhooks/vipps`.

### E-post

```text
RESEND_API_KEY
SMTP_FROM_EMAIL
INVOICE_FROM_EMAIL
USE_RESEND=true
```

Produksjon bruker Resend SMTP. Avsenderdomener må være verifisert før produksjonsbruk.

## Nummerering

- Referansenummer for nye avtaler følger `ROLAG-RE-10000` og øker fra en egen, transaksjonssikker nummerserie.
- Fakturanummer og betalingskvitteringer følger `10000-ROLAG` og øker fra en separat nummerserie.
- Eksisterende avtaler beholder nummeret de allerede har fått.

## Lagring og data

Bilder tilhører en avtale og lagres gjennom Active Storage. Registreringsnummer lagres på hvert lagringsobjekt, slik at en framtidig innlogget søkefunksjon kan finne avtale og bilder via registreringsnummer.

Lokal disk lagrer filer under `storage/`. Produksjon trenger varig objektlagring eller et korrekt montert og sikkerhetskopiert volum. Se [DEPLOYMENT.md](DEPLOYMENT.md) og [SQL.md](SQL.md).

## Veien videre

### Før produksjon

- Sett Vipps-produksjonsnøkler og en separat `VIPPS_WEBHOOK_SECRET` som Fly-secrets.
- Bruk fast offentlig HTTPS-domene og registrer produksjonswebhook.
- Verifiser Resend-domener for avtale- og faktura-e-post.
- Sett opp varig lagring og backup for opplastede bilder.
- Kjør ende-til-ende-test for Vipps, avbrudd, gjentatte webhooks og faktura.

### Fase 3, valgfri PowerOffice-integrasjon

PowerOffice er ikke integrert i dagens løsning. En senere fase kan omfatte:

1. Opprettelse av kunder og fakturaer i PowerOffice.
2. Synkronisering av faktura- og betalingsstatus.
3. Feilhåndtering, gjenkjøring og revisjonsspor for synkronisering.

Denne fasen må utformes mot gjeldende PowerOffice-API og bør ikke endre dagens manuelle fakturaflyt før synkronisering er robust og testet.

## Kvalitetssjekker

```bash
bin/rails test
bin/rails zeitwerk:check
bundle exec brakeman --no-pager
```

## Dokumentasjon

- [DEPLOYMENT.md](DEPLOYMENT.md), produksjonsoppsett og sikker drift.
- [SQL.md](SQL.md), databaseoversikt og driftsqueryer.
- [VIPPS_STATUS.md](VIPPS_STATUS.md), Vipps-sjekkliste for Sandbox og produksjon.
