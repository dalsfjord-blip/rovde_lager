# PowerOffice-driftsstatus

## Bekreftet i PowerOffice Go Demo

- OAuth 2.0 client credentials mot `POWEROFFICE_TOKEN_URL` fungerer og gir gyldig token.
- `POST /customers` oppretter kunde i Demo-miljøet (bekreftet med ekte kall mot testklienten "Rovde Industripark AS - API Test Client").
- `GET /customers`, `/products`, `/vatcodes`, `/generalledgeraccounts`, `/salesorders` fungerer for lesing.
- 25 % utgående MVA-kode i Demo-miljøet er `"3"` ("Utgående mva høy sats").

## Kjent blokkering: fakturautsending

Tilgangstokenet for testklienten inneholder claimet `"goAllowSendInvoice": "False"`. I praksis betyr dette at alle forsøk på å opprette eller sende fakturaer via API (`POST /salesorders`, `POST /OutgoingInvoice`, `POST /OutgoingInvoice/SendInvoice`, i alle store/små bokstav-varianter) svarer `404 Resource not found`, uansett om ressursen er dokumentert offentlig eller ikke. Dette gjelder også lesing av `/OutgoingInvoice/List`, så blokkeringen ser ut til å gjelde hele fakturaressursen, ikke bare selve utsendingen.

**Nødvendig handling:** Kontakt PowerOffice support/partneransvarlig og be om at fakturarettigheter (`OutgoingInvoice`/`SalesOrders`) aktiveres for testklienten "Rovde Industripark AS - API Test Client" i Go Demo. Produksjonsnøkler bør bestilles med fakturarettigheter inkludert fra start.

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
