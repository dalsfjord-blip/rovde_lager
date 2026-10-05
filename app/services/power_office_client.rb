class PowerOfficeClient
  class ConfigurationError < StandardError; end
  class RequestError < StandardError
    attr_reader :status, :retryable, :detail

    def initialize(status:, retryable:, detail: nil)
      @status = status
      @retryable = retryable
      @detail = detail
      super("PowerOffice returnerte status #{status}")
    end
  end

  OUTGOING_VAT_CODE_25_PERCENT = "3"
  SALES_ACCOUNT_RANGE = "3000-3999"

  def initialize(connection: nil)
    @connection = connection
    @application_key = credentials[:application_key]
    @client_key = credentials[:client_key]
    @subscription_key = credentials[:subscription_key]
    @token_url = credentials[:token_url].presence || "https://goapi.poweroffice.net/Demo/OAuth/Token"
    @base_url = credentials[:base_url].presence || "https://goapi.poweroffice.net/Demo/v2"
  end

  def configured?
    [ @application_key, @client_key, @subscription_key ].all?(&:present?)
  end

  # Offisiell PowerOffice Go API v2 kaller bedriftskunden "Customer" og bruker
  # feltnavnene Name/OrganizationNumber/EmailAddress (bekreftet mot Demo-miljøet).
  def create_customer(name:, organization_number:, email:)
    post("Customers", {
      Name: name,
      OrganizationNumber: organization_number,
      EmailAddress: email
    })
  end

  # Finner en eksisterende salgskonto (3000-3999) med gitt mva-kode, slik at et
  # produkt kan kobles til riktig mva-behandling ved fakturering.
  def find_sales_account(vat_code: OUTGOING_VAT_CODE_25_PERCENT, account_range: SALES_ACCOUNT_RANGE)
    accounts = get("GeneralLedgerAccounts", accountNos: account_range)
    Array(accounts).find { |account| account["VatCode"] == vat_code }
  end

  def find_product(code:)
    products = get("Products", codes: code)
    Array(products).find { |product| product["Code"] == code }
  end

  def create_product(code:, name:, sales_account_id:)
    post("Products", {
      Code: code,
      Name: name,
      StandardSalesAccountId: sales_account_id
    })
  end

  # Finner eller oppretter produktet som representerer tjenesten som faktureres.
  # Produktet kobles til en eksisterende salgskonto med riktig mva-kode, slik at
  # salgsordrelinjer som refererer produktet automatisk får riktig mva.
  def ensure_service_product!(code:, name:, vat_code: OUTGOING_VAT_CODE_25_PERCENT)
    existing = find_product(code: code)
    return existing["Id"] if existing

    sales_account = find_sales_account(vat_code: vat_code)
    unless sales_account
      raise ConfigurationError, "Fant ingen salgskonto (#{SALES_ACCOUNT_RANGE}) med mva-kode #{vat_code} i PowerOffice-kontoplanen"
    end

    created = create_product(code: code, name: name, sales_account_id: sales_account["Id"])
    created["Id"]
  end

  # Oppretter en salgsordre (fakturautkast) komplett med linjer i PowerOffice Go API v2.
  # customer_number skal være kundens "Number" fra create_customer-responsen, ikke Id-en.
  def create_sales_order(customer_number:, reference:, lines:)
    post("SalesOrders/Complete", {
      CustomerNo: customer_number,
      CustomerReference: reference,
      ExternalImportReference: reference,
      SalesOrderLines: lines
    })
  end

  # Omdanner salgsordren til en faktura og sender den. Returnerer 202 Accepted
  # ved vellykket kø-plassering; selve sendingen skjer asynkront i PowerOffice
  # og må følges opp med sent_state.
  def create_and_send_invoice(sales_order_id:, delivery_type: "Auto", email: nil, voucher_date: nil)
    payload = { DeliveryType: delivery_type }
    payload[:EmailAddress] = email if email.present?
    payload[:VoucherDate] = voucher_date if voucher_date.present?

    post("SalesOrders/#{sales_order_id}/CreateAndSendInvoice", payload)
  end

  # Poller status på en salgsordre som er under fakturering/sending.
  def sent_state(sales_order_id:)
    get("SalesOrders/SentState", id: sales_order_id)
  end

  # Diagnostikk: lister hvilke rettigheter/moduler integrasjonen faktisk har hos klienten.
  # Krever ingen egen tilgang, kun gyldig token.
  def client_integration_information
    get("ClientIntegrationInformation")
  end

  private

  def post(path, payload)
    ensure_configured!
    response = connection.post("#{@base_url}/#{path}") do |request|
      request.headers["Authorization"] = "Bearer #{access_token}"
      request.headers["Ocp-Apim-Subscription-Key"] = @subscription_key
      request.headers["Content-Type"] = "application/json"
      request.body = payload.to_json
    end
    parse_response(response)
  end

  def get(path, params = {})
    ensure_configured!
    response = connection.get("#{@base_url}/#{path}") do |request|
      request.headers["Authorization"] = "Bearer #{access_token}"
      request.headers["Ocp-Apim-Subscription-Key"] = @subscription_key
      request.params.update(params) if params.present?
    end
    parse_response(response)
  end

  def access_token
    Rails.cache.fetch("power_office/access_token", expires_in: 15.minutes) { fetch_access_token }
  end

  def fetch_access_token
    ensure_configured!
    response = connection.post(@token_url) do |request|
      request.headers["Authorization"] = "Basic #{Base64.strict_encode64("#{@application_key}:#{@client_key}")}"
      request.headers["Ocp-Apim-Subscription-Key"] = @subscription_key
      request.headers["Content-Type"] = "application/x-www-form-urlencoded"
      request.body = "grant_type=client_credentials"
    end
    parse_response(response).fetch("access_token")
  end

  def parse_response(response)
    return JSON.parse(response.body) if response.success? && response.body.present?
    return {} if response.success?

    raise RequestError.new(
      status: response.status,
      retryable: response.status >= 500 || response.status == 429,
      detail: response.body.to_s.truncate(500)
    )
  rescue JSON::ParserError
    raise RequestError.new(status: response.status, retryable: false, detail: response.body.to_s.truncate(500))
  end

  def connection
    @connection ||= Faraday.new(request: { open_timeout: 5, timeout: 10 })
  end

  def credentials
    Rails.application.credentials.fetch(:power_office, {}).merge(
      application_key: ENV["POWEROFFICE_APPLICATION_KEY"],
      client_key: ENV["POWEROFFICE_CLIENT_KEY"],
      subscription_key: ENV["POWEROFFICE_SUBSCRIPTION_KEY"],
      token_url: ENV["POWEROFFICE_TOKEN_URL"],
      base_url: ENV["POWEROFFICE_BASE_URL"]
    ) { |_key, credential_value, environment_value| environment_value.presence || credential_value }
  end

  def ensure_configured!
    return if configured?

    raise ConfigurationError, "PowerOffice-konfigurasjon mangler"
  end
end
