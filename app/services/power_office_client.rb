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
    post("customers", {
      Name: name,
      OrganizationNumber: organization_number,
      EmailAddress: email
    })
  end

  # Oppretter et fakturautkast ("OutgoingInvoice" i PowerOffice Go API v2).
  # customer_number skal være kundens "Number" fra create_customer-responsen,
  # ikke Id-en.
  def create_invoice(customer_number:, description:, unit_price:, reference:, vat_code: OUTGOING_VAT_CODE_25_PERCENT)
    post("OutgoingInvoice", {
      CustomerCode: customer_number,
      CustomerReference: reference,
      ExternalImportReference: reference,
      OutgoingInvoiceLines: [
        {
          Description: description,
          Quantity: 1,
          UnitPrice: unit_price,
          VatCode: vat_code
        }
      ]
    })
  end

  def send_invoice(invoice_id:, email:)
    post("OutgoingInvoice/SendInvoice", {
      InvoiceId: invoice_id,
      Email: email
    })
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
