# Kjøretøy- og Båtlagring App (Utleieregistrering)

Dette er en webapplikasjon utviklet for enkel og rask registrering av kjøretøy, båter og gjenstander til vinter-/sesonglagring. Appen er primært utformet for bruk på et 10" nettbrett (iPad/Android) på mottaksstedet.

---

## 🛠 Teknologistakk & Arkitektur

- **Rammeverk:** Ruby on Rails 8
- **Frontend:** Hotwire (Turbo & Stimulus), Tailwind CSS
- **Database:** PostgreSQL
- **Bilde- og filhåndtering:** Active Storage (Forberedt for Cloudflare R2 / S3, lokal disk i `development`)
- **Autentisering:** Enkel PIN/Passord-beskyttelse for nettbrett (styrt via `Rails.application.credentials`)
- **Eksterne Integrasjoner:** Statens vegvesen (SVV) Open Data API (Kjøretøyoppslag)
- **Bakgrunnsjobber:** Action Mailer (SendGrid / SMTP for e-postkontrakter)

---

## 🎨 UI/UX Designretningslinjer

- **Enhet:** Optimalisert for 10" nettbrett i liggende/stående modus (touch-vennlig layout).
- **Stil:** Lyst, moderne, rent og ryddig grensesnitt med store touch-flater, tydelige knapper og god kontrast.

---

## 📋 Funksjonelle Krav & Brukerreise

### 0. Adgangskontroll
- Ved oppstart kreves innlogging/PIN-kode for å låse opp skjemaet på nettbrettet.
- Koden valideres mot `Rails.application.credentials.tablet_passcode`.

---

### Del 1: Objekt- og Meterregistrering
Skjemaet starter med registrering av hva som skal lagres:

- **Dynamiske linjer:**
  - Brukeren kan legge til ubegrenset antall objekter via en `+ Legg til objekt`-knapp (Stimulus controller).
  - Hver linje inneholder:
    - `Registreringsnummer` (Tekstfelt) **eller** `Beskrivelse` (Tekstfelt om regnr mangler).
    - `Antall meter` (Tallfelt / Decimal).
- **Automatisk Kjøretøyoppslag (Statens vegvesen API) med Manuell Fallback:**
  - Når brukeren taster inn et gyldig norsk registreringsnummer, skal appen gjøre et oppslag mot SVV API via en bakgrunnskontroller (`VehicleLookupService`).
  - Hvis treff: `Antall meter` pre-fylles automatisk basert på kjøretøyets registrert lengde i mm (omregnet til meter).
  - **Manuell Overstyring / Fallback:** 
    - Brukeren skal når som helst kunne overskrive feltet for `Antall meter` manuelt.
    - Dersom oppslaget feiler, SVV-API-nøkkel mangler, kunden slår av integrasjonen i konfigurasjonen, eller objektet ikke har regnr (f.eks. båt på henger), fungerer feltet som et helt standard manuelt inntastingsfelt uten feilmeldinger eller blokkeringer.
- **Automatisk Prisberegning:**
  - Beregner fortløpende totalprisen i grensesnittet med formelen:
    $$\text{Totalsum (NOK)} = (\text{Sum av alle meter}) \times 700$$
  - Totalsummen vises fremtredende nederst i Del 1.
- **Videre-knapp:** Tar brukeren videre til Del 2.

---

### Del 2: Kundeinformasjon, Hentedato & Kontrakt
- **Kundeinformasjon:**
  - `Eiers navn` (Tekst, påkrevd)
  - `Telefonnummer` (Tekst/Tel, påkrevd)
  - `E-postadresse` (E-post, påkrevd)
- **Forhåndsbestemte Hentedatoer (Faste valg):**
  - Radioknapper/knappevalg for tre faste utleveringsdatoer:
    - `01. april`
    - `30. april`
    - `19. mars kl. 18:00`
- **Spesielle hentebehov:**
  - Avkrysningsboks (`Check_box`): "Krever spesiell/rask tilgjengelighet (avtalt på forhånd)".
  - Tekstfelt for valgfrie notater om tilgjengelighet.
- **Kameraintegrasjon / Bildeopplasting:**
  - Knapp: `📸 Ta bilder av lagringsobjekt`.
  - Åpner enhetens kamera direkte (`input type="file" accept="image/*" capture="environment"`).
  - Støtter opplasting av flere bilder.
  - Bildene knyttes til **kundeforholdet/kontrakten** i databasen, men indekseres/søkes også opp mot registreringsnumrene oppgitt i Del 1.
- **Kontraktsgodkjenning (Scroll to Accept):**
  - Vilkår og kontrakt vises i en rullbar boks (`overflow-y: scroll`).
  - Avkrysningsboksen/knappen "Jeg godtar leiekontrakten" er deaktivert (disabled) frem til brukeren har scrollet helt til bunnen av kontraktsboksen.
- **E-postkopi:**
  - Avkrysningsboks: "Send kopi av kontrakt på e-post" (Valgt som standard).

---

### Del 3: Betaling & Avslutning
- **Betalingsalternativer:**
  1. **Vipps:** Forberedt for Vipps MobilePay eCom API (Service/Adapter-mønster).
  2. **Faktura:** Logges i databasen som "Faktura ønsket". Forberedt for fremtidig API-integrasjon mot regnskapssystem (f.eks. Tripletex/Fiken).
- **Kvittering:**
  - Viser bekreftelsesside med sammendrag av registreringen og generert referansenummer.
  - Trigger e-postutsendelse om avkrysset.

---

## 🧪 Testmodus / Sandbox-oppførsel (Utvikling & Testing)

I `development`-miljø skal appen tillate enkel gjennomføring uten at manglende API-nøkler stopper brukertesten:
- **Vipps:** Tilbyr en enkel "Simuler Vipps-betaling"-knapp som automatisk oppdaterer status til `payment_status: :paid` og sender brukeren direkte videre til kvitteringssiden.
- **Faktura:** Settes direkte til `payment_status: :pending` og navigere umiddelbart til kvitteringssiden uten eksterne API-kall.
- **Vegvesen API:** Dersom `SVV_API_KEY` mangler eller ikke er konfigurert, returnerer oppslagsfunksjonen grasiøst `nil` (eller en mock-verdi om ønskelig), slik at manuell inntasting fungerer uforstyrret.

---

## 🔌 Tjenester & Integrasjonsmønster

### `VehicleLookupService`
- Håndterer API-kall mot Statens vegvesen Open Data API.
- Kan slås av/på via en miljøvariabel (`ENABLE_VEHICLE_LOOKUP=true/false`).
- Parse-eksempel: Henter `godkjenning -> tekniskGodkjenning -> tekniskeData -> dimensjoner -> lengde` (mm) og returnerer i meter.
- Feiler grasiøst (returnerer `nil`) dersom API-et er nede, kunden mangler nøkkel, eller kjennemerket ikke finnes.

---

## 🗄 Datamodell (Forslag til Rails Models)

### `RentalAgreement` / `Leieforhold`
- `customer_name`: string
- `customer_phone`: string
- `customer_email`: string
- `pickup_date`: datetime / string
- `special_needs`: boolean
- `special_needs_notes`: text
- `total_meters`: decimal
- `total_price`: decimal
- `payment_method`: string (enum: `vipps`, `invoice`)
- `payment_status`: string (enum: `pending`, `paid`)
- `contract_approved`: boolean
- `send_email_copy`: boolean
- `has_many_attached :photos` (Active Storage)
- `has_many :items`

### `StorageItem` / `Lagringsobjekt`
- `rental_agreement_id`: references
- `registration_number`: string (valgfritt)
- `description`: text (valgfritt)
- `meters`: decimal

---

## 🚀 Instrukser for CLI Agent

1. Gå igjennom kravspesifikasjonen over og sett opp en ren Rails 8-struktur.
2. Bruk `Tailwind CSS` for moderne, responsiv utforming tilpasset 10" tablet.
3. Lag Stimulus-controllers for:
   - Dynamisk legge til/fjerne linjer i Del 1.
   - Automatisk oppslag på regnr mot interne `VehicleLookupController` (med graceful fallback dersom API feiler eller bryter).
   - Reell-tids beregning av samlet meter og sum ($meter \times 700$).
   - "Scroll to accept"-logikk for kontraktsvisningen i Del 2.
4. Sett opp `Active Storage` for bildelagring.
5. Lag et fleksibelt `PaymentService`- og `VehicleLookupService`-mønster slik at eksterne tjenester enkelt kan aktiveres, deaktiveres eller byttes ut uten å berøre kjerne-kontrollerne.
6. Sørg for at Testmodus / Sandbox-flyten er aktiv under `development` slik at hele søknadsreisen fra registrering til kvittering kan testes umiddelbart uten eksterne nøkler.


## Konfigurasjon og Miljøvariabler

Applikasjonen krever et par konfigurasjoner for nettbrett-autentisering og eksterne API-kall.

### 1. PIN-kode for nettbrett (Innlogging)
Standard PIN-kode for lokal utvikling er satt til **`1234`**.

Dette sjekkes enten via credentials eller miljøvariabel:
- **Credentials:** `tablet_passcode: "1234"`
- **Miljøvariabel:** `TABLET_PASSCODE=1234`

### 2. Statens vegvesen API
For å hente ut kjøretøydata benyttes Statens vegvesen sitt API. Du må opprette en personlig/virksomhetsnøkkel hos Statens vegvesen sin utviklerportal.

Legg inn din nøkkel i konfigurasjonen:
- **Credentials:** `vegvesenet_api_key: "DIN_API_NØKKEL"`
- **Miljøvariabel:** `VEGVESENET_API_KEY=din_api_nøkkel`

> **Merk:** API-nøkler skal aldri sjekkes inn i versjonskontroll i klartekst. Legg din personlige nøkkel i `config/credentials.yml.enc` eller i en lokal `.env`-fil.