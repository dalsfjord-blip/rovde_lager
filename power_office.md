# Plan for PowerOffice Go-fakturering

## Mål

Når kunden velger **Faktura** i registreringsflyten, skal Rovde Lager opprette og sende en faktura gjennom PowerOffice Go. Løsningen skal støtte både privatkunder og bedriftskunder, og statusen i appen skal vise om fakturaen faktisk er opprettet.

Vipps-flyten skal ikke endres av denne integrasjonen.

## Dagens utgangspunkt

Applikasjonen er en Rails-app der registrering, kundeinformasjon, kontrakt og betalingsvalg samles i ett skjema. Faktura-knappen setter i dag:

- `payment_method` til `invoice`
- `payment_status` til `pending`
- avtalen lagres med kundeinformasjon, lagringsobjekter, total meter og totalpris

Det opprettes foreløpig ingen ordre eller faktura i et eksternt regnskapssystem. Teksten som sier at faktura er opprettet må derfor erstattes når integrasjonen innføres, slik at den beskriver faktisk synkroniseringsstatus.

## Kundeopplevelse

### Faktura-knappen

Når brukeren trykker **Faktura**, skal det vises en liten, mobiltilpasset dialog i registreringsskjemaet. Dialogen samler opplysninger som trengs for fakturering før brukeren kan fullføre registreringen.

Dialogen har to valg:

1. **Privatkunde**
2. **Bedrift**

Valget lagres på avtalen som kundetype.

### Privatkunde

Følgende opplysninger skal være tilgjengelige og valideres før innsending:

- navn
- e-postadresse for faktura
- telefonnummer
- fakturaadresse
- postnummer
- poststed

Navn, e-post og telefon finnes allerede i registreringsflyten. Fakturaadresse, postnummer og poststed må legges til.

### Bedrift

Ved valg av bedrift skal dialogen i tillegg vise:

- firmanavn
- organisasjonsnummer
- kontaktperson
- e-postadresse for faktura
- telefonnummer
- fakturaadresse
- postnummer
- poststed
- EHF-referanse, valgfritt

Organisasjonsnummer normaliseres til ni sifre uten mellomrom og valideres før avtalen sendes. Firmanavn og fakturaadresse er obligatoriske for bedriftsfaktura.

EHF-referanse lagres selv om første versjon sender faktura på e-post. Den gjør løsningen klar for EHF dersom PowerOffice-oppsettet og kunden støtter det.

### Flyt i skjemaet

1. Kunden fyller inn registrerings- og kontaktinformasjon som i dag.
2. Kunden trykker **Faktura**.
3. Dialogen åpnes og kunden velger privatkunde eller bedrift.
4. Kunden fyller inn manglende fakturaopplysninger.
5. Dialogen bekreftes, `payment_method` settes til `invoice`, og betalingsvalget vises tydelig i skjemaet.
6. Kunden godkjenner kontrakten og trykker **Fullfør registrering**.
7. Avtalen lagres, deretter køsettes opprettelse av faktura hos PowerOffice.
8. Kvitteringen viser at faktura behandles, eller at faktura er sendt når synkroniseringen er bekreftet.

Brukeren skal kunne lukke dialogen uten å velge faktura. Da beholdes tidligere betalingsvalg.

## Datamodell

`RentalAgreement` utvides med felter for fakturagrunnlag og PowerOffice-synkronisering:

- `customer_type`, for eksempel `private` eller `business`
- `billing_name`
- `billing_contact_name`
- `billing_organization_number`
- `billing_email`
- `billing_phone`
- `billing_address`
- `billing_postal_code`
- `billing_city`
- `billing_ehf_reference`
- `power_office_customer_id`
- `power_office_sales_order_id`
- `power_office_invoice_id`
- `power_office_invoice_number`
- `invoice_sync_status`, for eksempel `queued`, `processing`, `sent` eller `failed`
- `invoice_sync_error`
- `invoice_synced_at`

Eksisterende `reference_number` brukes som appens sporingsreferanse. Den skal sendes til PowerOffice som ekstern referanse og brukes for å unngå at samme avtale faktureres flere ganger ved gjenkjøring.

Kundeopplysningene som i dag ligger i `customer_name`, `customer_email` og `customer_phone` beholdes for kontakt og kontrakt. Fakturafeltene brukes som den autoritative kilden når faktura opprettes.

## PowerOffice Go-integrasjon

### Tilgang og konfigurasjon

Rovde Lager trenger sin egen utviklerkonto og en registrert applikasjon hos PowerOffice. Regnskapsføreren eller kunden gir deretter applikasjonen tilgang til PowerOffice-klienten som skal fakturere.

For én intern PowerOffice-klient kan integrasjonen normalt aktiveres manuelt som en egendefinert utvidelse. Hvis løsningen senere skal kobles mot flere regnskapsklienter, brukes PowerOffice sin onboarding-flyt.

Hemmeligheter lagres kun i Rails credentials eller sikre produksjonsmiljøvariabler, aldri i kode eller databasen:

- applikasjonsnøkkel
- klientnøkkel eller tilsvarende klienttilgang
- abonnementnøkkel
- klienthemmelighet, dersom PowerOffice krever den
- API- og identitetsserver-URL-er

Nøyaktig OAuth-flyt, URL-er, API-versjon, rettigheter, obligatoriske felt, MVA-koder og regler for utsending må verifiseres mot PowerOffice sin offisielle dokumentasjon og demo-klient før produksjonssetting.

### Rails-tjeneste

Opprett `PowerOfficeClient` i `app/services`, etter samme mønster som `VippsClient`.

Tjenesten skal:

1. hente tilgangstoken og cache det i `Rails.cache` til kort tid før utløp
2. sette riktige autentiserings- og abonnementheadere
3. finne eksisterende kunde hos PowerOffice
4. opprette kunde når den ikke finnes
5. opprette salgsordre med avtale- og linjedata
6. fakturere salgsordren og sende den med kundens fakturainnstilling
7. returnere strukturerte resultater eller meningsfulle feil til jobben

Faraday er allerede installert og skal brukes for HTTP-kall. API-nøkler og komplette responsdata skal ikke logges.

### Kundeoppslag og opprettelse

For bedriftskunder søkes det først på normalisert organisasjonsnummer. Hvis kunden finnes, lagres og gjenbrukes PowerOffice-kunde-ID-en.

For privatkunder brukes en stabil og dokumentert kombinasjon av tilgjengelige kundeopplysninger, for eksempel e-postadresse sammen med navn, dersom PowerOffice API-et støtter det. Hvis ingen trygg unik identifikator finnes, opprettes kunden én gang og den mottatte kunde-ID-en lagres på avtalen.

Hvis kunde ikke finnes, opprettes den med korrekt navn, adresse, e-post, telefon og leveringsinnstilling. Bedriftsopplysninger og EHF-referanse inkluderes der API-et støtter det.

### Ordrelinjer

Første versjon bør opprette én linje per `StorageItem`:

- beskrivelse: registreringsnummer eller beskrivelse av lagringsobjektet
- antall: objektets antall meter
- enhetspris: 700 kroner per meter
- linjens referanse: avtalens referansenummer

Alternativt kan regnskapsfører foretrekke én samlet linje, for eksempel «Sesonglagring», med total meter og totalpris. Dette besluttes sammen med regnskapsfører før produksjon, slik at produkt, konto og MVA behandles korrekt.

Produkt-ID, MVA-kode og eventuell kostnadsbærer konfigureres fra PowerOffice. De skal ikke hardkodes før de er avklart med regnskapsfører.

### Fakturering

Når salgsordren er opprettet, sendes den til PowerOffice sitt dokumenterte faktureringsendepunkt. PowerOffice tildeler fakturanummer, bokfører i henhold til kundens oppsett og sender faktura med valgt leveringsmetode.

Appen lagrer PowerOffice sine ordre-, faktura- og fakturanummer-ID-er. Kvitteringen viser deretter om fakturaen behandles, er sendt eller krever oppfølging.

## Bakgrunnsjobb og status

Fakturaopprettelse skal gå i en Active Job, ikke direkte i nettforespørselen. Applikasjonen har allerede Solid Queue tilgjengelig.

Foreslått jobb: `CreatePowerOfficeInvoiceJob`.

Ved fakturavalg:

1. Avtalen lagres lokalt med `payment_method: invoice`.
2. `payment_status` settes til `pending`.
3. `invoice_sync_status` settes til `queued`.
4. Jobben køsettes med avtale-ID.
5. Kvitteringen vises umiddelbart med teksten «Faktura behandles».

Jobben skal låse eller kontrollere avtalen før opprettelse, slik at den ikke sender dobbel faktura. Den skal også kontrollere om PowerOffice-faktura allerede er lagret før den gjør nye kall.

Ved vellykket synkronisering:

- `invoice_sync_status` settes til `sent`
- faktura-ID og fakturanummer lagres
- `invoice_synced_at` settes
- eventuell tidligere feiltekst fjernes

Ved feil:

- `invoice_sync_status` settes til `failed`
- en trygg, forståelig feilmelding lagres i `invoice_sync_error`
- tekniske detaljer logges uten nøkler eller unødvendige personopplysninger
- jobben kan prøves på nytt for midlertidige nettverks- og serverfeil

En valideringsfeil fra PowerOffice, som manglende adresse, ugyldig e-post eller sperret kunde, skal ikke automatisk repetere ubegrenset. Den må være synlig for administrasjon og kunne rettes før manuell gjenkjøring.

## Brukergrensesnitt og administrasjon

Registreringssiden oppdateres i `app/views/storage_items/index.html.erb` med dialogen for fakturaopplysninger.

Kvitteringen oppdateres slik at den skiller mellom:

- faktura er planlagt
- faktura behandles
- faktura er sendt, med fakturanummer når det finnes
- faktura kunne ikke opprettes

Det bør opprettes en enkel administrasjonsside for avtaler med fakturastatus. Den skal vise referansenummer, kunde, PowerOffice-fakturanummer, synkstatus og en kontrollert handling for å prøve mislykket synkronisering på nytt.

Kunden skal ikke få tekniske API-feil vist i registreringsskjemaet.

## Implementeringsrekkefølge

1. Avklar PowerOffice API-tilgang, demo-klient, autentisering, produkt, MVA og fakturaoppsett med regnskapsfører.
2. Legg til databasemigrering og modellvalideringer for fakturaopplysninger og synkstatus.
3. Implementer fakturadialogen med privatkunde og bedrift, inkludert mobilvisning og klient-/servervalidering.
4. Oppdater registreringsflyten slik at fakturaopplysninger lagres sammen med avtalen.
5. Implementer `PowerOfficeClient` med token-cache, kundeoppslag, kundeopprettelse, ordre og fakturering.
6. Implementer `CreatePowerOfficeInvoiceJob` med idempotens, feilhåndtering og sikker gjenkjøring.
7. Oppdater kvittering og meldinger slik at de gjenspeiler faktisk fakturastatus.
8. Legg til administrasjonsoversikt og manuell gjenkjøring.
9. Test mot PowerOffice-demo før produksjon.
10. Aktiver integrasjonen i produksjon først etter godkjenning med regnskapsfører.

## Tester

Legg til integrasjonstester for:

- privatkunde som velger faktura og fyller påkrevd fakturaadresse
- bedriftskunde med gyldig organisasjonsnummer
- manglende firmaopplysninger eller ugyldig organisasjonsnummer
- avbrutt fakturadialog uten valg av faktura
- lagring av fakturafelter på avtalen
- køsetting av fakturajobb etter vellykket registrering
- vellykket PowerOffice-respons med lagring av fakturanummer
- feilrespons fra PowerOffice uten at avtalen eller fakturastatus feilaktig blir markert som sendt
- gjenkjøring som ikke oppretter dobbel faktura

HTTP-kall skal stubbes i automatiske tester. Ende-til-ende-test gjøres manuelt mot PowerOffice sin demo-klient.

## Avklaringer før produksjon

- Hvilken PowerOffice API-versjon og autentiseringsflyt skal brukes?
- Hvilke nøkler mottas, og hvem godkjenner koblingen til regnskapsklienten?
- Skal faktura sendes på e-post, EHF eller følge kundens eksisterende PowerOffice-innstilling?
- Hvilket produkt, inntektskonto og MVA-kode skal sesonglagring bruke?
- Skal hver lagringsgjenstand være egen fakturalinje, eller skal fakturaen ha én samlet linje?
- Hvilken betalingsfrist, fakturatekst og referanse skal brukes?
- Hvem følger opp fakturaer som feiler eller blir kreditert?

## E-post fra Power office kundeservice
Takk for henvendelsen, og for en god beskrivelse av det du skal bygge.
 
Om utviklerkontoen: Det er ikke mulig å registrere seg selv i utviklerportalen – brukere opprettes av oss når vi har mottatt et registreringsskjema for demomiljøet. Det er derfor registreringen ikke gikk gjennom. Slik kommer du i gang:
Fyll ut demoskjema: Registrering for demomiljø . Oppgi deg selv som Lead Developer.
Invitasjon til utviklerportalen: Når skjemaet er behandlet, får du en invitasjon til developer.poweroffice.net på e-postadressen du oppga. Der får du subscription key, application key og client key til en fiktiv testklient i demomiljøet.
Gjør testkall: Sett opp løsningen din mot demomiljøet og gjør noen vellykkede kall mot de endepunktene du trenger.
 
Skulle skjemaet avvise e-postadressen din, gi oss beskjed i denne tråden, så hjelper vi deg videre.
 
Om nøklene og koblingen mot Rovde Industripark: Integrasjonen din identifiseres med en application key (din nøkkel), mens client key er unik per regnskapsklient i PowerOffice Go. I produksjon får du den ved at en administrator på Rovde Industripark sin klient – typisk regnskapsføreren – legger til integrasjonen under Meny → Innstillinger → Utvidelser → Legg til utvidelse → Egendefinert og oppgir application key. Da genereres client key, som vises kun én gang og må lagres sikkert. Det er beskrevet i detalj i Adding the integration to a client . Dette steget kommer etter demotesting, så det trenger du ikke tenke på ennå.
 
Om løsningen din: Faktura og Vipps-betaling håndteres som to ulike flyter i PowerOffice Go. Fakturering går normalt via salgsordre som faktureres fra systemet (eller ferdige fakturaer som bokføres), mens Vipps-betalinger registreres som egne betalingshendelser. Anbefalt oppsett for begge er beskrevet i eCommerce, POS and payments i utviklerportalen – verdt å lese før du begynner å kode.
 
Veien videre til produksjon: Når integrasjonen fungerer stabilt i demo, sender du oss en oppdatering i denne tråden. Vi sjekker loggene, og oversender så søknadsskjemaet for produksjonstilgang. Merk at Visma Developer Terms sendes til digital signering til den som oppgis som juridisk eier av integrasjonen i det skjemaet.
 
Lykke til med testingen, og si gjerne fra om du har tekniske spørsmål underveis.