## Vurdering for ny implementering

### Hva som ble gjort feil i nåværende kode



1. Del 2 og 3 implementert for tidlig
  • README spesifiserer tydelig å starte med Del 1 først (objektregistrering)
  • Del 2 (kundeinformasjon) og Del 3 (betaling) skulle komme senere
  • Nå er arkitekturen preget av å måtte "fylle inn" mellom ferdigkodede deler
2. Autentiseringen er ovorkomplisert
  •  Authenticatable  concern med cookies i stedet for enkel session
  • PIN-validering spredt mellom  PinAuthentication , credentials, og ENV-variabler
  • README sier bare: "Ved oppstart kreves innlogging/PIN-kode" - dette burde vært 20 linjer kode
3. Databasemodellen matcher ikke README
  •  StorageItem  har kun  meters , men skulle ha  registration_number  eller  description   •  Vehicle -modellen eksisterer, men README nevner den ikke
  • Duplikering: Vehicle-data lagres både i  StorageItem  og separat  Vehicle -tabell
4. JSON i form submissions
  •  items_json  som JSON-string i form er unødvendig komplekst
  • Rails nested attributes ( accepts_nested_attributes_for ) ville vært enklere og mer standard
5. Manglende features fra README
  • Ingen bildeopplasting (Active Storage ikke satt opp)
  • Ingen kontraktsvisning med scroll-to-accept
  • Ingen betalingsvalg (Vipps/Faktura)
  • Ingen kvitteringsside
  • Fokus har vært på å løse JSON-problemer i stedet for å bygge features


### Anbefaling for ny implementering


#### Alternativ 1: Start helt på nytt (anbefalt)

Estimat: 4-6 timer for komplett Del 1

Fordeler:

• Ren arkitektur fra starten
• Følger README nøyaktig
• Unngår teknisk gjeld
• Lettere å teste steg-for-steg

Fremgangsmåte:

  rails new rovde_lager_v2 --css=tailwind --database=postgresql


Implementeringsrekkefølge:

1. PIN-autentisering (30 min)
2. Database-modeller:  RentalAgreement  +  StorageItem  (30 min)
3. Del 1 view: dynamiske rader med Stimulus (2 timer)
4. SVV API-integrasjon med graceful fallback (1 time)
5. Prisberegning live (30 min)
6. Testing og finjustering (1 time)

#### Alternativ 2: Refaktorere nåværende kode

Estimat: 3-4 timer

Nødvendige endringer:

1. Fjern Del 2 og Del 3 views/controllers
2. Forenkle autentisering til basic session-basert PIN
3. Endre  StorageItem  til å bruke nested attributes i stedet for JSON
4. Fjern  Vehicle -modellen eller gjør den til en ren cache-tabell
5. Bygg ut Del 1 view med riktig Stimulus-funksjonalitet

Fordeler:

• Beholder database-migrasjoner
• Beholder Tailwind-oppsett
• Mindre arbeid enn full rewrite

Ulemper:

• Fortsatt teknisk gjeld fra workarounds
• Risiko for flere JSON-problemer
• Vanskeligere å resonnere om koden

### Min klare anbefaling


Start på nytt med Rails 8 + JSON 2.7 locked fra dag 1.

Grunn:

• Del 1 er kjernen av appen - den må være solid
• Nåværende kode har for mange workarounds og avvik fra README
• 4-6 timer investering nå sparer deg for dager med debugging senere
• Du får en ren arkitektur som er lett å bygge videre på til Del 2 og 3

Kritisk læring å ta med:

  # Gemfile - ALLTID låse JSON-versjonen med Rails 8.1
  gem "json", "~> 2.7.0"