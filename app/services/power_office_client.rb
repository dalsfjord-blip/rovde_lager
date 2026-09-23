class PowerOfficeClient
  class ConfigurationError < StandardError; end
  class RequestError < StandardError
    attr_reader :status, :retryable

    def initialize(status:, retryable:)
      @status = status
      @retryable = retryable
      super("PowerOffice request failed with status #{status}")
    end
  end

  TOKEN_URL = "https://goapi.poweroffice.net/Demo/OAuth/Token"
  BASE_URL = "https://goapi.poweroffice.net/demo/v2"
  TOKEN_LEEWAY = 60

  def initialize(connection: nil)
    @connection = connection
    @subscription_key = credentials[:subscription_key]
    @application_key = credentials[:application_key]
    @client_key = credentials[:client_key]
    @token_url = credentials[:token_url].presence || TOKEN_URL
    @base_url = credentials[:base_url].presence || BASE_URL
  end

  def create_customer(name:, organization_number:, email:)
    post("customers", {
      Name: name,
      LegalNumber: organization_number,
      EmailAddress: email
    })
  end

  def create_sales_order(customer_id:, description:, unit_price:)
    post("salesorders", {
      CustomerId: customer_id,
      SalesOrderLines: [
        {
          Description: description,
          Quantity: 1,
          UnitPrice: unit_price,
          VatCode: "3"
        }
      ]
    })
  end

  def invoice_sales_order(sales_order_id)
    post("salesorders/#{sales_order_id}/invoice", {})
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
    Rails.cache.fetch("power_office/access_token", expires_in: token_ttl) { fetch_access_token }
  end

  def fetch_access_token
    ensure_configured!
    response = connection.post(@token_url) do |request|
      request.headers["Authorization"] = "Basic #{Base64.strict_encode64("#{@application_key}:#{@client_key}")}"
      request.headers["Ocp-Apim-Subscription-Key"] = @subscription_key
      request.headers["Content-Type"] = "application/x-www-form-urlencoded"
      request.body = "grant_type=client_credentials"
    end
    body = parse_response(response)
    @token_ttl = [ body.fetch("expires_in", 3600).to_i - TOKEN_LEEWAY, 1 ].max
    body.fetch("access_token")
  end

  def token_ttl
    @token_ttl || 3000
  end

  def parse_response(response)
    return JSON.parse(response.body) if response.success? && response.body.present?
    return {} if response.success?

    raise RequestError.new(status: response.status, retryable: response.status >= 500 || response.status == 429)
  rescue JSON::ParserError
    raise RequestError.new(status: response.status, retryable: false)
  end

  def connection
    @connection ||= Faraday.new(request: { open_timeout: 5, timeout: 10 })
  end

  def credentials
    Rails.application.credentials.fetch(:power_office, {}).merge(
      subscription_key: ENV["POWER_OFFICE_SUBSCRIPTION_KEY"],
      application_key: ENV["POWER_OFFICE_APPLICATION_KEY"],
      client_key: ENV["POWER_OFFICE_CLIENT_KEY"]
    ) { |_key, credential_value, environment_value| environment_value.presence || credential_value }
  end

  def ensure_configured!
    return if [@subscription_key, @application_key, @client_key].all?(&:present?)

    raise ConfigurationError, "PowerOffice credentials mangler"
  end
end
