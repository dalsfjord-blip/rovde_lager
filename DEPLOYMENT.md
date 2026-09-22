# Deployment til fly.io

## Forberedelser gjort
- ✅ Production config oppdatert (SSL, hosts, mailer)
- ✅ fly.toml opprettet med Oslo region
- ✅ Placeholder credentials for API-integrasjoner
- ✅ Persistent storage for Active Storage

## VIKTIG: Production credentials key
```
7ed262a4eed1c87a7a769bae5b47cc62
```
**Lagre denne nøkkelen sikkert!** Trengs for å dekryptere production credentials.

## Deployment-steg

### 1. Installer fly CLI
```bash
brew install flyctl
fly auth login
```

### 2. Opprett app og database
```bash
# Opprett app (bruker fly.toml config)
fly apps create rovde-lager

# Opprett PostgreSQL cluster (HA med 2 nodes i Oslo)
fly postgres create --name rovde-lager-db --region osl --initial-cluster-size 2

# Koble database til app
fly postgres attach rovde-lager-db --app rovde-lager
```

### 3. Opprett ekstra databaser for Solid adapters
```bash
# Koble til Postgres
fly postgres connect -a rovde-lager-db

# I psql, opprett ekstra databaser:
CREATE DATABASE rovde_lager_production_cache;
CREATE DATABASE rovde_lager_production_queue;
CREATE DATABASE rovde_lager_production_cable;

# Gi tilgang til hovedbruker
GRANT ALL PRIVILEGES ON DATABASE rovde_lager_production_cache TO <username>;
GRANT ALL PRIVILEGES ON DATABASE rovde_lager_production_queue TO <username>;
GRANT ALL PRIVILEGES ON DATABASE rovde_lager_production_cable TO <username>;

\q
```

### 4. Sett production credentials key som secret
```bash
fly secrets set RAILS_MASTER_KEY=7ed262a4eed1c87a7a769bae5b47cc62
```

### 5. Opprett persistent volume for Active Storage
```bash
fly volumes create rovde_lager_storage --region osl --size 10
```

### 6. Deploy
```bash
fly deploy
```

### 7. Sjekk status
```bash
fly status
fly logs
fly open  # Åpne app i browser
```

## Etter første deployment

### Oppdater API-nøkler når klare
Når du har fått produksjonsnøkler fra Vipps og Power Office:

```bash
# Rediger production credentials
EDITOR=nano rails credentials:edit --environment production

# Oppdater følgende felter:
# - tablet_passcode: "CHANGE_ME_BEFORE_PRODUCTION"
# - vegvesenet_api: "TODO_SET_PRODUCTION_KEY"
# - vipps.client_id, client_secret, subscription_key, merchant_serial_number
# - power_office.client_key, application_key

# Re-deploy etter endringer
fly deploy
```

### Test betalingsintegrasjoner lokalt først
1. Sett test-nøkler i development credentials
2. Test Vipps-flyt lokalt
3. Test Power Office faktura lokalt
4. Når begge fungerer → oppdater production credentials
5. Deploy til fly.io

## Nyttige kommandoer

```bash
fly ssh console                    # SSH inn i container
fly postgres connect -a rovde-lager-db  # Koble til database
fly logs --app rovde-lager         # Se logger
fly status --app rovde-lager       # App status
fly scale count 2                  # Skaler til 2 instances
fly scale vm shared-cpu-1x --memory 2048  # Oppgrader VM
```

## Kostnad estimat (fly.io)
- **Hobby tier**: ~$10-15/måned
  - 1x shared-cpu-1x (256MB RAM)
  - Postgres (1GB storage, 2 nodes)
  - 10GB persistent storage

## Neste steg før live
- [ ] Få Vipps production API-nøkler
- [ ] Få Power Office API-nøkler
- [ ] Test betalingsintegrasjoner lokalt
- [ ] Oppdater production credentials
- [ ] Endre tablet_passcode til sterkt passord
- [ ] Eventuelt: sett opp custom domain
- [ ] Eventuelt: sett opp monitoring/alerts
- [ ] Eventuelt: sett opp backup-strategi for database

## Troubleshooting

### Database connection issues
Sjekk at `DATABASE_URL` secret er satt (skjer automatisk ved `postgres attach`):
```bash
fly secrets list
```

### Storage permission issues
Hvis Active Storage ikke fungerer:
```bash
fly ssh console
ls -la /rails/storage
# Sjekk at rails-bruker har tilgang
```

### SSL/Host errors
Verifiser at `APP_HOST` env var matcher ditt domene (satt i fly.toml).
