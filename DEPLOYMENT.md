# Deployment til Fly.io

Denne veiledningen er kilden for deploy, Vipps Sandbox, produksjonshemmeligheter og driftskontroll. Hemmeligheter skal kun settes med `fly secrets set`, aldri lagres i git eller dokumentasjonen.

## Før du deployer

- [ ] Kjør `bin/rails test`.
- [ ] Kjør `bin/rails zeitwerk:check`.
- [ ] Kjør `bundle exec brakeman --no-pager`.
- [ ] Bekreft at `APP_HOST` er korrekt i `fly.toml` eller som Fly-secret.
- [ ] Kontroller at valgt `APP_HOST` bruker HTTPS og er tillatt av `config.hosts`.
- [ ] Bekreft at `SOLID_QUEUE_IN_PUMA=true` settes slik at e-post- og fakturajobber behandles.

## Fly.io-oppsett

`fly.toml` bruker appen `rovde-lager`, region `arn`, HTTPS og ett kjørende program. Release-kommandoen kjører `bin/rails db:prepare`.

### Første gang

```bash
fly auth login
fly apps create rovde-lager
fly postgres create --name rovde-lager-db --region arn
fly postgres attach rovde-lager-db --app rovde-lager
fly volumes create rovde_lager_storage --region arn --size 10 --app rovde-lager
```

Produksjonsoppsettet forventer egne databaser for Solid Cache, Solid Queue og Solid Cable. Opprett dem før første deploy:

```sql
CREATE DATABASE rovde_lager_production_cache;
CREATE DATABASE rovde_lager_production_queue;
CREATE DATABASE rovde_lager_production_cable;
```

`database.yml` avleder tilkoblingene fra `DATABASE_URL`.

### Nødvendige Fly-secrets

Sett verdiene med dine faktiske hemmeligheter:

```bash
fly secrets set \
  RAILS_MASTER_KEY=<rails-master-key> \
  TABLET_PASSCODE=<sterk-pin> \
  RESEND_API_KEY=<resend-api-key> \
  SMTP_FROM_EMAIL=avtale@rovdeindustripark.app \
  INVOICE_FROM_EMAIL=faktura@rovdeindustripark.app \
  VEGVESENET_API_KEY=<vegvesenet-api-key> \
  SOLID_QUEUE_IN_PUMA=true \
  --app rovde-lager
```

Vipps-secrets settes separat, se Vipps-seksjonen. Sjekk kun navnene, ikke verdiene, med:

```bash
fly secrets list --app rovde-lager
```

### Deploy og kontroll

```bash
fly deploy --app rovde-lager
fly status --app rovde-lager
fly logs --app rovde-lager
```

Test deretter helseendepunktet på `https://<app-host>/up`, innlogging, registrering, e-post og bakgrunnsjobber.

### Databasekapasitet

Postgres-maskinen må ha minst 1 GB RAM. 256 MB gir minne- og IO-press som kan bryte databaseforbindelser og gi `500`-feil under registrering eller Vipps-betaling.

```bash
fly machine status <database-machine-id> --app rovde-lager-db
fly machine update <database-machine-id> --app rovde-lager-db --vm-memory 1024 --yes
```

Bekreft at kontrollene `pg`, `role` og `vm` er friske før du prøver betaling på nytt.

## Vipps Sandbox

Sandbox må bruke en offentlig HTTPS-adresse som Vipps kan nå. Lokal `localhost` fungerer ikke for webhooker. Ved lokal test kan en kortvarig HTTPS-tunnel brukes, mens Fly-appens HTTPS-adresse kan brukes for et varig testmiljø.

### Sandbox-secrets

```bash
fly secrets set \
  VIPPS_BASE_URL=https://apitest.vipps.no \
  VIPPS_CLIENT_ID=<sandbox-client-id> \
  VIPPS_CLIENT_SECRET=<sandbox-client-secret> \
  VIPPS_SUBSCRIPTION_KEY=<sandbox-subscription-key> \
  VIPPS_MERCHANT_SERIAL_NUMBER=<sandbox-msn> \
  VIPPS_WEBHOOK_SECRET=<sandbox-webhook-secret> \
  --app rovde-lager
```

Registrer webhooken mot:

```text
https://<app-host>/webhooks/vipps
```

Vipps returnerer `VIPPS_WEBHOOK_SECRET` bare når webhooken registreres. Lagre den direkte som Fly-secret. Appen avviser usignerte webhooker i produksjon, så en manglende eller feil secret stopper betalingsflyten.

### Sandbox-verifisering

1. Opprett en privat Vipps-betaling og godkjenn den i Sandbox.
2. Bekreft i loggen: `AUTHORIZED`, capture og `CAPTURED`.
3. Bekreft at avtalen får `paid` og QR-panelet lukker seg.
4. Opprett en bedriftsbetaling og bekreft at PDF-kvittering sendes én gang.
5. Test avbrutt betaling og gjentatt webhook.

Ikke bruk Sandbox-nøkler eller Sandbox-webhook-secret i produksjon.

### Anbefalt staging-fase

Bruk en egen staging-app med eget domene, database, Vipps Sandbox-nøkler og separat webhook-secret før produksjonsnøkler bestilles eller tas i bruk. Staging skal verifisere hele betalingsflyten, e-post, bakgrunnsjobber, QR-lukking, bilder og gjentatte webhooker uten å blande testdata med produksjon.

## Vipps-produksjon

Før produksjon må Vipps gi produksjonsnøkler og webhook må registreres på endelig domene. Sett produksjonsverdier som secrets:

```bash
fly secrets set \
  VIPPS_BASE_URL=<vipps-produksjons-url> \
  VIPPS_CLIENT_ID=<production-client-id> \
  VIPPS_CLIENT_SECRET=<production-client-secret> \
  VIPPS_SUBSCRIPTION_KEY=<production-subscription-key> \
  VIPPS_MERCHANT_SERIAL_NUMBER=<production-msn> \
  VIPPS_WEBHOOK_SECRET=<production-webhook-secret> \
  --app rovde-lager
```

Gjennomfør en ende-til-ende-test med liten beløpsgrense og kontroller capture, `CAPTURED`, QR-lukking og kvittering før ordinær bruk.

## E-post og bakgrunnsjobber

Produksjon sender e-post via Resend SMTP. Verifiser avsenderdomenene for både avtale- og faktura-e-post før bruk. `SOLID_QUEUE_IN_PUMA=true` er nødvendig fordi Solid Queue kjører inne i Puma for denne enkeltmaskininstallasjonen.

Kontroller utsending i loggene etter deploy. Feil med faktura eller kvittering må undersøkes før `receipt_sent_at` eller `invoice_sent_at` endres manuelt.

## Bilder og vedvarende lagring

Active Storage bruker lokal disk under `/rails/storage`, som er montert fra Fly-volumet `rovde_lager_storage`.

- Et Fly-volum er bundet til én maskin og region.
- Ta backup av både PostgreSQL og bildelageret.
- Ikke skaler til flere appmaskiner med lokal Active Storage uten delt objektlagring.
- Før funksjonen for oppslag av bilder på registreringsnummer lanseres, bør bildene flyttes til objektlagring med backup og tilgangskontroll.

## Drift og feilsøking

```bash
fly logs --app rovde-lager
fly ssh console --app rovde-lager
fly postgres connect -a rovde-lager-db
```

### Vanlige feil

| Symptom | Kontroller |
| --- | --- |
| Vipps-webhook får `401` | `VIPPS_WEBHOOK_SECRET`, webhook-URL, HTTPS og signatur fra riktig miljø. |
| QR-panelet lukker ikke | Se etter `AUTHORIZED`, capture og `CAPTURED` i Fly-loggen. |
| Kvittering mangler | Kontroller `SOLID_QUEUE_IN_PUMA`, Resend-secrets og `CAPTURED`-hendelsen. |
| Bilder mangler etter deploy | Kontroller volumets mount og backup. |
| E-post mangler | Kontroller Resend-domene, `RESEND_API_KEY` og bakgrunnsjobber. |

## Fase 3, PowerOffice

PowerOffice er ikke en del av dagens deploy. Når integrasjonen bygges, skal egne secrets og en separat ende-til-ende-testplan legges til her før produksjonssetting.

Se også [README.md](README.md), [VIPPS_STATUS.md](VIPPS_STATUS.md) og [SQL.md](SQL.md).
