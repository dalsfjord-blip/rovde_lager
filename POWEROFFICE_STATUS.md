# PowerOffice-driftsstatus

## Bekreftet i PowerOffice Go Demo

- OAuth 2.0 client credentials mot `POWEROFFICE_TOKEN_URL` fungerer og gir gyldig token.
- `POST /customers` oppretter kunde i Demo-miljøet (bekreftet med ekte kall mot testklienten "Rovde Industripark AS - API Test Client").
- `GET /customers`, `/products`, `/vatcodes`, `/generalledgeraccounts`, `/salesorders` fungerer for lesing.
- 25 % utgående MVA-kode i Demo-miljøet er `"3"` ("Utgående mva høy sats").

## Kjent blokkering: fakturautsending

Tilgangstokenet for testklienten inneholder claimet `"goAllowSendInvoice": "False"`. Presis diagnostisert oppførsel (bekreftet med ekte kall mot Demo-miljøet 2026-09-29):

| Kall | Resultat |
| --- | --- |
| `POST /customers` (opprette kunde) | Fungerer, `201`. |
| `PATCH /customers/{id}` (JSON Patch) | Fungerer, `200`. |
| `POST /products` (opprette produkt) | Fungerer, `201`. |
| `GET /salesorders`, `GET /salesorders/{id}` | Fungerer, `200`. |
| `PATCH /salesorders/{id}` (JSON Patch på eksisterende utkast) | Fungerer, `200`, men kun for felter som faktisk finnes i patch-skjemaet (f.eks. `CustomerId`). |
| `POST /salesorders` (opprette nytt utkast) | Blokkert, `404 Resource not found`. |
| `POST /salesorders/{id}/invoice` (fakturere et utkast) | Blokkert, `404 Resource not found`. |
| `PUT /salesorders/{id}` | Blokkert, `404 Resource not found`. |
| Offisiell `POST /OutgoingInvoice` / `POST /OutgoingInvoice/SendInvoice` (PascalCase, nyere API) | Blokkert, `404`, uansett store/små bokstaver. |

De blokkerte kallene returnerer et generisk gateway-svar (`{"statusCode":404,"message":"Resource not found"}`), mens ekte applikasjonsfeil (f.eks. ukjent ressurs-ID) returnerer et annet, mer beskrivende format (`"title":"Object(s) not found"`). Dette viser at blokkeringen skjer på API-abonnementnivå (Ocp-Apim), før forespørselen når selve PowerOffice-applikasjonen, ikke på grunn av feil i request-body eller feil path.

**Viktig funn: rollene i selve tokenet tillater skriving.** Access-tokenet ble dekodet og inneholder `role` claims med `SalesOrders_Full: true`, `OutgoingInvoice_Full: true` og `OutgoingInvoiceVoucher_Full: true`, altså har applikasjonen (styrt av `application_key`/`client_key`) offisielt lov til å skrive salgsordre og fakturaer. Samtidig står `goAllowSendInvoice: False` i samme token. Kombinasjonen av full skriverolle i JWT-et og generisk `404` fra gatewayen (ikke en `403 Forbidden` eller en rolle-spesifikk feil) peker mot at blokkeringen ligger på **abonnementsnøkkelnivå** (`Ocp-Apim-Subscription-Key`), ikke i applikasjonens roller. Sannsynligvis er `POWEROFFICE_SUBSCRIPTION_KEY` koblet til et begrenset API-produkt/abonnement i PowerOffice sin gateway som ikke eksponerer skriveoperasjonene for `SalesOrders`/`OutgoingInvoice`, uavhengig av at rollene tillater det.

**Konklusjon:** Testklienten kan opprette og oppdatere kunder og produkter, og kan lese/redigere eksisterende salgsordre-utkast, men kan ikke opprette nye salgsordrer/fakturaer eller sende dem via API. Dette henger sammen med `goAllowSendInvoice: False`, men ser ut til å være en begrensning på abonnementsnøkkelen/API-produktet, ikke bare et enkelt flagg som kan slås på.

**Nødvendig handling:** Kontakt PowerOffice support/partneransvarlig og be spesifikt om følgende, i prioritert rekkefølge:

1. Bekreft om `POWEROFFICE_SUBSCRIPTION_KEY` er knyttet til riktig API-produkt/abonnement med skrivetilgang for `SalesOrders` og `OutgoingInvoice`. Be om en ny/oppdatert subscription key hvis nåværende viser seg å være feilkonfigurert eller begrenset til lesetilgang.
2. Be dem verifisere at `goAllowSendInvoice` kan settes til `True` for klienten, selv om rollene i tokenet allerede sier `Full`.
3. Be om at `POST /salesorders`, `POST /salesorders/{id}/invoice` (eller de nyere `POST /OutgoingInvoice`-endepunktene) faktisk testes fra deres side før dere sender ny nøkkel tilbake.

Produksjonsnøkler bør bestilles med disse rettighetene bekreftet fra start, ikke som en driftsfeil å rette i etterkant.

## Nåværende oppførsel i appen

`PowerOfficeInvoiceSyncJob` kjøres automatisk for bedriftskunder etter at vår egen PDF-faktura er sendt (`InvoiceDeliveryJob`). Jobben:

1. Oppretter kunden i PowerOffice (`power_office_customer_id`).
2. Oppretter et fakturautkast (`power_office_sales_order_id`).
3. Sender fakturaen **bare** hvis `POWEROFFICE_INVOICE_SEND_ENABLED=true`. Standardverdien er `false` fordi steg 3 uansett vil feile til PowerOffice har aktivert rettigheten over.

Alle steg logges i `power_office_sync_logs` for revisjonsspor, og feil vises på avtalen via `power_office_sync_status`/`power_office_sync_error`.

## Lokal konfigurasjon

```text
POWEROFFICE_APPLICATION_KEY
POWEROFFICE_CLIENT_KEY
POWEROFFICE_SUBSCRIPTION_KEY
POWEROFFICE_TOKEN_URL=https://goapi.poweroffice.net/Demo/OAuth/Token
POWEROFFICE_BASE_URL=https://goapi.poweroffice.net/Demo/v2
POWEROFFICE_INVOICE_SEND_ENABLED=false
```

## Videre steg før produksjon

- [ ] Få PowerOffice til å aktivere fakturarettigheter for testklienten, og bekreft `POST /OutgoingInvoice` og `POST /OutgoingInvoice/SendInvoice` fungerer i Demo.
- [ ] Sett `POWEROFFICE_INVOICE_SEND_ENABLED=true` i test og verifiser én komplett bedriftsfaktura ende til ende i Go Demo.
- [ ] Avklar om PowerOffice skal erstatte vår egen PDF-faktura til kunden, eller kun speile bokføringen (se README, betalingsflyt).
- [ ] Bygg synkronisering av betalingsstatus. PowerOffice støtter ikke webhook, kun polling mot `GET /Reporting/CustomerLedger` filtrert på saldo/`balance last changed`.
- [ ] Be om egne produksjonsnøkler fra PowerOffice og sett dem som Fly-secrets, aldri i `.env`-filer eller git.

Se [README.md](README.md) for betalingsflyten og [DEPLOYMENT.md](DEPLOYMENT.md) for produksjonsoppsett.
