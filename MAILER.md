# E-post funksjonalitet

## Status

**Hva som finnes:**
- ✅ `ApplicationMailer` (basis for alle mailers)
- ✅ Mailer layouts (HTML og tekst)
- ✅ `ReceiptController#email` metode (men blokkert med feilmelding)
- ✅ Checkbox `send_email_copy` i skjemaet

**Hva som mangler:**
- ❌ Mailer-klasse for avtalebekreftelse (`RentalAgreementMailer`)
- ❌ E-post-maler (HTML + tekst)
- ❌ SMTP-konfigurasjon for production
- ❌ Implementering av e-post-sending ved fullført registrering

## E-post-tjenester (SMTP)

### Alternativ 1: Gmail/Google Workspace (Enklest for testing)
**Pris:** Gratis (med Gmail-konto) eller Google Workspace
**Begrensninger:** 500 e-post/dag
**Oppsett:**
```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: 'smtp.gmail.com',
  port: 587,
  user_name: ENV['SMTP_USERNAME'],  # din@gmail.com
  password: ENV['SMTP_PASSWORD'],    # App-spesifikt passord
  authentication: :plain,
  enable_starttls_auto: true
}
```

**Sett secrets på fly.io:**
```bash
fly secrets set \
  SMTP_USERNAME=din@gmail.com \
  SMTP_PASSWORD=ditt_app_passord \
  --app rovde-lager
```

**Note:** Du må aktivere 2-faktor-autentisering og generere "App-spesifikt passord" i Google-kontoen.

---

### Alternativ 2: SendGrid (Anbefalt for produksjon)
**Pris:** 
- Gratis tier: 100 e-post/dag (for alltid)
- Essentials: $19.95/måned for 50,000 e-post/måned

**Fordeler:**
- Profesjonell
- E-post-statistikk (åpningsrate, klikk)
- God leveringsrate
- Enkel API

**Oppsett:**
```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: 'smtp.sendgrid.net',
  port: 587,
  user_name: 'apikey',
  password: ENV['SENDGRID_API_KEY'],
  authentication: :plain,
  enable_starttls_auto: true
}
```

**Sett secrets på fly.io:**
```bash
fly secrets set SENDGRID_API_KEY=<din_api_key> --app rovde-lager
```

**Registrering:** https://sendgrid.com/

---

### Alternativ 3: Postmark (Best for transaksjonse-post)
**Pris:** 
- Gratis tier: 100 e-post/måned
- $15/måned for 10,000 e-post

**Fordeler:**
- Laget spesielt for transaksjonse-post (bekreftelser, fakturaer)
- Svært god leveringsrate
- Detaljert logging
- Rask levering

**Oppsett:**
```ruby
# Gemfile
gem 'postmark-rails'

# config/environments/production.rb
config.action_mailer.delivery_method = :postmark
config.action_mailer.postmark_settings = {
  api_token: ENV['POSTMARK_API_TOKEN']
}
```

**Sett secrets på fly.io:**
```bash
fly secrets set POSTMARK_API_TOKEN=<din_api_token> --app rovde-lager
```

**Registrering:** https://postmarkapp.com/

---

### Alternativ 4: Mailgun
**Pris:** Pay-as-you-go, ~$1 per 1000 e-post

**Oppsett:**
```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: 'smtp.mailgun.org',
  port: 587,
  user_name: ENV['MAILGUN_SMTP_LOGIN'],
  password: ENV['MAILGUN_SMTP_PASSWORD'],
  authentication: :plain,
  enable_starttls_auto: true
}
```

**Registrering:** https://www.mailgun.com/

---

## Min anbefaling

**For testing nå:**
- Start med **Gmail** (gratis, enkelt oppsett)

**For produksjon:**
- **SendGrid** gratis tier (100/dag) hvis du sender < 3000 e-post/måned
- **Postmark** hvis du vil ha best mulig leveringsrate og kan betale litt

---

## Hva må implementeres

### 1. Lag RentalAgreementMailer

```ruby
# app/mailers/rental_agreement_mailer.rb
class RentalAgreementMailer < ApplicationMailer
  def confirmation_email(agreement)
    @agreement = agreement
    @items = agreement.storage_items
    
    mail(
      to: agreement.customer_email,
      subject: "Bekreftelse på lagerregistrering - #{agreement.reference_number}"
    )
  end
  
  def invoice_notification(agreement)
    @agreement = agreement
    
    mail(
      to: agreement.customer_email,
      subject: "Faktura - #{agreement.reference_number}"
    )
  end
end
```

### 2. Lag e-post-maler

**HTML-versjon:**
```erb
<!-- app/views/rental_agreement_mailer/confirmation_email.html.erb -->
<h1>Takk for din registrering!</h1>

<p>Hei <%= @agreement.customer_name %>,</p>

<p>Din registrering er mottatt. Her er detaljene:</p>

<h2>Referansenummer: <%= @agreement.reference_number %></h2>

<h3>Dine gjenstander:</h3>
<ul>
  <% @items.each do |item| %>
    <li>
      <%= item.registration_number %> - <%= item.description %>
      (<%= item.meters %> meter)
    </li>
  <% end %>
</ul>

<p><strong>Total pris:</strong> <%= number_to_currency(@agreement.total_price, unit: "kr") %></p>
<p><strong>Betalingsmåte:</strong> <%= @agreement.payment_method == 'vipps' ? 'Vipps' : 'Faktura' %></p>
<p><strong>Hentetidspunkt:</strong> <%= l(@agreement.pickup_date, format: :long) if @agreement.pickup_date %></p>

<p>Med vennlig hilsen,<br>
Rovde Lager</p>
```

**Tekst-versjon:**
```erb
<!-- app/views/rental_agreement_mailer/confirmation_email.text.erb -->
Takk for din registrering!

Hei <%= @agreement.customer_name %>,

Din registrering er mottatt. Her er detaljene:

Referansenummer: <%= @agreement.reference_number %>

Dine gjenstander:
<% @items.each do |item| %>
- <%= item.registration_number %> - <%= item.description %> (<%= item.meters %> meter)
<% end %>

Total pris: <%= number_to_currency(@agreement.total_price, unit: "kr") %>
Betalingsmåte: <%= @agreement.payment_method == 'vipps' ? 'Vipps' : 'Faktura' %>
Hentetidspunkt: <%= l(@agreement.pickup_date, format: :long) if @agreement.pickup_date %>

Med vennlig hilsen,
Rovde Lager
```

### 3. Send e-post ved fullført registrering

**Endre i `ReceiptController`:**
```ruby
class ReceiptController < ApplicationController
  before_action :load_agreement

  def show
  end

  def email
    if @agreement.customer_email.present?
      RentalAgreementMailer.confirmation_email(@agreement).deliver_later
      redirect_to receipt_path, notice: "E-post sendt til #{@agreement.customer_email}"
    else
      redirect_to receipt_path, alert: "Ingen e-postadresse registrert."
    end
  rescue StandardError => e
    Rails.logger.error "E-post feilet: #{e.message}"
    redirect_to receipt_path, alert: "E-post kunne ikke sendes. Prøv igjen senere."
  end

  private

  def load_agreement
    @agreement = current_agreement
    redirect_to storage_items_path, alert: "Registrer minst ett lagringsobjekt først." unless @agreement
  end
end
```

**Eller automatisk ved fullført registrering:**
```ruby
# I customer_info_controller.rb eller der avtalen fullføres
if @agreement.save
  # Send e-post hvis kunden ønsker kopi
  RentalAgreementMailer.confirmation_email(@agreement).deliver_later if @agreement.send_email_copy
  
  redirect_to receipt_path
end
```

### 4. Oppdater ApplicationMailer

```ruby
# app/mailers/application_mailer.rb
class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('SMTP_FROM_EMAIL', 'noreply@rovdelager.no')
  layout "mailer"
end
```

### 5. Sett FROM-adresse på fly.io

```bash
fly secrets set SMTP_FROM_EMAIL=noreply@rovdelager.no --app rovde-lager
```

---

## Development oppsett (lokalt testing)

For å teste e-post lokalt uten å sende ekte e-post:

### Alternativ 1: letter_opener (anbefalt)

```ruby
# Gemfile
group :development do
  gem 'letter_opener'
end

# config/environments/development.rb
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.perform_deliveries = true
```

E-post åpnes automatisk i nettleseren i stedet for å sendes.

### Alternativ 2: Logg til konsoll

```ruby
# config/environments/development.rb
config.action_mailer.delivery_method = :test
config.action_mailer.perform_deliveries = true
```

E-post logges kun i konsollen.

---

## Oppsummering

### Steg for å få e-post til å fungere:

1. **Velg e-post-tjeneste** (Gmail for testing, SendGrid/Postmark for produksjon)
2. **Implementer mailer-klasse og maler** (kode over)
3. **Konfigurer SMTP i production.rb**
4. **Sett secrets på fly.io** (SMTP credentials)
5. **Test lokalt** med letter_opener
6. **Deploy** og test i produksjon

### Estimert tid:
- Koding: 1-2 timer
- Oppsett av e-post-tjeneste: 30 minutter
- Testing: 30 minutter

### Kostnad:
- Gmail: Gratis (begrenset)
- SendGrid free tier: Gratis (100/dag)
- Postmark: $15/måned (10,000 e-post)

---

## Neste steg

Når du er klar til å implementere:
1. Velg e-post-tjeneste
2. Gi beskjed, så implementerer jeg koden
3. Test lokalt
4. Deploy til produksjon
