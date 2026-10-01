 om en velger Hamneleige på landing page:
 
  Vi skal sette opp "Logg inn med Vipps" (Vipps Login) for den nye landingssiden for havneleie på `/hamneleige/login`.

Her er konfigurasjonen og flyten som skal gjelde:

1. GEM OG AVHENGIGHETER:
- Sjekk om gemyene `omniauth-vipps` (eller `omniauth-openid-connect`) og `omniauth-rails_csrf_protection` er installert. Hvis ikke, legg dem til i Gemfile og kjør bundle install.

2. KONFIGURASJON / INITIALIZER:
- Gjenbruk våre eksisterende Vipps-credentials (`client_id` og `client_secret`) som vi allerede har satt opp for Vipps Betaling i appen.
- Konfigurer OmniAuth initializer (`config/initializers/omniauth.rb`) for Vipps med scope: "openid name email phoneNumber".
- Sett opp callback-path til `/auth/vipps/callback`.

3. ROUTES:
- Legg til route for callback: `get '/auth/vipps/callback', to: 'sessions#vipps_callback'`
- Legg til route for feilhåndtering: `get '/auth/failure', to: 'sessions#failure'`
- Legg til landingsside-route: `/hamneleige/login` og selve prosesseringssiden: `/hamneleige`.

4. CONTROLLER OG LOGIKK (`app/controllers/sessions_controller.rb`):
- I `vipps_callback`: Hent ut navn, e-post og telefonnummer fra `request.env['omniauth.auth']`.
- Finn eller opprett bruker i databasen basert på telefonnummer/e-post.
- Lagre `user_id` i `session[:user_id]`.
- Omdiriger brukeren videre til `/hamneleige` med en bekreftelsesmelding (flash notice) om at de er innlogget.

5. VIEWS (UI):
- Opprett/oppdater landingssiden på `/hamneleige/login` med et rent Tailwind CSS-design.
- Siden skal ha en spisset overskrift for registrering av havneleie, og en tydelig Vipps-oransje knapp: "Logg inn med Vipps" (som poster/lenker til `/auth/vipps`).
- På `/hamneleige`-siden skal brukeren se sin innloggede status og et skjema for å registrere liggedøgn og be om faktura. Vi bruker samme oppsett på dette som vi gjør på bedriftskunde i storage_items, men uten mulighet for å betale med vipps, bare send faktura. Faktura må inneholde antall døgn (1500,- pr døgn + mva) også må en ha mulighet for å velge antall døgn. Minstepris er 1500,- ( ett døgn)

