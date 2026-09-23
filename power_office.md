# PowerOffice Go Demo, bedriftsfaktura

## Formål

Denne branchen brukes til å teste opprettelse og utsending av fakturaer for bedriftskunder direkte i PowerOffice Go Demo. Når brukeren velger **Faktura** og fullfører registreringen, oppretter appen kunden, oppretter en salgsordre og fakturerer ordren i PowerOffice.

Dette er en separat testflyt fra arbeidsflyten i `ARBEIDSFLYT.md`. Den erstatter ikke Vipps-flyten for privatkunder og skal ikke endre den.

## Avgrensning

Første versjon gjelder kun bedriftskunder og bruker:

- organisasjonsnummer
- bedriftsnavn
- e-postadresse
- samlet pris inkludert 25 % MVA

Produkt-ID er ikke nødvendig i demo-integrasjonen når fakturalinjen har beskrivelse og MVA-kode.

## Brønnøysundregistrene, bedriftsoppslag

Brønnøysundregistrene (Brreg) brukes til å hjelpe brukeren med å fylle inn bedriftsnavn og organisasjonsnummer før dataene sendes til PowerOffice. API-et er åpent, gratis og krever ingen API-nøkler.

### Søk og autofullfør

Når brukeren skriver bedriftsnavn, gjør appen et debouncet oppslag mot:

```text
GET https://data.brreg.no/enhetsregisteret/api/enheter?navn={søkeord}
```

Responsen inneholder en liste med matchende enheter. Brukeren velger et treff, og appen fyller inn bedriftsnavn og organisasjonsnummer. Feltene kan fortsatt redigeres manuelt.

### Direkte oppslag på organisasjonsnummer

Når organisasjonsnummeret er valgt eller skrevet inn, henter appen detaljer fra:

```text
GET https://data.brreg.no/enhetsregisteret/api/enheter/{organisasjonsnummer}
```

Responsen brukes til å bekrefte og fylle inn tilgjengelige bedriftsdetaljer, som navn, organisasjonsnummer og adresse. Organisasjonsnummeret normaliseres til ni sifre uten mellomrom og valideres fortsatt lokalt før avtalen opprettes.

`BrregClient` skal ha korte tidsavbrudd, cache vellykkede oppslag og håndtere utilgjengelig API uten å blokkere manuell utfylling eller fakturering. Data fra Brreg er et utfyllingshjelpemiddel, ikke eneste valideringsgrunnlag.

## Testmiljø

| Innstilling | Verdi |
| --- | --- |
| GUI | `https://godemo.poweroffice.net/` |
| Token-URL | `https://goapi.poweroffice.net/Demo/OAuth/Token` |
| API-base-URL | `https://goapi.poweroffice.net/demo/v2` |
| Testklient | Rovde Industripark AS - API Test Client |
| Application Key | `99a2cea5-68dc-4916-b9ad-09b6d623cbba` |
| Client Key | `b02b1c2b-c078-4b7e-8f01-463e668713f1` |
| Subscription Key | `bb5d7209946f429fa5dadef8652178e4` |

Nøklene over er kun for PowerOffice Go Demo. Produksjonsnøkler skal lagres i Rails credentials eller sikre miljøvariabler, aldri i kode eller database.

## Autentisering

Tilgangstoken hentes fra token-URL-en med `POST` og `grant_type=client_credentials`.

Forespørselen skal ha disse headerne:

```text
Authorization: Basic Base64(application_key:client_key)
Ocp-Apim-Subscription-Key: <subscription_key>
```

API-kall bruker tokenet og abonnementnøkkelen:

```text
Authorization: Bearer <access_token>
Ocp-Apim-Subscription-Key: <subscription_key>
```

Tokenet caches i `Rails.cache` og fornyes kort tid før utløp. Nøkler, token og komplette API-responser skal ikke logges.

## API-kontrakter

### Opprett kunde

Opprett kunden med:

```text
POST /v2/customers
```

Request body inneholder minst:

```json
{
  "Name": "Bedriftsnavn AS",
  "LegalNumber": "987654321",
  "EmailAddress": "faktura@bedrift.no"
}
```

Bruk kunde-ID-en fra responsen som `CustomerId` ved opprettelse av salgsordre.

### Opprett salgsordre

Opprett et utkast med:

```text
POST /v2/salesorders
```

Request body inneholder `CustomerId` og `SalesOrderLines`. Hver linje må minst ha:

- `Description`
- `Quantity`
- `UnitPrice`, netto pris ekskludert MVA
- `VatCode: "3"`, 25 % utgående MVA

Eksempel med én samlet linje:

```json
{
  "CustomerId": 12345,
  "SalesOrderLines": [
    {
      "Description": "Sesonglagring",
      "Quantity": 1,
      "UnitPrice": 8000.0,
      "VatCode": "3"
    }
  ]
}
```

Produkt-ID er valgfritt når `Description` og `VatCode` sendes. Ta vare på ordre-ID-en fra responsen.

### Fakturer salgsordren

Bokfør og send fakturaen med:

```text
POST /v2/salesorders/{id}/invoice
```

`{id}` erstattes med ordre-ID-en fra salgsordren. Responsen brukes til å lagre faktura-ID og fakturanummer når disse er tilgjengelige.

## Arbeidsflyt

1. Brukeren registrerer ett eller flere lagringsobjekter.
2. Brukeren velger **Faktura**.
3. Brukeren søker etter bedriftsnavn via Brreg, eller skriver inn bedriftsnavn og organisasjonsnummer manuelt.
4. Et valgt søkeresultat fyller inn bedriftsnavn og organisasjonsnummer. Et direkte Brreg-oppslag bekrefter tilgjengelige bedriftsdetaljer.
5. Skjemaet krever bedriftsnavn, organisasjonsnummer og e-postadresse for faktura.
6. Organisasjonsnummeret normaliseres til ni sifre uten mellomrom og valideres.
7. Appen beregner samlet pris inkludert 25 % MVA.
8. Når brukeren fullfører registreringen, lagres avtalen lokalt med fakturastatus `queued`.
9. En bakgrunnsjobb henter et tilgangstoken fra PowerOffice.
10. Jobben oppretter kunden i PowerOffice med bedriftsnavn, organisasjonsnummer og e-postadresse.
11. Jobben regner om bruttobeløpet til nettobeløp: `beløp_inkl_mva / 1.25`.
12. Jobben oppretter en salgsordre med én samlet linje, `Quantity: 1`, beskrivelse, nettobeløp og `VatCode: "3"`.
13. Jobben fakturerer salgsordren med ordre-ID-en.
14. Ved suksess lagres PowerOffice-ID-er, fakturanummer og tidspunkt. Ved feil markeres synkroniseringen som feilet uten å vise tekniske detaljer til kunden.

Vipps-flyten for privatkunder forblir uendret.

## Datamodell

`RentalAgreement` trenger felter for bedriftsfakturering og synkroniseringsstatus:

- `customer_type`, med verdien `business`
- `billing_name`
- `billing_organization_number`
- `billing_email`
- `vat_amount`
- `total_price_with_vat`
- `power_office_customer_id`
- `power_office_sales_order_id`
- `power_office_invoice_id`
- `power_office_invoice_number`
- `invoice_sync_status`, for eksempel `queued`, `processing`, `sent` eller `failed`
- `invoice_sync_error`
- `invoice_synced_at`

Eksisterende `reference_number` brukes som intern sporingsreferanse. Den skal lagres sammen med PowerOffice-dataene og brukes for å hindre doble fakturaer ved gjenkjøring.

## Implementeringsplan

1. Legg inn demo-nøklene i lokale Rails credentials eller utviklingsmiljøvariabler, og konfigurer token- og API-URL-er.
2. Implementer `BrregClient` for søk på navn og direkte oppslag på organisasjonsnummer, med tidsavbrudd, caching og trygg feilhåndtering.
3. Legg til Brreg-autofullfør i fakturadialogen, med manuelt redigerbare felt for bedriftsnavn og organisasjonsnummer.
4. Legg til migrering for bedriftsfelter, MVA-beløp, bruttobeløp og PowerOffice-synkronisering på `RentalAgreement`.
5. Legg til modellvalideringer for bedriftsnavn, e-post og normalisert organisasjonsnummer på ni sifre når faktura er valgt.
6. Oppdater fakturadialogen slik at den bare støtter bedriftskunde i denne testbranchen og samler inn påkrevde fakturaopplysninger.
7. Beregn og vis pris ekskludert MVA, MVA-beløp og pris inkludert MVA i registreringsflyten.
8. Implementer `PowerOfficeClient` med Faraday, token-cache og strukturerte feilresultater.
9. Implementer kundeopprettelse med `POST /v2/customers`.
10. Implementer salgsordre med én samlet fakturalinje via `POST /v2/salesorders`.
11. Implementer fakturering via `POST /v2/salesorders/{id}/invoice`.
12. Implementer `CreatePowerOfficeInvoiceJob` med låsing, idempotens og begrenset retry for midlertidige feil.
13. Køsett jobben etter at avtalen er lagret ved fakturavalg.
14. Oppdater kvitteringen med statusene planlagt, behandles, sendt og feilet, inkludert fakturanummer når tilgjengelig.
15. Legg til automatiske tester med stubbet HTTP og gjennomfør deretter manuelle testfakturaer mot PowerOffice Go Demo.

## Implementert 23. september 2026

- Demo-nøklene er lagt lokalt i `.env.development` som `POWER_OFFICE_SUBSCRIPTION_KEY`, `POWER_OFFICE_APPLICATION_KEY` og `POWER_OFFICE_CLIENT_KEY`. OAuth-token er verifisert hentet fra demo-miljøet.
- `BrregClient` søker på navn og slår opp organisasjonsnummer med korte tidsavbrudd og cache. API-feil returnerer tomt resultat slik at manuell utfylling fortsatt virker.
- Fakturaskjemaet har søk/autofullfør for bedriftsnavn, direkte oppslag på organisasjonsnummer og obligatorisk faktura-e-post.
- `RentalAgreement` lagrer faktura-e-post, MVA-beløp og totalpris inkludert MVA. Totalpris i registreringen behandles som bruttopris; PowerOffice-ordre bruker netto pris (`bruttobeløp / 1.25`).
- `PowerOfficeClient` henter og cacher OAuth-token, oppretter kunde, salgsordre med én linje og `VatCode: "3"`, og fakturerer salgsordren.
- `CreatePowerOfficeInvoiceJob` lagrer hvert vellykkede PowerOffice-resultat før neste API-kall, unngår allerede fakturerte avtaler, setter synkroniseringsstatus og prøver nettverksfeil på nytt opptil tre ganger.
- Første manuelle demoforsøk opprettet kunde med PowerOffice-ID `28088156`, men feilet før salgsordre og faktura. Den tidligere transaksjonen rullet tilbake lokal lagring av kunde-ID-en. Dette er rettet: kunde-ID og senere ordre-ID blir nå varig lagret etter hvert vellykkede kall, slik at en ny kjøring fortsetter fra neste steg og ikke oppretter duplikatkunde.
- Ved en ikke-retrybar PowerOffice-feil lagres nå HTTP-status og avkortet respons i `invoice_sync_error`, for eksempel `PowerOffice 400: ...`. Bruk denne teksten ved videre feilsøking av salgsordre- eller fakturaendepunktet.
- Kvitteringen viser planlagt, behandles, sendt med fakturanummer eller feilet. Bekreftelses-e-posten sendes fortsatt ved fullført registrering.
- Automatiske tester dekker Brreg-responser/feil, PowerOffice OAuth og API-flyt, e-post og registreringsflyten. `bin/rails test`, `bin/rails zeitwerk:check` og `bundle exec brakeman --no-pager` bestod ved implementeringstidspunktet.

## Gjenstående manuell demotest

1. Start appen med `.env.development` lastet og fullfør en registrering med **Faktura for bedrift**.
2. Velg eller skriv inn bedriftsnavn, organisasjonsnummer og faktura-e-post.
3. Kontroller at bakgrunnsjobben går fra `queued` til `sent` og at fakturanummer vises på kvitteringen.
4. Bekreft i PowerOffice Go Demo at kunde, salgsordre og faktura er opprettet med korrekt navn, organisasjonsnummer, e-post, nettobeløp og 25 % MVA.
5. Ved API-valideringsfeil, behold aktuell responsstatus og responsformat før klienten justeres. Ikke skriv token, nøkler eller fullstendige API-responser til logg.

## Tester

Automatiske tester stubber HTTP-kall for Brreg og PowerOffice. Ende-til-ende-testing gjøres manuelt i PowerOffice Go Demo.

## Videre mot produksjon

Når demo-integrasjonen er stabil, kan PowerOffice kontrollere loggene og sende søknadsskjema for produksjonstilgang. En administrator hos Rovde Industripark legger deretter til integrasjonen som en egendefinert utvidelse i PowerOffice Go og mottar produksjonens klientnøkkel.

Før produksjon må produkt, konto, MVA-oppsett, fakturatekst, betalingsfrist, leveringsmetode og håndtering av krediteringer avklares med regnskapsfører.
