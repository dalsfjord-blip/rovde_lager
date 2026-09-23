# E-post funksjonalitet - Implementert

## Oversikt
E-post-funksjonaliteten er nå implementert med Resend som SMTP-leverandør. Kunder kan motta en bekreftelse på sin lagerregistrering via e-post.

## Hva er implementert

### Backend
- ✅ `RentalAgreementMailer` med `confirmation_email` metode
- ✅ HTML og tekst e-post-maler
- ✅ `ReceiptController#email` implementert med feilhåndtering
- ✅ Resend SMTP-konfigurasjon i production.rb
- ✅ letter_opener for lokal testing

### E-post-mal inneholder
- Referansenummer og dato
- Kundeinformasjon
- Liste over lagringsobjekter
- Total pris og meter
- Betalingsinformasjon
- Hentedato og spesielle behov

## Oppsett for produksjon

### 1. Sett miljøvariabler på fly.io

```bash
fly secrets set \
  RESEND_API_KEY=<din_resend_api_key> \
  SMTP_FROM_EMAIL=avtale@rovdeindustripark.no \
  --app rovde-lager
```

### 2. Verifiser domene i Resend
- Logg inn på https://resend.com
- Legg til ditt domene (f.eks. rovdeindustripark.no)
- Følg instruksjonene for å legge til DNS-poster (SPF, DKIM, DMARC)
- Vent på verifisering (kan ta opptil 48 timer)

### 3. Deploy

```bash
git push origin email-functionality
fly deploy
```

## Lokal testing

E-post åpnes automatisk i nettleseren når du kjører lokalt:

1. Start serveren: `bin/rails server`
2. Fullfør en registrering med e-postadresse
3. Huk av for "Send kopi av kontrakt på e-post"
4. Velg betalingsmetode og fullfør
5. E-posten åpnes automatisk i nettleseren

## Hvordan det fungerer

**Privatkunder:**

1. Kunde fyller inn e-postadresse i skjemaet
2. Huker av for "Send kopi av kontrakt på e-post" (standard på)
3. Velger betalingsmetode (Vipps eller Faktura)
4. Ved Vipps: E-post sendes automatisk når betaling er bekreftet via webhook
5. Ved Faktura: E-post sendes umiddelbart når faktura opprettes
6. Kunde mottar bekreftelses-e-post automatisk

**E-posten inneholder:**
- Referansenummer og dato
- Kundeinformasjon
- Liste over lagringsobjekter med total pris
- Betalingsinformasjon
- Hentedato og spesielle behov
- Fullstendig leiekontrakt
- Disclaimer om at Vipps-kvittering kommer separat
- Disclaimer om at e-posten ikke kan besvares

**Fra-adresse:** avtale@rovdeindustripark.no

## Feilhåndtering

- Validerer at e-postadresse eksisterer før sending
- Logger feil til Rails.logger hvis sending feiler
- Viser brukervennlige feilmeldinger
- Bruker `deliver_later` for asynkron sending (ikke blokkerende)

## Testing

```bash
# Kjør mailer-tester
bin/rails test test/mailers/rental_agreement_mailer_test.rb
```

## Resend-konfigurasjon

**SMTP-innstillinger:**
- Server: smtp.resend.com
- Port: 587
- Brukernavn: resend
- Passord: RESEND_API_KEY
- Autentisering: PLAIN
- TLS: Aktivert

**Prismodell:**
- Gratis tier: 3,000 e-post/måned
- Growth: $20/måned for 50,000 e-post
- Ingen kredittkortkrav for gratis tier

## Neste steg (valgfritt)

1. **Automatisk sending ved fullført registrering**
   - Kan legges til i customer_info_controller hvis ønskelig
   - `RentalAgreementMailer.confirmation_email(@agreement).deliver_later if @agreement.send_email_copy`

2. **Faktura-e-post**
   - Kan legge til `invoice_notification` metode
   - Separat mal for faktura

3. **E-post-statistikk**
   - Resend dashboard viser åpningsrate og leveringsstatus
   - Kan integreres med webhooks hvis ønskelig

## Feilsøking

**E-post sendes ikke i produksjon:**
1. Sjekk at `RESEND_API_KEY` er satt: `fly secrets list`
2. Sjekk logs: `fly logs`
3. Verifiser domene i Resend-dashboard

**E-post havner i spam:**
1. Verifiser SPF, DKIM, DMARC records
2. Bruk verifisert domene (ikke @gmail.com)
3. Sjekk Resend deliverability score

**Lokal testing fungerer ikke:**
1. Sjekk at letter_opener er installert: `bundle list letter_opener`
2. Sjekk development.rb konfigurasjon
3. Restart Rails-server


## arbeidsflyt

**Privatkunder:**

Utsendelse av avtalen skal være automatisert. Den skal inneholde:
- Lagringsobjekt(er)
- Tidspunkt for uthenting
- Leiekontrakten (tekst)

Kvittering for betaling kommer fra Vipps-app (eksternt) - dette står i e-posten skriftelig.

Vi skal ikke åpne noe e-post-klient under registrering - alt skal være automatisk.

Kunden skal bare ha tilsendt avtalen hvis "send avtalen på e-post" er huket av i kontrakten.

Sendes ut via Resend fra "avtale@rovdeindustripark.no"

E-posten kan ikke besvares (noreply-disclaimer er inkludert).

**Bedriftskunder:**
Her kommer vi tilbake med en løsning.