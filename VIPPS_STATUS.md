# Vipps status

## Implementert

- Gren: `feature/vipps-og-bedrift`.
- PowerOffice API-kode er fjernet fra denne grenen. BRREG-oppslag beholdes.
- Kvitteringssiden er fjernet.
- Privatkunde betaler 700 kr per meter uten MVA.
- Bedriftskunde aktiveres med knappen **Bedriftskunde**:
  - åpner BRREG-felter,
  - beregner 25 % MVA,
  - viser netto, MVA og total i skjemaet,
  - kan lukkes igjen og går da tilbake til privatkunde uten MVA.
- **Betal med Vipps** lagrer avtalen og oppretter Vipps ePayment-krav.
- Vipps betalingslenke vises som QR-panel som ikke blokkerer neste registrering.
- QR-panelet kan lukkes manuelt med `×`. Dette rydder kun panelet fra nettleserøkten, ikke den opprettede betalingsordren.
- **Send faktura** vises bare for bedriftskunde, oppretter ingen Vipps-betaling og sender PDF-faktura.
- PDF-faktura og betalingskvittering genereres med MVA-spesifikasjon og sendes uten BCC-kopi.
- Lokal utvikling støtter Letter Opener eller Resend via `USE_RESEND=true`.
- Lokal demobetaling finnes bare når Vipps ikke er konfigurert.

## Sandbox verifisert

- Vipps Sandbox-konfigurasjon er lagret lokalt i `.env.development`, ikke i git.
- MSN `540057` fungerer.
- Vipps access token hentes.
- ePayment v1 oppretter betalingskrav.
- Norsk telefonnummer normaliseres fra åtte sifre til `47xxxxxxxx` før Vipps-kallet.
- Webhook er registrert hos Vipps Sandbox mot:
  - `https://placidly-refutable-shadily.ngrok-free.dev/webhooks/vipps`
- Sandbox sendte en `ABORTED`-webhook som appen mottok og lagret som `cancelled`.
- QR-panelet rydder nå nettleserøkten og lukker ved `paid`, `cancelled` eller `failed`.

## Må implementeres før produksjon

### 1. Capture etter autorisasjon

Dette er den viktigste mangelen.

- Vipps sender normalt `AUTHORIZED` når kunden godkjenner.
- Appen må da kalle Vipps capture-endepunktet for riktig referanse og beløp.
- `VippsClient#capture_payment` finnes allerede, men brukes ikke.
- Først når Vipps bekrefter `CAPTURED` skal avtalen settes til `paid`.
- Bedrifts-PDF-kvittering skal bare sendes etter `CAPTURED`.
- Implementer idempotent capture, slik at gjentatte webhooks aldri capturer eller sender kvittering mer enn én gang.

### 2. Sandbox ende-til-ende-test

Etter capture er implementert:

1. Opprett betaling fra nettbrettskjemaet.
2. Godkjenn betaling i Vipps Sandbox.
3. Verifiser `AUTHORIZED`-webhook.
4. Verifiser capture-kall og `CAPTURED`-webhook.
5. Kontroller status `paid`.
6. For bedriftskunde, kontroller PDF-kvittering og e-post.
7. Test avbrutt, utløpt og gjentatt webhook.

### 3. Produksjonsoppsett

- Legg inn produksjonsnøkler som Fly secrets, aldri i kode eller git.
- Bytt `VIPPS_BASE_URL` til Vipps produksjons-URL.
- Bruk fast offentlig HTTPS-domene, ikke ngrok.
- Registrer produksjonswebhook.
- Bekreft avsenderdomener i Resend for både avtale- og faktura-e-post.
- Sett opp varig lagring for opplastede bilder i produksjon.

## Lokale miljøvariabler

Se `.env.example` for variabelnavn. Lokale hemmeligheter ligger i `.env.development`, som ikke skal committes.

Nødvendige Vipps-variabler:

```text
VIPPS_CLIENT_ID
VIPPS_CLIENT_SECRET
VIPPS_SUBSCRIPTION_KEY
VIPPS_MERCHANT_SERIAL_NUMBER
VIPPS_BASE_URL=https://apitest.vipps.no
APP_HOST=placidly-refutable-shadily.ngrok-free.dev
```

## Kvalitetssjekker som bestod

```bash
bin/rails test
bin/rails zeitwerk:check
bundle exec brakeman --no-pager
```
