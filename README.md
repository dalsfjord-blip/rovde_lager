# Rovde Lager

Rails-applikasjon for nettbrettbasert registrering og sesonglagring av kjøretøy og båter.

## Betalingsflyt

### Vipps

Betjeningen registrerer kunden og velger **Betal med Vipps**. Avtalen lagres først med status `payment_pending`. Applikasjonen oppretter deretter en Vipps ePayment-betaling og viser betalingslenken som en QR-kode på nettbrettet. Vipps webhook verifiserer betalingen mot Vipps før avtalen settes til `paid`.

### Bedriftsfaktura

Bedrifter velger **Send faktura** og oppgir bedriftsnavn, organisasjonsnummer og faktura-e-post. Applikasjonen oppretter en faktura med MVA-spesifikasjon og betalingsfrist, og sender PDF-en til kunden med BCC til regnskapsadressen. Fakturaen lagres med status `invoice_sent`; innbetaling avstemmes utenfor applikasjonen i denne fasen.

Brønnøysundregistrene brukes til oppslag av bedriftsnavn og organisasjonsnummer. Det finnes ingen PowerOffice API-integrasjon i denne grenen.

## Starte lokalt

```bash
bin/rails db:prepare
bin/rails server
```

Åpne `http://localhost:3000`. I utviklingsmiljøet er PIN-koden `1234` dersom `TABLET_PASSCODE` ikke er satt.

## Tester og kvalitetssjekker

```bash
bin/rails test
bin/rails zeitwerk:check
bundle exec brakeman --no-pager
```
