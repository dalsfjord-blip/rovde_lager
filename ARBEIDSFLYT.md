# Arbeidsflyter - Privat vs Bedrift

## Status
✅ **Privatkunder:** Implementert (venter på Vipps-integrasjon)  
⏳ **Bedriftskunder:** Planlagt (implementeres etter Vipps er ferdig)

---

## Privatkunder (Implementert)

### Flyt:
1. **Del 1:** Registrer lagringsobjekt(er)
2. **Del 2:** Fyll inn kundeinfo
   - Huk av "Send avtaleteksten på e-post" (standard på)
3. **Del 3:** Velg **Vipps**-knappen
4. **Klikk "Fullfør registrering"**
   - Avtalen sendes automatisk på e-post hvis avhuket
   - E-post fra: `avtale@rovdeindustripark.app`
   - Inneholder: Referansenummer, lagringsobjekter, pris, leiekontrakt, disclaimer
5. **Vipps-betaling:** Kunden sendes til Vipps eksternt → betaler → kommer tilbake
6. **Webhook:** Vipps bekrefter betaling
7. **Kvittering:** Kommer fra Vipps-appen (eksternt)

### E-post innhold (privatkunder):
- ✅ Referansenummer og dato
- ✅ Kundeinformasjon
- ✅ Liste over lagringsobjekter (reg.nr, beskrivelse, meter)
- ✅ Total pris (uten mva)
- ✅ Betalingsinformasjon (Vipps)
- ✅ Hentedato og spesielle behov
- ✅ Fullstendig leiekontrakt
- ✅ Disclaimer: "Kvittering fra Vipps kommer i Vipps-appen"
- ✅ Disclaimer: "Ikke svar på denne e-posten"
- ✅ Kontaktinfo: torvik137@gmail.com

### Teknisk implementering:
- ✅ E-post sendes i `StorageItemsController#create`
- ✅ Resend SMTP konfigurert
- ✅ HTML og tekst-maler
- ✅ From-adresse: `avtale@rovdeindustripark.app`
- ✅ Asynkron sending via `deliver_later` (Solid Queue)

---

## Bedriftskunder (Planlagt)

### Flyt:
1. **Del 1:** Registrer lagringsobjekt(er)
2. **Del 2:** Fyll inn kundeinfo
   - Huk av "Send kopi av kontrakt på e-post" (valgfritt)
3. **Del 3:** Velg **"Faktura for bedrift"**-knappen
   - Fyller inn **org.nr** (required)
   - Fyller inn **bedriftsnavn** (required)
   - **Total pris beregnes med +25% mva**
4. **Klikk "Fullfør registrering"**
   - To e-poster sendes:
     a) **Avtaletekst** (hvis avhuket) til kundens e-post fra `avtale@rovdeindustripark.app`
     b) **PDF-kvittering** til kundens e-post fra `faktura@rovdeindustripark.app`
   - **Kopi av PDF-kvittering** sendes til `rovdeindustri@faktura.poweroffice.net`
5. **Vipps-betaling:** Kunden sendes til Vipps eksternt → betaler (pris med mva) → kommer tilbake
6. **Webhook:** Vipps bekrefter betaling
7. **Kvittering:** PDF-kvittering fungerer som fakturagrunnlag for regnskap

### E-post 1: Avtaletekst (hvis valgt)
- Fra: `avtale@rovdeindustripark.app`
- Til: Kundens e-post
- Innhold: Samme som privatkunder (se over)

### E-post 2: PDF-kvittering (alltid)
- Fra: `faktura@rovdeindustripark.app`
- Til: Kundens e-post
- Kopi til: `rovdeindustri@faktura.poweroffice.net`
- Vedlegg: **PDF med:**
  - Bedriftsnavn
  - Organisasjonsnummer
  - Referansenummer
  - Liste over lagringsobjekter
  - **Total pris eks. mva**
  - **Mva (25%)**
  - **Total pris inkl. mva**
  - Betalingsinformasjon (Vipps - betalt)
  - Hentedato
  - Leiekontrakt
  - MVA-spesifikasjon for regnskap

### Teknisk implementering (TODO):
- ⏳ Legg til `vat_amount` og `total_price_with_vat` felter i `rental_agreements`
- ⏳ Beregn mva automatisk når "Faktura for bedrift" velges
- ⏳ Lag PDF-generator (Prawn eller lignende)
- ⏳ Lag `InvoiceMailer` for PDF-kvittering
- ⏳ Send kopi til PowerOffice-e-post
- ⏳ Valider org.nr format (9 siffer)
- ⏳ Oppdater kvitteringsside for å vise mva-info for bedriftskunder

---

## Hovedforskjeller: Privat vs Bedrift

| | **Privatkunder** | **Bedriftskunder** |
|---|---|---|
| **Knapp** | Vipps | Faktura for bedrift |
| **Org.nr/Bedriftsnavn** | Nei | Ja (required) |
| **Pris** | Total pris (uten mva) | Total pris + 25% mva |
| **Betaling** | Vipps | Vipps (med mva) |
| **E-post 1** | Avtaletekst (hvis valgt) | Avtaletekst (hvis valgt) |
| **E-post 2** | - | PDF-kvittering til kunde + kopi til PowerOffice |
| **Kvittering** | Vipps-app | PDF med mva-spesifikasjon |

---

## Veien videre

### Fase 1: Vipps-integrasjon (nå)
1. ✅ E-post-funksjonalitet for privatkunder
2. ⏳ Implementer Vipps-betaling i produksjon
3. ⏳ Test hele flyten med ekte Vipps-transaksjoner
4. ⏳ Verifiser webhook-håndtering
5. ⏳ Sett opp Resend-domene og DNS

### Fase 2: Bedriftskundefunksjonalitet (etter Vipps)
1. ⏳ Legg til mva-beregning i backend
2. ⏳ Implementer PDF-generator for kvittering
3. ⏳ Lag `InvoiceMailer` med PDF-vedlegg
4. ⏳ Send kopi til PowerOffice-e-post
5. ⏳ Oppdater UI for å vise mva-info
6. ⏳ Test hele bedriftsflyten

### Fase 3: PowerOffice-integrasjon (valgfritt)
1. ⏳ Automatisk opprettelse av fakturaer i PowerOffice
2. ⏳ Synkronisering av betalingsstatus
3. ⏳ Kunderegistrering i PowerOffice
   se power_office.md for meg info om fase 3.   

---

## Miljøvariabler (produksjon)

### Fly.io secrets som må settes:
```bash
fly secrets set \
  RESEND_API_KEY=<din_resend_api_key> \
  SMTP_FROM_EMAIL=avtale@rovdeindustripark.app \
  --app rovde-lager
```

### Resend-domener som må verifiseres:
- `avtale@rovdeindustripark.app` (for avtaletekst)
- `faktura@rovdeindustripark.app` (for PDF-kvittering - fase 2)

### PowerOffice-e-post:
- `rovdeindustri@faktura.poweroffice.net` (mottar kopi av bedriftskvitteringer)

---

## Notater

- **Privatkunder:** Enkel flyt, kun Vipps, ingen mva, enkel e-post med avtaletekst
- **Bedriftskunder:** Mer kompleks, samme Vipps-betaling men med mva, PDF-kvittering til regnskap
- **Fakturaknappen:** Er egentlig en "bedriftskunde"-knapp som trigger mva-beregning og PDF-kvittering
- **PowerOffice:** Brukes kun for bedriftskunder, mottar kopi av kvittering for regnskapsføring
- **E-postadresser:** Forskjellige avsenderadresser for forskjellige typer e-post (avtale vs faktura)

---

## Kjente problemer som må fikses

### 1. Datoformatering i e-post
**Problem:** Dato og hentedato viser "Translation missing: nb.date.month_names"  
**Årsak:** Mangler norsk lokalisering (i18n)  
**Løsning:** 
- Legg til norsk lokaliseringsfil (`config/locales/nb.yml`)
- Eller bruk `strftime` i stedet for `l()` helper

### 2. Ufullstendig avtaletekst i e-post
**Problem:** E-posten inneholder kun deler av leiekontrakten  
**Årsak:** Forkortet tekst i e-post-malen  
**Løsning:** Kopier fullstendig avtaletekst fra `storage_items/index.html.erb` til e-post-malen

### 3. Referansenummer-oppsett
**Problem:** Må se på hvordan referansenummer genereres og formateres  
**TODO:** 
- Sjekk format (f.eks. AGR-2026-001 eller lignende)
- Sikre unikhet
- Vurdere prefix/suffix
- Dokumentere logikk

### "Jeg har lest og godkjenner leiekontrakten" må fungere som en signering av at avtalen er godkjent. Er det tydelig i dag?

---

## Kontaktinfo

**Rovde Industripark**  
Org.nr: 987988290  
E-post: torvik137@gmail.com  

**E-poster (utgående):**
- `avtale@rovdeindustripark.app` (avtaletekst)
- `faktura@rovdeindustripark.app` (PDF-kvittering - fase 2)

**E-post (innkommende):**
- `rovdeindustri@faktura.poweroffice.net` (kopi av bedriftskvitteringer)
