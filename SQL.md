# SQL og Database-informasjon

## Database-struktur

### rental_agreements (Leieavtaler)

Hovedtabell som inneholder all informasjon om kundens leieavtale.

**Tabell:** `rental_agreements`

| Kolonne | Type | Beskrivelse |
|---------|------|-------------|
| `id` | bigint | Primærnøkkel (auto-generert) |
| `reference_number` | string | Unik referanse (LAG-XXXX) |
| `customer_name` | string | Kundens navn |
| `customer_email` | string | Kundens e-postadresse |
| `customer_phone` | string | Kundens telefonnummer |
| `payment_method` | string | Betalingsmåte: "vipps" eller "invoice" |
| `payment_status` | string | Status på betaling (vipps-relatert) |
| `total_meters` | decimal | Totalt antall meter lagring |
| `total_price` | decimal | Total pris i NOK |
| `pickup_date` | date | Dato for henting av gjenstander |
| `contract_approved` | boolean | Om avtalevilkår er godkjent |
| `send_email_copy` | boolean | Om kunde ønsker e-postkopi |
| `special_needs` | boolean | Om det er spesielle behov |
| `special_needs_notes` | text | Beskrivelse av spesielle behov |
| **Bedriftsinfo (kun faktura)** | | |
| `billing_company_name` | string | Firmanavn for fakturering |
| `billing_organization_number` | string | Organisasjonsnummer (9 siffer) |
| **Power Office integrasjon** | | |
| `power_office_customer_id` | string | Kunde-ID i Power Office |
| `power_office_sales_order_id` | string | Salgsordre-ID i Power Office |
| `power_office_invoice_id` | string | Faktura-ID i Power Office |
| `power_office_invoice_number` | string | Fakturanummer fra Power Office |
| `invoice_sync_status` | string | Synkroniseringsstatus til Power Office |
| `invoice_sync_error` | string | Feilmelding ved synkronisering |
| `invoice_synced_at` | datetime | Tidspunkt for siste synkronisering |
| **Tidsstempler** | | |
| `created_at` | datetime | Opprettelsestidspunkt |
| `updated_at` | datetime | Sist oppdatert |

---

### storage_items (Lagringsobjekter)

Gjenstander som skal lagres (tilknyttet en leieavtale).

**Tabell:** `storage_items`

| Kolonne | Type | Beskrivelse |
|---------|------|-------------|
| `id` | bigint | Primærnøkkel |
| `rental_agreement_id` | bigint | Fremmednøkkel til rental_agreements |
| `registration_number` | string | Registreringsnummer (bil/båt) |
| `description` | text | Beskrivelse/merke av gjenstand |
| `meters` | decimal | Antall meter gjenstand tar |
| `created_at` | datetime | Opprettelsestidspunkt |
| `updated_at` | datetime | Sist oppdatert |

**Relasjon:** En leieavtale kan ha mange gjenstander (`has_many :storage_items`)

---

### active_storage_attachments (Bilder)

Bilder/vedlegg knyttet til leieavtaler.

**Tabell:** `active_storage_attachments`

| Kolonne | Type | Beskrivelse |
|---------|------|-------------|
| `id` | bigint | Primærnøkkel |
| `name` | string | Navn på vedlegg (f.eks. "photos") |
| `record_type` | string | Type record (f.eks. "RentalAgreement") |
| `record_id` | bigint | ID til record (rental_agreement_id) |
| `blob_id` | bigint | Fremmednøkkel til active_storage_blobs |
| `created_at` | datetime | Opprettelsestidspunkt |

**Relasjon:** En leieavtale kan ha opptil 10 bilder (`has_many_attached :photos`)

---

## Nyttige SQL-spørringer

### 1. Alle ufakturerte avtaler (for etterfakturering)

```sql
SELECT 
  reference_number,
  customer_name,
  customer_email,
  customer_phone,
  billing_company_name,
  billing_organization_number,
  total_price,
  total_meters,
  payment_method,
  created_at
FROM rental_agreements
WHERE payment_method = 'invoice'
  AND power_office_invoice_id IS NULL
ORDER BY created_at DESC;
```

---

### 2. Alle registreringer siste 7 dager

```sql
SELECT 
  reference_number,
  customer_name,
  customer_email,
  payment_method,
  total_price,
  created_at
FROM rental_agreements
WHERE created_at >= NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;
```

---

### 3. Komplett oversikt av én avtale med gjenstander

```sql
SELECT 
  ra.reference_number,
  ra.customer_name,
  ra.customer_email,
  ra.customer_phone,
  ra.total_price,
  ra.payment_method,
  si.registration_number,
  si.description,
  si.meters
FROM rental_agreements ra
LEFT JOIN storage_items si ON si.rental_agreement_id = ra.id
WHERE ra.reference_number = 'LAG-XXXX'
ORDER BY si.created_at;
```

---

### 4. Totalt antall registreringer per betalingsmåte

```sql
SELECT 
  payment_method,
  COUNT(*) as antall,
  SUM(total_price) as total_omsetning
FROM rental_agreements
GROUP BY payment_method;
```

---

### 5. Alle bedriftskunder (faktura)

```sql
SELECT 
  reference_number,
  billing_company_name,
  billing_organization_number,
  customer_name,
  customer_email,
  customer_phone,
  total_price,
  created_at
FROM rental_agreements
WHERE payment_method = 'invoice'
  AND billing_company_name IS NOT NULL
ORDER BY created_at DESC;
```

---

### 6. Gjenstander uten fullført registrering (mangler avtale)

Hvis du har half-fullførte registreringer i session men ikke i database, kan du ikke finne dem i SQL.
Men du kan finne avtaler som mangler gjenstander:

```sql
SELECT 
  ra.reference_number,
  ra.customer_name,
  COUNT(si.id) as antall_gjenstander
FROM rental_agreements ra
LEFT JOIN storage_items si ON si.rental_agreement_id = ra.id
GROUP BY ra.id, ra.reference_number, ra.customer_name
HAVING COUNT(si.id) = 0;
```

---

### 7. Registreringer med spesielle behov

```sql
SELECT 
  reference_number,
  customer_name,
  customer_phone,
  special_needs_notes,
  created_at
FROM rental_agreements
WHERE special_needs = true
ORDER BY created_at DESC;
```

---

### 8. Månedlig omsetning

```sql
SELECT 
  DATE_TRUNC('month', created_at) as måned,
  COUNT(*) as antall_registreringer,
  SUM(total_price) as total_omsetning,
  AVG(total_price) as gjennomsnittlig_pris
FROM rental_agreements
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY måned DESC;
```

---

### 9. Registreringer som venter på Vipps-betaling

```sql
SELECT 
  reference_number,
  customer_name,
  customer_email,
  total_price,
  payment_status,
  created_at
FROM rental_agreements
WHERE payment_method = 'vipps'
  AND (payment_status IS NULL OR payment_status != 'paid')
ORDER BY created_at DESC;
```

---

### 10. Power Office synkroniseringsfeil

```sql
SELECT 
  reference_number,
  customer_name,
  billing_company_name,
  invoice_sync_status,
  invoice_sync_error,
  invoice_synced_at
FROM rental_agreements
WHERE invoice_sync_status = 'error'
  OR invoice_sync_error IS NOT NULL
ORDER BY invoice_synced_at DESC;
```

---

## Eksport til CSV for Excel

### Via psql (PostgreSQL kommandolinje)

```sql
-- Koble til database
\c rovde_lager_production

-- Eksporter til CSV
\copy (SELECT reference_number, customer_name, customer_email, customer_phone, billing_company_name, billing_organization_number, total_price, payment_method, created_at FROM rental_agreements WHERE payment_method = 'invoice' AND power_office_invoice_id IS NULL ORDER BY created_at DESC) TO '/tmp/ufakturerte.csv' WITH CSV HEADER;
```

### Via fly.io

```bash
# Koble til database
fly postgres connect -a rovde-lager-db

# Bytt til riktig database
\c rovde_lager_production

# Kjør SQL-spørring og eksporter
\copy (SELECT * FROM rental_agreements) TO STDOUT WITH CSV HEADER > registreringer.csv
```

---

## Tilgang til database

### Via fly.io CLI

```bash
# Koble til database interaktivt
fly postgres connect -a rovde-lager-db

# Når du er inne, bytt database
\c rovde_lager_production

# Kjør SQL-spørringer
SELECT COUNT(*) FROM rental_agreements;

# Avslutt
\q
```

### Database-detaljer (fra deployment)

**Database-navn:**
- `rovde_lager_production` (hoveddata)
- `rovde_lager_production_cache` (cache)
- `rovde_lager_production_queue` (bakgrunnsjobber)
- `rovde_lager_production_cable` (websockets)

**Bruker:** `rovde_lager`

**Connection string:** Satt automatisk i `DATABASE_URL` environment variable

---

## Data som IKKE lagres

Følgende data lagres **kun i session** og forsvinner ved fullført registrering eller timeout:

- Ufullstendige registreringer (før "Fullfør registrering" trykkes)
- Midlertidig gjenstands-data før de legges til
- Session-state (innlogget status, nåværende steg i prosessen)

**NB:** Når kunde trykker "Fullfør registrering" skrives ALL data til `rental_agreements` og `storage_items` tabellene.

---

## Backup og data-sikkerhet

### Manuell backup

```bash
# Ta backup av hele databasen
fly postgres connect -a rovde-lager-db
pg_dump rovde_lager_production > backup_$(date +%Y%m%d).sql
```

### Automatisk backup (fly.io)

Fly.io tar automatisk snapshots av volumes. For database-backup, vurder:
- Fly.io Managed Postgres (har automatisk backup)
- Scheduled task som tar daglig dump til external storage (S3)

---

## Tips for etterfakturering

Når du skal fakturere manuelt uten Power Office:

1. **Eksporter data:**
```sql
\copy (
  SELECT 
    ra.reference_number as "Referanse",
    ra.customer_name as "Kunde",
    ra.billing_company_name as "Firma",
    ra.billing_organization_number as "Org.nr",
    ra.customer_email as "E-post",
    ra.customer_phone as "Telefon",
    ra.total_meters as "Meter",
    ra.total_price as "Pris",
    STRING_AGG(si.registration_number || ' - ' || si.description, ', ') as "Gjenstander",
    ra.created_at as "Registrert"
  FROM rental_agreements ra
  LEFT JOIN storage_items si ON si.rental_agreement_id = ra.id
  WHERE ra.payment_method = 'invoice' 
    AND ra.power_office_invoice_id IS NULL
  GROUP BY ra.id
  ORDER BY ra.created_at DESC
) TO '/tmp/fakturering.csv' WITH CSV HEADER;
```

2. Importer CSV til Excel/Google Sheets
3. Lag fakturaer manuelt
4. Marker som fakturert i systemet (oppdater `power_office_invoice_id` eller lag en `manually_invoiced` kolonne)

---

## Nyttige psql-kommandoer

```sql
\dt                          -- List alle tabeller
\d rental_agreements         -- Vis struktur for tabell
\d+ rental_agreements        -- Vis detaljert struktur
\l                           -- List alle databaser
\du                          -- List alle brukere
\x                           -- Toggle expanded output (for brede resultater)
\timing on                   -- Vis kjøretid for queries
```

---

## Kontakt meg hvis du trenger

- [ ] Mer komplekse SQL-spørringer
- [ ] Migrering for nye kolonner
- [ ] Database-optimalisering (indekser)
- [ ] Automatisk backup-løsning
- [ ] Rapporter/statistikk-queries
