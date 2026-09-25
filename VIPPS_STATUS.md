# Vipps-driftsstatus

## Bekreftet i Sandbox

- Vipps ePayment v1 oppretter betalingskrav med norsk telefonnummer i format `47xxxxxxxx`.
- Betalingslenken vises som QR-panel og kan lukkes manuelt uten å avbryte Vipps-ordren.
- Signert `AUTHORIZED`-webhook utløser idempotent capture.
- Signert `CAPTURED`-webhook setter avtalen til `paid`, lukker QR-panelet og køer bedriftskvittering.
- Avbrutte betalinger behandles som `cancelled`.
- Gjentatte webhooks gir ikke ny capture eller flere kvitteringer.

## Lokal Sandbox-konfigurasjon

Lokale hemmeligheter skal ligge i `.env.development`, aldri i git:

```text
VIPPS_CLIENT_ID
VIPPS_CLIENT_SECRET
VIPPS_SUBSCRIPTION_KEY
VIPPS_MERCHANT_SERIAL_NUMBER
VIPPS_WEBHOOK_SECRET
VIPPS_BASE_URL=https://apitest.vipps.no
APP_HOST=<offentlig-https-host>
```

Webhook-URL er `<APP_HOST>/webhooks/vipps`. `VIPPS_WEBHOOK_SECRET` mottas ved webhook-registrering og er nødvendig for å godta signerte hendelser.

## Produksjonssjekkliste

- [ ] Sett produksjonsnøkler og separat webhook-secret som Fly-secrets.
- [ ] Bytt `VIPPS_BASE_URL` til Vipps-produksjons-URL.
- [ ] Bruk et fast offentlig HTTPS-domene og registrer produksjonswebhooken.
- [ ] Verifiser én privat og én bedriftsbetaling ende til ende.
- [ ] Test `ABORTED`, utløpt betaling og gjentatt webhook.
- [ ] Bekreft at bedriftskvittering sendes bare én gang etter `CAPTURED`.

Se [README.md](README.md) for betalingsflyten og [DEPLOYMENT.md](DEPLOYMENT.md) for produksjonsoppsett.
