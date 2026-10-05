# PowerOffice-driftsstatus

## ⚠️ PÅVENTE: avklaring med kunde om ønsket flyt (2026-10-05)

Fakturaen opprettes nå korrekt i PowerOffice (bekreftet i Demo-miljøet), men **sendes ikke ut** derfra ennå. Dette er bevisst satt på vent, ikke en feil som skal rettes nå.

Bakgrunn: Vi fjernet nylig vår egen PDF-faktura/kvittering (sendt fra `faktura@rovdeindustripark.app`) til fordel for at PowerOffice skulle sende alt (se seksjonen under). Ved nærmere ettertanke er det uklart om dette er ønsket for alle tilfeller, spesielt fordi:

- PowerOffice har ikke noe eget "kvittering for allerede betalt"-konsept i API-et, kun faktura/kreditnota. En bedriftskunde som betaler direkte med Vipps vil derfor få tilsendt en **ordinær faktura** fra PowerOffice (med egne betalingsbetingelser, f.eks. 14 dager), selv om beløpet allerede er betalt til oss. Dette kan virke forvirrende eller feil for kunden.
- Det er flere gode grunner til å beholde vårt eget system for utsending slik det var før (bedre kontroll på innhold/tidspunkt, kvittering vs. faktura skilles tydelig, osv.), og kanskje ikke la PowerOffice stå for *all* kundekommunikasjon i appen.

**Neste steg:** Avklare med kunde hva som er ønsket flyt for:
1. Bedriftskunder som betaler direkte med Vipps (kvittering, ikke faktura).
2. Bedriftskunder som velger faktura/betal senere (reell faktura).

Når dette er avklart, oppdateres koden deretter. Fram til da: `POWEROFFICE_INVOICE_SEND_ENABLED` kan stå som den er (fakturaen opprettes men sendes ikke automatisk ut fra PowerOffice med mindre dette flagget er `true` og `CreateAndSendInvoice` faktisk kalles), og ingen videre endringer gjøres på utsendingslogikken før avklaringen er på plass.

### 🔁 Husk å sjekke: manglende sende-rettighet hos PowerOffice

Med `POWEROFFICE_INVOICE_SEND_ENABLED=true` ble faktisk utsending testet i Demo (2026-10-05). Kunde og salgsordre ble opprettet korrekt, men `CreateAndSendInvoice`-kallet feilet med:

```
PowerOffice 400: {"title":"Missing privilege","status":400,
"detail":"The integration does not have the required privileges to send invoices."}
```

Dette bekrefter mistanken fra det opprinnelige `goAllowSendInvoice: False`-funnet: selve test-klienten/integrasjonen mangler fortsatt sende-rettigheten hos PowerOffice, uavhengig av at JWT-tokenets roller sier `Full`. Supportsvaret om feil endepunkter (se under) løste 404-gåten, men avdekket samtidig dette gjenværende, reelle problemet.

**Før `CreateAndSendInvoice` kan tas i bruk i praksis:**
- [ ] Kontakt PowerOffice support/partneransvarlig på nytt og be dem spesifikt aktivere sende-rettigheten (`AllowSendInvoice`/tilsvarende privilegium) for testklienten.
- [ ] Bekreft med `GET /ClientIntegrationInformation` (se `PowerOfficeClient#client_integration_information`) at `AllowSendInvoice` er `true` og at `InvalidPrivileges` er tom før man tester på nytt.
- [ ] Vent med å sette `POWEROFFICE_INVOICE_SEND_ENABLED=true` i noe annet enn lokal test før dette er bekreftet løst, uavhengig av hvilken flyt som velges i avklaringen med kunde over.

## Bekreftet i PowerOffice Go Demo

- OAuth 2.0 client credentials mot `POWEROFFICE_TOKEN_URL` fungerer og gir gyldig token.
- `POST /customers` oppretter kunde i Demo-miljøet (bekreftet med ekte kall mot testklienten "Rovde Industripark AS - API Test Client").
- `GET /customers`, `/products`, `/vatcodes`, `/generalledgeraccounts`, `/salesorders` fungerer for lesing.
- 25 % utgående MVA-kode i Demo-miljøet er `"3"` ("Utgående mva høy sats").

## Erstattet egen e-postfaktura med PowerOffice (2026-10-05)

Appen sendte tidligere sin egen PDF-faktura/kvittering til kunden fra `faktura@rovdeindustripark.app` (med cc til `rovdeindustri@faktura.poweroffice.net`, en e-post-basert "stakkars manns integrasjon" mot PowerOffice fra før den ekte API-integrasjonen var på plass). Dette er nå fjernet:

- `InvoiceMailer`, `app/views/invoice_mailer/*` og `InvoicePdf` er slettet. Ingen PDF genereres eller sendes fra appen lenger for faktura/kvittering til bedriftskunder.
- `InvoiceDeliveryJob` sender ikke lenger e-post. Den markerer kun avtalen (`invoice_sent_at`/`receipt_sent_at`, `payment_status`) og trigger `PowerOfficeInvoiceSyncJob`, uansett om det gjelder en faktura (`payment_method == "invoice"`) eller en kvittering for en bedriftskunde som har betalt direkte med Vipps.
- `POWEROFFICE_INVOICE_SEND_ENABLED` er satt til `true` i `.env.development` og `.env.example` slik at PowerOffice faktisk sender fakturaen/kvitteringen til kunden (`CreateAndSendInvoice`), siden vi ikke lenger har noen egen utsendingskanal som sikkerhetsnett.
- Ryddet bort ubrukte miljøvariabler `INVOICE_FROM_EMAIL` og `ACCOUNTING_EMAIL` fra `.env.example`.

**Viktig forbehold:** PowerOffice sitt API har ikke noe eget "kvittering for allerede betalt beløp"-konsept, kun faktura/kreditnota. For bedriftskunder som betaler direkte med Vipps, vil PowerOffice derfor opprette og sende en ordinær faktura med egne betalingsbetingelser (f.eks. 14 dager), uavhengig av at beløpet allerede er betalt til oss via Vipps. Dette må avstemmes manuelt eller håndteres i det planlagte arbeidet med betalingsstatus-synkronisering (se "Videre steg" under), inntil videre.

## Løst: feil endepunkter ble brukt for fakturautsending (2026-10-05)

Tidligere antok vi at blokkeringen (`404` på `POST /salesorders` og `POST /OutgoingInvoice/SendInvoice`) skyldtes `goAllowSendInvoice: False` eller en begrenset abonnementsnøkkel. PowerOffice-support avkreftet dette (se fullt svar nederst i filen): de endepunktene finnes rett og slett ikke i API v2. Rettighetene i tokenet (`SalesOrders_Full`, `OutgoingInvoice_Full`) er tilstrekkelige, og ingen egen innstilling må skrus på hos PowerOffice.

**Riktig flyt i API v2** (bekreftet mot offisiell Swagger-spesifikasjon, `https://swagger.poweroffice.net/openapispecs/salesorders.json`):

1. `POST /SalesOrders/Complete` — oppretter en komplett salgsordre (fakturautkast) med linjer i ett kall. Krever `SalesOrders_Full`. Linjene refererer et `ProductId`/`ProductCode` (ikke en direkte `VatCode`); mva bestemmes av hvilken salgskonto produktet er koblet til.
2. `POST /SalesOrders/{id}/CreateAndSendInvoice` — omdanner ordren til faktura og sender den. Body har `DeliveryType` (`Auto` anbefales, faller tilbake på PDF e-post), valgfri `EmailAddress`/`VoucherDate`/`OverrideDueDate`. Svarer **`202 Accepted`** — sendingen skjer asynkront hos PowerOffice (validering, PDF-generering, levering).
3. `GET /SalesOrders/SentState?id={id}` — polles til `SentDateTimeOffset` har verdi (sendt) eller `LastErrorMessage` har verdi (feilet). Anbefalt backoff-strategi fra PowerOffice: 1s, 4s, 10s, osv.
4. Fakturaen dukker deretter opp i `GET /OutgoingInvoices` (kun lesing i v2).

**Viktig om mva/produkt:** Et produkt i Go har ingen direkte `VatCode`-felt. I stedet peker produktet på en salgskonto (`StandardSalesAccountId`), og det er salgskontoen (`GET /GeneralLedgerAccounts`, felt `VatCode`) som bestemmer mva-satsen. Implementasjonen finner (eller oppretter) et produkt `"SESONGLAGRING"` koblet til en eksisterende salgskonto i intervallet 3000-3999 med `VatCode == "3"`.

**Diagnoseendepunkt uten rettighetskrav:** `GET /ClientIntegrationInformation` (kun gyldig token nødvendig) returnerer `AllowSendInvoice`, `ActiveClientSubscriptions`, `ValidPrivileges` og `InvalidPrivileges` for den aktuelle integrasjonen/klienten. Nyttig for å feilsøke `403`-feil uten å gjette, lagt til som `PowerOfficeClient#client_integration_information`.

## Implementert i appen

`app/services/power_office_client.rb` er omskrevet til å bruke v2-flyten over:

- `create_customer` — uendret (`POST /customers`).
- `ensure_service_product!` — finner eller oppretter tjenesteproduktet, koblet til riktig salgskonto (mva).
- `create_sales_order` — `POST /SalesOrders/Complete`.
- `create_and_send_invoice` — `POST /SalesOrders/{id}/CreateAndSendInvoice`.
- `sent_state` — `GET /SalesOrders/SentState`.
- `client_integration_information` — diagnostikk, `GET /ClientIntegrationInformation`.

To jobber samarbeider om synkroniseringen:

1. `PowerOfficeInvoiceSyncJob` kjøres automatisk for bedriftskunder etter at vår egen PDF-faktura er sendt (`InvoiceDeliveryJob`). Oppretter kunde (`power_office_customer_id`) og salgsordre/fakturautkast (`power_office_sales_order_id`). Sender fakturaen **bare** hvis `POWEROFFICE_INVOICE_SEND_ENABLED=true` (standard `false`). Ved sending settes status til `"sending"` og `PowerOfficeInvoiceSentStateJob` køes.
2. `PowerOfficeInvoiceSentStateJob` poller `GET /SalesOrders/SentState` med backoff (1s → 10 min, maks 8 forsøk) til fakturaen er bekreftet sendt (status `"synced"`, `power_office_invoice_number` satt) eller feilet (status `"failed"`).

Alle steg logges i `power_office_sync_logs`, og feil vises på avtalen via `power_office_sync_status`/`power_office_sync_error`.

**Ikke verifisert ende-til-ende ennå:** Endringen er bygget utelukkende fra den offisielle Swagger-spesifikasjonen og supportens beskrivelse, ikke fra et faktisk testkall (ingen tilgang til ekte Demo-credentials i denne arbeidsøkten). Feltnavn på `SalesOrderLines` (`ProductId`, `Quantity`, `ProductUnitPrice`) og selve produkt/salgskonto-oppslaget bør bekreftes med et ekte kall før `POWEROFFICE_INVOICE_SEND_ENABLED=true` settes i noe annet enn lokal test.

## Lokal konfigurasjon

```text
POWEROFFICE_APPLICATION_KEY
POWEROFFICE_CLIENT_KEY
POWEROFFICE_SUBSCRIPTION_KEY
POWEROFFICE_TOKEN_URL=https://goapi.poweroffice.net/Demo/OAuth/Token
POWEROFFICE_BASE_URL=https://goapi.poweroffice.net/Demo/v2
POWEROFFICE_INVOICE_SEND_ENABLED=true
```

## Videre steg før produksjon

- [ ] Kjør én komplett bedriftsregistrering i appen mot Demo (med ekte credentials) og bekreft at `ensure_service_product!`, `create_sales_order` og `create_and_send_invoice` fungerer som forventet. Rett opp eventuelle feltnavn som ikke stemmer med antakelsene over.
- [ ] Verifiser at `PowerOfficeInvoiceSentStateJob` faktisk fanger opp `SentDateTimeOffset` og at fakturaen dukker opp i GoDemo-portalen/`GET /OutgoingInvoices`, nå som `POWEROFFICE_INVOICE_SEND_ENABLED=true` er standard.
- [x] Avklart: PowerOffice erstatter vår egen PDF-faktura/kvittering helt. All kundekommunikasjon om faktura og kvittering går via PowerOffice sin `CreateAndSendInvoice`.
- [ ] Håndter at bedriftskunder som betaler direkte med Vipps likevel får en ordinær PowerOffice-faktura med egne betalingsbetingelser (se forbehold over) - avklar om dette skal krediteres/markeres betalt automatisk.
- [ ] Bygg synkronisering av betalingsstatus. PowerOffice støtter ikke webhook, kun polling mot `GET /Reporting/CustomerLedger` filtrert på saldo/`balance last changed`.
- [ ] Be om egne produksjonsnøkler fra PowerOffice og sett dem som Fly-secrets, aldri i `.env`-filer eller git.

Se [README.md](README.md) for betalingsflyten og [DEPLOYMENT.md](DEPLOYMENT.md) for produksjonsoppsett.

## Gjenoppta arbeidet i en ny sesjon

Alt arbeid ligger på branchen `power-office-integrasjon` (ikke rørt `main`/deploy-branchen).

1. Les denne filen (`POWEROFFICE_STATUS.md`) for full kontekst, ingen annen fil er nødvendig for å forstå status.
2. Relevante filer å gå videre med:
   - `app/services/power_office_client.rb`, klienten som snakker med PowerOffice (v2-flyt: `SalesOrders/Complete` → `CreateAndSendInvoice` → `SentState`).
   - `app/jobs/power_office_invoice_sync_job.rb`, oppretter kunde, produkt og salgsordre, og trigger sending når `POWEROFFICE_INVOICE_SEND_ENABLED=true`.
   - `app/jobs/power_office_invoice_sent_state_job.rb`, poller status på en sendt faktura og oppdaterer avtalen når den er bekreftet sendt eller feilet.
   - `test/services/power_office_client_test.rb`, `test/jobs/power_office_invoice_sync_job_test.rb`, `test/jobs/power_office_invoice_sent_state_job_test.rb`, eksisterende tester som må fortsatt være grønne.
3. Når ende-til-ende er bekreftet i Demo: fjern eventuelle midlertidige diagnostikk-skript, sett `POWEROFFICE_INVOICE_SEND_ENABLED=true` lokalt, kjør en komplett bedriftsregistrering i appen og bekreft i GoDemo-portalen at fakturautkastet blir en faktisk sendt faktura.
4. Oppdater denne filen med resultatet og fjern punktene under "Videre steg" etter hvert som de er løst.

## Historikk: svar fra PowerOffice-support (2026-10-05)

404-feilen skyldes ikke nøkkelen eller rettighetene – den kommer av at POST /SalesOrders ikke finnes som endepunkt i API v2. Manglende rettighet ville gitt 403, ikke 404, og siden kundeopprettelsen fungerer er både subscription key og token i orden.

Riktig flyt for ordre og faktura i v2:
Opprett ordren med linjer i ett kall: POST /SalesOrders/Complete – body er en komplett ordre (kunde, dato, betalingsbetingelse osv.) med SalesOrderLines som array. Krever SalesOrders_Full .
Fakturer og send: POST /SalesOrders/{id}/CreateAndSendInvoice med DeliveryType i body (og EmailAddress ved e-postutsendelse). Kallet svarer 202 Accepted, og Location -headeren peker til statusendepunktet.
Sjekk status: GET /SalesOrders/SentState?id={id} – fakturaen dukker deretter opp under GET /OutgoingInvoices .

Merk at /SalesOrders/{id}/invoice og POST /OutgoingInvoices heller ikke finnes – OutgoingInvoices er kun lesing i v2, og alle utgående fakturaer opprettes via salgsordre. Det er ingen egen innstilling vi må skru på for klienten i demo; rettighetene du allerede har i tokenet er tilstrekkelig.

Full spesifikasjon finner du i Swagger for Sales Orders.
